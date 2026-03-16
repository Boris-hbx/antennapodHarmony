import { router } from '@kit.ArkUI';

/**
 * 设置页面 — 主入口（Hub），导航到 6 个子页面
 * 对照 Android MainPreferencesFragment
 */
@Entry
@Component
struct SettingsPage {
  build() {
    Column() {
      // 顶部导航
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .alignContent(Alignment.Center)
        .onClick(() => { router.back(); })

        Text($r('app.string.title_settings'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // 6 个子页面入口
        ListItem() {
          this.navEntry('用户界面', '主题、封面、默认页面', 'sys.symbol.rectangle_on_rectangle')
        }.onClick(() => { router.pushUrl({ url: 'pages/SettingsUserInterfacePage' }); })

        ListItem() {
          this.navEntry('播放', '速度、快进倒退、队列、耳机', 'sys.symbol.play_circle')
        }.onClick(() => { router.pushUrl({ url: 'pages/SettingsPlaybackPage' }); })

        ListItem() {
          this.navEntry('下载', '自动下载、缓存、更新频率', 'sys.symbol.arrow_down_circle')
        }.onClick(() => { router.pushUrl({ url: 'pages/SettingsDownloadsPage' }); })

        ListItem() {
          this.navEntry('同步', '跨设备同步订阅和播放进度', 'sys.symbol.arrow_triangle_2_circlepath')
        }.onClick(() => { router.pushUrl({ url: 'pages/SettingsSyncPage' }); })

        ListItem() {
          this.navEntry('备份和恢复', 'OPML 导入导出', 'sys.symbol.folder')
        }.onClick(() => { router.pushUrl({ url: 'pages/SettingsBackupPage' }); })

        ListItem() {
          this.navEntry('通知', '新单集通知、下载通知', 'sys.symbol.bell')
        }.onClick(() => { router.pushUrl({ url: 'pages/SettingsNotificationsPage' }); })

        // 关于
        ListItem() {
          Column() {
            Text('关于')
              .fontSize(13)
              .fontColor('#888888')
              .margin({ bottom: 4 })
          }
          .padding({ left: 16, right: 16, top: 24, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          Column() {
            Text('AntennaPod for HarmonyOS')
              .fontSize(14)
            Text('版本 1.0.0')
              .fontSize(12)
              .fontColor('#444444')
              .margin({ top: 2 })
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
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
  navEntry(title: string, subtitle: string, icon: string) {
    Row() {
      SymbolGlyph($r(icon))
        .fontSize(22)
        .fontColor(['#333333'])
        .margin({ right: 16 })
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#444444')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#CCCCCC'])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}
