import { router, promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { FeedItem, FeedItemFilter, SortOrder,
  EventBus, FEED_LIST_UPDATE, QUEUE_UPDATE, FAVORITES_UPDATE } from 'common';
import type { FeedListUpdateData, QueueUpdateData } from 'common';
import { getQueue, getEpisodes, getFeedItem } from 'datastore';
import { refreshAllFeeds } from 'network';

/**
 * 首页 — 完美复刻 Android 截图
 *
 * Sections: 继续收听 / 最近更新 / 不期而遇
 */
@Component
export struct HomePage {
  @State queueItems: FeedItem[] = [];
  @State newItems: FeedItem[] = [];
  @State randomItems: FeedItem[] = [];
  @State isRefreshing: boolean = false;

  onSwitchTab?: (index: number) => void;

  private onFeedUpdate: (data: FeedListUpdateData) => void = () => { this.loadData(); };
  private onQueueUpdate: (data: QueueUpdateData) => void = () => { this.loadData(); };
  private onFavUpdate: () => void = () => { this.loadData(); };

  aboutToAppear(): void {
    this.loadData();
    EventBus.on<FeedListUpdateData>(FEED_LIST_UPDATE, this.onFeedUpdate);
    EventBus.on<QueueUpdateData>(QUEUE_UPDATE, this.onQueueUpdate);
    EventBus.on<void>(FAVORITES_UPDATE, this.onFavUpdate);
  }

  aboutToDisappear(): void {
    EventBus.off(FEED_LIST_UPDATE, this.onFeedUpdate);
    EventBus.off(QUEUE_UPDATE, this.onQueueUpdate);
    EventBus.off(FAVORITES_UPDATE, this.onFavUpdate);
  }

  async loadData(): Promise<void> {
    // 继续收听 — 队列中的单集
    const allQueue = await getQueue();
    this.queueItems = allQueue.slice(0, 8);

    // 最近更新 — 新单集
    const newFilter = new FeedItemFilter(['new']);
    this.newItems = await getEpisodes(0, 8, newFilter, SortOrder.DATE_NEW_OLD);

    // 不期而遇 — 随机推荐
    this.randomItems = await getEpisodes(0, 5, null, SortOrder.RANDOM);
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          // ── 顶栏 ──
          Row() {
            Text('首页')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#212121')
            Blank()
            Text('🔍')
              .fontSize(22)
              .margin({ right: 20 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/SearchPage' });
              })
            Text('⋮')
              .fontSize(22)
              .fontColor('#212121')
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          // ── 继续收听 ──
          if (this.queueItems.length > 0) {
            this.sectionHeader('继续收听', '队列 »', () => {
              this.onSwitchTab?.(1);
            })
            this.horizontalCards(this.queueItems)
          }

          // ── 最近更新 ──
          this.sectionHeader('最近更新', '收件箱 »', () => {
            this.onSwitchTab?.(2);
          })
          if (this.newItems.length > 0) {
            this.horizontalCards(this.newItems)
          } else {
            // 空状态
            Text('新单集将在此处显示。随后您可以决定是否对其感兴趣。')
              .fontSize(14)
              .fontColor('#444444')
              .textAlign(TextAlign.Center)
              .padding({ left: 32, right: 32, top: 24, bottom: 24 })
              .width('100%')
          }

          // ── 不期而遇 ──
          if (this.randomItems.length > 0) {
            Row() {
              Text('不期而遇')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#212121')
              Text('  🔀')
                .fontSize(16)
              Blank()
              Text('单集 »')
                .fontSize(14)
                .fontColor('#0078C2')
                .onClick(() => {
                  // 跳转全部单集
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 4 })

            this.horizontalCards(this.randomItems)
          }

          // 底部间距（给 MiniPlayer 留空）
          Blank()
            .height(100)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .onRefreshing(async () => {
      await refreshAllFeeds();
      await this.loadData();
      this.isRefreshing = false;
    })
  }

  @Builder
  sectionHeader(title: string, linkText: string, onLinkClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#212121')
      Blank()
      Text(linkText)
        .fontSize(14)
        .fontColor('#0078C2')
        .onClick(onLinkClick)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 4 })
  }

  @Builder
  horizontalCards(items: FeedItem[]) {
    Scroll() {
      Row() {
        ForEach(items, (item: FeedItem) => {
          Column() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              // 大封面
              if ((item.getImageLocation() ?? '').length > 0) {
                Image(item.getImageLocation()!)
                  .width(128)
                  .height(128)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  Text('🎙️')
                    .fontSize(40)
                }
                .width(128)
                .height(128)
                .borderRadius(12)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)
              }

              // 右下角悬浮按钮
              Button(item.isDownloaded() ? '▶' : '↓')
                .width(48)
                .height(48)
                .borderRadius(24)
                .backgroundColor('#FFFFFF')
                .fontColor('#333333')
                .fontSize(14)
                .margin({ right: 8, bottom: 8 })
                .shadow({ radius: 4, color: 'rgba(0,0,0,0.3)' })
                .onClick(() => {
                  this.playOrDownload(item);
                })
            }

            // 标题
            Text(item.title ?? '')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 8 })
              .width(128)

            // 日期
            Text(this.formatDateSmart(item.pubDate))
              .fontSize(14)
              .fontColor('#444444')
              .margin({ top: 2 })
              .width(128)
          }
          .margin({ right: 8 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: item.id } });
          })
        }, (item: FeedItem) => item.id.toString())
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  private async playOrDownload(item: FeedItem): Promise<void> {
    try {
      const freshItem = await getFeedItem(item.id);
      if (freshItem !== null && freshItem.media !== null) {
        if (freshItem.isDownloaded()) {
          await getController().playMedia(freshItem.media, freshItem.feedId, false);
        } else {
          await getController().playMedia(freshItem.media, freshItem.feedId, true);
        }
      }
    } catch (_e) {
      promptAction.showToast({ message: '操作失败', duration: 2000 });
    }
  }

  formatDateSmart(date: Date | null): string {
    if (date === null) return '';
    const now = new Date();
    if (date.getFullYear() === now.getFullYear()) {
      return `${date.getMonth() + 1}月${date.getDate()}日`;
    }
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
  }
}
