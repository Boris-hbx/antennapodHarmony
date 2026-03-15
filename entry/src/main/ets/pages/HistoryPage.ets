import { router } from '@kit.ArkUI';
import { FeedItem, FeedMedia, PlayState } from 'common';
import { getEpisodes, getFeedList } from 'datastore';
import { FeedItemFilter, SortOrder } from 'common';

/**
 * 播放历史页面
 */

interface HistoryItem {
  item: FeedItem;
  feedTitle: string;
}

@Entry
@Component
struct HistoryPage {
  @State historyItems: HistoryItem[] = [];

  aboutToAppear(): void {
    this.loadHistory();
  }

  async loadHistory(): Promise<void> {
    const playedFilter = new FeedItemFilter(['played']);
    const items = await getEpisodes(0, 100, playedFilter, SortOrder.DATE_NEW_OLD);

    // 获取 feed 标题映射
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
      Row() {
        Button('←')
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .fontColor('#333')
          .fontSize(20)
          .onClick(() => { router.back(); })
        Text($r('app.string.title_history'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      if (this.historyItems.length === 0) {
        Column() {
          Text('暂无播放记录')
            .fontSize(16)
            .fontColor('#CCC')
            .margin({ top: 60 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.historyItems, (hi: HistoryItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text('🎙️').fontSize(18)
                }
                .width(44)
                .height(44)
                .borderRadius(6)
                .backgroundColor('#F0F0F0')
                .justifyContent(FlexAlign.Center)

                Column() {
                  Text(hi.item.title ?? '')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(hi.feedTitle)
                    .fontSize(12)
                    .fontColor('#444444')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .margin({ left: 10 })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            }
          }, (hi: HistoryItem) => hi.item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 70 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
