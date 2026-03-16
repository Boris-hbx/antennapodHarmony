import { router, promptAction } from '@kit.ArkUI';
import { Feed, FeedItem, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { searchFeeds, searchFeedItems, getFeedItemList, addOrUpdateFeed } from 'datastore';

/**
 * 本地搜索页 — 搜索已订阅的 Feed 和单集
 * Task-023: 播客结果点击 → 底部弹窗预览（而非全屏跳转）
 */
@Entry
@Component
struct SearchPage {
  @State query: string = '';
  @State feedResults: Feed[] = [];
  @State itemResults: FeedItem[] = [];
  @State isSearching: boolean = false;
  @State hasSearched: boolean = false;

  // Task-023: 底部弹窗预览状态
  @State showFeedPreview: boolean = false;
  @State previewFeed: Feed | null = null;
  @State previewEpisodes: FeedItem[] = [];
  @State descExpanded: boolean = false;

  async doSearch(): Promise<void> {
    if (this.query.trim().length === 0) return;
    this.isSearching = true;
    this.feedResults = await searchFeeds(this.query);
    this.itemResults = await searchFeedItems(null, this.query);
    this.hasSearched = true;
    this.isSearching = false;
  }

  build() {
    Column() {
      // 搜索栏
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
        Search({ value: this.query, placeholder: '搜索播客或单集' })
          .onSubmit((value: string) => {
            this.query = value;
            this.doSearch();
          })
          .onChange((value: string) => {
            this.query = value;
          })
          .layoutWeight(1)
          .height(40)
          .margin({ right: 16 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8 })

      if (this.isSearching) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ top: 60 })
          Text('搜索中...')
            .fontSize(14)
            .fontColor('#444444')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else if (!this.hasSearched) {
        Column() {
          Text('输入关键词搜索已订阅的播客和单集')
            .fontSize(14)
            .fontColor('#CCC')
            .margin({ top: 80 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else if (this.feedResults.length === 0 && this.itemResults.length === 0) {
        Column() {
          Text('未找到匹配结果')
            .fontSize(16)
            .fontColor('#444444')
            .margin({ top: 80 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          // 播客结果
          if (this.feedResults.length > 0) {
            ListItem() {
              Text(`播客 (${this.feedResults.length})`)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#444444')
                .padding({ left: 16, top: 12, bottom: 8 })
            }

            ForEach(this.feedResults, (feed: Feed) => {
              ListItem() {
                Row() {
                  if ((feed.imageUrl ?? '').length > 0) {
                    Image(feed.imageUrl!)
                      .width(48)
                      .height(48)
                      .borderRadius(6)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Column() {
                      Text('🎙️')
                        .fontSize(18)
                    }
                    .width(48)
                    .height(48)
                    .borderRadius(6)
                    .backgroundColor('#F0F0F0')
                    .justifyContent(FlexAlign.Center)
                  }
                  Column() {
                    Text(feed.getTitle() ?? '')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(feed.author ?? '')
                      .fontSize(12)
                      .fontColor('#444444')
                      .margin({ top: 2 })
                      .maxLines(1)
                  }
                  .layoutWeight(1)
                  .margin({ left: 12 })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .onClick(async () => {
                  // Task-023: 改为弹窗预览
                  this.previewFeed = feed;
                  this.descExpanded = false;
                  try {
                    this.previewEpisodes = await getFeedItemList(feed.id, null, null, 0, 3);
                  } catch (_e) {
                    this.previewEpisodes = [];
                  }
                  this.showFeedPreview = true;
                })
              }
            }, (feed: Feed) => feed.id.toString())
          }

          // 单集结果
          if (this.itemResults.length > 0) {
            ListItem() {
              Text(`单集 (${this.itemResults.length})`)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#444444')
                .padding({ left: 16, top: 16, bottom: 8 })
            }

            ForEach(this.itemResults, (item: FeedItem) => {
              ListItem() {
                Row() {
                  Column() {
                    if ((item.getImageLocation() ?? '').length > 0) {
                      Image(item.getImageLocation()!)
                        .width(48)
                        .height(48)
                        .borderRadius(6)
                        .objectFit(ImageFit.Cover)
                    } else {
                      Text('🎙️')
                        .fontSize(18)
                    }
                  }
                  .width(48)
                  .height(48)
                  .borderRadius(6)
                  .backgroundColor('#F0F0F0')
                  .justifyContent(FlexAlign.Center)

                  Column() {
                    Text(item.title ?? '')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.media !== null && item.media.duration > 0) {
                      Text(this.formatDuration(item.media.duration))
                        .fontSize(11)
                        .fontColor('#444444')
                        .margin({ top: 3 })
                    }
                  }
                  .layoutWeight(1)
                  .margin({ left: 12 })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/EpisodeDetailPage',
                    params: { itemId: item.id, feedId: item.feedId }
                  });
                })
              }
            }, (item: FeedItem) => item.id.toString())
          }
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 76 })
      }
    }
    .width('100%')
    .height('100%')
    // Task-023: 播客预览弹窗
    .bindSheet($$this.showFeedPreview, () => { this.FeedPreviewSheet(); }, {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      dragBar: true
    })
  }

  // ===== Task-023: 播客预览底部弹窗 =====

  @Builder
  FeedPreviewSheet() {
    Column() {
      // 顶栏：× 关闭
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { this.showFeedPreview = false; })

        Blank()
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })

      // 封面 + 标题/作者
      Row({ space: 12 }) {
        if (this.previewFeed !== null && (this.previewFeed!.imageUrl ?? '').length > 0) {
          Image(this.previewFeed!.imageUrl!)
            .width(88)
            .height(88)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('🎙️').fontSize(28)
          }
          .width(88)
          .height(88)
          .borderRadius(8)
          .backgroundColor('#F0F0F0')
          .justifyContent(FlexAlign.Center)
        }

        Column() {
          Text(this.previewFeed?.getTitle() ?? '')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.previewFeed?.author ?? '')
            .fontSize(14)
            .fontColor('#444444')
            .margin({ top: 4 })
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })

      // 查看全部单集按钮
      Button('查看全部单集')
        .width('90%')
        .height(40)
        .backgroundColor('#0078C2')
        .fontColor('#FFFFFF')
        .fontSize(14)
        .borderRadius(8)
        .onClick(() => {
          this.showFeedPreview = false;
          if (this.previewFeed !== null) {
            router.pushUrl({
              url: 'pages/EpisodeListPage',
              params: { feedId: this.previewFeed!.id, feedTitle: this.previewFeed!.getTitle() }
            });
          }
        })

      // 描述
      if (this.previewFeed !== null && (this.previewFeed!.description ?? '').length > 0) {
        Text(this.stripHtml(this.previewFeed!.description ?? ''))
          .fontSize(14)
          .fontColor('#444444')
          .maxLines(this.descExpanded ? 100 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 16, right: 16, top: 12 })
          .onClick(() => { this.descExpanded = !this.descExpanded; })
      }

      // 单集预览
      if (this.previewEpisodes.length > 0) {
        Divider()
          .strokeWidth(0.5)
          .color('#E8E8E8')
          .margin({ top: 12, bottom: 4 })

        Text('最新单集')
          .fontSize(13)
          .fontColor('#888888')
          .padding({ left: 16, top: 8, bottom: 4 })

        ForEach(this.previewEpisodes, (ep: FeedItem) => {
          Row() {
            Column() {
              Text(ep.title ?? '')
                .fontSize(14)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.formatDate(ep.pubDate))
                .fontSize(12)
                .fontColor('#888888')
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }, (ep: FeedItem) => ep.id.toString())
      }

      Blank().height(20)
    }
    .width('100%')
  }

  // ===== 工具方法 =====

  stripHtml(html: string): string {
    return html.replace(/<[^>]*>/g, '').replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ').trim();
  }

  formatDate(date: Date | null): string {
    if (date === null) return '';
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  formatDuration(ms: number): string {
    if (ms <= 0) return '';
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    if (h > 0) return `${h}h${m}min`;
    return `${m}min`;
  }
}
