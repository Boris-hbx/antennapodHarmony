import { router } from '@kit.ArkUI';

/**
 * 更多 Tab — 聚合入口（下载/历史/统计/设置）
 */
@Component
export struct MorePage {
  build() {
    Column() {
      Text($r('app.string.tab_more'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, left: 16 })

      List() {
        ListItem() {
          this.menuItem($r('app.string.title_downloads'), $r('app.string.desc_manage_downloads'))
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/DownloadsPage' });
        })

        ListItem() {
          this.menuItem($r('app.string.title_history'), $r('app.string.desc_view_history'))
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/HistoryPage' });
        })

        ListItem() {
          this.menuItem($r('app.string.title_statistics'), $r('app.string.desc_listening_stats'))
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/StatisticsPage' });
        })

        ListItem() {
          this.menuItem($r('app.string.title_settings'), $r('app.string.desc_app_settings'))
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })
      }
      .width('100%')
      .margin({ top: 8 })
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  menuItem(title: string | Resource, subtitle: string | Resource) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text(subtitle)
        .fontSize(12)
        .fontColor('#444444')
        .margin({ top: 2 })
    }
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
