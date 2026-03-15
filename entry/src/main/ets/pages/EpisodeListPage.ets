import { router, promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { Feed, FeedItem, FeedMedia, FeedItemFilter, SortOrder, PlayState, TAG_QUEUE, TAG_FAVORITE,
  EventBus, QUEUE_UPDATE, FAVORITES_UPDATE, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE } from 'common';
import type { QueueUpdateData, DownloadProgressData, DownloadCompleteData } from 'common';
import { getFeed, getFeedItemList, addQueueItem, removeQueueItem,
  addFavoriteItem, removeFavoriteItem, markItemPlayed } from 'datastore';
import { refreshFeed, downloadNow, isDownloading, getDownloadProgress, cancelDownload } from 'network';

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
  @State showFilterMenu: boolean = false;
  @State downloadingUrls: Map<string, number> = new Map(); // url → progress(0~100)
  @State downloadRefreshKey: number = 0; // 触发 ForEach 重渲染
  private downloadTimers: Map<string, number> = new Map(); // url → timerId（未使用，保留兼容）
  private pageOffset: number = 0;
  private readonly pageSize: number = 50;

  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    // 更新进度百分比，触发圆环重渲染
    if (data.url && data.percent !== undefined) {
      this.downloadingUrls.set(data.url, data.percent);
      this.downloadingUrls = new Map(this.downloadingUrls);
    }
  };

  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    // 下载完成：清除标记 + 从 DB 重新加载
    this.downloadingUrls = new Map();
    this.loadItems(true);
  };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.feedId = params['feedId'] as number ?? 0;
      this.feedTitle = params['feedTitle'] as string ?? '';
    }
    this.loadFeed();
    this.loadItems(true);
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
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
      // 筛选菜单（浮动在列表上方）
      if (this.showFilterMenu) {
        Row() {
          this.filterChip('全部', null)
          this.filterChip('未播放', new FeedItemFilter(['unplayed']))
          this.filterChip('已下载', new FeedItemFilter(['downloaded']))
          this.filterChip('队列中', new FeedItemFilter(['queued']))
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .justifyContent(FlexAlign.Start)
        .backgroundColor('#FAFAFA')
      }

      Refresh({ refreshing: $$this.isRefreshing }) {
        List() {
          // ===== Feed 头部（深色模糊背景）=====
          if (this.feed !== null) {
            ListItem() {
              Stack() {
                // 模糊暗化背景
                if ((this.feed!.imageUrl ?? '').length > 0) {
                  Image(this.feed!.imageUrl!)
                    .width('100%')
                    .height(156)
                    .objectFit(ImageFit.Cover)
                    .blur(30)
                    .brightness(0.3)
                } else {
                  Column()
                    .width('100%')
                    .height(156)
                    .backgroundColor('#2C2C2C')
                }

                Column() {
                  // 顶栏（白色图标，融入背景）
                  Row() {
                    Button('←')
                      .type(ButtonType.Circle)
                      .width(40)
                      .height(40)
                      .fontSize(20)
                      .fontColor(Color.White)
                      .backgroundColor(Color.Transparent)
                      .onClick(() => { router.back(); })
                    Blank()
                    Button('🔍')
                      .type(ButtonType.Circle)
                      .width(40)
                      .height(40)
                      .fontSize(16)
                      .fontColor(Color.White)
                      .backgroundColor(Color.Transparent)
                      .onClick(() => { router.pushUrl({ url: 'pages/SearchPage' }); })
                    Button('⋮')
                      .type(ButtonType.Circle)
                      .width(40)
                      .height(40)
                      .fontSize(18)
                      .fontColor(Color.White)
                      .backgroundColor(Color.Transparent)
                  }
                  .width('100%')
                  .padding({ left: 8, right: 8 })
                  .height(48)

                  // 封面 + 标题/作者
                  Row() {
                    if ((this.feed!.imageUrl ?? '').length > 0) {
                      Image(this.feed!.imageUrl!)
                        .width(124)
                        .height(124)
                        .borderRadius(8)
                        .objectFit(ImageFit.Cover)
                        .shadow({ radius: 8, color: 'rgba(0,0,0,0.3)' })
                    }
                    Column() {
                      Text(this.feed!.getTitle() ?? '')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .textShadow({ radius: 2, color: '#000000' })
                      Text(this.feed!.author ?? '')
                        .fontSize(14)
                        .fontColor('#FFFFFF')
                        .maxLines(1)
                        .margin({ top: 4 })
                        .textShadow({ radius: 2, color: '#000000' })
                    }
                    .margin({ left: 16 })
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .padding({ left: 20, right: 20 })
                  .margin({ top: 8 })

                  // 3 个半透明图标按钮
                  Row() {
                    Button('ⓘ')
                      .type(ButtonType.Circle)
                      .width(40)
                      .height(40)
                      .fontSize(16)
                      .fontColor(Color.White)
                      .backgroundColor('rgba(255,255,255,0.15)')
                    Button('🔽')
                      .type(ButtonType.Circle)
                      .width(40)
                      .height(40)
                      .fontSize(14)
                      .fontColor(Color.White)
                      .backgroundColor('rgba(255,255,255,0.15)')
                      .margin({ left: 24, right: 24 })
                      .onClick(() => { this.showFilterMenu = !this.showFilterMenu; })
                    Button('⚙️')
                      .type(ButtonType.Circle)
                      .width(40)
                      .height(40)
                      .fontSize(14)
                      .fontColor(Color.White)
                      .backgroundColor('rgba(255,255,255,0.15)')
                  }
                  .width('100%')
                  .height(48)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#80000000')
                  .margin({ top: 16 })
                }
              }
              .width('100%')
              .height(156)
            }
          }

          // ===== 单集列表 =====
          ForEach(this.items, (item: FeedItem) => {
            ListItem() {
              this.episodeRow(item)
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
  }

  // ===== 单集行（逐像素还原 Android 截图）=====
  @Builder
  episodeRow(item: FeedItem) {
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
            .fontSize(12)
            .fontColor('#444444')
          if (item.media !== null && item.media.size > 0) {
            Text(' · ')
              .fontSize(12)
              .fontColor('#444444')
            Text(this.formatSize(item.media.size))
              .fontSize(12)
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
            .fontSize(12)
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
    .onClick(() => {
      router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: item.id } });
    })
  }

  // ===== 右侧按钮：按状态切换（#14 精确复刻 Android）=====
  @Builder
  actionButton(item: FeedItem) {
    if (item.media === null) {
      // 无媒体 → 不显示
    } else if (isDownloading(item.media.downloadUrl ?? '') || this.downloadingUrls.has(item.media.downloadUrl ?? '')) {
      // ===== 下载中 → 旋转进度环 + 居中 ✕ =====
      Stack() {
        // 使用 LoadingProgress 做持续旋转动画（无闪烁）
        LoadingProgress()
          .width(40)
          .height(40)
          .color('#333333')
        Text('✕')
          .fontSize(16)
          .fontColor('#000000')
      }
      .width(48)
      .height(48)
      .onClick(() => {
        const dlUrl = item.media!.downloadUrl ?? '';
        cancelDownload(dlUrl);
        const timerId = this.downloadTimers.get(dlUrl);
        if (timerId !== undefined) {
          clearInterval(timerId);
          this.downloadTimers.delete(dlUrl);
        }
        this.downloadingUrls.delete(dlUrl);
        this.downloadingUrls = new Map(this.downloadingUrls);
        this.downloadRefreshKey++;
        promptAction.showToast({ message: '已取消下载', duration: 1500 });
      })
    } else if (item.isDownloaded()) {
      // ===== 已下载 → ▶ 播放 =====
      // Android: 24dp 图标居中 + 40dp 进度满圆(100%)，容器 48dp
      Stack() {
        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(40)
          .height(40)
          .color('#000000')
          .backgroundColor('#D0D0D0')
          .style({ strokeWidth: 3 })
        Text('▶')
          .fontSize(16)
          .fontColor('#000000')
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
      // ===== 未下载 → ↓ 下载 =====
      // Android: 24dp 图标居中 + 40dp 空轨道，容器 48dp，轨道细线 1dp
      Stack() {
        Progress({ value: 0, total: 100, type: ProgressType.Ring })
          .width(40)
          .height(40)
          .color('#000000')
          .backgroundColor('#D0D0D0')
          .style({ strokeWidth: 1 })
        Text('↓')
          .fontSize(18)
          .fontColor('#555555')
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

  @Builder
  filterChip(label: string, filter: FeedItemFilter | null) {
    Text(label)
      .fontSize(12)
      .fontColor(this.currentFilter === filter ? '#0078C2' : '#444444')
      .backgroundColor(this.currentFilter === filter ? '#E3F2FD' : '#F5F5F5')
      .borderRadius(14)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .onClick(() => {
        this.currentFilter = filter;
        this.loadItems(true);
        this.showFilterMenu = false;
      })
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
