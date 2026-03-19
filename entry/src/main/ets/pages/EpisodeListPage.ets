import { router, promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { Feed, FeedItem, FeedMedia, FeedItemFilter, SortOrder, PlayState, TAG_QUEUE, TAG_FAVORITE,
  EventBus, QUEUE_UPDATE, FAVORITES_UPDATE, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE, DOWNLOAD_ERROR } from 'common';
import type { QueueUpdateData, DownloadProgressData, DownloadCompleteData, DownloadErrorData } from 'common';
import { getFeed, getFeedItemList, addQueueItem, removeQueueItem,
  addFavoriteItem, removeFavoriteItem, markItemPlayed, deleteFeedMediaOfItem,
  setFeedCustomTitle } from 'datastore';
import { refreshFeed, downloadNow, isDownloading, getDownloadProgress, cancelDownload, getActiveDownloads, requestProgressUpdate } from 'network';
import { pasteboard } from '@kit.BasicServicesKit';
import { LongPressHelper } from '../utils/LongPressHelper';

/**
 * 剧集列表页 — 对照 Android 截图逐像素还原
 */
@Entry
@Component
struct EpisodeListPage {
  @State feed: Feed | null = null;
  @State items: FeedItem[] = [];
  @State feedId: number = 0;
  @State feedTitle: string = '';
  @State isRefreshing: boolean = false;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State sortOrder: SortOrder = SortOrder.DATE_NEW_OLD;
  @State currentFilter: FeedItemFilter | null = null;
  @State downloadingUrls: Map<string, number> = new Map(); // url → progress(0~100)
  @State downloadRefreshKey: number = 0; // 触发 ForEach 重渲染
  @State showContextMenu: boolean = false;
  @State selectedEpisode: FeedItem | null = null;
  @State publishCycleText: string = ''; // Task-031: 发布周期预测
  // Task-024: 排序/筛选弹窗
  @State showSortSheet: boolean = false;
  @State showFilterSheet: boolean = false;
  @State filterPlayed: string = 'ALL';
  @State showRenameSheet: boolean = false;
  @State renameText: string = '';
  @State filterDownloaded: string = 'ALL';
  @State filterFavorite: boolean = false;
  private downloadTimers: Map<string, number> = new Map(); // url → timerId（未使用，保留兼容）
  private lp = new LongPressHelper();
  private pageOffset: number = 0;
  private readonly pageSize: number = 50;

  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    // 从 urls Map 更新本地下载状态
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };

  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    // 下载完成：清除标记 + 从 DB 重新加载
    this.downloadingUrls = new Map();
    this.loadItems(true);
  };

  private onDownloadError: (data: DownloadErrorData) => void = (data: DownloadErrorData) => {
    // 下载失败：清除该 URL 的进度标记
    this.downloadingUrls = new Map();
    promptAction.showToast({
      message: `下载失败: ${data.episodeTitle} (${data.errorType})`,
      duration: 3000
    });
  };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.feedId = params['feedId'] as number ?? 0;
      this.feedTitle = params['feedTitle'] as string ?? '';
    }
    this.loadFeed();
    this.loadItems(true).then(() => {
      this.calcPublishCycle();
      // items 加载完后再请求一次进度推送，确保 UI 显示正确
      requestProgressUpdate();
    });
    // 先注册监听，再请求进度推送 — 保证不丢事件
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    EventBus.on<DownloadErrorData>(DOWNLOAD_ERROR, this.onDownloadError);
    // 立即请求一次当前下载进度（页面重新进入时恢复状态）
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    EventBus.off(DOWNLOAD_ERROR, this.onDownloadError);
  }

  async loadFeed(): Promise<void> {
    this.feed = await getFeed(this.feedId);
    if (this.feed !== null) {
      this.feedTitle = this.feed.getTitle() ?? '';
      if (this.feed.sortOrder !== null) {
        this.sortOrder = this.feed.sortOrder;
      }
    }
  }

  async loadItems(reset: boolean): Promise<void> {
    if (reset) {
      this.pageOffset = 0;
      this.hasMore = true;
    }
    const newItems = await getFeedItemList(this.feedId, this.currentFilter,
      this.sortOrder, this.pageOffset, this.pageSize);
    if (reset) {
      this.items = newItems;
    } else {
      this.items = this.items.concat(newItems);
    }
    this.hasMore = newItems.length >= this.pageSize;
    this.pageOffset += newItems.length;
  }

  build() {
    Column() {
      Refresh({ refreshing: $$this.isRefreshing }) {
        List() {
          // ===== Feed 头部（深色模糊背景）=====
          if (this.feed !== null) {
            ListItem() {
              Stack() {
                // 模糊暗化背景 — 高度跟 Stack 同步（220vp）
                if ((this.feed!.imageUrl ?? '').length > 0) {
                  Image(this.feed!.imageUrl!)
                    .width('100%')
                    .height(220)
                    .objectFit(ImageFit.Cover)
                    .blur(30)
                    .brightness(0.3)
                } else {
                  Column()
                    .width('100%')
                    .height(220)
                    .backgroundColor('#2C2C2C')
                }

                Column() {
                  // 顶栏（SymbolGlyph 白色图标，融入背景）
                  Row() {
                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.chevron_left'))
                        .fontSize(22)
                        .fontColor([Color.White])
                    }
                    .width(40).height(40)
                    .onClick(() => { router.back(); })

                    Blank()

                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.magnifyingglass'))
                        .fontSize(20)
                        .fontColor([Color.White])
                    }
                    .width(40).height(40)
                    .onClick(() => { router.pushUrl({ url: 'pages/SearchPage' }); })

                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.gearshape'))
                        .fontSize(20)
                        .fontColor([Color.White])
                    }
                    .width(40).height(40)
                    .onClick(() => {
                      router.pushUrl({
                        url: 'pages/FeedSettingsPage',
                        params: { feedId: this.feedId, feedTitle: this.feedTitle }
                      });
                    })

                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
                        .fontSize(20)
                        .fontColor([Color.White])
                    }
                    .width(40).height(40)
                    .bindMenu([
                      {
                        value: '重命名',
                        action: () => {
                          this.renameText = this.feed?.customTitle ?? this.feed?.feedTitle ?? '';
                          this.showRenameSheet = true;
                        }
                      }
                    ])
                  }
                  .width('100%')
                  .padding({ left: 8, right: 8 })
                  .height(48)

                  // 封面 96×96 + 标题/作者（缩小封面使总高度适配 220vp）
                  Row() {
                    if ((this.feed!.imageUrl ?? '').length > 0) {
                      Image(this.feed!.imageUrl!)
                        .width(96)
                        .height(96)
                        .borderRadius(8)
                        .objectFit(ImageFit.Cover)
                        .shadow({ radius: 8, color: 'rgba(0,0,0,0.3)' })
                    }
                    Column() {
                      Text(this.feed!.getTitle() ?? '')
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .textShadow({ radius: 2, color: '#000000' })
                      Text(this.feed!.author ?? '')
                        .fontSize(13)
                        .fontColor('#FFFFFF')
                        .maxLines(1)
                        .margin({ top: 4 })
                        .textShadow({ radius: 2, color: '#000000' })
                      // Task-031: 发布周期预测
                      if (this.publishCycleText.length > 0) {
                        Text(this.publishCycleText)
                          .fontSize(11)
                          .fontColor('#AADDFF')
                          .maxLines(1)
                          .margin({ top: 3 })
                          .textShadow({ radius: 2, color: '#000000' })
                      }
                    }
                    .margin({ left: 16 })
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .padding({ left: 20, right: 20 })
                  .margin({ top: 8 })

                  // 3 个半透明图标按钮 — FD8: 48×48vp, FD2: SymbolGlyph
                  Row() {
                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.info_circle'))
                        .fontSize(24)
                        .fontColor([Color.White])
                    }
                    .width(48)
                    .height(48)
                    .borderRadius(24)
                    .backgroundColor('rgba(255,255,255,0.15)')
                    .onClick(() => {
                      router.pushUrl({
                        url: 'pages/FeedInfoPage',
                        params: { feedId: this.feedId }
                      });
                    })

                    // Task-024: 筛选按钮（带激活指示点）
                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
                        .fontSize(24)
                        .fontColor([Color.White])
                      // 筛选激活时显示小蓝点
                      if (this.hasActiveFilter()) {
                        Circle()
                          .width(8)
                          .height(8)
                          .fill('#0078C2')
                          .position({ x: 34, y: 6 })
                      }
                    }
                    .width(48)
                    .height(48)
                    .borderRadius(24)
                    .backgroundColor('rgba(255,255,255,0.15)')
                    .margin({ left: 24, right: 24 })
                    .onClick(() => { this.showFilterSheet = true; })

                    // Task-024: 排序按钮
                    Stack({ alignContent: Alignment.Center }) {
                      SymbolGlyph($r('sys.symbol.arrow_down'))
                        .fontSize(24)
                        .fontColor([Color.White])
                    }
                    .width(48)
                    .height(48)
                    .borderRadius(24)
                    .backgroundColor('rgba(255,255,255,0.15)')
                    .onClick(() => { this.showSortSheet = true; })
                  }
                  .width('100%')
                  .height(48)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#80000000')
                  .margin({ top: 12 })
                  .padding({ bottom: 4 })
                }
              }
              .width('100%')
              .height(220)
            }
          }

          // ===== 单集列表 =====
          ForEach(this.items, (item: FeedItem) => {
            ListItem() {
              Row() {
                // FD9: 列表项封面 56×56vp, FD7: 圆角 4vp
                Image(item.getImageLocation() ?? this.feed?.imageUrl ?? '')
                  .width(56)
                  .height(56)
                  .borderRadius(4)
                  .objectFit(ImageFit.Cover)
                  .margin({ right: 12 })

                // 中间：信息区
                Column() {
                  // 第一行：≡→(新) · 日期 · 大小
                  Row() {
                    if (item.isNew()) {
                      Text('≡→')
                        .fontSize(11)
                        .fontColor('#0078C2')
                        .margin({ right: 4 })
                    }
                    Text(this.formatDate(item.pubDate))
                      .fontSize(11)
                      .fontColor('#444444')
                    if (item.media !== null && item.media.size > 0) {
                      Text(' · ')
                        .fontSize(11)
                        .fontColor('#444444')
                      Text(this.formatSize(item.media.size))
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                  }

                  // 第二行：标题（BodyLarge 16fp，最多 2 行）
                  Text(item.title ?? '')
                    .fontSize(16)
                    .fontWeight(FontWeight.Normal)
                    .fontColor(item.isPlayed() ? '#444444' : '#000000')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 4 })

                  // 第三行：进度条 或 时长
                  if (item.media !== null && item.media.position > 0 && item.media.duration > 0) {
                    Row() {
                      Text(this.formatTime(item.media.position))
                        .fontSize(11)
                        .fontColor('#444444')
                      Progress({
                        value: item.media.position,
                        total: item.media.duration,
                        type: ProgressType.Linear
                      })
                        .layoutWeight(1)
                        .height(3)
                        .color('#0078C2')
                        .backgroundColor('#E0E0E0')
                        .margin({ left: 6, right: 6 })
                      Text(this.formatTime(item.media.duration))
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                    .width('100%')
                    .margin({ top: 4 })
                    .alignItems(VerticalAlign.Center)
                  } else if (item.media !== null && item.media.duration > 0) {
                    Text(this.formatTime(item.media.duration))
                      .fontSize(11)
                      .fontColor('#444444')
                      .margin({ top: 4 })
                  }
                }
                .layoutWeight(1)

                // 右侧：操作按钮（圆形描边 40vp）
                this.actionButton(item)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .alignItems(VerticalAlign.Center)
              .onTouch((e: TouchEvent) => {
                this.lp.onTouch(e, () => {
                  this.selectedEpisode = item;
                  this.showContextMenu = true;
                });
              })
              .onClick(() => {
                if (!this.lp.fired) {
                  router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: item.id } });
                }
              })
            }
            .swipeAction({
              start: {
                builder: () => { this.swipeFavoriteButton(item) }
              },
              end: {
                builder: () => { this.swipeDownloadButton(item) }
              }
            })
          }, (item: FeedItem) => {
            const url = item.media !== null ? (item.media.downloadUrl ?? '') : '';
            const isDl = this.downloadingUrls.has(url) ? 'ing' : '';
            return item.id.toString() + '_' +
              (item.isFavorite() ? 'f' : '') +
              (item.isQueued() ? 'q' : '') +
              (item.isPlayed() ? 'p' : '') +
              (item.isDownloaded() ? 'd' : '') + isDl;
          })

          // 加载更多
          if (this.hasMore) {
            ListItem() {
              Row() {
                Text('加载更多...')
                  .fontSize(14)
                  .fontColor('#444444')
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
              .onAppear(() => {
                if (!this.isLoadingMore) {
                  this.isLoadingMore = true;
                  this.loadItems(false).then(() => {
                    this.isLoadingMore = false;
                  });
                }
              })
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#E8E8E8', startMargin: 88 })
      }
      .onRefreshing(async () => {
        if (this.feed !== null) {
          await refreshFeed(this.feed);
          await this.loadFeed();
          await this.loadItems(true);
        }
        this.isRefreshing = false;
      })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showContextMenu, () => { this.contextMenuSheet(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false,
      dragBar: true
    })
    // Task-024: 排序弹窗
    .bindSheet($$this.showSortSheet, () => { this.SortSheetBuilder(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: true,
      dragBar: true
    })
    // Task-024: 筛选弹窗
    .bindSheet($$this.showFilterSheet, () => { this.FilterSheetBuilder(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: true,
      dragBar: true
    })
    .bindSheet($$this.showRenameSheet, () => { this.RenameSheetBuilder(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: true,
      dragBar: true
    })
  }

  // ===== 右侧按钮：按状态切换（#14 精确复刻 Android）=====
  @Builder
  actionButton(item: FeedItem) {
    if (item.media === null) {
      // 无媒体 → 不显示
    } else if (isDownloading(item.media.downloadUrl ?? '') || this.downloadingUrls.has(item.media.downloadUrl ?? '')) {
      // ===== 下载中 → FD1: Progress Ring 真实进度 + FD2: SymbolGlyph ✕ =====
      Stack() {
        Progress({ value: this.downloadingUrls.get(item.media!.downloadUrl ?? '') ?? 0, total: 100, type: ProgressType.Ring })
          .width(40)
          .height(40)
          .color('#0078C2')
          .backgroundColor('#D0D0D0')
          .style({ strokeWidth: 3 })
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(16)
          .fontColor(['#000000'])
      }
      .width(48)
      .height(48)
      .onClick(() => {
        const dlUrl = item.media!.downloadUrl ?? '';
        cancelDownload(dlUrl);
        this.downloadingUrls.delete(dlUrl);
        this.downloadingUrls = new Map(this.downloadingUrls);
        this.downloadRefreshKey++;
        promptAction.showToast({ message: '已取消下载', duration: 1500 });
      })
    } else if (item.isDownloaded()) {
      // ===== 已下载 → FD2: SymbolGlyph ▶ + 满圆环 =====
      Stack() {
        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(40)
          .height(40)
          .color('#000000')
          .backgroundColor('#D0D0D0')
          .style({ strokeWidth: 3 })
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(18)
          .fontColor(['#000000'])
      }
      .width(48)
      .height(48)
      .onClick(async () => {
        if (item.media !== null) {
          try {
            await getController().playMedia(item.media, item.feedId, false);
            promptAction.showToast({ message: '正在播放', duration: 1500 });
          } catch (e) {
            const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
            promptAction.showToast({ message: '播放失败: ' + msg, duration: 3000 });
          }
        }
      })
    } else {
      // ===== 未下载 → FD2: SymbolGlyph ↓ + 空轨道圆环 =====
      Stack() {
        Progress({ value: 0, total: 100, type: ProgressType.Ring })
          .width(40)
          .height(40)
          .color('#000000')
          .backgroundColor('#D0D0D0')
          .style({ strokeWidth: 1 })
        SymbolGlyph($r('sys.symbol.arrow_down'))
          .fontSize(18)
          .fontColor(['#444444'])
      }
      .width(48)
      .height(48)
      .onClick(() => {
        if (item.media !== null && item.media.downloadUrl !== null) {
          // 立刻标记为下载中 → 触发 key 变化 → 显示 LoadingProgress
          this.downloadingUrls.set(item.media.downloadUrl, 1);
          this.downloadingUrls = new Map(this.downloadingUrls);
          const feedTitle = this.feed !== null ? (this.feed.getTitle() ?? 'podcast') : 'podcast';
          downloadNow(item, feedTitle, getContext(this).filesDir);
        }
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

  @Builder
  swipeFavoriteButton(item: FeedItem) {
    Row() {
      Button(item.isFavorite() ? '取消收藏' : '★ 收藏')
        .backgroundColor('#FFC107')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => { this.toggleFavorite(item); })
    }
  }

  @Builder
  swipeDownloadButton(item: FeedItem) {
    Row() {
      Button(item.isDownloaded() ? '已下载' : '↓ 下载')
        .backgroundColor('#0078C2')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => {
          if (!item.isDownloaded() && item.media !== null && item.media.downloadUrl !== null) {
            const feedTitle = this.feed !== null ? (this.feed.getTitle() ?? 'podcast') : 'podcast';
            downloadNow(item, feedTitle, getContext(this).filesDir);
            promptAction.showToast({ message: '开始下载', duration: 1500 });
          }
        })
    }
  }

  // ===== 长按上下文菜单（#19 — 对照 Android FeedItemMenuHandler 复刻）=====

  @Builder
  contextMenuSheet() {
    Column() {
      // 标题区
      if (this.selectedEpisode !== null) {
        Text(this.selectedEpisode!.title ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      }

      Divider().strokeWidth(0.5).color('#E8E8E8')

      // 队列操作（互斥显示）
      if (this.selectedEpisode !== null && !this.selectedEpisode!.isQueued()) {
        this.contextMenuItem('加入队列', $r('sys.symbol.music_note_list'), () => {
          this.ctxToggleQueue();
        })
      }
      if (this.selectedEpisode !== null && this.selectedEpisode!.isQueued()) {
        this.contextMenuItem('从队列移除', $r('sys.symbol.xmark'), () => {
          this.ctxToggleQueue();
        })
      }

      // 收藏操作（互斥显示）
      if (this.selectedEpisode !== null && !this.selectedEpisode!.isFavorite()) {
        this.contextMenuItem('加收藏', $r('sys.symbol.star'), () => {
          this.ctxToggleFavorite();
        })
      }
      if (this.selectedEpisode !== null && this.selectedEpisode!.isFavorite()) {
        this.contextMenuItem('取消收藏', $r('sys.symbol.star_fill'), () => {
          this.ctxToggleFavorite();
        })
      }

      // 播放已播/未播（互斥显示）
      if (this.selectedEpisode !== null && !this.selectedEpisode!.isPlayed()) {
        this.contextMenuItem('标记已播', $r('sys.symbol.checkmark'), () => {
          this.ctxMarkPlayed(true);
        })
      }
      if (this.selectedEpisode !== null && this.selectedEpisode!.isPlayed()) {
        this.contextMenuItem('标记未播', $r('sys.symbol.arrow_clockwise'), () => {
          this.ctxMarkPlayed(false);
        })
      }

      // 下载/删除（互斥显示）
      if (this.selectedEpisode !== null && this.selectedEpisode!.media !== null && !this.selectedEpisode!.isDownloaded()) {
        this.contextMenuItem('下载', $r('sys.symbol.arrow_down'), () => {
          this.ctxDownload();
        })
      }
      if (this.selectedEpisode !== null && this.selectedEpisode!.isDownloaded()) {
        this.contextMenuItem('删除本地文件', $r('sys.symbol.xmark'), () => {
          this.ctxDeleteMedia();
        })
      }

      // 流式播放
      if (this.selectedEpisode !== null && this.selectedEpisode!.media !== null) {
        this.contextMenuItem('流式播放', $r('sys.symbol.play_fill'), () => {
          this.ctxStreamPlay();
        })
      }

      // 分享
      this.contextMenuItem('分享链接', $r('sys.symbol.arrow_up'), () => {
        this.ctxShare();
      })

      // 跳转至播客（当前已在该播客页时隐藏）— 但保留以备从其他页面复用
      Blank().height(20)
    }
    .width('100%')
  }

  @Builder
  contextMenuItem(label: string, icon: Resource, action: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor(['#333333'])
        .margin({ right: 16 })
      Text(label)
        .fontSize(16)
        .fontColor('#1A1A1A')
    }
    .width('100%')
    .height(52)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.showContextMenu = false;
      action();
    })
  }

  // ===== 上下文菜单操作 =====

  private ctxToggleQueue(): void {
    if (this.selectedEpisode === null) return;
    this.toggleQueue(this.selectedEpisode!).catch(() => {});
  }

  private ctxToggleFavorite(): void {
    if (this.selectedEpisode === null) return;
    this.toggleFavorite(this.selectedEpisode!).catch(() => {});
  }

  private ctxMarkPlayed(played: boolean): void {
    if (this.selectedEpisode === null) return;
    const item = this.selectedEpisode!;
    markItemPlayed(item.id, played ? PlayState.PLAYED : PlayState.UNPLAYED).then(() => {
      item.state = played ? PlayState.PLAYED : PlayState.UNPLAYED;
      this.items = this.items.slice();
      promptAction.showToast({ message: played ? '已标记为已播' : '已标记为未播', duration: 1500 });
    }).catch(() => {});
  }

  private ctxDownload(): void {
    if (this.selectedEpisode === null || this.selectedEpisode!.media === null) return;
    const media = this.selectedEpisode!.media!;
    if (media.downloadUrl !== null) {
      this.downloadingUrls.set(media.downloadUrl, 1);
      this.downloadingUrls = new Map(this.downloadingUrls);
      const feedTitle = this.feed !== null ? (this.feed.getTitle() ?? 'podcast') : 'podcast';
      downloadNow(this.selectedEpisode!, feedTitle, getContext(this).filesDir);
      promptAction.showToast({ message: '开始下载', duration: 1500 });
    }
  }

  private ctxDeleteMedia(): void {
    if (this.selectedEpisode === null) return;
    const item = this.selectedEpisode!;
    deleteFeedMediaOfItem(item.id).then(() => {
      if (item.media !== null) {
        item.media.localFileUrl = null;
      }
      this.items = this.items.slice();
      promptAction.showToast({ message: '已删除本地文件', duration: 1500 });
    }).catch(() => {});
  }

  private ctxStreamPlay(): void {
    if (this.selectedEpisode === null || this.selectedEpisode!.media === null) return;
    const media = this.selectedEpisode!.media!;
    getController().playMedia(media, this.selectedEpisode!.feedId, true).then(() => {
      promptAction.showToast({ message: '正在播放', duration: 1500 });
    }).catch((e: Error) => {
      promptAction.showToast({ message: '播放失败: ' + e.message, duration: 3000 });
    });
  }

  private ctxShare(): void {
    if (this.selectedEpisode === null) return;
    const item = this.selectedEpisode!;
    const url = item.link ?? item.media?.downloadUrl ?? '';
    if (url.length > 0) {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData).then(() => {
        promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
      }).catch(() => {
        promptAction.showToast({ message: '复制失败', duration: 1500 });
      });
    }
  }

  // ===== Task-024: 排序弹窗 =====

  @Builder
  SortSheetBuilder() {
    Column() {
      Text('排序方式')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, top: 16, bottom: 12 })
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.sortButton('发布日期', SortOrder.DATE_NEW_OLD, SortOrder.DATE_OLD_NEW)
        this.sortButton('单集标题', SortOrder.EPISODE_TITLE_A_Z, SortOrder.EPISODE_TITLE_Z_A)
        this.sortButton('时长', SortOrder.DURATION_LONG_SHORT, SortOrder.DURATION_SHORT_LONG)
        this.sortButton('大小', SortOrder.SIZE_LARGE_SMALL, SortOrder.SIZE_SMALL_LARGE)
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 8 })

      // 随机排序单独一行
      Button('随机')
        .width(100)
        .height(36)
        .margin({ left: 16, bottom: 20 })
        .backgroundColor(this.sortOrder === SortOrder.RANDOM ? '#0078C2' : '#F0F0F0')
        .fontColor(this.sortOrder === SortOrder.RANDOM ? '#FFFFFF' : '#333333')
        .fontSize(13)
        .borderRadius(8)
        .onClick(() => {
          this.sortOrder = SortOrder.RANDOM;
          this.loadItems(true);
          this.showSortSheet = false;
        })
    }
    .width('100%')
  }

  @Builder
  sortButton(label: string, descOrder: SortOrder, ascOrder: SortOrder) {
    Button(this.getSortButtonLabel(label, descOrder, ascOrder))
      .height(36)
      .margin(4)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.isSortActive(descOrder, ascOrder) ? '#0078C2' : '#F0F0F0')
      .fontColor(this.isSortActive(descOrder, ascOrder) ? '#FFFFFF' : '#333333')
      .fontSize(13)
      .borderRadius(8)
      .onClick(() => {
        // 点击已选中项 → 切换升降序
        if (this.sortOrder === descOrder) {
          this.sortOrder = ascOrder;
        } else {
          this.sortOrder = descOrder;
        }
        this.loadItems(true);
        this.showSortSheet = false;
      })
  }

  private isSortActive(descOrder: SortOrder, ascOrder: SortOrder): boolean {
    return this.sortOrder === descOrder || this.sortOrder === ascOrder;
  }

  private getSortButtonLabel(label: string, descOrder: SortOrder, ascOrder: SortOrder): string {
    if (this.sortOrder === descOrder) return label + ' ↓';
    if (this.sortOrder === ascOrder) return label + ' ↑';
    return label;
  }

  // ===== Task-024: 筛选弹窗 =====

  @Builder
  FilterSheetBuilder() {
    Column() {
      Text('筛选')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, top: 16, bottom: 12 })
        .width('100%')

      // 播放状态
      Text('播放状态')
        .fontSize(13)
        .fontColor('#888888')
        .padding({ left: 16, bottom: 6 })
        .width('100%')
      Row() {
        this.filterChipNew('全部', this.filterPlayed === 'ALL', () => {
          this.filterPlayed = 'ALL';
          this.applyFilters();
        })
        this.filterChipNew('未播放', this.filterPlayed === 'UNPLAYED', () => {
          this.filterPlayed = 'UNPLAYED';
          this.applyFilters();
        })
        this.filterChipNew('已播放', this.filterPlayed === 'PLAYED', () => {
          this.filterPlayed = 'PLAYED';
          this.applyFilters();
        })
      }
      .padding({ left: 16, right: 16, bottom: 12 })

      // 下载状态
      Text('下载状态')
        .fontSize(13)
        .fontColor('#888888')
        .padding({ left: 16, bottom: 6 })
        .width('100%')
      Row() {
        this.filterChipNew('全部', this.filterDownloaded === 'ALL', () => {
          this.filterDownloaded = 'ALL';
          this.applyFilters();
        })
        this.filterChipNew('已下载', this.filterDownloaded === 'DOWNLOADED', () => {
          this.filterDownloaded = 'DOWNLOADED';
          this.applyFilters();
        })
        this.filterChipNew('未下载', this.filterDownloaded === 'NOT_DOWNLOADED', () => {
          this.filterDownloaded = 'NOT_DOWNLOADED';
          this.applyFilters();
        })
      }
      .padding({ left: 16, right: 16, bottom: 12 })

      // 收藏
      Row() {
        Text('仅显示收藏')
          .fontSize(14)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.filterFavorite })
          .selectedColor('#0078C2')
          .onChange((v: boolean) => {
            this.filterFavorite = v;
            this.applyFilters();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 12 })

      // 重置
      Button('重置筛选')
        .width('90%')
        .height(40)
        .backgroundColor('#F0F0F0')
        .fontColor('#333333')
        .fontSize(14)
        .borderRadius(8)
        .margin({ bottom: 20 })
        .onClick(() => {
          this.filterPlayed = 'ALL';
          this.filterDownloaded = 'ALL';
          this.filterFavorite = false;
          this.currentFilter = null;
          this.loadItems(true);
          this.showFilterSheet = false;
        })
    }
    .width('100%')
  }

  @Builder
  filterChipNew(label: string, selected: boolean, action: () => void) {
    Text(label)
      .fontSize(13)
      .fontColor(selected ? '#FFFFFF' : '#333333')
      .backgroundColor(selected ? '#0078C2' : '#F0F0F0')
      .borderRadius(16)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .onClick(() => { action(); })
  }

  private applyFilters(): void {
    const props: string[] = [];
    if (this.filterPlayed === 'PLAYED') props.push('played');
    if (this.filterPlayed === 'UNPLAYED') props.push('unplayed');
    if (this.filterDownloaded === 'DOWNLOADED') props.push('downloaded');
    if (this.filterDownloaded === 'NOT_DOWNLOADED') props.push('not_downloaded');
    if (this.filterFavorite) props.push('is_favorite');

    this.currentFilter = props.length > 0 ? new FeedItemFilter(props) : null;
    this.loadItems(true);
  }

  private hasActiveFilter(): boolean {
    return this.filterPlayed !== 'ALL' || this.filterDownloaded !== 'ALL' || this.filterFavorite;
  }

  // ===== Task-031: 发布周期预测 =====

  private calcPublishCycle(): void {
    // 从已加载的单集中提取有 pubDate 的条目，计算平均间隔
    const dates: number[] = [];
    for (const item of this.items) {
      if (item.pubDate !== null) {
        dates.push(item.pubDate.getTime());
      }
    }
    if (dates.length < 3) {
      this.publishCycleText = '';
      return;
    }
    // 按时间倒序排列
    dates.sort((a: number, b: number) => b - a);
    // 计算相邻间隔的平均值
    let totalInterval = 0;
    const count = Math.min(dates.length - 1, 20); // 最多取最近 20 个间隔
    for (let i = 0; i < count; i++) {
      totalInterval += dates[i] - dates[i + 1];
    }
    const avgMs = totalInterval / count;
    const avgDays = Math.round(avgMs / (1000 * 60 * 60 * 24));

    if (avgDays <= 0) {
      this.publishCycleText = '';
    } else if (avgDays === 1) {
      this.publishCycleText = '约每天更新';
    } else if (avgDays <= 6) {
      this.publishCycleText = `约每 ${avgDays} 天更新`;
    } else if (avgDays <= 10) {
      this.publishCycleText = '约每周更新';
    } else if (avgDays <= 17) {
      this.publishCycleText = '约每两周更新';
    } else if (avgDays <= 45) {
      this.publishCycleText = '约每月更新';
    } else {
      this.publishCycleText = `约每 ${avgDays} 天更新`;
    }
  }

  // ===== 重命名弹窗 =====

  @Builder
  RenameSheetBuilder() {
    Column() {
      Text('重命名订阅')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, top: 16, bottom: 12 })
        .width('100%')

      TextInput({ placeholder: '输入新名称', text: this.renameText })
        .onChange((value: string) => { this.renameText = value; })
        .width('90%')
        .height(44)
        .borderRadius(8)

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
            if (this.feed !== null) {
              const newTitle = this.renameText.trim().length > 0 ? this.renameText.trim() : null;
              await setFeedCustomTitle(this.feed.id, newTitle);
              this.showRenameSheet = false;
              promptAction.showToast({ message: '已重命名', duration: 1500 });
              await this.loadFeed();
            }
          })
      }
      .width('90%')
      .padding({ top: 16, bottom: 16 })
    }
  }

  // ===== 格式化方法（匹配 Android 显示格式）=====

  formatDate(date: Date | null): string {
    if (date === null) return '';
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  formatSize(bytes: number): string {
    if (bytes <= 0) return '';
    const mb = bytes / (1024 * 1024);
    if (mb >= 1) return `${mb.toFixed(1)} MB`;
    return `${(bytes / 1024).toFixed(0)} KB`;
  }

  formatTime(ms: number): string {
    if (ms <= 0) return '00:00:00';
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    const s = totalSec % 60;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
}
