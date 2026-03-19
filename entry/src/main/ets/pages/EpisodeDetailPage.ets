import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { Feed, FeedItem, FeedMedia, TAG_QUEUE, TAG_FAVORITE,
  EventBus, QUEUE_UPDATE, FAVORITES_UPDATE, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE, DOWNLOAD_ERROR } from 'common';
import type { QueueUpdateData, DownloadProgressData, DownloadCompleteData, DownloadErrorData } from 'common';
import { getFeedItem, getFeed, addQueueItem, removeQueueItem,
  addFavoriteItem, removeFavoriteItem, markItemPlayed } from 'datastore';
import { PlayState } from 'common';
import { downloadNow, requestProgressUpdate } from 'network';
import { getController } from '../entryability/EntryAbility';
import { EpisodeActionButton } from '../components/EpisodeActionButton';

/**
 * 单集详情页 — 显示 show notes + 操作按钮
 */
@Entry
@Component
struct EpisodeDetailPage {
  @State item: FeedItem | null = null;
  @State feed: Feed | null = null;
  @State isFav: boolean = false;
  @State isQueued: boolean = false;
  @State isDownloaded: boolean = false;
  @State isPlayed: boolean = false;
  @State isLoading: boolean = true;
  @State downloadingUrls: Map<string, number> = new Map();

  private itemId: number = 0;

  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };

  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    // 下载完成：清除标记 + 从 DB 重新加载
    this.downloadingUrls = new Map();
    if (this.itemId > 0) {
      this.loadItem(this.itemId);
    }
  };

  private onDownloadError: (data: DownloadErrorData) => void = (data: DownloadErrorData) => {
    this.downloadingUrls = new Map();
    promptAction.showToast({
      message: `下载失败: ${data.episodeTitle} (${data.errorType})`,
      duration: 3000
    });
  };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.itemId = params['itemId'] as number ?? 0;
      this.loadItem(this.itemId);
    }
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    EventBus.on<DownloadErrorData>(DOWNLOAD_ERROR, this.onDownloadError);
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    EventBus.off(DOWNLOAD_ERROR, this.onDownloadError);
  }

  async loadItem(itemId: number): Promise<void> {
    this.isLoading = true;
    this.item = await getFeedItem(itemId);
    if (this.item !== null) {
      this.feed = await getFeed(this.item.feedId);
      this.isFav = this.item.isFavorite();
      this.isQueued = this.item.isQueued();
      this.isDownloaded = this.item.isDownloaded();
      this.isPlayed = this.item.isPlayed();
      if (this.feed !== null) {
        this.item.setFeedImageUrl(this.feed.imageUrl);
      }
    }
    this.isLoading = false;
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { router.back(); })

        Text(this.item?.title ?? '单集详情')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // ⋮ 菜单
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
            .fontSize(18)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .bindMenu([
          {
            value: this.isPlayed ? '标记为未播' : '标记为已播',
            action: () => { this.togglePlayed(); }
          }
        ])
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载中...').fontSize(14).fontColor('#444444').margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.item !== null) {
        Scroll() {
          Column() {
            // 封面 + 信息
            Row() {
              if ((this.item!.getImageLocation() ?? '').length > 0) {
                Image(this.item!.getImageLocation()!)
                  .width(80)
                  .height(80)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                  .onClick(() => { this.goToFeed(); })
              } else {
                Column() {
                  SymbolGlyph($r('sys.symbol.mic'))
                    .fontSize(30)
                    .fontColor(['#AAAAAA'])
                }
                .width(80)
                .height(80)
                .borderRadius(8)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)
                .onClick(() => { this.goToFeed(); })
              }

              Column() {
                Text(this.feed?.getTitle() ?? '')
                  .fontSize(14)
                  .fontColor('#0078C2')
                  .maxLines(1)
                  .onClick(() => { this.goToFeed(); })
                Row() {
                  if (this.item!.pubDate !== null) {
                    Text(this.formatDate(this.item!.pubDate!))
                      .fontSize(12)
                      .fontColor('#444444')
                  }
                  if (this.item!.media !== null && this.item!.media!.duration > 0) {
                    Text(` · ${this.formatDuration(this.item!.media!.duration)}`)
                      .fontSize(12)
                      .fontColor('#444444')
                  }
                }
                .margin({ top: 4 })

                // 进度
                if (this.item!.media !== null && this.item!.media!.position > 0 && this.item!.media!.duration > 0) {
                  Progress({
                    value: this.item!.media!.position / this.item!.media!.duration * 100,
                    total: 100,
                    type: ProgressType.Linear
                  })
                    .width('100%')
                    .height(3)
                    .color('#0078C2')
                    .margin({ top: 8 })
                }
              }
              .layoutWeight(1)
              .margin({ left: 14 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12 })

            // 操作按钮行
            Row() {
              // 播放
              Button(this.item!.isInProgress() ? '▶ 继续' : '▶ 播放')
                .type(ButtonType.Normal)
                .height(36)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .backgroundColor('#0078C2')
                .borderRadius(18)
                .onClick(async () => {
                  if (this.item!.media !== null) {
                    try {
                      await getController().playMedia(this.item!.media!, this.item!.feedId, !this.isDownloaded);
                      promptAction.showToast({ message: '正在播放', duration: 1500 });
                    } catch (e) {
                      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
                      promptAction.showToast({ message: '播放失败: ' + msg, duration: 3000 });
                    }
                  }
                })

              // 下载 / 播放统一按钮
              EpisodeActionButton({
                itemId: this.item!.id,
                downloadUrl: this.item!.media?.downloadUrl ?? '',
                isItemDownloaded: this.isDownloaded,
                feedId: this.item!.feedId,
                feedTitle: this.feed !== null ? (this.feed!.getTitle() ?? '') : '',
                filesDir: getContext(this).filesDir,
                itemTitle: this.item!.title ?? '',
                downloadProgress: this.downloadingUrls.has(this.item!.media?.downloadUrl ?? '')
                  ? (this.downloadingUrls.get(this.item!.media?.downloadUrl ?? '') ?? -1)
                  : -1,
              })
                .margin({ left: 8 })

              // 队列
              Button(this.isQueued ? '✓ 队列' : '+ 队列')
                .type(ButtonType.Normal)
                .height(36)
                .fontSize(13)
                .fontColor(this.isQueued ? '#4CAF50' : '#444444')
                .backgroundColor(this.isQueued ? '#E8F5E9' : '#F5F5F5')
                .borderRadius(18)
                .margin({ left: 8 })
                .onClick(() => { this.toggleQueue(); })

              // 收藏
              Button(this.isFav ? '★' : '☆')
                .type(ButtonType.Circle)
                .width(36)
                .height(36)
                .fontSize(16)
                .fontColor(this.isFav ? '#FFC107' : '#CCC')
                .backgroundColor('transparent')
                .margin({ left: 8 })
                .onClick(() => { this.toggleFavorite(); })

              // 分享
              Button('↗')
                .type(ButtonType.Circle)
                .width(36)
                .height(36)
                .fontSize(16)
                .fontColor('#444444')
                .backgroundColor('#F5F5F5')
                .margin({ left: 8 })
                .onClick(() => { this.shareEpisode(); })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16 })
            .justifyContent(FlexAlign.Start)

            // Show Notes
            Column() {
              Text('Show Notes')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#444444')
                .margin({ bottom: 8 })

              if ((this.item!.description ?? '').length > 0) {
                RichText(this.item!.description!)
                  .width('100%')
              } else {
                Text('暂无详细描述')
                  .fontSize(14)
                  .fontColor('#CCC')
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 20, bottom: 40 })
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  private goToFeed(): void {
    if (this.item !== null) {
      router.pushUrl({
        url: 'pages/EpisodeListPage',
        params: { feedId: this.item.feedId, feedTitle: this.feed?.getTitle() ?? '' }
      });
    }
  }

  private async togglePlayed(): Promise<void> {
    if (this.item === null) return;
    const newState = this.isPlayed ? PlayState.UNPLAYED : PlayState.PLAYED;
    await markItemPlayed(this.item.id, newState);
    this.isPlayed = !this.isPlayed;
    promptAction.showToast({ message: this.isPlayed ? '已标记为已播' : '已标记为未播', duration: 1500 });
  }

  shareEpisode(): void {
    if (this.item === null) return;
    const shareUrl = this.item.link ?? this.item.media?.downloadUrl ?? '';
    const shareText = `${this.item.title ?? ''}\n${this.feed?.getTitle() ?? ''}\n${shareUrl}`;
    // 使用剪贴板作为简易分享（systemShare 需要额外配置）
    promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
    // 实际复制到剪贴板
    const ctx = getContext(this);
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, shareText);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
    } catch (_e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  async toggleQueue(): Promise<void> {
    if (this.item === null) return;
    if (this.isQueued) {
      await removeQueueItem(this.item);
      this.item.tags.delete(TAG_QUEUE);
      this.isQueued = false;
      promptAction.showToast({ message: '已从队列移除', duration: 1500 });
    } else {
      await addQueueItem(this.item);
      this.item.tags.add(TAG_QUEUE);
      this.isQueued = true;
      promptAction.showToast({ message: '已添加到队列', duration: 1500 });
    }
    EventBus.emit<QueueUpdateData>(QUEUE_UPDATE, { action: 'toggle' });
  }

  async toggleFavorite(): Promise<void> {
    if (this.item === null) return;
    if (this.isFav) {
      await removeFavoriteItem(this.item);
      this.item.tags.delete(TAG_FAVORITE);
      this.isFav = false;
      promptAction.showToast({ message: '已取消收藏', duration: 1500 });
    } else {
      await addFavoriteItem(this.item);
      this.item.tags.add(TAG_FAVORITE);
      this.isFav = true;
      promptAction.showToast({ message: '已收藏', duration: 1500 });
    }
    EventBus.emit<void>(FAVORITES_UPDATE);
  }

  formatDate(date: Date): string {
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${date.getFullYear()}-${m}-${d}`;
  }

  formatDuration(ms: number): string {
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    if (h > 0) return `${h}h${m}min`;
    return `${m}min`;
  }
}
