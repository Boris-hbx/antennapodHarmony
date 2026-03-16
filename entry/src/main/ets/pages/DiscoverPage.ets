import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { Feed, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { addOrUpdateFeed } from 'datastore';
import { getTopPodcasts, httpRequest, prepareUrl, parseFeed, searchPodcasts } from 'network';
import type { ItunesResult, FeedParseResult } from 'network';

/**
 * 发现页 — 热门播客网格 + 国家选择器 + 隐藏功能
 * Task-027: 对照 Android DiscoveryFragment
 */

interface CountryItem {
  code: string;
  name: string;
}

@Entry
@Component
struct DiscoverPage {
  @State topFeeds: ItunesResult[] = [];
  @State isLoading: boolean = false;
  @State selectedCountry: string = 'CN';
  @State hiddenFeedUrls: Set<string> = new Set();
  @State showCountryPicker: boolean = false;

  private prefs: preferences.Preferences | null = null;

  readonly countries: CountryItem[] = [
    { code: 'CN', name: '中国' },
    { code: 'US', name: '美国' },
    { code: 'GB', name: '英国' },
    { code: 'DE', name: '德国' },
    { code: 'JP', name: '日本' },
    { code: 'KR', name: '韩国' },
    { code: 'FR', name: '法国' },
    { code: 'AU', name: '澳大利亚' },
    { code: 'CA', name: '加拿大' },
    { code: 'TW', name: '中国台湾' },
    { code: 'HK', name: '中国香港' },
    { code: 'IN', name: '印度' },
  ];

  aboutToAppear(): void {
    this.initPrefs();
  }

  async initPrefs(): Promise<void> {
    this.prefs = await preferences.getPreferences(getContext(this), 'discover_prefs');
    // 恢复国家设置
    const savedCountry = await this.prefs.get('discover_country', 'CN');
    this.selectedCountry = savedCountry as string;
    // 恢复隐藏列表
    const hiddenJson = await this.prefs.get('discover_hidden_feeds', '[]');
    try {
      const arr = JSON.parse(hiddenJson as string) as string[];
      this.hiddenFeedUrls = new Set(arr);
    } catch (_e) {
      this.hiddenFeedUrls = new Set();
    }
    await this.loadTopPodcasts();
  }

  async loadTopPodcasts(): Promise<void> {
    this.isLoading = true;
    try {
      const all = await getTopPodcasts(this.selectedCountry, 24);
      this.topFeeds = all.filter((f: ItunesResult) => !this.hiddenFeedUrls.has(f.feedUrl));
    } catch (_e) {
      this.topFeeds = [];
    }
    this.isLoading = false;
  }

  async saveHiddenList(): Promise<void> {
    if (this.prefs === null) return;
    const arr: string[] = [];
    this.hiddenFeedUrls.forEach((url: string) => arr.push(url));
    await this.prefs.put('discover_hidden_feeds', JSON.stringify(arr));
    await this.prefs.flush();
  }

  async saveCountry(): Promise<void> {
    if (this.prefs === null) return;
    await this.prefs.put('discover_country', this.selectedCountry);
    await this.prefs.flush();
  }

  getCountryName(): string {
    const found = this.countries.find((c: CountryItem) => c.code === this.selectedCountry);
    return found !== undefined ? found.name : this.selectedCountry;
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { router.back(); })

        Text('发现')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 4 })

        Blank()

        // 国家选择入口
        Row() {
          SymbolGlyph($r('sys.symbol.house'))
            .fontSize(16)
            .fontColor(['#0078C2'])
            .margin({ right: 4 })
          Text(this.getCountryName())
            .fontSize(14)
            .fontColor('#0078C2')
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(12)
            .fontColor(['#0078C2'])
            .margin({ left: 2 })
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(16)
        .backgroundColor('#E3F2FD')
        .onClick(() => { this.showCountryPicker = true; })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)

      // 标题
      Text('热门播客')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#212121')
        .padding({ left: 16, top: 4, bottom: 8 })
        .width('100%')

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载中...').fontSize(14).fontColor('#444444').margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.topFeeds.length === 0) {
        Column() {
          Text('暂无热门播客')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 60 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 热门播客网格 — 3列
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.topFeeds, (feed: ItunesResult) => {
              Column() {
                if (feed.artworkUrl100.length > 0) {
                  Image(feed.artworkUrl100)
                    .width('100%')
                    .aspectRatio(1)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                } else {
                  Column() {
                    Text('🎙️').fontSize(28)
                  }
                  .width('100%')
                  .aspectRatio(1)
                  .borderRadius(8)
                  .backgroundColor('#F0F0F0')
                  .justifyContent(FlexAlign.Center)
                }
                Text(feed.trackName)
                  .fontSize(12)
                  .fontColor('#1A1A1A')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })
                  .width('100%')
                Text(feed.artistName)
                  .fontSize(11)
                  .fontColor('#888888')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
                  .width('100%')
              }
              .width('30%')
              .margin({ left: '1.5%', right: '1.5%', bottom: 16 })
              .onClick(() => {
                this.subscribePodcast(feed);
              })
              .gesture(
                LongPressGesture({ repeat: false })
                  .onAction(() => {
                    this.showHideAction(feed);
                  })
              )
            }, (feed: ItunesResult) => feed.feedUrl)
          }
          .padding({ left: 8, right: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showCountryPicker, () => { this.countryPickerSheet(); }, {
      detents: [SheetSize.MEDIUM],
      showClose: false,
      dragBar: true
    })
  }

  @Builder
  countryPickerSheet() {
    Column() {
      Text('选择国家/地区')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 20, top: 16, bottom: 12 })
        .width('100%')

      List() {
        ForEach(this.countries, (country: CountryItem) => {
          ListItem() {
            Row() {
              Text(country.name)
                .fontSize(16)
                .fontColor('#1A1A1A')
                .layoutWeight(1)
              if (this.selectedCountry === country.code) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(18)
                  .fontColor(['#0078C2'])
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .onClick(() => {
              this.selectedCountry = country.code;
              this.showCountryPicker = false;
              this.saveCountry();
              this.loadTopPodcasts();
            })
          }
        }, (country: CountryItem) => country.code)
      }
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
      .layoutWeight(1)
    }
    .width('100%')
  }

  private showHideAction(feed: ItunesResult): void {
    ActionSheet.show({
      title: feed.trackName,
      message: '选择操作',
      sheets: [
        {
          title: '隐藏此结果',
          action: () => {
            this.hiddenFeedUrls.add(feed.feedUrl);
            this.hiddenFeedUrls = new Set(this.hiddenFeedUrls);
            this.topFeeds = this.topFeeds.filter((f: ItunesResult) => f.feedUrl !== feed.feedUrl);
            this.saveHiddenList();
            promptAction.showToast({ message: '已隐藏', duration: 1500 });
          }
        }
      ],
      cancel: () => {}
    });
  }

  private async subscribePodcast(result: ItunesResult): Promise<void> {
    // iTunes top podcasts 的 feedUrl 是 iTunes 链接，不是 RSS URL
    // 需要通过 iTunes lookup 获取真正的 feedUrl，或直接跳转到添加页搜索
    router.pushUrl({
      url: 'pages/AddFeedPage',
      params: { searchQuery: result.trackName }
    });
  }
}
