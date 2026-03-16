import { router, promptAction } from '@kit.ArkUI';
import { Feed, FeedItem, FeedItemFilter, PlayState,
  EventBus, FEED_LIST_UPDATE } from 'common';
import { getFeed, getFeedList, getFeedItemList, deleteFeed, getStatistics } from 'datastore';
import type { StatisticsItem } from 'datastore';
import { pasteboard } from '@kit.BasicServicesKit';

/**
 * Feed 信息页 — 展示播客统计、描述、URL、退订
 * 对照 Android FeedInfoFragment 实现
 */
@Entry
@Component
struct FeedInfoPage {
  @State feed: Feed | null = null;
  @State feedId: number = 0;
  @State episodeCount: number = 0;
  @State downloadedCount: number = 0;
  @State totalDuration: number = 0;
  @State diskUsage: number = 0;
  @State descExpanded: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.feedId = params['feedId'] as number ?? 0;
    }
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.feed = await getFeed(this.feedId);

    // 统计：集数
    const allItems = await getFeedItemList(this.feedId, null, null, 0, 0);
    this.episodeCount = allItems.length;

    // 统计：已下载数 + 占用空间 + 总时长
    let dlCount = 0;
    let totalSize = 0;
    let totalDur = 0;
    for (const item of allItems) {
      if (item.media !== null) {
        totalDur += item.media.duration;
        if (item.media.isDownloaded()) {
          dlCount++;
          totalSize += item.media.size;
        }
      }
    }
    this.downloadedCount = dlCount;
    this.diskUsage = totalSize;
    this.totalDuration = totalDur;
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([Color.White])
        }
        .width(40).height(40)
        .onClick(() => { router.back(); })

        Blank()

        Text('播客信息')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Blank()

        // 占位，保持标题居中
        Stack().width(40).height(40)
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .zIndex(1)

      Scroll() {
        Column() {
          // 1. 模糊背景头部
          Stack({ alignContent: Alignment.Center }) {
            if ((this.feed?.imageUrl ?? '').length > 0) {
              Image(this.feed!.imageUrl!)
                .width('100%')
                .height(220)
                .objectFit(ImageFit.Cover)
                .blur(30)
                .brightness(0.3)
            } else {
              Column()
                .width('100%')
                .height(220)
                .backgroundColor('#2C2C2C')
            }

            Column() {
              if ((this.feed?.imageUrl ?? '').length > 0) {
                Image(this.feed!.imageUrl!)
                  .width(120)
                  .height(120)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
                  .shadow({ radius: 8, color: 'rgba(0,0,0,0.3)' })
              }
              Text(this.feed?.getTitle() ?? '')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Center)
                .margin({ top: 12 })
                .textShadow({ radius: 2, color: '#000000' })
              if ((this.feed?.author ?? '').length > 0) {
                Text(this.feed!.author!)
                  .fontSize(13)
                  .fontColor('#CCCCCC')
                  .margin({ top: 4 })
                  .textShadow({ radius: 2, color: '#000000' })
              }
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .height(220)

          // 2. 统计卡片
          Row() {
            this.statItem('播放时长', this.formatDuration(this.totalDuration))
            this.statItem('单集数', `${this.episodeCount}`)
            this.statItem('已下载', `${this.downloadedCount}`)
            this.statItem('占用空间', this.formatSize(this.diskUsage))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .justifyContent(FlexAlign.SpaceAround)

          Divider().strokeWidth(0.5).color('#E8E8E8')

          // 3. 描述（可展开/折叠）
          Column() {
            Text('简介')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .margin({ bottom: 8 })

            if ((this.feed?.description ?? '').length > 0) {
              Text(this.stripHtml(this.feed!.description!))
                .fontSize(14)
                .fontColor('#444444')
                .maxLines(this.descExpanded ? undefined : 4)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(this.descExpanded ? '收起' : '展开全部')
                .fontSize(14)
                .fontColor('#0078C2')
                .margin({ top: 8 })
                .onClick(() => { this.descExpanded = !this.descExpanded; })
            } else {
              Text('暂无描述')
                .fontSize(14)
                .fontColor('#888888')
            }
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)

          Divider().strokeWidth(0.5).color('#E8E8E8')

          // 4. Feed URL
          Column() {
            Text('Feed 地址')
              .fontSize(14)
              .fontColor('#888888')
              .margin({ bottom: 4 })

            Row() {
              Text(this.feed?.downloadUrl ?? '')
                .fontSize(14)
                .fontColor('#1A1A1A')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              SymbolGlyph($r('sys.symbol.arrow_up'))
                .fontSize(20)
                .fontColor(['#0078C2'])
                .margin({ left: 12 })
                .onClick(() => { this.copyUrl(); })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)

          Divider().strokeWidth(0.5).color('#E8E8E8')

          // 5. 退订按钮
          Button('退订播客')
            .type(ButtonType.Normal)
            .fontColor('#FF3B30')
            .fontSize(16)
            .backgroundColor('transparent')
            .borderWidth(1)
            .borderColor('#FF3B30')
            .borderRadius(8)
            .width('90%')
            .height(44)
            .margin({ top: 24, bottom: 40 })
            .onClick(() => { this.showUnsubscribeDialog(); })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  statItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text(label)
        .fontSize(12)
        .fontColor('#888888')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  private copyUrl(): void {
    const url = this.feed?.downloadUrl ?? '';
    if (url.length === 0) return;
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).then(() => {
      promptAction.showToast({ message: '已复制 Feed 地址', duration: 1500 });
    }).catch(() => {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    });
  }

  private showUnsubscribeDialog(): void {
    if (this.feed === null) return;
    const feedTitle = this.feed!.getTitle() ?? '此播客';
    AlertDialog.show({
      title: '退订',
      message: `确定要退订「${feedTitle}」吗？所有已下载的剧集将被删除。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '退订',
        fontColor: '#FF3B30',
        action: () => {
          this.doUnsubscribe();
        }
      }
    });
  }

  private doUnsubscribe(): void {
    deleteFeed(this.feedId).then(() => {
      EventBus.emit<void>(FEED_LIST_UPDATE);
      promptAction.showToast({ message: '已退订', duration: 1500 });
      router.back();
    }).catch(() => {
      promptAction.showToast({ message: '退订失败', duration: 2000 });
    });
  }

  private stripHtml(html: string): string {
    return html.replace(/<[^>]*>/g, '').replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ').trim();
  }

  private formatDuration(ms: number): string {
    if (ms <= 0) return '0分钟';
    const totalMin = Math.floor(ms / 60000);
    const h = Math.floor(totalMin / 60);
    const m = totalMin % 60;
    if (h > 0) return `${h}小时${m}分`;
    return `${m}分钟`;
  }

  private formatSize(bytes: number): string {
    if (bytes <= 0) return '0 MB';
    const mb = bytes / (1024 * 1024);
    if (mb >= 1024) return `${(mb / 1024).toFixed(1)} GB`;
    return `${mb.toFixed(1)} MB`;
  }
}
