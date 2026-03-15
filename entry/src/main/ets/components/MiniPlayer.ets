/**
 * 迷你播放器组件（#12.1 — 对照 Android ExternalPlayerFragment 复刻）
 *
 * 64vp 高度，浅蓝灰背景，底部进度条，封面 64x64
 */
@Component
export struct MiniPlayer {
  @Prop isVisible: boolean = false;
  @Prop title: string = '';
  @Prop feedTitle: string = '';
  @Prop imageUrl: string = '';
  @Prop isPlaying: boolean = false;
  @Prop progress: number = 0; // 0~1

  onPlayPause?: () => void;
  onTap?: () => void;

  build() {
    if (this.isVisible) {
      Column() {
        Row() {
          // 封面 64x64
          if (this.imageUrl.length > 0) {
            Image(this.imageUrl)
              .constraintSize({ maxWidth: 96, maxHeight: 64 })
              .objectFit(ImageFit.Contain)
          } else {
            Column() {
              Text('🎙️')
                .fontSize(26)
            }
            .width(64)
            .height(64)
            .backgroundColor('#D0D5DA')
            .justifyContent(FlexAlign.Center)
          }

          // 标题 + Feed 名
          Column() {
            Text(this.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1A1A1A')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.feedTitle)
              .fontSize(12)
              .fontColor('#444444')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)

          // 播放/暂停按钮 48x48 点击区域
          Column() {
            Text(this.isPlaying ? '⏸' : '▶')
              .fontSize(26)
              .fontColor('#1A1A1A')
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .borderRadius(24)
          .onClick(() => {
            this.onPlayPause?.();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 4, right: 8 })
        .alignItems(VerticalAlign.Center)

        // 底部进度条 4vp
        Stack({ alignContent: Alignment.TopStart }) {
          Row()
            .width('100%')
            .height(4)
            .backgroundColor('#C8CDD2')
          Row()
            .width(`${this.progress * 100}%`)
            .height(4)
            .backgroundColor('#0078C2')
        }
        .width('100%')
        .height(4)
      }
      .width('100%')
      .height(64)
      .backgroundColor(Color.Transparent)
      .shadow({ radius: 6, color: '#20000000', offsetY: -2 })
      .onClick(() => {
        this.onTap?.();
      })
    }
  }
}
