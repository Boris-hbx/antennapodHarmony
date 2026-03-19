import { router, promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { EpisodeActionButton } from '../components/EpisodeActionButton';
import { Feed, FeedItem, FeedItemFilter, SortOrder,
  EventBus, FEED_LIST_UPDATE, QUEUE_UPDATE, FAVORITES_UPDATE,
  DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE } from 'common';
import type { FeedListUpdateData, QueueUpdateData, DownloadProgressData, DownloadCompleteData } from 'common';
import { getQueue, getEpisodes, getFeedItem, getFeedList, getFeedItemList,
  getHomeSectionOrder, setHomeSectionOrder } from 'datastore';
import { LongPressHelper } from '../utils/LongPressHelper';
import { refreshAllFeeds, getActiveDownloads, requestProgressUpdate } from 'network';
import type { DownloadTask } from 'network';

// Section 定义
interface SectionDef {
  key: string;
  label: string;
}

const ALL_SECTIONS: SectionDef[] = [
  { key: 'queue', label: '继续收听' },
  { key: 'surprise', label: '不期而遇' },
  { key: 'inbox', label: '最近更新' },
  { key: 'subscriptions', label: '订阅列表' },
  { key: 'downloads', label: '管理下载' },
];

/**
 * 首页 — Task-030: Section 自定义排序
 */
@Component
export struct HomePage {
  @State queueItems: FeedItem[] = [];
  @State newItems: FeedItem[] = [];
  @State randomItems: FeedItem[] = [];
  @State subscriptions: FeedWithCount[] = [];
  @State activeTasks: DownloadTask[] = [];
  @State recentDownloads: FeedItem[] = [];
  @State isRefreshing: boolean = false;
  @State downloadingUrls: Map<string, number> = new Map();

  // 长按上下文菜单（剧集）
  @State showContextMenu: boolean = false;
  @State selectedEpisode: FeedItem | null = null;

  // 长按上下文菜单（订阅 Feed）
  @State showFeedContextMenu: boolean = false;
  @State selectedFeedEntry: FeedWithCount | null = null;
  private lp = new LongPressHelper();

  // Task-030: Section 排序
  @State sectionOrder: string[] = [];
  @State showSectionOrderSheet: boolean = false;

  onSwitchTab?: (index: number) => void;

  private onFeedUpdate: (data: FeedListUpdateData) => void = () => { this.loadData(); };
  private onQueueUpdate: (data: QueueUpdateData) => void = () => { this.loadData(); };
  private onFavUpdate: () => void = () => { this.loadData(); };
  private onDownloadProgress: (data: DownloadProgressData) => void = (data: DownloadProgressData) => {
    this.activeTasks = getActiveDownloads();
    for (const entry of data.urls.entries()) {
      this.downloadingUrls.set(entry[0], entry[1]);
    }
    this.downloadingUrls = new Map(this.downloadingUrls);
  };
  private onDownloadComplete: (data: DownloadCompleteData) => void = () => {
    this.loadDownloads();
    this.downloadingUrls = new Map();
    this.loadData();
  };

  aboutToAppear(): void {
    this.sectionOrder = getHomeSectionOrder();
    this.loadData();
    EventBus.on<FeedListUpdateData>(FEED_LIST_UPDATE, this.onFeedUpdate);
    EventBus.on<QueueUpdateData>(QUEUE_UPDATE, this.onQueueUpdate);
    EventBus.on<void>(FAVORITES_UPDATE, this.onFavUpdate);
    EventBus.on<DownloadProgressData>(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.onDownloadComplete);
    requestProgressUpdate();
  }

  aboutToDisappear(): void {
    EventBus.off(FEED_LIST_UPDATE, this.onFeedUpdate);
    EventBus.off(QUEUE_UPDATE, this.onQueueUpdate);
    EventBus.off(FAVORITES_UPDATE, this.onFavUpdate);
    EventBus.off(DOWNLOAD_PROGRESS, this.onDownloadProgress);
    EventBus.off(DOWNLOAD_COMPLETE, this.onDownloadComplete);
  }

  async loadData(): Promise<void> {
    const allQueue = await getQueue();
    this.queueItems = allQueue.slice(0, 8);

    const newFilter = new FeedItemFilter(['new']);
    this.newItems = await getEpisodes(0, 8, newFilter, SortOrder.DATE_NEW_OLD);

    this.randomItems = await getEpisodes(0, 5, null, SortOrder.RANDOM);

    await this.loadSubscriptions();
    await this.loadDownloads();
  }

  async loadSubscriptions(): Promise<void> {
    const feeds = await getFeedList();
    const result: FeedWithCount[] = [];
    for (const feed of feeds) {
      const unplayedFilter = new FeedItemFilter(['unplayed']);
      const items = await getFeedItemList(feed.id, unplayedFilter, null, 0, 0);
      const entry: FeedWithCount = { feed: feed, unplayedCount: items.length };
      result.push(entry);
    }
    this.subscriptions = result;
  }

  async loadDownloads(): Promise<void> {
    this.activeTasks = getActiveDownloads();
    const dlFilter = new FeedItemFilter(['downloaded']);
    const downloaded = await getEpisodes(0, 3, dlFilter, SortOrder.DATE_NEW_OLD);
    this.recentDownloads = downloaded;
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          // ── 顶栏 ──
          Row() {
            Text('首页')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#212121')
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(20)
                .fontColor(['#444444'])
            }
            .width(40).height(40)
            .borderRadius(20)
            .backgroundColor('#F0F0F0')
            .margin({ right: 8 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/SearchPage' });
            })

            // Task-030: ⋮ 菜单（编辑 Section 排序）
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
                .fontSize(20)
                .fontColor(['#444444'])
            }
            .width(40).height(40)
            .borderRadius(20)
            .backgroundColor('#F0F0F0')
            .bindMenu([
              { value: '编辑 Section 排序', action: () => { this.showSectionOrderSheet = true; } },
            ])
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          // ── 按用户自定义顺序渲染 Section ──
          ForEach(this.sectionOrder, (key: string) => {
            if (key === 'queue' && this.queueItems.length > 0) {
              this.sectionHeader('继续收听', '队列 »', () => {
                this.onSwitchTab?.(1);
              })
              this.horizontalCards(this.queueItems)
            } else if (key === 'inbox') {
              this.sectionHeader('最近更新', '收件箱 »', () => {
                this.onSwitchTab?.(2);
              })
              if (this.newItems.length > 0) {
                this.horizontalCards(this.newItems)
              } else {
                Text('新单集将在此处显示。随后您可以决定是否对其感兴趣。')
                  .fontSize(14)
                  .fontColor('#444444')
                  .textAlign(TextAlign.Center)
                  .padding({ left: 32, right: 32, top: 24, bottom: 24 })
                  .width('100%')
              }
            } else if (key === 'surprise' && this.randomItems.length > 0) {
              Row() {
                Text('不期而遇')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#212121')
                Blank()
                Text('单集 »')
                  .fontSize(14)
                  .fontColor('#0078C2')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 4 })

              this.horizontalCards(this.randomItems)
            } else if (key === 'subscriptions' && this.subscriptions.length > 0) {
              this.sectionHeader('订阅列表', '查看全部 »', () => {
                this.onSwitchTab?.(3);
              })
              this.subscriptionsRow()
            } else if (key === 'downloads') {
              this.sectionHeader('管理下载', '查看全部 »', () => {
                router.pushUrl({ url: 'pages/DownloadsPage' });
              })
              if (this.activeTasks.length === 0 && this.recentDownloads.length === 0) {
                Text('没有下载内容')
                  .fontSize(14)
                  .fontColor('#888888')
                  .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                  .width('100%')
              } else {
                this.downloadsSection()
              }
            }
          }, (key: string) => key)

          Blank().height(100)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .onRefreshing(async () => {
      await refreshAllFeeds();
      await this.loadData();
      this.isRefreshing = false;
    })
    .bindSheet($$this.showSectionOrderSheet, this.SectionOrderSheetBuilder(), {
      detents: [SheetSize.MEDIUM],
      showClose: true
    })
    .bindSheet($$this.showContextMenu, () => { this.contextMenuSheet(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false,
      dragBar: true
    })
    .bindSheet($$this.showFeedContextMenu, () => { this.feedContextMenuSheet(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false,
      dragBar: true
    })
  }

  // ===== Task-030: Section 排序弹窗 =====
  @Builder SectionOrderSheetBuilder() {
    Column() {
      Text('Section 排序')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding(16)
      Text('长按拖拽调整顺序')
        .fontSize(13)
        .fontColor('#888888')
        .padding({ left: 16, bottom: 12 })

      List() {
        ForEach(this.sectionOrder, (key: string, index: number) => {
          ListItem() {
            Row() {
              SymbolGlyph($r('sys.symbol.line_3_horizontal'))
                .fontSize(18)
                .fontColor(['#BBBBBB'])
                .margin({ right: 12 })
              Text(this.getSectionLabel(key))
                .fontSize(16)
                .layoutWeight(1)
              // 上移按钮
              if (index > 0) {
                Stack({ alignContent: Alignment.Center }) {
                  SymbolGlyph($r('sys.symbol.chevron_up'))
                    .fontSize(18)
                    .fontColor(['#0078C2'])
                }
                .width(36).height(36)
                .onClick(() => { this.moveSectionUp(index); })
              }
              // 下移按钮
              if (index < this.sectionOrder.length - 1) {
                Stack({ alignContent: Alignment.Center }) {
                  SymbolGlyph($r('sys.symbol.chevron_down'))
                    .fontSize(18)
                    .fontColor(['#0078C2'])
                }
                .width(36).height(36)
                .onClick(() => { this.moveSectionDown(index); })
              }
            }
            .width('100%')
            .padding({ left: 20, right: 16, top: 12, bottom: 12 })
          }
        }, (key: string) => key)
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })

      Button('恢复默认')
        .width('80%')
        .height(40)
        .backgroundColor('#F0F0F0')
        .fontColor('#333333')
        .fontSize(14)
        .borderRadius(20)
        .margin({ top: 12, bottom: 20 })
        .onClick(async () => {
          this.sectionOrder = ALL_SECTIONS.map((s: SectionDef) => s.key);
          await setHomeSectionOrder(this.sectionOrder);
        })
    }
    .width('100%')
    .height('100%')
  }

  getSectionLabel(key: string): string {
    const found = ALL_SECTIONS.find((s: SectionDef) => s.key === key);
    return found !== undefined ? found.label : key;
  }

  async moveSectionUp(index: number): Promise<void> {
    if (index <= 0) return;
    const arr = this.sectionOrder.slice();
    const tmp = arr[index];
    arr[index] = arr[index - 1];
    arr[index - 1] = tmp;
    this.sectionOrder = arr;
    await setHomeSectionOrder(arr);
  }

  async moveSectionDown(index: number): Promise<void> {
    if (index >= this.sectionOrder.length - 1) return;
    const arr = this.sectionOrder.slice();
    const tmp = arr[index];
    arr[index] = arr[index + 1];
    arr[index + 1] = tmp;
    this.sectionOrder = arr;
    await setHomeSectionOrder(arr);
  }

  @Builder
  sectionHeader(title: string, linkText: string, onLinkClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#212121')
      Blank()
      Text(linkText)
        .fontSize(14)
        .fontColor('#0078C2')
        .onClick(onLinkClick)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 4 })
  }

  @Builder
  horizontalCards(items: FeedItem[]) {
    Scroll() {
      Row() {
        ForEach(items, (item: FeedItem) => {
          Column() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              if ((item.getImageLocation() ?? '').length > 0) {
                Image(item.getImageLocation()!)
                  .width(128)
                  .height(128)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  SymbolGlyph($r('sys.symbol.mic'))
                    .fontSize(40)
                    .fontColor(['#AAAAAA'])
                }
                .width(128)
                .height(128)
                .borderRadius(12)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)
              }

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
            }

            Text(item.title ?? '')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 8 })
              .width(128)

            Text(this.formatDateSmart(item.pubDate))
              .fontSize(14)
              .fontColor('#444444')
              .margin({ top: 2 })
              .width(128)
          }
          .margin({ right: 8 })
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
        }, (item: FeedItem) => item.id.toString())
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  contextMenuSheet() {
    Column() {
      if (this.selectedEpisode !== null) {
        Text(this.selectedEpisode!.title ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      }
      Divider().strokeWidth(0.5).color('#E8E8E8')
      this.ctxMenuItem('播放', $r('sys.symbol.play_fill'), () => {
        if (this.selectedEpisode !== null && this.selectedEpisode!.media !== null) {
          this.showContextMenu = false;
          getController().playMedia(this.selectedEpisode!.media!, this.selectedEpisode!.feedId, false).catch(() => {});
        }
      })
      this.ctxMenuItem('查看详情', $r('sys.symbol.info_circle'), () => {
        if (this.selectedEpisode !== null) {
          this.showContextMenu = false;
          router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: this.selectedEpisode!.id } });
        }
      })
      this.ctxMenuItem('跳转至播客', $r('sys.symbol.music_note_list'), () => {
        if (this.selectedEpisode !== null) {
          this.showContextMenu = false;
          router.pushUrl({ url: 'pages/EpisodeListPage', params: { feedId: this.selectedEpisode!.feedId } });
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

  @Builder
  feedContextMenuSheet() {
    Column() {
      if (this.selectedFeedEntry !== null) {
        Text(this.selectedFeedEntry!.feed.getTitle() ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      }
      Divider().strokeWidth(0.5).color('#E8E8E8')
      this.ctxMenuItem('打开播客', $r('sys.symbol.music_note_list'), () => {
        if (this.selectedFeedEntry !== null) {
          this.showFeedContextMenu = false;
          router.pushUrl({
            url: 'pages/EpisodeListPage',
            params: { feedId: this.selectedFeedEntry!.feed.id, feedTitle: this.selectedFeedEntry!.feed.getTitle() ?? '' }
          });
        }
      })
      this.ctxMenuItem('播客信息', $r('sys.symbol.info_circle'), () => {
        if (this.selectedFeedEntry !== null) {
          this.showFeedContextMenu = false;
          router.pushUrl({
            url: 'pages/FeedInfoPage',
            params: { feedId: this.selectedFeedEntry!.feed.id }
          });
        }
      })
      Blank().height(20)
    }
    .width('100%')
  }

  private async playOrDownload(item: FeedItem): Promise<void> {
    try {
      const freshItem = await getFeedItem(item.id);
      if (freshItem !== null && freshItem.media !== null) {
        if (freshItem.isDownloaded()) {
          await getController().playMedia(freshItem.media, freshItem.feedId, false);
        } else {
          await getController().playMedia(freshItem.media, freshItem.feedId, true);
        }
      }
    } catch (_e) {
      promptAction.showToast({ message: '操作失败', duration: 2000 });
    }
  }

  @Builder
  subscriptionsRow() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.subscriptions, (entry: FeedWithCount) => {
          Stack({ alignContent: Alignment.TopEnd }) {
            if ((entry.feed.imageUrl ?? '').length > 0) {
              Image(entry.feed.imageUrl!)
                .width(72)
                .height(72)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
            } else {
              Column() {
                SymbolGlyph($r('sys.symbol.mic'))
                  .fontSize(24)
                  .fontColor(['#AAAAAA'])
              }
              .width(72)
              .height(72)
              .borderRadius(8)
              .backgroundColor('#F0F0F0')
              .justifyContent(FlexAlign.Center)
            }
            if (entry.unplayedCount > 0) {
              Text(`${entry.unplayedCount}`)
                .fontSize(10)
                .fontColor('#FFFFFF')
                .backgroundColor('#0078C2')
                .borderRadius(8)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .margin(2)
            }
          }
          .onTouch((e: TouchEvent) => {
            this.lp.onTouch(e, () => {
              this.selectedFeedEntry = entry;
              this.showFeedContextMenu = true;
            });
          })
          .onClick(() => {
            if (!this.lp.fired) {
              router.pushUrl({
                url: 'pages/EpisodeListPage',
                params: { feedId: entry.feed.id, feedTitle: entry.feed.getTitle() ?? '' }
              });
            }
          })
        }, (entry: FeedWithCount) => entry.feed.id.toString() + '_' + entry.unplayedCount.toString())
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .height(88)
  }

  @Builder
  downloadsSection() {
    Column() {
      ForEach(this.activeTasks.slice(0, 2), (task: DownloadTask) => {
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.arrow_down'))
              .fontSize(16)
              .fontColor(['#888888'])
          }
          .width(40)
          .height(40)
          .borderRadius(4)
          .backgroundColor('#F0F0F0')
          .justifyContent(FlexAlign.Center)
          .margin({ right: 12 })

          Column() {
            Text(task.itemTitle)
              .fontSize(14)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Progress({ value: task.progress, total: 100, type: ProgressType.Linear })
              .width('100%')
              .color('#0078C2')
              .height(4)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }, (task: DownloadTask) => task.url)

      ForEach(this.recentDownloads.slice(0, 2), (item: FeedItem) => {
        Row() {
          if ((item.getImageLocation() ?? '').length > 0) {
            Image(item.getImageLocation()!)
              .width(40)
              .height(40)
              .borderRadius(4)
              .objectFit(ImageFit.Cover)
              .margin({ right: 12 })
          } else {
            Column() {
              SymbolGlyph($r('sys.symbol.mic'))
                .fontSize(16)
                .fontColor(['#AAAAAA'])
            }
            .width(40)
            .height(40)
            .borderRadius(4)
            .backgroundColor('#F0F0F0')
            .justifyContent(FlexAlign.Center)
            .margin({ right: 12 })
          }

          Column() {
            Text(item.title ?? '')
              .fontSize(14)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('已下载')
              .fontSize(12)
              .fontColor('#0078C2')
              .margin({ top: 2 })
          }
          .layoutWeight(1)

          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(18)
            .fontColor(['#0078C2'])
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: item.id } });
        })
      }, (item: FeedItem) => item.id.toString())
    }
    .width('100%')
  }

  formatDateSmart(date: Date | null): string {
    if (date === null) return '';
    const now = new Date();
    if (date.getFullYear() === now.getFullYear()) {
      return `${date.getMonth() + 1}月${date.getDate()}日`;
    }
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
  }
}

interface FeedWithCount {
  feed: Feed;
  unplayedCount: number;
}
