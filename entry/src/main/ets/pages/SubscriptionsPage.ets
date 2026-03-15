import { router, promptAction } from '@kit.ArkUI';
import { Feed, FeedOrder, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { getFeedList, getNavDrawerData, deleteFeed } from 'datastore';
import { refreshAllFeeds } from 'network';
import { FeedCover } from '../components/FeedCover';

/**
 * 订阅列表页（需求 2）
 *
 * 3 列网格展示已订阅 Feed，支持排序、下拉刷新、点击跳转。
 */
@Component
export struct SubscriptionsPage {
  @State feeds: Feed[] = [];
  @State isRefreshing: boolean = false;
  @State sortOrder: FeedOrder = FeedOrder.ALPHABETICAL;
  @State showSortMenu: boolean = false;

  private feedUpdateCallback: (data: FeedListUpdateData) => void = () => {
    this.loadData();
  };

  aboutToAppear(): void {
    this.loadData();
    EventBus.on<FeedListUpdateData>(FEED_LIST_UPDATE, this.feedUpdateCallback);
  }

  aboutToDisappear(): void {
    EventBus.off(FEED_LIST_UPDATE, this.feedUpdateCallback);
  }

  async loadData(): Promise<void> {
    const allFeeds = await getFeedList();
    this.feeds = this.sortFeeds(allFeeds);
  }

  sortFeeds(feeds: Feed[]): Feed[] {
    const sorted = feeds.slice();
    switch (this.sortOrder) {
      case FeedOrder.ALPHABETICAL:
        sorted.sort((a: Feed, b: Feed) => {
          const titleA = (a.getTitle() ?? '').toLowerCase();
          const titleB = (b.getTitle() ?? '').toLowerCase();
          if (titleA < titleB) return -1;
          if (titleA > titleB) return 1;
          return 0;
        });
        break;
      case FeedOrder.MOST_RECENT_EPISODE:
        sorted.sort((a: Feed, b: Feed) => b.lastRefreshAttempt - a.lastRefreshAttempt);
        break;
      default:
        break;
    }
    return sorted;
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Refresh({ refreshing: $$this.isRefreshing }) {
        Column() {
          // 顶部标题栏
          Row() {
            Text($r('app.string.tab_subscriptions'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
            if (this.feeds.length > 0) {
              Text(`${this.feeds.length}`)
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
              .height(32)
              .fontSize(13)
              .fontColor('#444444')
              .backgroundColor('#F0F0F0')
              .borderRadius(16)
              .margin({ right: 8 })
              .onClick(async () => {
                this.isRefreshing = true;
                await refreshAllFeeds();
                await this.loadData();
                this.isRefreshing = false;
              })
            Button($r('app.string.action_sort'))
              .type(ButtonType.Normal)
              .height(32)
              .fontSize(13)
              .fontColor('#444444')
              .backgroundColor('#F0F0F0')
              .borderRadius(16)
              .onClick(() => {
                this.showSortMenu = !this.showSortMenu;
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          // 排序菜单
          if (this.showSortMenu) {
            Column() {
              this.sortMenuItem('按字母排序', FeedOrder.ALPHABETICAL)
              this.sortMenuItem('按最近更新', FeedOrder.MOST_RECENT_EPISODE)
              this.sortMenuItem('按收听次数', FeedOrder.MOST_PLAYED)
            }
            .width('100%')
            .backgroundColor('#FAFAFA')
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })
          }

          if (this.feeds.length === 0) {
            // 空状态
            Column() {
              Text('还没有订阅')
                .fontSize(18)
                .fontColor('#444444')
                .margin({ top: 100 })
              Text('点击右下角 + 添加你的第一个播客')
                .fontSize(14)
                .fontColor('#CCC')
                .margin({ top: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          } else {
            // 3 列网格
            Grid() {
              ForEach(this.feeds, (feed: Feed) => {
                GridItem() {
                  Column() {
                    FeedCover({
                      imageUrl: feed.imageUrl ?? '',
                      coverSize: 100,
                      coverRadius: 16
                    })
                    Text(feed.getTitle() ?? '')
                      .fontSize(12)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width(100)
                      .margin({ top: 6 })
                      .textAlign(TextAlign.Center)
                  }
                  .onClick(() => {
                    router.pushUrl({
                      url: 'pages/EpisodeListPage',
                      params: { feedId: feed.id, feedTitle: feed.getTitle() }
                    });
                  })
                  .padding(4)
                  .priorityGesture(
                    LongPressGesture({ repeat: false, duration: 500 })
                      .onAction(() => {
                        AlertDialog.show({
                          title: '取消订阅',
                          message: `确定要取消订阅「${feed.getTitle()}」吗？所有剧集数据将被删除。`,
                          primaryButton: {
                            value: '取消',
                            action: () => {}
                          },
                          secondaryButton: {
                            value: '确定',
                            fontColor: '#F44336',
                            action: async () => {
                              await deleteFeed(feed.id);
                              promptAction.showToast({ message: '已取消订阅', duration: 1500 });
                              this.loadData();
                              EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: [feed.id] });
                            }
                          }
                        });
                      })
                  )
                }
              }, (feed: Feed) => feed.id.toString())
            }
            .columnsTemplate('1fr 1fr 1fr')
            .columnsGap(10)
            .rowsGap(10)
            .padding({ left: 16, right: 16, top: 8 })
            .width('100%')
            .layoutWeight(1)
          }
        }
        .width('100%')
        .height('100%')
      }
      .onRefreshing(async () => {
        await refreshAllFeeds();
        await this.loadData();
        this.isRefreshing = false;
      })

      // FAB 添加订阅
      Button('+')
        .type(ButtonType.Circle)
        .width(56)
        .height(56)
        .fontSize(28)
        .fontColor('#FFFFFF')
        .backgroundColor('#0078C2')
        .shadow({ radius: 8, color: '#40000000', offsetY: 4 })
        .margin({ right: 20, bottom: 80 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddFeedPage' });
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  sortMenuItem(label: string, order: FeedOrder) {
    Text(label)
      .fontSize(14)
      .fontColor(this.sortOrder === order ? '#0078C2' : '#333')
      .fontWeight(this.sortOrder === order ? FontWeight.Bold : FontWeight.Normal)
      .padding({ top: 10, bottom: 10 })
      .width('100%')
      .onClick(() => {
        this.sortOrder = order;
        this.feeds = this.sortFeeds(this.feeds);
        this.showSortMenu = false;
      })
  }
}
