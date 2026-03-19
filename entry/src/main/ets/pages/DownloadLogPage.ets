import { router } from '@kit.ArkUI';
import { getDownloadLog } from 'datastore';

interface DownloadLogEntry {
  id: number;
  title: string;
  successful: boolean;
  completionDate: number;
  reasonDetailed: string;
}

@Entry
@Component
struct DownloadLogPage {
  @State logEntries: DownloadLogEntry[] = [];

  aboutToAppear(): void {
    this.loadLog();
  }

  async loadLog(): Promise<void> {
    const rs = await getDownloadLog();
    const entries: DownloadLogEntry[] = [];
    while (rs.goToNextRow()) {
      const entry: DownloadLogEntry = {
        id: rs.getLong(rs.getColumnIndex('id')),
        title: rs.getString(rs.getColumnIndex('title')),
        successful: rs.getLong(rs.getColumnIndex('successful')) === 1,
        completionDate: rs.getLong(rs.getColumnIndex('completion_date')),
        reasonDetailed: rs.getString(rs.getColumnIndex('reason_detailed'))
      };
      entries.push(entry);
    }
    rs.close();
    this.logEntries = entries;
  }

  private formatDate(timestamp: number): string {
    const d = new Date(timestamp);
    const year = d.getFullYear();
    const month = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const hour = d.getHours().toString().padStart(2, '0');
    const minute = d.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}`;
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
        .width(40)
        .height(40)
        .onClick(() => {
          router.back();
        })

        Text('下载日志')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右侧占位
        Row().width(40).height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      if (this.logEntries.length === 0) {
        Column() {
          Text('暂无下载记录')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.logEntries, (entry: DownloadLogEntry) => {
            ListItem() {
              Row() {
                // 状态图标
                Text(entry.successful ? '\u2713' : '\u2717')
                  .fontSize(20)
                  .fontColor(entry.successful ? '#4CAF50' : '#F44336')
                  .width(32)
                  .textAlign(TextAlign.Center)

                Column() {
                  Text(entry.title)
                    .fontSize(15)
                    .fontColor('#333333')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Text(this.formatDate(entry.completionDate))
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 4 })

                  if (!entry.successful && entry.reasonDetailed.length > 0) {
                    Text(entry.reasonDetailed)
                      .fontSize(12)
                      .fontColor('#F44336')
                      .margin({ top: 2 })
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }
                }
                .layoutWeight(1)
                .margin({ left: 8 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#EEEEEE', startMargin: 56, endMargin: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
