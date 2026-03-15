import { EventBus } from 'common';

// 睡眠定时器事件
export const SLEEP_TIMER_UPDATE = 'SLEEP_TIMER_UPDATE';

export interface SleepTimerData {
  timeLeft: number;
  isActive: boolean;
}

/**
 * 睡眠定时器（需求 8）
 *
 * 支持两种模式：
 * - 时钟定时器：N 分钟后暂停播放
 * - 集数定时器：播放 N 集后暂停播放
 */
export class SleepTimer {
  private timer: number = -1;
  private endTimeMs: number = 0;
  private episodesLeft: number = 0;
  private episodeMode: boolean = false;
  private active: boolean = false;

  onTimerEnd: () => void = () => {};

  /**
   * 启动定时器
   * @param value 时钟模式：毫秒数；集数模式：集数
   * @param isEpisodeMode 是否为集数模式
   */
  start(value: number, isEpisodeMode: boolean): void {
    this.stop();
    this.episodeMode = isEpisodeMode;
    this.active = true;

    if (isEpisodeMode) {
      this.episodesLeft = value;
      this.emitUpdate();
    } else {
      this.endTimeMs = Date.now() + value;
      this.timer = setInterval(() => {
        const left = this.getTimeLeft();
        this.emitUpdate();
        if (left <= 0) {
          this.onTimerEnd();
          this.stop();
        }
      }, 1000);
      this.emitUpdate();
    }
  }

  /**
   * 停止定时器
   */
  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.active = false;
    this.endTimeMs = 0;
    this.episodesLeft = 0;
    this.emitUpdate();
  }

  /**
   * 获取剩余时间（ms）或剩余集数
   */
  getTimeLeft(): number {
    if (!this.active) return 0;
    if (this.episodeMode) {
      return this.episodesLeft;
    }
    return Math.max(0, this.endTimeMs - Date.now());
  }

  isActive(): boolean {
    return this.active;
  }

  isEpisodeMode(): boolean {
    return this.episodeMode;
  }

  /**
   * 集数模式：一集播完时调用，递减计数
   * 返回 true 表示计数归零，应暂停播放
   */
  onEpisodeCompleted(): boolean {
    if (!this.active || !this.episodeMode) return false;

    this.episodesLeft--;
    this.emitUpdate();

    if (this.episodesLeft <= 0) {
      this.onTimerEnd();
      this.stop();
      return true;
    }
    return false;
  }

  /**
   * 重置定时器（摇动重置用）
   */
  restart(durationMs: number): void {
    if (!this.active || this.episodeMode) return;
    this.endTimeMs = Date.now() + durationMs;
    this.emitUpdate();
  }

  private emitUpdate(): void {
    EventBus.emit<SleepTimerData>(SLEEP_TIMER_UPDATE, {
      timeLeft: this.getTimeLeft(),
      isActive: this.active
    });
  }
}
