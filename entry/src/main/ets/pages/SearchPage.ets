import { router } from '@kit.ArkUI';
import { Feed, FeedItem } from 'common';
import { searchFeeds, searchFeedItems } from 'datastore';

/**
 * 本地搜索页 — 搜索已订阅的 Feed 和单集
 */
@Entry
@Component
struct SearchPage {
  @State query: string = '';
  @State feedResults: Feed[] = [];
  @State itemResults: FeedItem[] = [];
  @State isSearching: boolean = false;
  @State hasSearched: boolean = false;

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
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/EpisodeListPage',
                    params: { feedId: feed.id, feedTitle: feed.getTitle() }
                  });
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
