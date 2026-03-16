/**
 * 封面图片组件 — 支持圆角、角标（未读数）、占位图
 * SU1: 默认圆角 12vp
 * SU2: 角标改为半透明 TextPill 样式
 * SU4: 支持 fillParent 模式（自适应列宽）
 */
@Component
export struct FeedCover {
  @Prop imageUrl: string = '';
  @Prop coverSize: number = 80;
  @Prop coverRadius: number = 12;   // SU1: 12vp 默认
  @Prop badgeCount: number = 0;
  @Prop fillParent: boolean = false; // SU4: 自适应父容器宽度

  build() {
    if (this.fillParent) {
      // SU4: 全宽模式 — 宽度跟随父容器，高度等于宽度（正方形）
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.imageUrl.length > 0) {
          Image(this.imageUrl)
            .width('100%')
            .aspectRatio(1)
            .borderRadius(this.coverRadius)
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.startIcon'))
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.mic'))
              .fontSize(32)
              .fontColor(['#AAAAAA'])
          }
          .width('100%')
          .aspectRatio(1)
          .borderRadius(this.coverRadius)
          .backgroundColor('#F0F0F0')
          .justifyContent(FlexAlign.Center)
        }

        // SU2: TextPill 半透明角标
        if (this.badgeCount > 0) {
          Text(this.badgeCount > 99 ? '99+' : this.badgeCount.toString())
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('rgba(0,0,0,0.45)')
            .borderRadius(12)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ top: 4, right: 4 })
        }
      }
      .width('100%')
      .aspectRatio(1)
    } else {
      // 固定尺寸模式
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.imageUrl.length > 0) {
          Image(this.imageUrl)
            .width(this.coverSize)
            .height(this.coverSize)
            .borderRadius(this.coverRadius)
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.startIcon'))
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.mic'))
              .fontSize(this.coverSize * 0.4)
              .fontColor(['#AAAAAA'])
          }
          .width(this.coverSize)
          .height(this.coverSize)
          .borderRadius(this.coverRadius)
          .backgroundColor('#F0F0F0')
          .justifyContent(FlexAlign.Center)
        }

        // SU2: TextPill 半透明角标
        if (this.badgeCount > 0) {
          Text(this.badgeCount > 99 ? '99+' : this.badgeCount.toString())
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('rgba(0,0,0,0.45)')
            .borderRadius(12)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ top: 4, right: 4 })
        }
      }
      .width(this.coverSize)
      .height(this.coverSize)
    }
  }
}
