import { router } from '@kit.ArkUI';
import { getStatistics } from 'datastore';
import type { StatisticsItem } from 'datastore';

/**
 * 收听统计页面
 */
@Entry
@Component
struct StatisticsPage {
  @State stats: StatisticsItem[] = [];
  @State totalTime: number = 0;
  @State totalEpisodes: number = 0;

  aboutToAppear(): void {
    this.loadStats();
  }

  async loadStats(): Promise<void> {
    const result = await getStatistics(true, 0, Date.now());
    // 只保留有播放记录的 Feed
    const filtered: StatisticsItem[] = [];
    let time = 0;
    let eps = 0;
    for (const s of result) {
      time += s.totalTime;
      eps += s.episodesStarted;
      if (s.episodesStarted > 0 || s.totalTime > 0) {
        filtered.push(s);
      }
    }
    this.stats = filtered;
    this.totalTime = time;
    this.totalEpisodes = eps;
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
        Text($r('app.string.title_statistics'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      // 总计卡片
      Row() {
        Column() {
          Text(this.formatHours(this.totalTime))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0078C2')
          Text('总收听时长')
            .fontSize(12)
            .fontColor('#444444')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.totalEpisodes.toString())
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')
          Text('已开始集数')
            .fontSize(12)
            .fontColor('#444444')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#FAFAFA')
      .borderRadius(12)
      .margin({ left: 16, right: 16, top: 8 })

      // 每个 Feed 的统计
      if (this.stats.length === 0) {
        Column() {
          Text('暂无收听记录')
            .fontSize(16)
            .fontColor('#CCC')
            .margin({ top: 40 })
          Text('播放播客后这里会显示统计数据')
            .fontSize(13)
            .fontColor('#DDD')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }

      List() {
        ForEach(this.stats, (stat: StatisticsItem) => {
          ListItem() {
            Row() {
              Column() {
                Text(stat.feed.getTitle() ?? '')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${stat.episodesStarted} 集 · ${this.formatHours(stat.totalTime)}`)
                  .fontSize(12)
                  .fontColor('#444444')
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (stat.totalDownloadSize > 0) {
                Text(this.formatSize(stat.totalDownloadSize))
                  .fontSize(12)
                  .fontColor('#444444')
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
        }, (stat: StatisticsItem) => stat.feed.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ top: 12 })
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
  }

  formatHours(ms: number): string {
    if (ms <= 0) return '0h';
    const hours = ms / 3600000;
    if (hours < 1) return `${Math.round(hours * 60)}min`;
    return `${hours.toFixed(1)}h`;
  }

  formatSize(bytes: number): string {
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)}KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)}MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(1)}GB`;
  }
}
