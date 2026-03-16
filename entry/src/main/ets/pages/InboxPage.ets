import { promptAction, router } from '@kit.ArkUI';
import { FeedItem, FeedItemFilter, SortOrder, PlayState, EventBus,
  FEED_LIST_UPDATE, UNREAD_UPDATE, QUEUE_UPDATE, FAVORITES_UPDATE,
  TAG_QUEUE, TAG_FAVORITE } from 'common';
import type { FeedListUpdateData, QueueUpdateData } from 'common';
import { getEpisodes, getTotalEpisodeCount, markItemPlayed,
  addFavoriteItem, removeFavoriteItem, addQueueItem, removeQueueItem } from 'datastore';

/**
 * 收件箱 Tab — 显示新单集，支持标记已播/收藏/加入队列
 */
@Component
export struct InboxPage {
  @State items: FeedItem[] = [];
  @State totalCount: number = 0;
  @State isRefreshing: boolean = false;

  private updateCallback: () => void = () => {
    this.loadData();
  };

  aboutToAppear(): void {
    this.loadData();
    EventBus.on<FeedListUpdateData>(FEED_LIST_UPDATE, this.updateCallback);
    EventBus.on<void>(UNREAD_UPDATE, this.updateCallback);
  }

  aboutToDisappear(): void {
    EventBus.off(FEED_LIST_UPDATE, this.updateCallback);
    EventBus.off(UNREAD_UPDATE, this.updateCallback);
  }

  async loadData(): Promise<void> {
    const newFilter = new FeedItemFilter(['new']);
    this.items = await getEpisodes(0, 100, newFilter, SortOrder.DATE_NEW_OLD);
    this.totalCount = this.items.length;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text($r('app.string.tab_inbox'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        if (this.totalCount > 0) {
          Text(`${this.totalCount}`)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor('#0078C2')
            .borderRadius(10)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ left: 8 })
        }
        Blank()
        Button('🔍')
          .type(ButtonType.Circle)
          .width(32)
          .height(32)
          .fontSize(16)
          .fontColor('#444444')
          .backgroundColor('#F0F0F0')
          .margin({ right: 8 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchPage' });
          })
        Button($r('app.string.action_refresh'))
          .type(ButtonType.Normal)
          .height(30)
          .fontSize(12)
          .fontColor('#444444')
          .backgroundColor('#F0F0F0')
          .borderRadius(15)
          .margin({ right: 8 })
          .onClick(() => {
            this.loadData();
          })
        if (this.totalCount > 0) {
          Button('全部已读')
            .type(ButtonType.Normal)
            .height(30)
            .fontSize(12)
            .fontColor('#444444')
            .backgroundColor('#F0F0F0')
            .borderRadius(15)
            .onClick(() => {
              this.markAllRead();
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.items.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.envelope'))
            .fontSize(56)
            .fontColor(['#AAAAAA'])
            .margin({ top: 24, bottom: 16 })
          Text('收件箱中没有单集')
            .fontSize(18)
            .fontColor('#444444')
          Text('新单集上线后，将在此处显示。\n随后您可以决定是否对其感兴趣。')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
            .padding({ left: 40, right: 40 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.items, (item: FeedItem) => {
            ListItem() {
              Row() {
                // 封面
                Column() {

                  if ((item.getImageLocation() ?? '').length > 0) {
                    Image(item.getImageLocation()!)
                      .width(52)
                      .height(52)
                      .borderRadius(6)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Text('🎙️')
                      .fontSize(18)
                  }
                }
                .width(52)
                .height(52)
                .borderRadius(6)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)

                // 内容
                Column() {
                  Text(item.title ?? '')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    if (item.media !== null && item.media.duration > 0) {
                      Text(this.formatDuration(item.media.duration))
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                  }
                  .margin({ top: 3 })
                }
                .layoutWeight(1)
                .margin({ left: 10 })
                .alignItems(HorizontalAlign.Start)

                // 操作按钮
                Column() {
                  Row() {
                    // 收藏
                    Button(item.isFavorite() ? '★' : '☆')
                      .type(ButtonType.Circle)
                      .width(30)
                      .height(30)
                      .fontSize(14)
                      .fontColor(item.isFavorite() ? '#FFC107' : '#CCC')
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.toggleFavorite(item);
                      })
                    // 队列
                    Button(item.isQueued() ? '✓' : '+')
                      .type(ButtonType.Circle)
                      .width(30)
                      .height(30)
                      .fontSize(13)
                      .fontColor(item.isQueued() ? '#4CAF50' : '#CCC')
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.toggleQueue(item);
                      })
                    // 标记已读
                    Button('✔')
                      .type(ButtonType.Circle)
                      .width(30)
                      .height(30)
                      .fontSize(12)
                      .fontColor('#444444')
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.markRead(item);
                      })
                  }
                }
              }
              .width('100%')
              .padding({ left: 16, right: 8, top: 10, bottom: 10 })
              .alignItems(VerticalAlign.Center)
            }
            .swipeAction({
              start: {
                builder: () => {
                  this.swipeQueueButton(item)
                }
              },
              end: {
                builder: () => {
                  this.swipeReadButton(item)
                }
              }
            })
          }, (item: FeedItem) => item.id.toString() + '_' + (item.isFavorite() ? 'f' : '') + (item.isQueued() ? 'q' : ''))
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 78 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  swipeQueueButton(item: FeedItem) {
    Row() {
      Button(item.isQueued() ? '移出队列' : '加入队列')
        .backgroundColor('#0078C2')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => {
          this.toggleQueue(item);
        })
    }
  }

  @Builder
  swipeReadButton(item: FeedItem) {
    Row() {
      Button('已读')
        .backgroundColor('#4CAF50')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => {
          this.markRead(item);
        })
    }
  }

  async toggleFavorite(item: FeedItem): Promise<void> {
    if (item.isFavorite()) {
      await removeFavoriteItem(item);
      item.tags.delete(TAG_FAVORITE);
      promptAction.showToast({ message: '已取消收藏', duration: 1500 });
    } else {
      await addFavoriteItem(item);
      item.tags.add(TAG_FAVORITE);
      promptAction.showToast({ message: '已收藏', duration: 1500 });
    }
    this.items = this.items.slice();
    EventBus.emit<void>(FAVORITES_UPDATE);
  }

  async toggleQueue(item: FeedItem): Promise<void> {
    if (item.isQueued()) {
      await removeQueueItem(item);
      item.tags.delete(TAG_QUEUE);
      promptAction.showToast({ message: '已从队列移除', duration: 1500 });
    } else {
      await addQueueItem(item);
      item.tags.add(TAG_QUEUE);
      promptAction.showToast({ message: '已添加到队列', duration: 1500 });
    }
    this.items = this.items.slice();
    EventBus.emit<QueueUpdateData>(QUEUE_UPDATE, { action: 'toggle' });
  }

  async markRead(item: FeedItem): Promise<void> {
    await markItemPlayed(item.id, PlayState.UNPLAYED);
    await this.loadData();
  }

  async markAllRead(): Promise<void> {
    for (const item of this.items) {
      await markItemPlayed(item.id, PlayState.UNPLAYED);
    }
    await this.loadData();
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
