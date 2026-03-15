/**
 * 播放器桌面 Widget 卡片 UI（2×2）
 *
 * 显示当前播放状态和快捷控制按钮。
 */

let widgetStorage = new LocalStorage();

@Entry(widgetStorage)
@Component
struct PlayerWidgetCard {
  @LocalStorageProp('title') title: string = '未在播放';
  @LocalStorageProp('feedTitle') feedTitle: string = 'AntennaPod';
  @LocalStorageProp('isPlaying') isPlaying: boolean = false;

  build() {
    Column() {
      Row() {
        Text('🎙️')
          .fontSize(24)
          .margin({ right: 8 })
        Column() {
          Text(this.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.feedTitle)
            .fontSize(11)
            .fontColor('#444444')
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)

      Row() {
        Button(this.isPlaying ? '⏸' : '▶')
          .type(ButtonType.Circle)
          .width(36)
          .height(36)
          .fontSize(16)
          .fontColor('#0078C2')
          .backgroundColor('#FFF3E0')
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { widgetAction: 'playPause' }
            });
          })

        Button('⏩')
          .type(ButtonType.Circle)
          .width(32)
          .height(32)
          .fontSize(14)
          .fontColor('#444444')
          .backgroundColor('#F5F5F5')
          .margin({ left: 12 })
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { widgetAction: 'fastForward' }
            });
          })

        Button('⏭️')
          .type(ButtonType.Circle)
          .width(32)
          .height(32)
          .fontSize(14)
          .fontColor('#444444')
          .backgroundColor('#F5F5F5')
          .margin({ left: 12 })
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { widgetAction: 'skip' }
            });
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}
