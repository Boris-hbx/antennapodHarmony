import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { Feed, FeedItem, FeedMedia, TAG_QUEUE, TAG_FAVORITE,
  EventBus, QUEUE_UPDATE, FAVORITES_UPDATE, DOWNLOAD_COMPLETE } from 'common';
import type { QueueUpdateData, DownloadCompleteData } from 'common';
import { getFeedItem, getFeed, addQueueItem, removeQueueItem,
  addFavoriteItem, removeFavoriteItem } from 'datastore';
import { downloadNow } from 'network';
import { getController } from '../entryability/EntryAbility';

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

  private itemId: number = 0;

  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    // 下载完成后重新加载，刷新下载状态和 localFileUrl
    if (this.itemId > 0) {
      this.loadItem(this.itemId);
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.itemId = params['itemId'] as number ?? 0;
      this.loadItem(this.itemId);
    }
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  async loadItem(itemId: number): Promise<void> {
    this.item = await getFeedItem(itemId);
    if (this.item !== null) {
      this.feed = await getFeed(this.item.feedId);
      this.isFav = this.item.isFavorite();
      this.isQueued = this.item.isQueued();
      this.isDownloaded = this.item.isDownloaded();
      if (this.feed !== null) {
        this.item.setFeedImageUrl(this.feed.imageUrl);
      }
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button('←')
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .fontColor('#333')
          .fontSize(20)
          .onClick(() => { router.back(); })
        Text(this.item?.title ?? '单集详情')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      if (this.item !== null) {
        Scroll() {
          Column() {
            // 封面 + 信息
            Row() {
              if ((this.item!.getImageLocation() ?? '').length > 0) {
                Image(this.item!.getImageLocation()!)
                  .width(100)
                  .height(100)
                  .borderRadius(10)
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  Text('🎙️')
                    .fontSize(36)
                }
                .width(100)
                .height(100)
                .borderRadius(10)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)
              }

              Column() {
                Text(this.feed?.getTitle() ?? '')
                  .fontSize(14)
                  .fontColor('#444444')
                  .maxLines(1)
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

              // 下载
              Button(this.isDownloaded ? '✓ 已下载' : '↓ 下载')
                .type(ButtonType.Normal)
                .height(36)
                .fontSize(13)
                .fontColor(this.isDownloaded ? '#4CAF50' : '#0078C2')
                .backgroundColor(this.isDownloaded ? '#E8F5E9' : '#E3F2FD')
                .borderRadius(18)
                .margin({ left: 8 })
                .onClick(() => {
                  if (!this.isDownloaded && this.item!.media !== null) {
                    const feedTitle = this.feed !== null ? (this.feed!.getTitle() ?? '') : '';
                    downloadNow(this.item!, feedTitle, getContext(this).filesDir);
                    promptAction.showToast({ message: '开始下载', duration: 1500 });
                  }
                })

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
