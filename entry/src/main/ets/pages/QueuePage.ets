import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { FeedItem, FeedMedia, EventBus, QUEUE_UPDATE, FAVORITES_UPDATE, FEED_ITEM_UPDATE } from 'common';
import { getController } from '../entryability/EntryAbility';
import type { QueueUpdateData } from 'common';
import {
  getQueue, getFeedItem, removeQueueItem, moveQueueItem, clearQueue,
  markItemPlayed, addFavoriteItem, removeFavoriteItem, deleteFeedMediaOfItem
} from 'datastore';
import { PlayState, TAG_FAVORITE } from 'common';

/**
 * 播放队列页面（P5）
 *
 * 展示队列中的单集列表，支持移除、移动、清空。
 * 长按单集弹出操作菜单（移至底部/标记已播/移除/删除/收藏/分享/多选）。
 */
@Component
export struct QueuePage {
  @State queueItems: FeedItem[] = [];
  @State isEmpty: boolean = true;
  @State isMultiSelect: boolean = false;
  @State selectedIds: number[] = [];

  private queueCallback: (data: QueueUpdateData) => void = () => {
    this.loadQueue();
  };

  aboutToAppear(): void {
    this.loadQueue();
    EventBus.on<QueueUpdateData>(QUEUE_UPDATE, this.queueCallback);
  }

  aboutToDisappear(): void {
    EventBus.off(QUEUE_UPDATE, this.queueCallback);
  }

  async loadQueue(): Promise<void> {
    this.queueItems = await getQueue();
    this.isEmpty = this.queueItems.length === 0;
    // 退出多选：如果队列变空或选中项已不在队列中，清理选中状态
    if (this.isMultiSelect) {
      const ids = this.queueItems.map(i => i.id);
      this.selectedIds = this.selectedIds.filter(id => ids.includes(id));
      if (this.selectedIds.length === 0) {
        this.isMultiSelect = false;
      }
    }
  }

  build() {
    Column() {
      // ─── 标题栏 ───
      if (this.isMultiSelect) {
        this.multiSelectHeader()
      } else {
        this.normalHeader()
      }

      if (this.isEmpty) {
        // 空状态
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
                  // 多选模式：复选框
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
                  // QU4 拖拽手柄
                  Text('☰')
                    .fontSize(16)
                    .fontColor('#BFBFBF')
                    .width(24)
                    .textAlign(TextAlign.Center)
                }

                // QU1 封面 56×56vp, 圆角 4vp; QU7 margin
                Column() {
                  if ((item.getImageLocation() ?? '').length > 0) {
                    Image(item.getImageLocation()!)
                      .width(56)
                      .height(56)
                      .borderRadius(4)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Text('🎙️')
                      .fontSize(18)
                  }
                }
                .width(56)
                .height(56)
                .borderRadius(4)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)
                .margin({ top: 11, bottom: 11, right: 16 })

                // 信息
                Column() {
                  // QU2 标题 16fp Normal, fontColor 按播放状态
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
                  // QU3 复合操作按钮 48×48vp
                  Stack() {
                    if (item.isDownloaded()) {
                      // 已下载
                      Progress({ value: 100, type: ProgressType.Ring })
                        .width(40)
                        .height(40)
                        .color('#000000')
                        .style({ strokeWidth: 3 })
                      Text('▶')
                        .fontSize(16)
                        .fontColor('#000000')
                    } else {
                      // 未下载
                      Progress({ value: 0, type: ProgressType.Ring })
                        .width(40)
                        .height(40)
                        .color('#000000')
                        .style({ strokeWidth: 1 })
                      Text('↓')
                        .fontSize(18)
                        .fontColor('#555555')
                    }
                  }
                  .width(48)
                  .height(48)
                  .onClick(async () => {
                    try {
                      const freshItem = await getFeedItem(item.id);
                      if (freshItem !== null && freshItem.media !== null) {
                        if (freshItem.isDownloaded()) {
                          await getController().playMedia(freshItem.media, freshItem.feedId, false);
                        } else {
                          await getController().playMedia(freshItem.media, freshItem.feedId, true);
                        }
                        promptAction.showToast({ message: '正在播放', duration: 1500 });
                      } else {
                        promptAction.showToast({ message: '该单集无媒体文件', duration: 3000 });
                      }
                    } catch (e) {
                      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
                      promptAction.showToast({ message: '播放失败: ' + msg, duration: 3000 });
                    }
                  })

                  // QU3 移除按钮 24×24vp; QU6 margin right 12vp
                  Text('✕')
                    .fontSize(12)
                    .fontColor('#444444')
                    .textAlign(TextAlign.Center)
                    .width(24)
                    .height(24)
                    .margin({ right: 12 })
                    .onClick(() => {
                      this.removeItem(item);
                    })
                }
              }
              .width('100%')
              .padding({ left: 12, right: 0, top: 8, bottom: 8 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                if (this.isMultiSelect) {
                  this.toggleSelection(item.id);
                }
              })
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.swipePlayedButton(item)
                }
              }
            })
            .bindContextMenu(() => {
              this.itemContextMenu(item, index)
            }, ResponseType.LongPress)
          }, (item: FeedItem) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 86 })
      }

      // ─── 多选模式底部工具栏 ───
      if (this.isMultiSelect && this.selectedIds.length > 0) {
        this.multiSelectToolbar()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ─── 普通标题栏 ───
  @Builder
  normalHeader() {
    Row() {
      Text($r('app.string.tab_queue'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Blank()
      if (!this.isEmpty) {
        // QU5 信息栏字号 12fp
        Text(`${this.queueItems.length} 集`)
          .fontSize(12)
          .fontColor('#444444')
          .margin({ right: 8 })
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
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  // ─── 多选标题栏 ───
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

  // ─── 多选底部工具栏 ───
  @Builder
  multiSelectToolbar() {
    Row() {
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
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FAFAFA')
    .border({ width: { top: 0.5 }, color: '#E0E0E0' })
  }

  // ─── 长按上下文菜单 ───
  @Builder
  itemContextMenu(item: FeedItem, index: number) {
    Menu() {
      MenuItem({
        content: this.truncateTitle(item.title ?? '')
      })
        .enabled(false)

      if (index > 0) {
        MenuItem({ content: '移至顶部' })
          .onClick(() => {
            this.moveToTop(index);
          })
      }

      if (index < this.queueItems.length - 1) {
        MenuItem({ content: '移至底部' })
          .onClick(() => {
            this.moveToBottom(index);
          })
      }

      MenuItem({
        content: item.isPlayed() ? '标记为未播放' : '标记为已播放'
      })
        .onClick(() => {
          this.togglePlayed(item);
        })

      MenuItem({ content: '从队列中移除' })
        .onClick(() => {
          this.removeItem(item);
        })

      MenuItem({ content: '删除' })
        .onClick(() => {
          this.deleteDownload(item);
        })

      MenuItem({
        content: item.isFavorite() ? '取消收藏' : '添加到收藏'
      })
        .onClick(() => {
          this.toggleFavorite(item);
        })

      MenuItem({ content: '分享' })
        .onClick(() => {
          this.shareItem(item);
        })

      MenuItem({ content: '多选' })
        .onClick(() => {
          this.enterMultiSelect(item);
        })
    }
  }

  // ─── 滑动：标记已播 ───
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

  /** 移至队列顶部 */
  async moveToTop(fromIndex: number): Promise<void> {
    if (fromIndex <= 0) {
      promptAction.showToast({ message: '已在顶部', duration: 1500 });
      return;
    }
    await moveQueueItem(fromIndex, 0);
    await this.loadQueue();
    promptAction.showToast({ message: '已移至顶部', duration: 1500 });
  }

  /** 移至队列底部 */
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

  /** 切换播放状态 */
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

  /** 从队列移除 */
  async removeItem(item: FeedItem): Promise<void> {
    await removeQueueItem(item);
    await this.loadQueue();
  }

  /** 删除已下载文件 */
  async deleteDownload(item: FeedItem): Promise<void> {
    if (!item.isDownloaded()) {
      promptAction.showToast({ message: '该单集未下载', duration: 1500 });
      return;
    }
    await deleteFeedMediaOfItem(item.id);
    // 刷新 item 状态
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

  /** 切换收藏状态 */
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

  /** 分享（复制链接到剪贴板） */
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

  /** 进入多选模式 */
  enterMultiSelect(item: FeedItem): void {
    this.isMultiSelect = true;
    this.selectedIds = [item.id];
  }

  /** 退出多选模式 */
  exitMultiSelect(): void {
    this.isMultiSelect = false;
    this.selectedIds = [];
  }

  /** 切换选中状态 */
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

  /** 批量移除队列 */
  async batchRemoveFromQueue(): Promise<void> {
    const targets = this.queueItems.filter(i => this.selectedIds.includes(i.id));
    for (const item of targets) {
      await removeQueueItem(item);
    }
    this.exitMultiSelect();
    await this.loadQueue();
    promptAction.showToast({ message: `已移除 ${targets.length} 集`, duration: 1500 });
  }

  /** 批量标记已播 */
  async batchMarkPlayed(): Promise<void> {
    for (const id of this.selectedIds) {
      await markItemPlayed(id, PlayState.PLAYED);
    }
    this.exitMultiSelect();
    await this.loadQueue();
    promptAction.showToast({ message: `已标记 ${this.selectedIds.length} 集为已播放`, duration: 1500 });
    EventBus.emit<void>(FEED_ITEM_UPDATE);
  }

  /** 批量移至底部 */
  async batchMoveToBottom(): Promise<void> {
    // 从后往前移，避免索引错位
    const indices = this.selectedIds
      .map(id => this.queueItems.findIndex(i => i.id === id))
      .filter(idx => idx >= 0)
      .sort((a, b) => b - a); // 降序
    for (const fromIdx of indices) {
      const currentLen = this.queueItems.length;
      if (fromIdx < currentLen - 1) {
        await moveQueueItem(fromIdx, currentLen - 1);
        // 移动后重新加载以获取正确索引
        this.queueItems = await getQueue();
      }
    }
    this.exitMultiSelect();
    await this.loadQueue();
    promptAction.showToast({ message: '已移至底部', duration: 1500 });
  }

  /** 清空队列 */
  async clearAll(): Promise<void> {
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
