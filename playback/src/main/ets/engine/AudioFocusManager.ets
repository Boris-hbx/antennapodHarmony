/**
 * 音频焦点管理
 *
 * HarmonyOS 的 AVPlayer 内置了音频中断处理：
 * - 来电时自动暂停
 * - 其他 App 播放时自动暂停
 * - 焦点恢复时通过 stateChange 回调通知
 *
 * 本类提供额外的中断回调接口，由 PlaybackController 在 AVPlayer
 * 的 stateChange 中手动调用，实现 30 秒超时恢复等高级逻辑。
 *
 * 注意：HarmonyOS `audioInterrupt` 事件仅在 AudioRenderer 上可用，
 * 不在 AudioStreamManager 上。AVPlayer 内部已处理中断，我们通过
 * AVPlayer 的 stateChange 感知中断即可。
 */

const TAG = 'AudioFocusManager';

export class AudioFocusManager {
  onPause: (() => void) | null = null;
  onResume: (() => void) | null = null;
  onDuck: (() => void) | null = null;
  onUnduck: (() => void) | null = null;
  onStop: (() => void) | null = null;

  init(): void {
    console.info(TAG, 'AudioFocusManager initialized (AVPlayer handles interrupt internally)');
  }

  release(): void {
    this.onPause = null;
    this.onResume = null;
    this.onDuck = null;
    this.onUnduck = null;
    this.onStop = null;
    console.info(TAG, 'AudioFocusManager released');
  }

  /**
   * 由 PlaybackController 在检测到 AVPlayer 被系统暂停时调用
   */
  notifyInterruptPause(): void {
    console.info(TAG, 'Interrupt: PAUSE (from AVPlayer stateChange)');
    this.onPause?.();
  }

  /**
   * 由 PlaybackController 在检测到 AVPlayer 恢复播放时调用
   */
  notifyInterruptResume(): void {
    console.info(TAG, 'Interrupt: RESUME (from AVPlayer stateChange)');
    this.onResume?.();
  }
}
