import { router } from '@kit.ArkUI';

/**
 * 设置 — 通知
 * 对照 Android NotificationPreferencesFragment
 */
@Entry
@Component
struct SettingsNotificationsPage {
  @State notifyNewEpisodes: boolean = true;
  @State notifyDownloadComplete: boolean = true;
  @State notifyDownloadError: boolean = true;
  @State notifySyncError: boolean = true;

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .alignContent(Alignment.Center)
        .onClick(() => { router.back(); })

        Text('通知')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // ===== 新单集 =====
        ListItem() { this.sectionHeader('内容更新') }

        ListItem() {
          this.switchRow('新单集通知', '订阅的播客有新单集时推送通知',
            this.notifyNewEpisodes, (v: boolean) => {
              this.notifyNewEpisodes = v;
            })
        }

        // ===== 下载 =====
        ListItem() { this.sectionHeader('下载') }

        ListItem() {
          this.switchRow('下载完成通知', '单集下载完成后提醒',
            this.notifyDownloadComplete, (v: boolean) => {
              this.notifyDownloadComplete = v;
            })
        }

        // ===== 错误 =====
        ListItem() { this.sectionHeader('错误通知') }

        ListItem() {
          this.switchRow('下载错误通知', '下载失败时显示通知',
            this.notifyDownloadError, (v: boolean) => {
              this.notifyDownloadError = v;
            })
        }
        ListItem() {
          this.switchRow('同步错误通知', '同步失败时显示通知',
            this.notifySyncError, (v: boolean) => {
              this.notifySyncError = v;
            })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  sectionHeader(title: string) {
    Column() {
      Text(title).fontSize(13).fontColor('#888888').margin({ bottom: 4 })
    }
    .padding({ left: 16, right: 16, top: 20, bottom: 4 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  switchRow(title: string, subtitle: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#1A1A1A')
        Text(subtitle).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#0078C2')
        .onChange((value: boolean) => { onChange(value); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}
