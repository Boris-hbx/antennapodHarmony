import { router, promptAction } from '@kit.ArkUI';
import { FeedItem, FeedMedia, PlayState, FeedItemFilter, SortOrder,
  EventBus, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE } from 'common';
import type { DownloadProgressData, DownloadCompleteData } from 'common';
import { getEpisodes, getFeedList, markItemPlayed } from 'datastore';
import { requestProgressUpdate } from 'network';
import { EpisodeActionButton } from '../components/EpisodeActionButton';
import { getController } from '../entryability/EntryAbility';
import { LongPressHelper } from '../utils/LongPressHelper';

/**
 * 播放历史页（#40 — 对照 Android PlaybackHistoryFragment 重写）
 */

interface HistoryItem {
  item: FeedItem;
  feedTitle: string;
}

@Entry
@Component
struct HistoryPage {
  @State historyItems: HistoryItem[] = [];
  @State downloadingUrls: Map<string, number> = new Map();
  @State showContextMenu: boolean = false;
  @State selectedItem: FeedItem | null = null;
  private lp = new LongPressHelper();

  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };

  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    this.downloadingUrls = new Map();
    this.loadHistory();
  };

  aboutToAppear(): void {
    this.loadHistory();
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  async loadHistory(): Promise<void> {
    const playedFilter = new FeedItemFilter(['played']);
    const items = await getEpisodes(0, 200, playedFilter, SortOrder.COMPLETION_DATE_NEW_OLD);

    const feeds = await getFeedList();
    const feedMap = new Map<number, string>();
    for (const feed of feeds) {
      feedMap.set(feed.id, feed.getTitle() ?? '');
    }

    const result: HistoryItem[] = [];
    for (const item of items) {
      const hi: HistoryItem = {
        item: item,
        feedTitle: feedMap.get(item.feedId) ?? ''
      };
      result.push(hi);
    }
    this.historyItems = result;
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { router.back(); })

        Text($r('app.string.title_history'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })

        // 清除历史
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { this.confirmClearHistory(); })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      if (this.historyItems.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(48)
            .fontColor(['#CCCCCC'])
          Text('暂无播放记录')
            .fontSize(16)
            .fontColor('#CCC')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.historyItems, (hi: HistoryItem) => {
            ListItem() {
              Row() {
                // 封面 56×56 + 底部进度条
                Stack({ alignContent: Alignment.BottomStart }) {
                  Image(hi.item.getImageLocation() ?? '')
                    .width(56)
                    .height(56)
                    .borderRadius(4)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor('#F0F0F0')
                  if (hi.item.media !== null && hi.item.media.position > 0 && hi.item.media.duration > 0) {
                    Row()
                      .width(`${Math.round(hi.item.media.position / hi.item.media.duration * 100)}%`)
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
                  Text(hi.item.title ?? '')
                    .fontSize(16)
                    .fontWeight(FontWeight.Normal)
                    .fontColor(hi.item.isPlayed() ? '#444444' : '#000000')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    Text(hi.feedTitle)
                      .fontSize(12)
                      .fontColor('#666666')
                      .maxLines(1)
                    if (hi.item.media !== null && hi.item.media.lastPlayedTimeStatistics > 0) {
                      Text(` · ${this.formatDate(hi.item.media.lastPlayedTimeStatistics)}`)
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                    if (hi.item.media !== null && hi.item.media.duration > 0) {
                      Text(` · ${this.formatDuration(hi.item.media.duration)}`)
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                  }
                  .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 操作按钮
                EpisodeActionButton({
                  itemId: hi.item.id,
                  downloadUrl: hi.item.media?.downloadUrl ?? '',
                  isItemDownloaded: hi.item.isDownloaded(),
                  feedId: hi.item.feedId,
                  feedTitle: hi.feedTitle,
                  filesDir: getContext(this).filesDir,
                  itemTitle: hi.item.title ?? '',
                  downloadProgress: this.downloadingUrls.has(hi.item.media?.downloadUrl ?? '') ? (this.downloadingUrls.get(hi.item.media?.downloadUrl ?? '') ?? 0) : -1,
                  isCurrentPlaying: false
                })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 10, bottom: 10 })
              .onTouch((e: TouchEvent) => {
                this.lp.onTouch(e, () => {
                  this.selectedItem = hi.item;
                  this.showContextMenu = true;
                });
              })
              .onClick(() => {
                if (!this.lp.fired) {
                  router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: hi.item.id } });
                }
              })
            }
          }, (hi: HistoryItem) => hi.item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 84 })
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showContextMenu, () => { this.contextMenuSheet(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false,
      dragBar: true
    })
  }

  // ===== 上下文菜单 =====

  @Builder
  contextMenuSheet() {
    Column() {
      if (this.selectedItem !== null) {
        Text(this.selectedItem!.title ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      }
      Divider().strokeWidth(0.5).color('#E8E8E8')
      this.ctxMenuItem('播放', $r('sys.symbol.play_fill'), () => {
        if (this.selectedItem !== null && this.selectedItem!.media !== null) {
          this.showContextMenu = false;
          getController().playMedia(this.selectedItem!.media!, this.selectedItem!.feedId, false).catch(() => {});
        }
      })
      this.ctxMenuItem('标记为未播', $r('sys.symbol.arrow_clockwise'), () => {
        if (this.selectedItem !== null) {
          this.showContextMenu = false;
          markItemPlayed(this.selectedItem!.id, PlayState.UNPLAYED).then(() => {
            promptAction.showToast({ message: '已标记为未播', duration: 1500 });
            this.loadHistory();
          }).catch(() => {});
        }
      })
      this.ctxMenuItem('查看详情', $r('sys.symbol.info_circle'), () => {
        if (this.selectedItem !== null) {
          this.showContextMenu = false;
          router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: this.selectedItem!.id } });
        }
      })
      this.ctxMenuItem('跳转至播客', $r('sys.symbol.music_note_list'), () => {
        if (this.selectedItem !== null) {
          this.showContextMenu = false;
          router.pushUrl({ url: 'pages/EpisodeListPage', params: { feedId: this.selectedItem!.feedId } });
        }
      })
      Blank().height(20)
    }
    .width('100%')
  }

  @Builder
  ctxMenuItem(label: string, icon: Resource, action: () => void) {
    Row() {
      SymbolGlyph(icon).fontSize(20).fontColor(['#333333']).margin({ right: 16 })
      Text(label).fontSize(16).fontColor('#1A1A1A')
    }
    .width('100%').height(52).padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { action(); })
  }

  // ===== 清除历史 =====

  private confirmClearHistory(): void {
    AlertDialog.show({
      title: '清除播放历史',
      message: '确定要清除所有播放记录吗？这不会删除已下载的文件。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确定',
        fontColor: '#F44336',
        action: async () => {
          // 将所有已播标记为未播
          for (const hi of this.historyItems) {
            await markItemPlayed(hi.item.id, PlayState.UNPLAYED);
          }
          this.historyItems = [];
          promptAction.showToast({ message: '已清除播放历史', duration: 1500 });
        }
      }
    });
  }

  // ===== 格式化 =====

  formatDate(timestamp: number): string {
    if (timestamp <= 0) return '';
    const d = new Date(timestamp);
    return `${d.getMonth() + 1}月${d.getDate()}日`;
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
