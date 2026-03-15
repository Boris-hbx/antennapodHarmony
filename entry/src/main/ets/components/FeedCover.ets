/**
 * 封面图片组件 — 支持圆角、角标（未读数）、占位图
 */
@Component
export struct FeedCover {
  @Prop imageUrl: string = '';
  @Prop coverSize: number = 80;
  @Prop coverRadius: number = 16;
  @Prop badgeCount: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.imageUrl.length > 0) {
        Image(this.imageUrl)
          .width(this.coverSize)
          .height(this.coverSize)
          .borderRadius(this.coverRadius)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.startIcon'))
      } else {
        // 占位图
        Column() {
          Text('🎙️')
            .fontSize(this.coverSize * 0.4)
        }
        .width(this.coverSize)
        .height(this.coverSize)
        .borderRadius(this.coverRadius)
        .backgroundColor('#F0F0F0')
        .justifyContent(FlexAlign.Center)
      }

      // 未读角标
      if (this.badgeCount > 0) {
        Text(this.badgeCount > 99 ? '99+' : this.badgeCount.toString())
          .fontSize(10)
          .fontColor('#FFFFFF')
          .backgroundColor('#0078C2')
          .borderRadius(10)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .margin({ top: 2, right: 2 })
      }
    }
    .width(this.coverSize)
    .height(this.coverSize)
  }
}
