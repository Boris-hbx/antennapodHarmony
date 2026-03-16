import { router } from '@kit.ArkUI';

/**
 * 设置 — 同步
 * 对照 Android SynchronizationPreferencesFragment
 * 当前为占位页面，后续接入 gpodder.net / Nextcloud 同步
 */
@Entry
@Component
struct SettingsSyncPage {
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

        Text('同步')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      // 说明
      Column() {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(48)
          .fontColor(['#CCCCCC'])
          .margin({ bottom: 16 })

        Text('跨设备同步')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 8 })

        Text('将订阅列表和播放进度同步到其他设备。')
          .fontSize(14)
          .fontColor('#444444')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 8 })

        Text('支持的同步服务：')
          .fontSize(14)
          .fontColor('#444444')
          .margin({ top: 16, bottom: 8 })

        Column() {
          this.syncOption('gpodder.net', '开源播客同步服务')
          this.syncOption('Nextcloud gPodder', 'Nextcloud 自建同步')
        }
        .width('100%')
        .padding({ left: 24, right: 24 })

        Text('同步功能即将推出')
          .fontSize(13)
          .fontColor('#888888')
          .margin({ top: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  syncOption(name: string, desc: string) {
    Row() {
      Column() {
        Text(name).fontSize(14).fontColor('#1A1A1A')
        Text(desc).fontSize(12).fontColor('#888888').margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .margin({ bottom: 8 })
  }
}
