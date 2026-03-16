import { router, promptAction } from '@kit.ArkUI';
import { Feed, FeedOrder, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { getFeedList, getNavDrawerData, deleteFeed, setFeedCustomTitle } from 'datastore';
import { refreshAllFeeds } from 'network';
import { FeedCover } from '../components/FeedCover';

/**
 * 订阅列表页 — Task-025: 排序/筛选/计数 ⋮ 菜单 + 长按完整操作菜单
 */
@Component
export struct SubscriptionsPage {
  @State feeds: Feed[] = [];
  @State allFeeds: Feed[] = [];
  @State isRefreshing: boolean = false;
  @State sortOrder: FeedOrder = FeedOrder.ALPHABETICAL;
  @State columnCount: number = 3;

  // Task-025: 排序/筛选/计数弹窗
  @State showSortSheet: boolean = false;
  @State showFilterSheet: boolean = false;
  @State showBadgeSheet: boolean = false;
  @State filterTag: string = '';
  @State allTags: string[] = [];
  @State badgeMode: string = 'NONE'; // NONE / UNPLAYED / UNDOWNLOADED

  // Task-025: 长按菜单
  @State showFeedMenuSheet: boolean = false;
  @State selectedFeed: Feed | null = null;
  @State showRenameSheet: boolean = false;
  @State renameText: string = '';

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
    const rawFeeds = await getFeedList();
    this.allFeeds = rawFeeds;
    this.collectTags(rawFeeds);
    this.applyFilterAndSort();
  }

  collectTags(feeds: Feed[]): void {
    const tagSet = new Set<string>();
    for (const feed of feeds) {
      if (feed.preferences !== null) {
        feed.preferences.tags.forEach((t: string) => {
          if (t.length > 0) {
            tagSet.add(t);
          }
        });
      }
    }
    this.allTags = Array.from(tagSet).sort();
  }

  applyFilterAndSort(): void {
    let filtered = this.allFeeds.slice();
    // 按标签筛选
    if (this.filterTag.length > 0) {
      filtered = filtered.filter((f: Feed) =>
        f.preferences !== null && f.preferences.tags.has(this.filterTag)
      );
    }
    this.feeds = new Array<Feed>(...this.sortFeeds(filtered));
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
      case FeedOrder.COUNTER: // Z-A (reverse alphabetical)
        sorted.sort((a: Feed, b: Feed) => {
          const titleA = (a.getTitle() ?? '').toLowerCase();
          const titleB = (b.getTitle() ?? '').toLowerCase();
          if (titleA > titleB) return -1;
          if (titleA < titleB) return 1;
          return 0;
        });
        break;
      case FeedOrder.MOST_RECENT_EPISODE:
        sorted.sort((a: Feed, b: Feed) => b.lastRefreshAttempt - a.lastRefreshAttempt);
        break;
      case FeedOrder.MOST_PLAYED:
        sorted.sort((a: Feed, b: Feed) => b.lastRefreshAttempt - a.lastRefreshAttempt);
        break;
      default:
        break;
    }
    return sorted;
  }

  toggleColumnCount(): void {
    if (this.columnCount === 3) {
      this.columnCount = 2;
    } else if (this.columnCount === 2) {
      this.columnCount = 1;
    } else {
      this.columnCount = 3;
    }
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

            // 搜索
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(20)
                .fontColor(['#444444'])
            }
            .width(40).height(40)
            .borderRadius(20)
            .backgroundColor('#F0F0F0')
            .margin({ right: 8 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SearchPage' });
            })

            // 刷新
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(20)
                .fontColor(['#444444'])
            }
            .width(40).height(40)
            .borderRadius(20)
            .backgroundColor('#F0F0F0')
            .margin({ right: 8 })
            .onClick(async () => {
              this.isRefreshing = true;
              await refreshAllFeeds();
              await this.loadData();
              this.isRefreshing = false;
            })

            // ⋮ 菜单按钮 — Task-025: 排序/筛选器/计数
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
                .fontSize(20)
                .fontColor(['#444444'])
            }
            .width(40).height(40)
            .borderRadius(20)
            .backgroundColor('#F0F0F0')
            .margin({ right: 4 })
            .bindMenu([
              { value: '排序', action: () => { this.showSortSheet = true; } },
              { value: '筛选器', action: () => { this.showFilterSheet = true; } },
              { value: '计数', action: () => { this.showBadgeSheet = true; } },
            ])

            // 切换列数按钮
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph(this.columnCount === 1 ? $r('sys.symbol.dot_grid_2x2') : $r('sys.symbol.list_bullet'))
                .fontSize(20)
                .fontColor(['#444444'])
            }
            .width(40).height(40)
            .borderRadius(20)
            .backgroundColor('#F0F0F0')
            .onClick(() => { this.toggleColumnCount(); })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          if (this.feeds.length === 0) {
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
          } else if (this.columnCount === 1) {
            // 1列 list layout
            List() {
              ForEach(this.feeds, (feed: Feed) => {
                ListItem() {
                  Row() {
                    FeedCover({
                      imageUrl: feed.imageUrl ?? '',
                      coverSize: 56,
                      coverRadius: 12
                    })
                    Text(feed.getTitle() ?? '')
                      .fontSize(16)
                      .fontWeight(FontWeight.Normal)
                      .fontColor('#000000')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                      .margin({ left: 12 })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                  .alignItems(VerticalAlign.Center)
                  .gesture(
                    GestureGroup(GestureMode.Exclusive,
                      LongPressGesture({ repeat: false, duration: 500 })
                        .onAction(() => {
                          this.selectedFeed = feed;
                          this.showFeedMenuSheet = true;
                        }),
                      TapGesture()
                        .onAction(() => {
                          router.pushUrl({
                            url: 'pages/EpisodeListPage',
                            params: { feedId: feed.id, feedTitle: feed.getTitle() }
                          });
                        })
                    )
                  )
                }
              }, (feed: Feed) => feed.id.toString())
            }
            .width('100%')
            .layoutWeight(1)
            .divider({ strokeWidth: 0.5, color: '#E8E8E8', startMargin: 84 })
          } else {
            // 2/3 列网格
            Grid() {
              ForEach(this.feeds, (feed: Feed) => {
                GridItem() {
                  Column() {
                    FeedCover({
                      imageUrl: feed.imageUrl ?? '',
                      coverRadius: 12,
                      fillParent: true
                    })
                    Text(feed.getTitle() ?? '')
                      .fontSize(12)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .margin({ top: 6 })
                      .textAlign(TextAlign.Center)
                  }
                  .padding(4)
                  .gesture(
                    GestureGroup(GestureMode.Exclusive,
                      LongPressGesture({ repeat: false, duration: 500 })
                        .onAction(() => {
                          this.selectedFeed = feed;
                          this.showFeedMenuSheet = true;
                        }),
                      TapGesture()
                        .onAction(() => {
                          router.pushUrl({
                            url: 'pages/EpisodeListPage',
                            params: { feedId: feed.id, feedTitle: feed.getTitle() }
                          });
                        })
                    )
                  )
                }
              }, (feed: Feed) => feed.id.toString())
            }
            .columnsTemplate(this.columnCount === 2 ? '1fr 1fr' : '1fr 1fr 1fr')
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
    .bindSheet($$this.showSortSheet, this.SortSheetBuilder(), { detents: [SheetSize.FIT_CONTENT], showClose: true })
    .bindSheet($$this.showFilterSheet, this.FilterSheetBuilder(), { detents: [SheetSize.FIT_CONTENT], showClose: true })
    .bindSheet($$this.showBadgeSheet, this.BadgeSheetBuilder(), { detents: [SheetSize.FIT_CONTENT], showClose: true })
    .bindSheet($$this.showFeedMenuSheet, this.FeedMenuSheetBuilder(), { detents: [SheetSize.FIT_CONTENT], showClose: true })
    .bindSheet($$this.showRenameSheet, this.RenameSheetBuilder(), { detents: [SheetSize.FIT_CONTENT], showClose: true })
  }

  // ===== 排序弹窗 =====
  @Builder SortSheetBuilder() {
    Column() {
      Text('订阅排序').fontSize(18).fontWeight(FontWeight.Bold).padding(16)
      this.sortOption('A-Z', FeedOrder.ALPHABETICAL)
      Divider()
      this.sortOption('Z-A', FeedOrder.COUNTER)
      Divider()
      this.sortOption('最近更新', FeedOrder.MOST_RECENT_EPISODE)
      Divider()
      this.sortOption('收听次数', FeedOrder.MOST_PLAYED)
    }.padding({ bottom: 16 })
  }

  @Builder sortOption(label: string, order: FeedOrder) {
    Row() {
      Text(label).fontSize(16).layoutWeight(1)
      if (this.sortOrder === order) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor(['#0078C2'])
      }
    }
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick(() => {
      this.sortOrder = order;
      this.applyFilterAndSort();
      this.showSortSheet = false;
    })
  }

  // ===== 筛选器弹窗 =====
  @Builder FilterSheetBuilder() {
    Column() {
      Text('筛选器').fontSize(18).fontWeight(FontWeight.Bold).padding(16)

      if (this.allTags.length > 0) {
        Text('按标签').fontSize(14).fontColor('#888888').padding({ left: 16, bottom: 8 })
        Scroll() {
          Row() {
            this.FilterChip('全部', this.filterTag === '')
            ForEach(this.allTags, (tag: string) => {
              this.FilterChip(tag, this.filterTag === tag)
            }, (tag: string) => tag)
          }.padding({ left: 16, right: 16 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      } else {
        Text('暂无标签').fontSize(14).fontColor('#888888').padding(16)
      }

      Button('确定')
        .width('80%')
        .height(40)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor('#0078C2')
        .borderRadius(20)
        .margin({ top: 20, bottom: 16 })
        .onClick(() => { this.showFilterSheet = false; })
    }
  }

  @Builder FilterChip(label: string, selected: boolean) {
    Text(label)
      .fontSize(14)
      .fontColor(selected ? '#FFFFFF' : '#333333')
      .backgroundColor(selected ? '#0078C2' : '#F0F0F0')
      .borderRadius(16)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .margin({ right: 8 })
      .onClick(() => {
        this.filterTag = label === '全部' ? '' : label;
        this.applyFilterAndSort();
      })
  }

  // ===== 计数（角标模式）弹窗 =====
  @Builder BadgeSheetBuilder() {
    Column() {
      Text('角标显示').fontSize(18).fontWeight(FontWeight.Bold).padding(16)
      this.badgeOption('不显示', 'NONE')
      Divider()
      this.badgeOption('未播集数', 'UNPLAYED')
      Divider()
      this.badgeOption('未下载集数', 'UNDOWNLOADED')
    }.padding({ bottom: 16 })
  }

  @Builder badgeOption(label: string, mode: string) {
    Row() {
      Text(label).fontSize(16).layoutWeight(1)
      if (this.badgeMode === mode) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor(['#0078C2'])
      }
    }
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick(() => {
      this.badgeMode = mode;
      this.showBadgeSheet = false;
    })
  }

  // ===== 长按菜单弹窗 =====
  @Builder FeedMenuSheetBuilder() {
    Column() {
      if (this.selectedFeed !== null) {
        Text(this.selectedFeed.getTitle() ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 20, right: 20, top: 16, bottom: 8 })
          .width('100%')
      }
      this.feedMenuItem('取消订阅', $r('sys.symbol.trash'), () => { this.confirmUnsubscribe(); })
      Divider()
      this.feedMenuItem('重命名', $r('sys.symbol.star'), () => {
        this.showFeedMenuSheet = false;
        this.renameText = this.selectedFeed?.customTitle ?? this.selectedFeed?.feedTitle ?? '';
        this.showRenameSheet = true;
      })
      Divider()
      this.feedMenuItem('Feed 设置', $r('sys.symbol.circle_grid_2x2'), () => {
        this.showFeedMenuSheet = false;
        router.pushUrl({
          url: 'pages/FeedSettingsPage',
          params: { feedId: this.selectedFeed?.id }
        });
      })
    }.padding({ bottom: 16 })
  }

  @Builder feedMenuItem(label: string, icon: Resource, action: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor(['#333333'])
        .margin({ right: 12 })
      Text(label).fontSize(16).fontColor('#333333')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick(() => { action(); })
  }

  confirmUnsubscribe(): void {
    if (this.selectedFeed === null) return;
    const feed = this.selectedFeed;
    this.showFeedMenuSheet = false;
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
  }

  // ===== 重命名弹窗 =====
  @Builder RenameSheetBuilder() {
    Column() {
      Text('重命名').fontSize(18).fontWeight(FontWeight.Bold).padding(16)
      TextInput({ placeholder: '输入新名称', text: this.renameText })
        .onChange((value: string) => { this.renameText = value; })
        .width('90%')
        .height(44)
        .borderRadius(8)
        .margin({ left: 16, right: 16 })
      Row() {
        Button('取消')
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .height(40)
          .fontSize(15)
          .fontColor('#333333')
          .backgroundColor('#F0F0F0')
          .borderRadius(20)
          .margin({ right: 8 })
          .onClick(() => { this.showRenameSheet = false; })
        Button('确定')
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .height(40)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor('#0078C2')
          .borderRadius(20)
          .margin({ left: 8 })
          .onClick(async () => {
            if (this.selectedFeed !== null) {
              const newTitle = this.renameText.trim().length > 0 ? this.renameText.trim() : null;
              await setFeedCustomTitle(this.selectedFeed.id, newTitle);
              this.showRenameSheet = false;
              promptAction.showToast({ message: '已重命名', duration: 1500 });
              await this.loadData();
            }
          })
      }
      .width('90%')
      .padding({ top: 16, bottom: 16 })
    }
  }
}
