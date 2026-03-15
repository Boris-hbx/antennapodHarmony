import { router } from '@kit.ArkUI';
import { Feed, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { addOrUpdateFeed } from 'datastore';
import { httpRequest, prepareUrl, parseFeed, searchPodcasts } from 'network';
import type { FeedParseResult, ItunesResult } from 'network';
import { FeedCover } from '../components/FeedCover';

/**
 * 添加订阅页（需求 5）
 *
 * 流程：输入 URL → 规范化 → HTTP 获取 → 解析 → 预览 → 确认订阅 → 写入数据库
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

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button('←')
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .fontColor('#333')
          .fontSize(20)
          .onClick(() => {
            router.back();
          })
        Text($r('app.string.title_add_podcast'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      Scroll() {
        Column() {
          // URL 输入区
          Column() {
            Text('输入播客 RSS 地址')
              .fontSize(14)
              .fontColor('#444444')

            TextInput({ placeholder: 'https://example.com/feed.xml', text: this.urlInput })
              .onChange((value: string) => {
                this.urlInput = value;
                this.errorMsg = '';
                this.previewFeed = null;
              })
              .width('100%')
              .height(44)
              .margin({ top: 8 })
              .borderRadius(8)

            Button(this.isLoading ? '加载中...' : '获取播客')
              .width('100%')
              .height(44)
              .margin({ top: 12 })
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor(this.urlInput.trim().length > 0 ? '#0078C2' : '#CCC')
              .fontColor('#FFFFFF')
              .enabled(!this.isLoading && this.urlInput.trim().length > 0)
              .onClick(() => {
                this.fetchFeed();
              })
          }
          .padding(16)
          .width('100%')

          // 错误信息
          if (this.errorMsg.length > 0) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor('#F44336')
              .padding({ left: 16, right: 16 })
              .width('100%')
          }

          // 搜索和推荐
          if (this.previewFeed === null) {
            // 搜索区
            Column() {
              Divider().margin({ top: 4, bottom: 12 })

              // 搜索方式标签
              Row() {
                Text('Apple Podcasts')
                  .fontSize(12)
                  .fontColor('#0078C2')
                  .fontWeight(FontWeight.Bold)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor('#FFF3E0')
                  .borderRadius(14)
                Text('RSS 地址')
                  .fontSize(12)
                  .fontColor('#444444')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor('#F5F5F5')
                  .borderRadius(14)
                  .margin({ left: 8 })
              }
              .width('100%')
              .margin({ bottom: 8 })

              Text('搜索播客')
                .fontSize(14)
                .fontColor('#444444')

              Row() {
                TextInput({ placeholder: '输入播客名称搜索', text: this.searchQuery })
                  .onChange((value: string) => {
                    this.searchQuery = value;
                  })
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
                  .onClick(() => {
                    this.doSearch();
                  })
              }
              .width('100%')
              .margin({ top: 8 })

              if (this.isSearching) {
                Text('搜索中...')
                  .fontSize(13)
                  .fontColor('#444444')
                  .margin({ top: 12 })
              }

              // 搜索结果
              ForEach(this.searchResults, (result: ItunesResult) => {
                Row() {
                  if (result.artworkUrl100.length > 0) {
                    Image(result.artworkUrl100)
                      .width(50)
                      .height(50)
                      .borderRadius(6)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Column() {
                      Text('🎙️')
                        .fontSize(18)
                    }
                    .width(50)
                    .height(50)
                    .borderRadius(6)
                    .backgroundColor('#F0F0F0')
                    .justifyContent(FlexAlign.Center)
                  }

                  Column() {
                    Text(result.trackName)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(result.artistName)
                      .fontSize(12)
                      .fontColor('#444444')
                      .margin({ top: 2 })
                    Text(`${result.trackCount} 集`)
                      .fontSize(11)
                      .fontColor('#444444')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                  .alignItems(HorizontalAlign.Start)

                  Button('添加')
                    .type(ButtonType.Normal)
                    .height(30)
                    .fontSize(12)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#0078C2')
                    .borderRadius(15)
                    .onClick(() => {
                      this.urlInput = result.feedUrl;
                      this.searchResults = [];
                      this.fetchFeed();
                    })
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .alignItems(VerticalAlign.Center)
              }, (result: ItunesResult) => result.feedUrl)
            }
            .padding({ left: 16, right: 16 })
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 推荐播客
            Column() {
              Divider().margin({ top: 12, bottom: 12 })
              Text('推荐播客（点击一键添加）')
                .fontSize(14)
                .fontColor('#444444')
                .margin({ bottom: 8 })

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

          // Feed 预览
          if (this.previewFeed !== null) {
            Column() {
              // 分割线
              Divider().margin({ top: 8, bottom: 16 })

              Row() {
                FeedCover({
                  imageUrl: this.previewFeed!.imageUrl ?? '',
                  coverSize: 80,
                  coverRadius: 10
                })
                Column() {
                  Text(this.previewFeed!.getTitle() ?? '未知播客')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .maxLines(2)
                  if ((this.previewFeed!.author ?? '').length > 0) {
                    Text(this.previewFeed!.author!)
                      .fontSize(13)
                      .fontColor('#444444')
                      .margin({ top: 4 })
                  }
                  Text(`${this.itemCount} 集`)
                    .fontSize(12)
                    .fontColor('#444444')
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')

              // 描述
              if ((this.previewFeed!.description ?? '').length > 0) {
                Text(this.previewFeed!.description!)
                  .fontSize(13)
                  .fontColor('#444444')
                  .maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 12 })
                  .width('100%')
              }

              // 确认订阅按钮
              Button('确认订阅')
                .width('100%')
                .height(48)
                .margin({ top: 20 })
                .type(ButtonType.Normal)
                .borderRadius(8)
                .backgroundColor('#4CAF50')
                .fontColor('#FFFFFF')
                .fontSize(16)
                .onClick(() => {
                  this.subscribeFeed();
                })
            }
            .padding({ left: 16, right: 16, bottom: 16 })
            .width('100%')
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
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

      const xmlContent = typeof response.body === 'string'
        ? response.body : '';

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
      // 诊断：统计有 media 的 item 数量
      let mediaCount = 0;
      for (const item of result.feed.items) {
        if (item.media !== null) {
          mediaCount++;
        }
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
      router.back();
    } catch (e) {
      this.errorMsg = '订阅失败：' + this.getErrorMessage(e);
    }
  }

  @Builder
  presetItem(title: string, desc: string, url: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text(desc)
          .fontSize(12)
          .fontColor('#444444')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('添加')
        .type(ButtonType.Normal)
        .height(30)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .backgroundColor('#0078C2')
        .borderRadius(15)
        .onClick(() => {
          this.urlInput = url;
          this.fetchFeed();
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
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
    if (e instanceof Error) {
      return e.message;
    }
    // HarmonyOS BusinessError: { code: number, message: string }
    const obj = e as Record<string, Object>;
    if (obj['message'] !== undefined) {
      const code = obj['code'] !== undefined ? `[${obj['code']}] ` : '';
      return code + String(obj['message']);
    }
    return JSON.stringify(e);
  }
}
