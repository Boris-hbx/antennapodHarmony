/**
 * 迷你播放器组件（#12.1 — 对照 Android ExternalPlayerFragment 复刻）
 *
 * 64vp 高度，浅蓝灰背景，底部进度条，封面 64x64
 * 左右滑动 >100vp → dismiss（对标 Android BottomSheet STATE_HIDDEN 行为）
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
  onFastForward?: () => void;
  onRewind?: () => void;
  onTap?: () => void;
  onDismiss?: () => void; // 左右滑动消失回调

  @State swipeOffsetX: number = 0; // 当前拖动偏移量

  // 滑动消失阈值（vp）
  private readonly DISMISS_THRESHOLD: number = 100;

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
              SymbolGlyph($r('sys.symbol.mic'))
                .fontSize(26)
                .fontColor(['#666666'])
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

          // 快退按钮
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.gobackward_15'))
              .fontSize(20)
              .fontColor(['#1A1A1A'])
          }
          .width(40)
          .height(48)
          .onClick(() => { this.onRewind?.(); })
          .hitTestBehavior(HitTestMode.Block)

          // 播放/暂停按钮
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(26)
              .fontColor(['#1A1A1A'])
          }
          .width(48)
          .height(48)
          .onClick(() => { this.onPlayPause?.(); })
          .hitTestBehavior(HitTestMode.Block)

          // 快进按钮
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.goforward_30'))
              .fontSize(20)
              .fontColor(['#1A1A1A'])
          }
          .width(40)
          .height(48)
          .onClick(() => { this.onFastForward?.(); })
          .hitTestBehavior(HitTestMode.Block)
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
      // 拖动时水平偏移 + 透明度随距离渐变
      .translate({ x: this.swipeOffsetX })
      .opacity(1 - Math.min(Math.abs(this.swipeOffsetX) / this.DISMISS_THRESHOLD, 1) * 0.5)
      // 点击 → 打开全屏播放器（priorityGesture 优先级高于 PanGesture）
      .priorityGesture(
        TapGesture()
          .onAction(() => {
            this.onTap?.();
          })
      )
      // 左右滑动 → dismiss
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionUpdate((event: GestureEvent) => {
            this.swipeOffsetX = event.offsetX;
          })
          .onActionEnd(() => {
            if (Math.abs(this.swipeOffsetX) >= this.DISMISS_THRESHOLD) {
              this.swipeOffsetX = 0;
              this.onDismiss?.();
            } else {
              this.swipeOffsetX = 0;
            }
          })
      )
    }
  }
}
