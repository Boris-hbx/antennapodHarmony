import { router, promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { FeedItem, FeedMedia, EventBus, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE } from 'common';
import type { DownloadProgressData, DownloadCompleteData } from 'common';
import { getFeedList, getFeedItemList } from 'datastore';
import {
  getActiveDownloads, cancelDownload, isDownloading, getDownloadProgress
} from 'network';
import type { DownloadTask } from 'network';

/**
 * 下载管理页面（需求 6）
 *
 * 展示下载中 + 已下载两个列表。
 */

interface DownloadedEpisode {
  item: FeedItem;
  media: FeedMedia;
  feedTitle: string;
}

@Entry
@Component
struct DownloadsPage {
  @State activeTasks: DownloadTask[] = [];
  @State downloadedItems: DownloadedEpisode[] = [];
  @State isLoading: boolean = true;

  private progressCallback: (data: DownloadProgressData) => void = () => {
    this.activeTasks = getActiveDownloads();
  };

  private completeCallback: (data: DownloadCompleteData) => void = () => {
    // 下载完成后重新加载，刷新已下载列表
    this.loadData();
  };

  aboutToAppear(): void {
    this.loadData();
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.progressCallback);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.completeCallback);
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_PROGRESS, this.progressCallback);
    EventBus.off(DOWNLOAD_COMPLETE, this.completeCallback);
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    this.activeTasks = getActiveDownloads();

    // 收集所有已下载的单集
    const downloaded: DownloadedEpisode[] = [];
    const feeds = await getFeedList();
    for (const feed of feeds) {
      const items = await getFeedItemList(feed.id, null, null, 0, 0);
      for (const item of items) {
        if (item.media !== null && item.media.isDownloaded()) {
          const ep: DownloadedEpisode = {
            item: item,
            media: item.media,
            feedTitle: feed.getTitle() ?? ''
          };
          downloaded.push(ep);
        }
      }
    }
    // 按下载时间降序
    downloaded.sort((a: DownloadedEpisode, b: DownloadedEpisode) =>
      b.media.downloadDate - a.media.downloadDate);
    this.downloadedItems = downloaded;
    this.isLoading = false;
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
          .onClick(() => {
            router.back();
          })
        Text($r('app.string.title_downloads'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // 下载中
        if (this.activeTasks.length > 0) {
          ListItem() {
            Text(`下载中 (${this.activeTasks.length})`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#444444')
              .padding({ left: 16, top: 12, bottom: 8 })
          }

          ForEach(this.activeTasks, (task: DownloadTask) => {
            ListItem() {
              Row() {
                Column() {
                  Text(task.itemTitle)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Progress({ value: task.progress, total: 100, type: ProgressType.Linear })
                    .width('100%')
                    .height(4)
                    .color('#0078C2')
                    .backgroundColor('#E0E0E0')
                    .margin({ top: 6 })
                  Text(`${task.progress}%`)
                    .fontSize(11)
                    .fontColor('#444444')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)

                Button('✕')
                  .type(ButtonType.Circle)
                  .width(32)
                  .height(32)
                  .fontSize(14)
                  .fontColor('#F44336')
                  .backgroundColor('#FFEBEE')
                  .margin({ left: 12 })
                  .onClick(() => {
                    cancelDownload(task.url);
                    this.activeTasks = getActiveDownloads();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            }
          }, (task: DownloadTask) => task.url)
        }

        // 已下载
        ListItem() {
          Text(`已下载 (${this.downloadedItems.length})`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#444444')
            .padding({ left: 16, top: 16, bottom: 8 })
        }

        if (this.downloadedItems.length === 0 && this.activeTasks.length === 0) {
          ListItem() {
            Column() {
              Text('暂无下载')
                .fontSize(16)
                .fontColor('#CCC')
                .margin({ top: 40 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }

        ForEach(this.downloadedItems, (ep: DownloadedEpisode) => {
          ListItem() {
            Row() {
              // 封面
              Column() {
                Text('🎙️')
                  .fontSize(18)
              }
              .width(48)
              .height(48)
              .borderRadius(6)
              .backgroundColor('#F0F0F0')
              .justifyContent(FlexAlign.Center)

              Column() {
                Text(ep.item.title ?? '')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(ep.feedTitle)
                  .fontSize(12)
                  .fontColor('#444444')
                  .margin({ top: 2 })
                Row() {
                  Text(this.formatDuration(ep.media.duration))
                    .fontSize(11)
                    .fontColor('#444444')
                  Text(' · ')
                    .fontSize(11)
                    .fontColor('#444444')
                  Text(this.formatSize(ep.media.size))
                    .fontSize(11)
                    .fontColor('#444444')
                }
                .margin({ top: 2 })
              }
              .layoutWeight(1)
              .margin({ left: 12 })
              .alignItems(HorizontalAlign.Start)

              // 播放按钮
              Button('▶')
                .type(ButtonType.Circle)
                .width(36)
                .height(36)
                .fontSize(14)
                .fontColor('#0078C2')
                .backgroundColor('#FFF3E0')
                .onClick(async () => {
                  if (ep.media !== null) {
                    try {
                      await getController().playMedia(ep.media, ep.item.feedId, false);
                      promptAction.showToast({ message: '正在播放', duration: 1500 });
                    } catch (e) {
                      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
                      promptAction.showToast({ message: '播放失败: ' + msg, duration: 3000 });
                    }
                  }
                })
            }
            .width('100%')
            .padding({ left: 16, right: 12, top: 10, bottom: 10 })
          }
        }, (ep: DownloadedEpisode) => ep.item.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 76 })
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

  formatSize(bytes: number): string {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)}KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)}MB`;
  }
}
