import { router } from '@kit.ArkUI';
import { getStatistics } from 'datastore';
import type { StatisticsItem } from 'datastore';

/**
 * 收听统计页（#43 — 对照 Android StatisticsFragment 重写）
 *
 * 饼图/柱状图在 ArkUI 中无原生组件，用 Progress 环形图 + 排行列表替代
 */

// 颜色表（最多 10 个播客颜色）
const CHART_COLORS: string[] = [
  '#0078C2', '#4CAF50', '#FF9800', '#9C27B0', '#F44336',
  '#00BCD4', '#FFC107', '#607D8B', '#E91E63', '#3F51B5'
];

@Entry
@Component
struct StatisticsPage {
  @State stats: StatisticsItem[] = [];
  @State totalTime: number = 0;
  @State totalEpisodes: number = 0;
  @State totalDownload: number = 0;
  @State filterLabel: string = '全部时间';
  @State filterStartMs: number = 0;

  aboutToAppear(): void {
    this.loadStats();
  }

  async loadStats(): Promise<void> {
    const result = await getStatistics(true, this.filterStartMs, Date.now());
    const filtered: StatisticsItem[] = [];
    let time = 0;
    let eps = 0;
    let dl = 0;
    for (const s of result) {
      time += s.totalTime;
      eps += s.episodesStarted;
      dl += s.totalDownloadSize;
      if (s.episodesStarted > 0 || s.totalTime > 0) {
        filtered.push(s);
      }
    }
    // 按收听时长排序
    filtered.sort((a: StatisticsItem, b: StatisticsItem) => b.totalTime - a.totalTime);
    this.stats = filtered;
    this.totalTime = time;
    this.totalEpisodes = eps;
    this.totalDownload = dl;
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

        Text($r('app.string.title_statistics'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })

        // 时间筛选
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
            .fontSize(18)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .bindMenu([
          { value: '全部时间', action: () => { this.setFilter('全部时间', 0); } },
          { value: '最近 1 年', action: () => { this.setFilter('最近 1 年', Date.now() - 365 * 86400000); } },
          { value: '最近 30 天', action: () => { this.setFilter('最近 30 天', Date.now() - 30 * 86400000); } },
          { value: '最近 7 天', action: () => { this.setFilter('最近 7 天', Date.now() - 7 * 86400000); } }
        ])
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      Scroll() {
        Column() {
          // 筛选标签
          Text(this.filterLabel)
            .fontSize(13)
            .fontColor('#888888')
            .padding({ left: 16, top: 4, bottom: 8 })
            .width('100%')

          // 总计卡片
          Row() {
            Column() {
              Text(this.formatHours(this.totalTime))
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0078C2')
              Text('收听时长')
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
              Text('已播集数')
                .fontSize(12)
                .fontColor('#444444')
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(this.formatSize(this.totalDownload))
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FF9800')
              Text('下载量')
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
          .margin({ left: 16, right: 16 })

          // 播客排行（替代饼图）
          if (this.stats.length > 0) {
            Text('播客收听排行')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .padding({ left: 16, top: 20, bottom: 8 })
              .width('100%')

            ForEach(this.stats, (stat: StatisticsItem, index: number) => {
              Row() {
                // 排名 + 颜色条
                Text(`${index + 1}`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getColor(index))
                  .width(28)
                  .textAlign(TextAlign.Center)

                // 封面
                if ((stat.feed.imageUrl ?? '').length > 0) {
                  Image(stat.feed.imageUrl!)
                    .width(44)
                    .height(44)
                    .borderRadius(6)
                    .objectFit(ImageFit.Cover)
                    .margin({ right: 12 })
                } else {
                  Column() {
                    SymbolGlyph($r('sys.symbol.mic'))
                      .fontSize(18)
                      .fontColor(['#AAAAAA'])
                  }
                  .width(44).height(44)
                  .borderRadius(6)
                  .backgroundColor('#F0F0F0')
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 12 })
                }

                // 信息
                Column() {
                  Text(stat.feed.getTitle() ?? '')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    Text(`${stat.episodesStarted} 集`)
                      .fontSize(11)
                      .fontColor('#444444')
                    Text(` · ${this.formatHours(stat.totalTime)}`)
                      .fontSize(11)
                      .fontColor('#444444')
                    if (stat.totalDownloadSize > 0) {
                      Text(` · ${this.formatSize(stat.totalDownloadSize)}`)
                        .fontSize(11)
                        .fontColor('#444444')
                    }
                  }
                  .margin({ top: 3 })

                  // 占比进度条
                  if (this.totalTime > 0) {
                    Progress({
                      value: Math.round(stat.totalTime / this.totalTime * 100),
                      total: 100,
                      type: ProgressType.Linear
                    })
                      .width('100%')
                      .height(4)
                      .color(this.getColor(index))
                      .backgroundColor('#E8E8E8')
                      .margin({ top: 6 })
                  }
                }
                .layoutWeight(1)

                // 百分比
                if (this.totalTime > 0) {
                  Text(`${Math.round(stat.totalTime / this.totalTime * 100)}%`)
                    .fontSize(13)
                    .fontColor('#444444')
                    .fontWeight(FontWeight.Medium)
                    .margin({ left: 8 })
                    .width(40)
                    .textAlign(TextAlign.End)
                }
              }
              .width('100%')
              .padding({ left: 12, right: 16, top: 10, bottom: 10 })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/EpisodeListPage',
                  params: { feedId: stat.feed.id, feedTitle: stat.feed.getTitle() }
                });
              })
            }, (stat: StatisticsItem) => stat.feed.id.toString())
          } else {
            Column() {
              SymbolGlyph($r('sys.symbol.timer'))
                .fontSize(48)
                .fontColor(['#CCCCCC'])
              Text('暂无收听记录')
                .fontSize(16)
                .fontColor('#CCC')
                .margin({ top: 12 })
              Text('播放播客后这里会显示统计数据')
                .fontSize(13)
                .fontColor('#DDD')
                .margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 60 })
            .alignItems(HorizontalAlign.Center)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  private setFilter(label: string, startMs: number): void {
    this.filterLabel = label;
    this.filterStartMs = startMs;
    this.loadStats();
  }

  private getColor(index: number): string {
    return CHART_COLORS[index % CHART_COLORS.length];
  }

  formatHours(ms: number): string {
    if (ms <= 0) return '0h';
    const hours = ms / 3600000;
    if (hours < 1) return `${Math.round(hours * 60)}min`;
    return `${hours.toFixed(1)}h`;
  }

  formatSize(bytes: number): string {
    if (bytes <= 0) return '0';
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)}KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)}MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(1)}GB`;
  }
}
