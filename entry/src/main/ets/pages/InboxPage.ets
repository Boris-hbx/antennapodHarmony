import { promptAction, router } from '@kit.ArkUI';
import { FeedItem, FeedItemFilter, SortOrder, PlayState, EventBus,
  FEED_LIST_UPDATE, UNREAD_UPDATE, QUEUE_UPDATE, FAVORITES_UPDATE,
  DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE,
  TAG_QUEUE, TAG_FAVORITE } from 'common';
import type { FeedListUpdateData, QueueUpdateData, DownloadProgressData, DownloadCompleteData } from 'common';
import { getEpisodes, getFeedList, markItemPlayed,
  addFavoriteItem, removeFavoriteItem, addQueueItem, removeQueueItem } from 'datastore';
import { refreshAllFeeds, requestProgressUpdate } from 'network';
import { EpisodeActionButton } from '../components/EpisodeActionButton';
import { getController } from '../entryability/EntryAbility';
import { LongPressHelper } from '../utils/LongPressHelper';

/**
 * 收件箱 Tab（#41 — 对照 Android InboxFragment 重写）
 */

interface InboxItem {
  item: FeedItem;
  feedTitle: string;
}

@Component
export struct InboxPage {
  @State inboxItems: InboxItem[] = [];
  @State totalCount: number = 0;
  @State isRefreshing: boolean = false;
  @State downloadingUrls: Map<string, number> = new Map();
  @State showContextMenu: boolean = false;
  @State selectedItem: FeedItem | null = null;
  private lp = new LongPressHelper();

  private updateCallback: () => void = () => { this.loadData(); };
  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };
  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    this.downloadingUrls = new Map();
    this.loadData();
  };

  aboutToAppear(): void {
    this.loadData();
    EventBus.on<FeedListUpdateData>(FEED_LIST_UPDATE, this.updateCallback);
    EventBus.on<void>(UNREAD_UPDATE, this.updateCallback);
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(FEED_LIST_UPDATE, this.updateCallback);
    EventBus.off(UNREAD_UPDATE, this.updateCallback);
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  async loadData(): Promise<void> {
    const newFilter = new FeedItemFilter(['new']);
    const items = await getEpisodes(0, 200, newFilter, SortOrder.DATE_NEW_OLD);

    const feeds = await getFeedList();
    const feedMap = new Map<number, string>();
    for (const feed of feeds) {
      feedMap.set(feed.id, feed.getTitle() ?? '');
    }

    const result: InboxItem[] = [];
    for (const item of items) {
      const ii: InboxItem = {
        item: item,
        feedTitle: feedMap.get(item.feedId) ?? ''
      };
      result.push(ii);
    }
    this.inboxItems = result;
    this.totalCount = result.length;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text($r('app.string.tab_inbox'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        if (this.totalCount > 0) {
          Text(`${this.totalCount}`)
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
            .fontSize(18)
            .fontColor(['#444444'])
        }
        .width(36).height(36)
        .borderRadius(18)
        .backgroundColor('#F0F0F0')
        .margin({ right: 8 })
        .onClick(() => { router.pushUrl({ url: 'pages/SearchPage' }); })

        // ⋮ 菜单
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
            .fontSize(18)
            .fontColor(['#444444'])
        }
        .width(36).height(36)
        .borderRadius(18)
        .backgroundColor('#F0F0F0')
        .bindMenu([
          { value: '全部标为已读', action: () => { this.markAllRead(); } }
        ])
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.inboxItems.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.envelope'))
            .fontSize(56)
            .fontColor(['#AAAAAA'])
            .margin({ top: 24, bottom: 16 })
          Text('收件箱中没有单集')
            .fontSize(18)
            .fontColor('#444444')
          Text('新单集上线后，将在此处显示。\n随后您可以决定是否对其感兴趣。')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
            .padding({ left: 40, right: 40 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List() {
            ForEach(this.inboxItems, (ii: InboxItem) => {
              ListItem() {
                Row() {
                  // 封面 56×56
                  Stack({ alignContent: Alignment.BottomStart }) {
                    Image(ii.item.getImageLocation() ?? '')
                      .width(56)
                      .height(56)
                      .borderRadius(4)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor('#F0F0F0')
                    if (ii.item.media !== null && ii.item.media.position > 0 && ii.item.media.duration > 0) {
                      Row()
                        .width(`${Math.round(ii.item.media.position / ii.item.media.duration * 100)}%`)
                        .height(3)
                        .backgroundColor('#0078C2')
                        .borderRadius(1.5)
                    }
                  }
                  .width(56).height(56)
                  .margin({ right: 12 })

                  // 信息区
                  Column() {
                    Text(ii.item.title ?? '')
                      .fontSize(16)
                      .fontWeight(FontWeight.Normal)
                      .fontColor('#000000')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row() {
                      Text(ii.feedTitle)
                        .fontSize(12)
                        .fontColor('#666666')
                        .maxLines(1)
                      if (ii.item.pubDate !== null) {
                        Text(` · ${this.formatDate(ii.item.pubDate)}`)
                          .fontSize(11)
                          .fontColor('#444444')
                      }
                      if (ii.item.media !== null && ii.item.media.duration > 0) {
                        Text(` · ${this.formatDuration(ii.item.media.duration)}`)
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
                    itemId: ii.item.id,
                    downloadUrl: ii.item.media?.downloadUrl ?? '',
                    isItemDownloaded: ii.item.isDownloaded(),
                    feedId: ii.item.feedId,
                    feedTitle: ii.feedTitle,
                    filesDir: getContext(this).filesDir,
                    itemTitle: ii.item.title ?? '',
                    downloadProgress: this.downloadingUrls.has(ii.item.media?.downloadUrl ?? '') ? (this.downloadingUrls.get(ii.item.media?.downloadUrl ?? '') ?? 0) : -1,
                    isCurrentPlaying: false
                  })
                }
                .width('100%')
                .padding({ left: 16, right: 12, top: 10, bottom: 10 })
                .alignItems(VerticalAlign.Center)
                .onTouch((e: TouchEvent) => {
                  this.lp.onTouch(e, () => {
                    this.selectedItem = ii.item;
                    this.showContextMenu = true;
                  });
                })
                .onClick(() => {
                  if (!this.lp.fired) {
                    router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: ii.item.id } });
                  }
                })
              }
              .swipeAction({
                start: { builder: () => { this.swipeQueueButton(ii.item) } },
                end: { builder: () => { this.swipeReadButton(ii.item) } }
              })
            }, (ii: InboxItem) => ii.item.id.toString() + '_' +
              (ii.item.isFavorite() ? 'f' : '') + (ii.item.isQueued() ? 'q' : ''))
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 84 })
        }
        .onRefreshing(async () => {
          await refreshAllFeeds();
          await this.loadData();
          this.isRefreshing = false;
        })
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
          getController().playMedia(this.selectedItem!.media!, this.selectedItem!.feedId, true).catch(() => {});
        }
      })
      if (this.selectedItem !== null && !this.selectedItem!.isQueued()) {
        this.ctxMenuItem('加入队列', $r('sys.symbol.music_note_list'), () => {
          if (this.selectedItem !== null) {
            this.showContextMenu = false;
            this.toggleQueue(this.selectedItem!);
          }
        })
      }
      if (this.selectedItem !== null && this.selectedItem!.isQueued()) {
        this.ctxMenuItem('从队列移除', $r('sys.symbol.xmark'), () => {
          if (this.selectedItem !== null) {
            this.showContextMenu = false;
            this.toggleQueue(this.selectedItem!);
          }
        })
      }
      this.ctxMenuItem('标为已读', $r('sys.symbol.checkmark'), () => {
        if (this.selectedItem !== null) {
          this.showContextMenu = false;
          this.markRead(this.selectedItem!);
        }
      })
      this.ctxMenuItem('查看详情', $r('sys.symbol.info_circle'), () => {
        if (this.selectedItem !== null) {
          this.showContextMenu = false;
          router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: this.selectedItem!.id } });
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

  // ===== 滑动按钮 =====

  @Builder
  swipeQueueButton(item: FeedItem) {
    Row() {
      Button(item.isQueued() ? '移出队列' : '加入队列')
        .backgroundColor('#0078C2')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => { this.toggleQueue(item); })
    }
  }

  @Builder
  swipeReadButton(item: FeedItem) {
    Row() {
      Button('已读')
        .backgroundColor('#4CAF50')
        .fontColor(Color.White)
        .fontSize(13)
        .height('100%')
        .width(80)
        .onClick(() => { this.markRead(item); })
    }
  }

  // ===== 操作 =====

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
    this.inboxItems = this.inboxItems.slice();
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
    this.inboxItems = this.inboxItems.slice();
    EventBus.emit<QueueUpdateData>(QUEUE_UPDATE, { action: 'toggle' });
  }

  async markRead(item: FeedItem): Promise<void> {
    await markItemPlayed(item.id, PlayState.UNPLAYED);
    await this.loadData();
    promptAction.showToast({ message: '已标为已读', duration: 1500 });
  }

  async markAllRead(): Promise<void> {
    for (const ii of this.inboxItems) {
      await markItemPlayed(ii.item.id, PlayState.UNPLAYED);
    }
    await this.loadData();
    promptAction.showToast({ message: '已全部标为已读', duration: 1500 });
  }

  formatDate(date: Date | null): string {
    if (date === null) return '';
    return `${date.getMonth() + 1}月${date.getDate()}日`;
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
