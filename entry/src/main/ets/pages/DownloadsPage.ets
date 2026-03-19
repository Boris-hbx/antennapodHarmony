import { router, promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { FeedItem, FeedMedia, EventBus, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE, DOWNLOAD_ERROR } from 'common';
import type { DownloadProgressData, DownloadCompleteData, DownloadErrorData } from 'common';
import { getFeedList, getFeedItemList, deleteFeedMediaOfItem, markItemPlayed } from 'datastore';
import {
  getActiveDownloads, cancelDownload, requestProgressUpdate
} from 'network';
import type { DownloadTask } from 'network';
import { EpisodeActionButton } from '../components/EpisodeActionButton';
import { PlayState } from 'common';
import { LongPressHelper } from '../utils/LongPressHelper';

/**
 * 下载管理页（#39 重构 — 对照 Android CompletedDownloadsFragment）
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
  @State downloadingUrls: Map<string, number> = new Map();
  @State sortMode: string = 'date'; // date / size / name
  @State showContextMenu: boolean = false;
  @State selectedEp: DownloadedEpisode | null = null;
  private lp = new LongPressHelper();

  private progressCallback: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    this.activeTasks = getActiveDownloads();
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };

  private completeCallback: (data: DownloadCompleteData) => void = () => {
    this.downloadingUrls = new Map();
    this.loadData();
  };

  private errorCallback: (data: DownloadErrorData) => void = (data: DownloadErrorData) => {
    // 下载失败 → 刷新列表 + 提示
    this.activeTasks = getActiveDownloads();
    this.downloadingUrls = new Map();
    promptAction.showToast({
      message: `下载失败: ${data.episodeTitle} (${data.errorType})`,
      duration: 3000
    });
  };

  aboutToAppear(): void {
    this.loadData();
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.progressCallback);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.completeCallback);
    EventBus.on<DownloadErrorData>(DOWNLOAD_ERROR, this.errorCallback);
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_PROGRESS, this.progressCallback);
    EventBus.off(DOWNLOAD_COMPLETE, this.completeCallback);
    EventBus.off(DOWNLOAD_ERROR, this.errorCallback);
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    this.activeTasks = getActiveDownloads();

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
    this.sortItems(downloaded);
    this.downloadedItems = downloaded;
    this.isLoading = false;
  }

  private sortItems(items: DownloadedEpisode[]): void {
    switch (this.sortMode) {
      case 'size':
        items.sort((a: DownloadedEpisode, b: DownloadedEpisode) => b.media.size - a.media.size);
        break;
      case 'name':
        items.sort((a: DownloadedEpisode, b: DownloadedEpisode) => {
          const ta = (a.item.title ?? '').toLowerCase();
          const tb = (b.item.title ?? '').toLowerCase();
          if (ta < tb) return -1;
          if (ta > tb) return 1;
          return 0;
        });
        break;
      default: // date
        items.sort((a: DownloadedEpisode, b: DownloadedEpisode) =>
          b.media.downloadDate - a.media.downloadDate);
        break;
    }
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

        Text($r('app.string.title_downloads'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })

        // 溢出菜单：排序 + 删除已播
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
            .fontSize(20)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .bindMenu([
          { value: '按日期排序', action: () => { this.sortMode = 'date'; this.loadData(); } },
          { value: '按大小排序', action: () => { this.sortMode = 'size'; this.loadData(); } },
          { value: '按名称排序', action: () => { this.sortMode = 'name'; this.loadData(); } },
          { value: '删除已播放', action: () => { this.deletePlayedItems(); } }
        ])
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      List() {
        // ===== 下载中 =====
        if (this.activeTasks.length > 0) {
          ListItem() {
            Text(`下载中 (${this.activeTasks.length})`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#888888')
              .padding({ left: 16, top: 12, bottom: 8 })
              .width('100%')
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

                Stack({ alignContent: Alignment.Center }) {
                  SymbolGlyph($r('sys.symbol.xmark'))
                    .fontSize(14)
                    .fontColor(['#F44336'])
                }
                .width(32).height(32)
                .borderRadius(16)
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
          }, (task: DownloadTask) => task.url + '_' + task.progress.toString())
        }

        // ===== 已下载 =====
        ListItem() {
          Text(`已下载 (${this.downloadedItems.length})`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#888888')
            .padding({ left: 16, top: 16, bottom: 8 })
            .width('100%')
        }

        if (this.downloadedItems.length === 0 && this.activeTasks.length === 0) {
          ListItem() {
            Column() {
              SymbolGlyph($r('sys.symbol.arrow_down'))
                .fontSize(48)
                .fontColor(['#CCCCCC'])
              Text('暂无下载')
                .fontSize(16)
                .fontColor('#CCC')
                .margin({ top: 12 })
            }
            .width('100%')
            .padding({ top: 60 })
            .alignItems(HorizontalAlign.Center)
          }
        }

        ForEach(this.downloadedItems, (ep: DownloadedEpisode) => {
          ListItem() {
            Row() {
              // 封面 56×56 + 底部播放进度条
              Stack({ alignContent: Alignment.BottomStart }) {
                Image(ep.item.getImageLocation() ?? '')
                  .width(56)
                  .height(56)
                  .borderRadius(4)
                  .objectFit(ImageFit.Cover)
                  .backgroundColor('#F0F0F0')
                // 播放进度条（底部 3vp）
                if (ep.media.position > 0 && ep.media.duration > 0) {
                  Row()
                    .width(`${Math.round(ep.media.position / ep.media.duration * 100)}%`)
                    .height(3)
                    .backgroundColor('#0078C2')
                    .borderRadius(1.5)
                }
              }
              .width(56)
              .height(56)
              .margin({ right: 12 })

              // 信息区
              Column() {
                Text(ep.item.title ?? '')
                  .fontSize(16)
                  .fontWeight(FontWeight.Normal)
                  .fontColor(ep.item.isPlayed() ? '#444444' : '#000000')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row() {
                  Text(ep.feedTitle)
                    .fontSize(12)
                    .fontColor('#666666')
                    .maxLines(1)
                  if (ep.media.duration > 0) {
                    Text(` · ${this.formatDuration(ep.media.duration)}`)
                      .fontSize(11)
                      .fontColor('#444444')
                  }
                  if (ep.media.size > 0) {
                    Text(` · ${this.formatSize(ep.media.size)}`)
                      .fontSize(11)
                      .fontColor('#444444')
                  }
                }
                .margin({ top: 3 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              // 统一操作按钮
              EpisodeActionButton({
                itemId: ep.item.id,
                downloadUrl: ep.media.downloadUrl ?? '',
                isItemDownloaded: true,
                feedId: ep.item.feedId,
                feedTitle: ep.feedTitle,
                filesDir: '',
                itemTitle: ep.item.title ?? '',
                downloadProgress: -1,
                isCurrentPlaying: false
              })
            }
            .width('100%')
            .padding({ left: 16, right: 12, top: 10, bottom: 10 })
            .onTouch((e: TouchEvent) => {
              this.lp.onTouch(e, () => {
                this.selectedEp = ep;
                this.showContextMenu = true;
              });
            })
            .onClick(() => {
              if (!this.lp.fired) {
                router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: ep.item.id } });
              }
            })
          }
          .swipeAction({
            end: {
              builder: () => { this.swipeDeleteButton(ep) }
            }
          })
        }, (ep: DownloadedEpisode) => ep.item.id.toString() + (ep.item.isPlayed() ? '_p' : ''))
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 84 })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showContextMenu, () => { this.contextMenuSheet(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false,
      dragBar: true
    })
  }

  // ===== 长按上下文菜单 =====

  @Builder
  contextMenuSheet() {
    Column() {
      if (this.selectedEp !== null) {
        Text(this.selectedEp!.item.title ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      }
      Divider().strokeWidth(0.5).color('#E8E8E8')

      this.ctxMenuItem('播放', $r('sys.symbol.play_fill'), () => {
        if (this.selectedEp !== null) {
          this.showContextMenu = false;
          getController().playMedia(this.selectedEp!.media, this.selectedEp!.item.feedId, false)
            .catch(() => {});
        }
      })
      this.ctxMenuItem('查看详情', $r('sys.symbol.info_circle'), () => {
        if (this.selectedEp !== null) {
          this.showContextMenu = false;
          router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: this.selectedEp!.item.id } });
        }
      })
      this.ctxMenuItem('删除本地文件', $r('sys.symbol.xmark'), () => {
        if (this.selectedEp !== null) {
          this.showContextMenu = false;
          this.deleteEpisode(this.selectedEp!);
        }
      })
      Blank().height(20)
    }
    .width('100%')
  }

  @Builder
  ctxMenuItem(label: string, icon: Resource, action: () => void) {
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
    .onClick(() => { action(); })
  }

  // ===== 滑动删除 =====

  @Builder
  swipeDeleteButton(ep: DownloadedEpisode) {
    Row() {
      Button('删除')
        .backgroundColor('#F44336')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => { this.deleteEpisode(ep); })
    }
  }

  // ===== 操作方法 =====

  private deleteEpisode(ep: DownloadedEpisode): void {
    deleteFeedMediaOfItem(ep.item.id).then(() => {
      promptAction.showToast({ message: '已删除本地文件', duration: 1500 });
      this.loadData();
    }).catch(() => {});
  }

  private deletePlayedItems(): void {
    const played = this.downloadedItems.filter((ep: DownloadedEpisode) => ep.item.isPlayed());
    if (played.length === 0) {
      promptAction.showToast({ message: '没有已播放的下载', duration: 1500 });
      return;
    }
    AlertDialog.show({
      title: '删除已播放',
      message: `确定要删除 ${played.length} 个已播放的下载文件吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确定',
        fontColor: '#F44336',
        action: async () => {
          for (const ep of played) {
            await deleteFeedMediaOfItem(ep.item.id);
          }
          promptAction.showToast({ message: `已删除 ${played.length} 个文件`, duration: 1500 });
          this.loadData();
        }
      }
    });
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
