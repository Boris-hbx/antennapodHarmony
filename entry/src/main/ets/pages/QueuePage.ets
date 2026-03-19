import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { FeedItem, FeedMedia, EventBus, QUEUE_UPDATE, FAVORITES_UPDATE, FEED_ITEM_UPDATE,
  DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE } from 'common';
import type { QueueUpdateData, DownloadProgressData, DownloadCompleteData } from 'common';
import { getController } from '../entryability/EntryAbility';
import { EpisodeActionButton } from '../components/EpisodeActionButton';
import { requestProgressUpdate } from 'network';
import {
  getQueue, getFeedItem, removeQueueItem, moveQueueItem, clearQueue,
  markItemPlayed, addFavoriteItem, removeFavoriteItem, deleteFeedMediaOfItem,
  isQueueLocked, setQueueLocked
} from 'datastore';
import { PlayState, TAG_FAVORITE } from 'common';
import { LongPressHelper } from '../utils/LongPressHelper';

/**
 * 播放队列页面 — Task-031: 队列锁定功能
 */
@Component
export struct QueuePage {
  @State queueItems: FeedItem[] = [];
  @State isEmpty: boolean = true;
  @State isMultiSelect: boolean = false;
  @State selectedIds: number[] = [];
  @State locked: boolean = false; // Task-031: 队列锁定
  @State downloadingUrls: Map<string, number> = new Map();
  @State showItemMenu: boolean = false;
  @State selectedItem: FeedItem | null = null;
  @State selectedIndex: number = -1;
  private lp = new LongPressHelper();

  private queueCallback: (data: QueueUpdateData) => void = () => {
    this.loadQueue();
  };

  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };

  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    this.downloadingUrls = new Map();
    this.loadQueue();
  };

  aboutToAppear(): void {
    this.locked = isQueueLocked();
    this.loadQueue();
    EventBus.on<QueueUpdateData>(QUEUE_UPDATE, this.queueCallback);
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(QUEUE_UPDATE, this.queueCallback);
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  async loadQueue(): Promise<void> {
    this.queueItems = await getQueue();
    this.isEmpty = this.queueItems.length === 0;
    if (this.isMultiSelect) {
      const ids = this.queueItems.map(i => i.id);
      this.selectedIds = this.selectedIds.filter(id => ids.includes(id));
      if (this.selectedIds.length === 0) {
        this.isMultiSelect = false;
      }
    }
  }

  async toggleLock(): Promise<void> {
    this.locked = !this.locked;
    await setQueueLocked(this.locked);
    promptAction.showToast({
      message: this.locked ? '队列已锁定' : '队列已解锁',
      duration: 1500
    });
  }

  build() {
    Column() {
      if (this.isMultiSelect) {
        this.multiSelectHeader()
      } else {
        this.normalHeader()
      }

      if (this.isEmpty) {
        Column() {
          Text('队列为空')
            .fontSize(18)
            .fontColor('#444444')
            .margin({ top: 80 })
          Text('在剧集列表中点击 + 按钮添加到队列')
            .fontSize(14)
            .fontColor('#CCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.queueItems, (item: FeedItem, index: number) => {
            ListItem() {
              Row() {
                if (this.isMultiSelect) {
                  Checkbox()
                    .select(this.selectedIds.includes(item.id))
                    .selectedColor('#0078C2')
                    .width(20)
                    .height(20)
                    .margin({ right: 4 })
                    .onChange((checked: boolean) => {
                      this.toggleSelection(item.id);
                    })
                } else {
                  SymbolGlyph($r('sys.symbol.line_3_horizontal'))
                    .fontSize(20)
                    .fontColor([this.locked ? '#DDDDDD' : '#BFBFBF'])
                    .width(24)
                }

                Column() {
                  if ((item.getImageLocation() ?? '').length > 0) {
                    Image(item.getImageLocation()!)
                      .width(56)
                      .height(56)
                      .borderRadius(4)
                      .objectFit(ImageFit.Cover)
                  } else {
                    SymbolGlyph($r('sys.symbol.mic'))
                      .fontSize(18)
                      .fontColor(['#AAAAAA'])
                  }
                }
                .width(56)
                .height(56)
                .borderRadius(4)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)
                .margin({ top: 11, bottom: 11, right: 16 })

                Column() {
                  Text(item.title ?? '')
                    .fontSize(16)
                    .fontWeight(FontWeight.Normal)
                    .fontColor(item.isPlayed() ? '#444444' : '#000000')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    if (item.media !== null && item.media.duration > 0) {
                      Text(this.formatDuration(item.media.duration))
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                    if (item.media !== null && item.media.position > 0 && item.media.duration > 0) {
                      Text(` · ${Math.round(item.media.position / item.media.duration * 100)}%`)
                        .fontSize(11)
                        .fontColor('#0078C2')
                    }
                  }
                  .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (!this.isMultiSelect) {
                  EpisodeActionButton({
                    itemId: item.id,
                    downloadUrl: item.media?.downloadUrl ?? '',
                    isItemDownloaded: item.isDownloaded(),
                    feedId: item.feedId,
                    feedTitle: '',
                    filesDir: getContext(this).filesDir,
                    itemTitle: item.title ?? '',
                    downloadProgress: this.downloadingUrls.has(item.media?.downloadUrl ?? '') ? (this.downloadingUrls.get(item.media?.downloadUrl ?? '') ?? 0) : -1,
                    isCurrentPlaying: false
                  })

                  // 移除按钮 — 锁定时禁用
                  if (!this.locked) {
                    SymbolGlyph($r('sys.symbol.xmark'))
                      .fontSize(14)
                      .fontColor(['#444444'])
                      .width(24)
                      .height(24)
                      .margin({ right: 12 })
                      .onClick(() => {
                        this.removeItem(item);
                      })
                  }
                }
              }
              .width('100%')
              .padding({ left: 12, right: 0, top: 8, bottom: 8 })
              .alignItems(VerticalAlign.Center)
              .onTouch((e: TouchEvent) => {
                this.lp.onTouch(e, () => {
                  this.selectedItem = item;
                  this.selectedIndex = index;
                  this.showItemMenu = true;
                });
              })
              .onClick(() => {
                if (!this.lp.fired && this.isMultiSelect) {
                  this.toggleSelection(item.id);
                }
              })
            }
            .swipeAction({
              end: this.locked ? undefined : {
                builder: () => {
                  this.swipePlayedButton(item)
                }
              }
            })
          }, (item: FeedItem) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 86 })
      }

      if (this.isMultiSelect && this.selectedIds.length > 0) {
        this.multiSelectToolbar()
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showItemMenu, () => { this.itemMenuSheet(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false,
      dragBar: true
    })
  }

  // ─── 普通标题栏 + 锁定图标 ───
  @Builder
  normalHeader() {
    Row() {
      Text($r('app.string.tab_queue'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Blank()
      if (!this.isEmpty) {
        Text(`${this.queueItems.length} 集`)
          .fontSize(12)
          .fontColor('#444444')
          .margin({ right: 8 })

        // Task-031: 队列锁定
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph(this.locked ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock'))
            .fontSize(18)
            .fontColor([this.locked ? '#0078C2' : '#444444'])
        }
        .width(36).height(36)
        .borderRadius(18)
        .backgroundColor(this.locked ? '#D6E6F3' : '#F0F0F0')
        .margin({ right: 8 })
        .onClick(() => { this.toggleLock(); })

        if (!this.locked) {
          Button('清空')
            .type(ButtonType.Normal)
            .height(30)
            .fontSize(12)
            .fontColor('#F44336')
            .backgroundColor('#FFEBEE')
            .borderRadius(15)
            .onClick(() => {
              this.clearAll();
            })
        }
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  multiSelectHeader() {
    Row() {
      Button('取消')
        .type(ButtonType.Normal)
        .height(30)
        .fontSize(14)
        .fontColor('#444444')
        .backgroundColor('transparent')
        .onClick(() => {
          this.exitMultiSelect();
        })
      Blank()
      Text(`已选 ${this.selectedIds.length} 项`)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Blank()
      Button(this.selectedIds.length === this.queueItems.length ? '取消全选' : '全选')
        .type(ButtonType.Normal)
        .height(30)
        .fontSize(14)
        .fontColor('#0078C2')
        .backgroundColor('transparent')
        .onClick(() => {
          if (this.selectedIds.length === this.queueItems.length) {
            this.selectedIds = [];
          } else {
            this.selectedIds = this.queueItems.map(i => i.id);
          }
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  multiSelectToolbar() {
    Row() {
      if (!this.locked) {
        Button('移除队列')
          .type(ButtonType.Normal)
          .height(36)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#F44336')
          .borderRadius(18)
          .margin({ right: 12 })
          .onClick(() => {
            this.batchRemoveFromQueue();
          })
      }
      Button('标记已播')
        .type(ButtonType.Normal)
        .height(36)
        .fontSize(13)
        .fontColor(Color.White)
        .backgroundColor('#4CAF50')
        .borderRadius(18)
        .margin({ right: 12 })
        .onClick(() => {
          this.batchMarkPlayed();
        })
      if (!this.locked) {
        Button('移至底部')
          .type(ButtonType.Normal)
          .height(36)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#0078C2')
          .borderRadius(18)
          .onClick(() => {
            this.batchMoveToBottom();
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FAFAFA')
    .border({ width: { top: 0.5 }, color: '#E0E0E0' })
  }

  @Builder
  itemMenuSheet() {
    Column() {
      if (this.selectedItem !== null) {
        Text(this.selectedItem!.title ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        Divider().strokeWidth(0.5).color('#E8E8E8')

        if (this.selectedIndex > 0 && !this.locked) {
          this.menuRow('移至顶部', $r('sys.symbol.arrow_up'), () => {
            this.showItemMenu = false;
            this.moveToTop(this.selectedIndex);
          })
        }

        if (this.selectedIndex < this.queueItems.length - 1 && !this.locked) {
          this.menuRow('移至底部', $r('sys.symbol.arrow_down'), () => {
            this.showItemMenu = false;
            this.moveToBottom(this.selectedIndex);
          })
        }

        this.menuRow(
          this.selectedItem!.isPlayed() ? '标记为未播放' : '标记为已播放',
          $r('sys.symbol.checkmark'),
          () => {
            this.showItemMenu = false;
            this.togglePlayed(this.selectedItem!);
          }
        )

        if (!this.locked) {
          this.menuRow('从队列中移除', $r('sys.symbol.xmark'), () => {
            this.showItemMenu = false;
            this.removeItem(this.selectedItem!);
          })
        }

        this.menuRow('删除下载', $r('sys.symbol.xmark'), () => {
          this.showItemMenu = false;
          this.deleteDownload(this.selectedItem!);
        })

        this.menuRow(
          this.selectedItem!.isFavorite() ? '取消收藏' : '添加到收藏',
          $r('sys.symbol.star'),
          () => {
            this.showItemMenu = false;
            this.toggleFavorite(this.selectedItem!);
          }
        )

        this.menuRow('分享', $r('sys.symbol.arrow_up'), () => {
          this.showItemMenu = false;
          this.shareItem(this.selectedItem!);
        })

        if (!this.locked) {
          this.menuRow('多选', $r('sys.symbol.checkmark'), () => {
            this.showItemMenu = false;
            this.enterMultiSelect(this.selectedItem!);
          })
        }
      }
      Blank().height(20)
    }
    .width('100%')
  }

  @Builder
  menuRow(label: string, icon: Resource, action: () => void) {
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
    .onClick(action)
  }

  @Builder
  swipePlayedButton(item: FeedItem) {
    Row() {
      Button('已播')
        .backgroundColor('#4CAF50')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(async () => {
          await markItemPlayed(item.id, PlayState.PLAYED);
          await removeQueueItem(item);
          await this.loadQueue();
        })
    }
  }

  // ═══════════════════════════════════════════
  //  操作方法
  // ═══════════════════════════════════════════

  async moveToTop(fromIndex: number): Promise<void> {
    if (fromIndex <= 0) {
      promptAction.showToast({ message: '已在顶部', duration: 1500 });
      return;
    }
    await moveQueueItem(fromIndex, 0);
    await this.loadQueue();
    promptAction.showToast({ message: '已移至顶部', duration: 1500 });
  }

  async moveToBottom(fromIndex: number): Promise<void> {
    const lastIndex = this.queueItems.length - 1;
    if (fromIndex >= lastIndex) {
      promptAction.showToast({ message: '已在底部', duration: 1500 });
      return;
    }
    await moveQueueItem(fromIndex, lastIndex);
    await this.loadQueue();
    promptAction.showToast({ message: '已移至底部', duration: 1500 });
  }

  async togglePlayed(item: FeedItem): Promise<void> {
    if (item.isPlayed()) {
      await markItemPlayed(item.id, PlayState.UNPLAYED);
      item.state = PlayState.UNPLAYED;
      promptAction.showToast({ message: '已标记为未播放', duration: 1500 });
    } else {
      await markItemPlayed(item.id, PlayState.PLAYED);
      item.state = PlayState.PLAYED;
      promptAction.showToast({ message: '已标记为已播放', duration: 1500 });
    }
    this.queueItems = this.queueItems.slice();
    EventBus.emit<void>(FEED_ITEM_UPDATE);
  }

  async removeItem(item: FeedItem): Promise<void> {
    if (this.locked) {
      promptAction.showToast({ message: '队列已锁定', duration: 1500 });
      return;
    }
    await removeQueueItem(item);
    await this.loadQueue();
  }

  async deleteDownload(item: FeedItem): Promise<void> {
    if (!item.isDownloaded()) {
      promptAction.showToast({ message: '该单集未下载', duration: 1500 });
      return;
    }
    await deleteFeedMediaOfItem(item.id);
    const fresh = await getFeedItem(item.id);
    if (fresh !== null) {
      const idx = this.queueItems.findIndex(i => i.id === item.id);
      if (idx >= 0) {
        this.queueItems[idx] = fresh;
        this.queueItems = this.queueItems.slice();
      }
    }
    promptAction.showToast({ message: '已删除下载', duration: 1500 });
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
    this.queueItems = this.queueItems.slice();
    EventBus.emit<void>(FAVORITES_UPDATE);
  }

  shareItem(item: FeedItem): void {
    const shareUrl = item.link ?? item.media?.downloadUrl ?? '';
    const shareText = `${item.title ?? ''}\n${shareUrl}`;
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, shareText);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
      promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  enterMultiSelect(item: FeedItem): void {
    this.isMultiSelect = true;
    this.selectedIds = [item.id];
  }

  exitMultiSelect(): void {
    this.isMultiSelect = false;
    this.selectedIds = [];
  }

  toggleSelection(id: number): void {
    const idx = this.selectedIds.indexOf(id);
    if (idx >= 0) {
      this.selectedIds.splice(idx, 1);
    } else {
      this.selectedIds.push(id);
    }
    this.selectedIds = this.selectedIds.slice();
  }

  // ─── 批量操作 ───

  async batchRemoveFromQueue(): Promise<void> {
    if (this.locked) return;
    const targets = this.queueItems.filter(i => this.selectedIds.includes(i.id));
    for (const item of targets) {
      await removeQueueItem(item);
    }
    this.exitMultiSelect();
    await this.loadQueue();
    promptAction.showToast({ message: `已移除 ${targets.length} 集`, duration: 1500 });
  }

  async batchMarkPlayed(): Promise<void> {
    for (const id of this.selectedIds) {
      await markItemPlayed(id, PlayState.PLAYED);
    }
    this.exitMultiSelect();
    await this.loadQueue();
    promptAction.showToast({ message: `已标记 ${this.selectedIds.length} 集为已播放`, duration: 1500 });
    EventBus.emit<void>(FEED_ITEM_UPDATE);
  }

  async batchMoveToBottom(): Promise<void> {
    if (this.locked) return;
    const indices = this.selectedIds
      .map(id => this.queueItems.findIndex(i => i.id === id))
      .filter(idx => idx >= 0)
      .sort((a, b) => b - a);
    for (const fromIdx of indices) {
      const currentLen = this.queueItems.length;
      if (fromIdx < currentLen - 1) {
        await moveQueueItem(fromIdx, currentLen - 1);
        this.queueItems = await getQueue();
      }
    }
    this.exitMultiSelect();
    await this.loadQueue();
    promptAction.showToast({ message: '已移至底部', duration: 1500 });
  }

  async clearAll(): Promise<void> {
    if (this.locked) {
      promptAction.showToast({ message: '队列已锁定，无法清空', duration: 1500 });
      return;
    }
    await clearQueue();
    await this.loadQueue();
  }

  // ─── 工具方法 ───

  formatDuration(ms: number): string {
    if (ms <= 0) return '';
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    if (h > 0) return `${h}h${m}min`;
    return `${m}min`;
  }

  truncateTitle(title: string): string {
    if (title.length <= 18) return title;
    return title.substring(0, 18) + '..';
  }
}
