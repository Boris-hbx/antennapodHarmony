/**
 * 单集列表项组件（需求 3.4）
 *
 * 可复用于首页、收件箱、队列、剧集列表等页面。
 */
@Component
export struct EpisodeItem {
  @Prop title: string = '';
  @Prop feedTitle: string = '';
  @Prop dateStr: string = '';
  @Prop durationStr: string = '';
  @Prop imageUrl: string = '';
  @Prop isNew: boolean = false;
  @Prop isPlayed: boolean = false;
  @Prop progress: number = 0; // 0~1，播放进度

  onPlay?: () => void;
  onTap?: () => void;

  build() {
    Row() {
      // 封面
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.imageUrl.length > 0) {
          Image(this.imageUrl)
            .width(56)
            .height(56)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('🎙️')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .borderRadius(6)
          .backgroundColor('#F0F0F0')
          .justifyContent(FlexAlign.Center)
        }

        // NEW 蓝点
        if (this.isNew) {
          Circle()
            .width(8)
            .height(8)
            .fill('#0078C2')
            .margin({ top: 2, left: 2 })
        }
      }

      // 内容
      Column() {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isPlayed ? '#444444' : '#333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          if (this.dateStr.length > 0) {
            Text(this.dateStr)
              .fontSize(12)
              .fontColor('#444444')
          }
          if (this.dateStr.length > 0 && this.durationStr.length > 0) {
            Text(' · ')
              .fontSize(12)
              .fontColor('#444444')
          }
          if (this.durationStr.length > 0) {
            Text(this.durationStr)
              .fontSize(12)
              .fontColor('#444444')
          }
        }
        .margin({ top: 4 })

        // 播放进度条
        if (this.progress > 0 && this.progress < 1) {
          Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(3)
            .color('#0078C2')
            .backgroundColor('#E0E0E0')
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      // 播放按钮
      Button('▶')
        .type(ButtonType.Circle)
        .width(36)
        .height(36)
        .fontSize(14)
        .fontColor('#0078C2')
        .backgroundColor('#E0F0FF')
        .onClick(() => {
          this.onPlay?.();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onTap?.();
    })
  }
}
