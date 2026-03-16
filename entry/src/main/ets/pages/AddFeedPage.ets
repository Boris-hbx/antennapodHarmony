import { router, promptAction } from '@kit.ArkUI';
import { Feed, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { addOrUpdateFeed } from 'datastore';
import { httpRequest, prepareUrl, parseFeed, searchPodcasts, getTopPodcasts } from 'network';
import type { FeedParseResult, ItunesResult } from 'network';
import { FeedCover } from '../components/FeedCover';
import { pasteboard } from '@kit.BasicServicesKit';

/**
 * 添加订阅页 — 6 种添加方式 + 热门播客网格
 * Task-029: 对照 Android AddFeedFragment
 *
 * 6 种添加方式：
 * 1. 搜索 Apple Podcasts
 * 2. 输入 RSS URL
 * 3. 从剪贴板粘贴
 * 4. 发现热门播客
 * 5. OPML 导入（入口）
 * 6. 推荐播客
 */
@Entry
@Component
struct AddFeedPage {
  @State urlInput: string = '';
  @State isLoading: boolean = false;
  @State searchQuery: string = '';
  @State searchResults: ItunesResult[] = [];
  @State isSearching: boolean = false;
  @State errorMsg: string = '';
  @State previewFeed: Feed | null = null;
  @State itemCount: number = 0;
  @State topFeeds: ItunesResult[] = [];
  @State isLoadingTop: boolean = false;
  @State activeTab: number = 0; // 0=搜索, 1=RSS地址

  aboutToAppear(): void {
    // 接收来自 DiscoverPage 等页面的搜索参数
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      const sq = params['searchQuery'] as string;
      if (sq !== undefined && sq.length > 0) {
        this.searchQuery = sq;
        this.doSearch();
      }
    }
    this.loadTopPodcasts();
  }

  async loadTopPodcasts(): Promise<void> {
    this.isLoadingTop = true;
    try {
      this.topFeeds = await getTopPodcasts('CN', 12);
    } catch (_e) {
      this.topFeeds = [];
    }
    this.isLoadingTop = false;
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { router.back(); })

        Text($r('app.string.title_add_podcast'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      Scroll() {
        Column() {
          // ── 6 种添加方式入口 ──
          this.addMethodsGrid()

          // 错误信息
          if (this.errorMsg.length > 0) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor(this.errorMsg.startsWith('解析完成') ? '#4CAF50' : '#F44336')
              .padding({ left: 16, right: 16, top: 4, bottom: 4 })
              .width('100%')
          }

          // ── 搜索 / RSS 输入区（Tab 切换）──
          if (this.previewFeed === null) {
            // Tab 切换
            Row() {
              Text('搜索播客')
                .fontSize(14)
                .fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.activeTab === 0 ? '#0078C2' : '#444444')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .borderWidth({ bottom: this.activeTab === 0 ? 2 : 0 })
                .borderColor('#0078C2')
                .onClick(() => { this.activeTab = 0; })
              Text('RSS 地址')
                .fontSize(14)
                .fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.activeTab === 1 ? '#0078C2' : '#444444')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .borderWidth({ bottom: this.activeTab === 1 ? 2 : 0 })
                .borderColor('#0078C2')
                .onClick(() => { this.activeTab = 1; })
            }
            .width('100%')
            .borderWidth({ bottom: 0.5 })
            .borderColor('#E8E8E8')

            if (this.activeTab === 0) {
              // 搜索 Apple Podcasts
              this.searchSection()
            } else {
              // RSS URL 输入
              this.rssInputSection()
            }

            // ── 热门播客网格（4×3）──
            if (this.searchResults.length === 0) {
              this.topPodcastsGrid()
            }
          }

          // ── Feed 预览 ──
          if (this.previewFeed !== null) {
            this.feedPreview()
          }

          Blank().height(40)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  // ===== 6 种添加方式网格 =====
  @Builder
  addMethodsGrid() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceEvenly }) {
        this.addMethodItem('搜索播客', $r('sys.symbol.magnifyingglass'), '#0078C2', () => {
          this.activeTab = 0;
        })
        this.addMethodItem('RSS 地址', $r('sys.symbol.link'), '#FF9800', () => {
          this.activeTab = 1;
        })
        this.addMethodItem('从剪贴板', $r('sys.symbol.arrow_up'), '#4CAF50', () => {
          this.pasteFromClipboard();
        })
        this.addMethodItem('发现热门', $r('sys.symbol.house'), '#9C27B0', () => {
          router.pushUrl({ url: 'pages/DiscoverPage' });
        })
        this.addMethodItem('OPML 导入', $r('sys.symbol.arrow_down'), '#607D8B', () => {
          promptAction.showToast({ message: 'OPML 导入功能开发中', duration: 1500 });
        })
        this.addMethodItem('推荐播客', $r('sys.symbol.star'), '#FFC107', () => {
          this.scrollToPresets();
        })
      }
      .padding({ left: 8, right: 8, top: 12, bottom: 8 })
    }
    .width('100%')
  }

  @Builder
  addMethodItem(label: string, icon: Resource, color: string, action: () => void) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([color])
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(color + '15')

      Text(label)
        .fontSize(11)
        .fontColor('#333333')
        .margin({ top: 6 })
        .textAlign(TextAlign.Center)
    }
    .width('30%')
    .margin({ bottom: 12 })
    .alignItems(HorizontalAlign.Center)
    .onClick(action)
  }

  // ===== 搜索区 =====
  @Builder
  searchSection() {
    Column() {
      Row() {
        TextInput({ placeholder: '输入播客名称搜索', text: this.searchQuery })
          .onChange((value: string) => { this.searchQuery = value; })
          .layoutWeight(1)
          .height(40)
          .borderRadius(8)

        Button('搜索')
          .type(ButtonType.Normal)
          .height(40)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#0078C2')
          .borderRadius(8)
          .margin({ left: 8 })
          .enabled(!this.isSearching && this.searchQuery.trim().length > 0)
          .onClick(() => { this.doSearch(); })
      }
      .width('100%')
      .margin({ top: 12 })

      if (this.isSearching) {
        Row() {
          LoadingProgress().width(20).height(20)
          Text('搜索中...').fontSize(13).fontColor('#444444').margin({ left: 8 })
        }.margin({ top: 12 })
      }

      // 搜索结果
      ForEach(this.searchResults, (result: ItunesResult) => {
        Row() {
          if (result.artworkUrl100.length > 0) {
            Image(result.artworkUrl100)
              .width(50).height(50).borderRadius(6).objectFit(ImageFit.Cover)
          } else {
            Column() { Text('🎙️').fontSize(18) }
              .width(50).height(50).borderRadius(6).backgroundColor('#F0F0F0')
              .justifyContent(FlexAlign.Center)
          }

          Column() {
            Text(result.trackName)
              .fontSize(14).fontWeight(FontWeight.Medium)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(result.artistName)
              .fontSize(12).fontColor('#444444').margin({ top: 2 })
            Text(`${result.trackCount} 集`)
              .fontSize(11).fontColor('#444444').margin({ top: 2 })
          }
          .layoutWeight(1).margin({ left: 10 }).alignItems(HorizontalAlign.Start)

          Button('添加')
            .type(ButtonType.Normal).height(30).fontSize(12)
            .fontColor('#FFFFFF').backgroundColor('#0078C2').borderRadius(15)
            .onClick(() => {
              this.urlInput = result.feedUrl;
              this.searchResults = [];
              this.fetchFeed();
            })
        }
        .width('100%').padding({ top: 10, bottom: 10 }).alignItems(VerticalAlign.Center)
      }, (result: ItunesResult) => result.feedUrl)
    }
    .padding({ left: 16, right: 16 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ===== RSS URL 输入区 =====
  @Builder
  rssInputSection() {
    Column() {
      TextInput({ placeholder: 'https://example.com/feed.xml', text: this.urlInput })
        .onChange((value: string) => {
          this.urlInput = value;
          this.errorMsg = '';
          this.previewFeed = null;
        })
        .width('100%').height(44).margin({ top: 12 }).borderRadius(8)

      Button(this.isLoading ? '加载中...' : '获取播客')
        .width('100%').height(44).margin({ top: 12 })
        .type(ButtonType.Normal).borderRadius(8)
        .backgroundColor(this.urlInput.trim().length > 0 ? '#0078C2' : '#CCC')
        .fontColor('#FFFFFF')
        .enabled(!this.isLoading && this.urlInput.trim().length > 0)
        .onClick(() => { this.fetchFeed(); })

      // 推荐播客
      Divider().margin({ top: 16, bottom: 12 })
      Text('推荐播客（点击一键添加）')
        .fontSize(14).fontColor('#444444').margin({ bottom: 8 })
      this.presetItem('BBC 6 Minute English', '英语学习', 'https://podcasts.files.bbci.co.uk/p02pc9tn.rss')
      this.presetItem('Planet Money', 'NPR 经济播客', 'https://feeds.npr.org/510289/podcast.xml')
      this.presetItem('TED Radio Hour', 'TED 深度对话', 'https://feeds.npr.org/510298/podcast.xml')
      this.presetItem('Freakonomics Radio', '经济学趣闻', 'https://feeds.simplecast.com/Y8lFbOT4')
      this.presetItem('Global News Podcast', 'BBC 全球新闻', 'https://podcasts.files.bbci.co.uk/p02nq0gn.rss')
    }
    .padding({ left: 16, right: 16 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ===== 热门播客网格（4×3）=====
  @Builder
  topPodcastsGrid() {
    Column() {
      Divider().margin({ top: 12, bottom: 12 })
      Row() {
        Text('热门播客')
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#212121')
        Blank()
        Text('更多 »')
          .fontSize(14).fontColor('#0078C2')
          .onClick(() => { router.pushUrl({ url: 'pages/DiscoverPage' }); })
      }
      .width('100%')
      .margin({ bottom: 8 })

      if (this.isLoadingTop) {
        Row() {
          LoadingProgress().width(24).height(24)
          Text('加载中...').fontSize(13).fontColor('#444444').margin({ left: 8 })
        }.margin({ top: 8 })
      } else if (this.topFeeds.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.topFeeds, (feed: ItunesResult) => {
            Column() {
              if (feed.artworkUrl100.length > 0) {
                Image(feed.artworkUrl100)
                  .width('100%').aspectRatio(1).borderRadius(8).objectFit(ImageFit.Cover)
              } else {
                Column() { Text('🎙️').fontSize(24) }
                  .width('100%').aspectRatio(1).borderRadius(8)
                  .backgroundColor('#F0F0F0').justifyContent(FlexAlign.Center)
              }
              Text(feed.trackName)
                .fontSize(11).fontColor('#1A1A1A')
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 }).width('100%')
            }
            .width('23%')
            .margin({ left: '1%', right: '1%', bottom: 12 })
            .onClick(() => {
              this.searchQuery = feed.trackName;
              this.activeTab = 0;
              this.doSearch();
            })
          }, (feed: ItunesResult) => feed.trackName + feed.artistName)
        }
      }
    }
    .padding({ left: 16, right: 16 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ===== Feed 预览 =====
  @Builder
  feedPreview() {
    Column() {
      Divider().margin({ top: 8, bottom: 16 })
      Row() {
        FeedCover({ imageUrl: this.previewFeed!.imageUrl ?? '', coverSize: 80, coverRadius: 10 })
        Column() {
          Text(this.previewFeed!.getTitle() ?? '未知播客')
            .fontSize(16).fontWeight(FontWeight.Bold).maxLines(2)
          if ((this.previewFeed!.author ?? '').length > 0) {
            Text(this.previewFeed!.author!)
              .fontSize(13).fontColor('#444444').margin({ top: 4 })
          }
          Text(`${this.itemCount} 集`)
            .fontSize(12).fontColor('#444444').margin({ top: 4 })
        }
        .layoutWeight(1).margin({ left: 12 }).alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if ((this.previewFeed!.description ?? '').length > 0) {
        Text(this.previewFeed!.description!)
          .fontSize(13).fontColor('#444444')
          .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 12 }).width('100%')
      }

      Row() {
        Button('确认订阅')
          .layoutWeight(1).height(48)
          .type(ButtonType.Normal).borderRadius(8)
          .backgroundColor('#4CAF50').fontColor('#FFFFFF').fontSize(16)
          .onClick(() => { this.subscribeFeed(); })

        Button('取消')
          .width(80).height(48).margin({ left: 12 })
          .type(ButtonType.Normal).borderRadius(8)
          .backgroundColor('#F5F5F5').fontColor('#444444').fontSize(14)
          .onClick(() => {
            this.previewFeed = null;
            this.errorMsg = '';
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .padding({ left: 16, right: 16, bottom: 16 })
    .width('100%')
  }

  @Builder
  presetItem(title: string, desc: string, url: string) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium)
        Text(desc).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)

      Button('添加')
        .type(ButtonType.Normal).height(30).fontSize(12)
        .fontColor('#FFFFFF').backgroundColor('#0078C2').borderRadius(15)
        .onClick(() => {
          this.urlInput = url;
          this.fetchFeed();
        })
    }
    .width('100%').padding({ top: 10, bottom: 10 }).alignItems(VerticalAlign.Center)
  }

  // ===== 操作方法 =====

  private async pasteFromClipboard(): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = await systemPasteboard.getData();
      const text = pasteData.getPrimaryText();
      if (text !== null && text.length > 0) {
        // 检查是否像 URL
        if (text.startsWith('http://') || text.startsWith('https://') || text.includes('.xml') || text.includes('rss')) {
          this.urlInput = text;
          this.activeTab = 1;
          this.fetchFeed();
        } else {
          // 当作搜索关键词
          this.searchQuery = text;
          this.activeTab = 0;
          this.doSearch();
        }
      } else {
        promptAction.showToast({ message: '剪贴板为空', duration: 1500 });
      }
    } catch (_e) {
      promptAction.showToast({ message: '无法读取剪贴板', duration: 1500 });
    }
  }

  private scrollToPresets(): void {
    this.activeTab = 1;
  }

  async fetchFeed(): Promise<void> {
    this.isLoading = true;
    this.errorMsg = '';
    this.previewFeed = null;

    try {
      const url = prepareUrl(this.urlInput.trim());
      const response = await httpRequest({ url: url, method: 'GET' });

      if (response.statusCode !== 200) {
        this.errorMsg = `请求失败：HTTP ${response.statusCode}`;
        this.isLoading = false;
        return;
      }

      const xmlContent = typeof response.body === 'string' ? response.body : '';
      if (xmlContent.length === 0) {
        this.errorMsg = '未获取到有效内容';
        this.isLoading = false;
        return;
      }

      const feed = new Feed(url);
      const result: FeedParseResult = parseFeed(xmlContent, feed);

      if (result.feed.getTitle() === null) {
        this.errorMsg = '无法解析此 RSS 地址，请检查 URL';
        this.isLoading = false;
        return;
      }

      this.previewFeed = result.feed;
      this.itemCount = result.feed.items.length;
      let mediaCount = 0;
      for (const item of result.feed.items) {
        if (item.media !== null) mediaCount++;
      }
      this.errorMsg = `解析完成: ${this.itemCount} 集, ${mediaCount} 集有媒体`;
    } catch (e) {
      this.errorMsg = '加载失败：' + this.getErrorMessage(e);
    }

    this.isLoading = false;
  }

  async subscribeFeed(): Promise<void> {
    if (this.previewFeed === null) return;
    try {
      const feedId = await addOrUpdateFeed(this.previewFeed);
      EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: [feedId] });
      promptAction.showToast({ message: '订阅成功', duration: 1500 });
      router.back();
    } catch (e) {
      this.errorMsg = '订阅失败：' + this.getErrorMessage(e);
    }
  }

  async doSearch(): Promise<void> {
    this.isSearching = true;
    this.searchResults = [];
    try {
      this.searchResults = await searchPodcasts(this.searchQuery);
    } catch (e) {
      this.errorMsg = '搜索失败：' + this.getErrorMessage(e);
    }
    this.isSearching = false;
  }

  getErrorMessage(e: Object): string {
    if (e instanceof Error) return e.message;
    const obj = e as Record<string, Object>;
    if (obj['message'] !== undefined) {
      const code = obj['code'] !== undefined ? `[${obj['code']}] ` : '';
      return code + String(obj['message']);
    }
    return JSON.stringify(e);
  }
}
