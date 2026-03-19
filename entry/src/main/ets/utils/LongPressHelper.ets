/**
 * 手动长按检测 — 绕过 ArkUI 手势系统，
 * 避免 List/Scroll/Grid 等可滚动容器抢占触摸事件导致 LongPressGesture 失效。
 *
 * 用法：
 *   private lp = new LongPressHelper();
 *
 *   Row() { ... }
 *     .onTouch((e: TouchEvent) => {
 *       this.lp.onTouch(e, () => {
 *         this.selectedItem = item;
 *         this.showContextMenu = true;
 *       });
 *     })
 *     .onClick(() => {
 *       if (!this.lp.fired) {
 *         router.pushUrl({ ... });
 *       }
 *     })
 */
export class LongPressHelper {
  /** 长按定时器 ID */
  private timer: number = -1;
  /** 本次触摸是否已触发长按 */
  fired: boolean = false;
  /** 触摸起始坐标 */
  private startX: number = 0;
  private startY: number = 0;
  /** 移动容忍距离 (vp) */
  private readonly threshold: number = 10;
  /** 长按时长 (ms) */
  private readonly duration: number = 500;

  /**
   * 绑定到 .onTouch() 回调
   * @param event 触摸事件
   * @param onLongPress 长按触发时的回调
   */
  onTouch(event: TouchEvent, onLongPress: () => void): void {
    switch (event.type) {
      case TouchType.Down:
        this.fired = false;
        this.startX = event.touches[0].x;
        this.startY = event.touches[0].y;
        this.cancelTimer();
        this.timer = setTimeout(() => {
          this.fired = true;
          this.timer = -1;
          onLongPress();
        }, this.duration);
        break;

      case TouchType.Move:
        if (this.timer >= 0) {
          const dx = Math.abs(event.touches[0].x - this.startX);
          const dy = Math.abs(event.touches[0].y - this.startY);
          if (dx > this.threshold || dy > this.threshold) {
            this.cancelTimer();
          }
        }
        break;

      default: // TouchType.Up, TouchType.Cancel
        this.cancelTimer();
        break;
    }
  }

  private cancelTimer(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }
}
