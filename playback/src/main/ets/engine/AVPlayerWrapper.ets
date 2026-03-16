import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { PlayerStatus } from './PlayerStatus';

/**
 * AVPlayer 封装（需求 2）
 *
 * 封装 @ohos.multimedia.media.AVPlayer，提供统一的播放引擎接口。
 * 关键：AVPlayer 的状态变化通过回调异步通知，操作前必须等待正确状态。
 *
 * BUG-5 修复：所有 AVPlayer 系统 API 调用都用 raceTimeout 包裹，
 * 防止 Promise 永不 resolve 导致 UI 线程卡死。
 */
export class AVPlayerWrapper {
  private player: media.AVPlayer | null = null;
  private status: PlayerStatus = PlayerStatus.STOPPED;
  private currentSpeed: number = 1.0;
  private currentVolume: number = 1.0;
  private localFd: number = -1;

  // 状态等待 Promise resolver
  private stateResolve: (() => void) | null = null;
  private waitingForState: string = '';
  private stateReject: ((reason: Error) => void) | null = null;

  // 回调
  onStatusChange: (status: PlayerStatus) => void = () => {};
  onPositionUpdate: (positionMs: number, durationMs: number) => void = () => {};
  onError: (error: string) => void = () => {};
  onCompletion: () => void = () => {};
  onBufferingUpdate: (percent: number) => void = () => {};

  // ===== 生命周期 =====

  async init(): Promise<void> {
    this.player = await media.createAVPlayer();
    this.registerCallbacks();
  }

  async release(): Promise<void> {
    if (this.player !== null) {
      try {
        await this.raceTimeout(this.player.release(), 5000, 'release');
      } catch (_e) {
        console.error('AVPlayerWrapper: release failed, forcing null');
      }
      this.player = null;
    }
    this.closeLocalFd();
    this.cancelWait('released');
    this.setStatus(PlayerStatus.STOPPED);
  }

  // ===== 媒体加载 =====

  async setDataSource(url: string, isLocal: boolean, fallbackUrl?: string): Promise<void> {
    if (this.player === null) return;

    this.closeLocalFd();

    // 重置到 idle 状态
    await this.safeReset();

    // 设置数据源（AVPlayer 自动转为 initialized 状态）
    const initPromise = this.waitForState('initialized');
    let usedLocal = false;
    if (isLocal) {
      try {
        // 先验证文件存在且可读
        const exists = fileIo.accessSync(url);
        if (exists) {
          const file = fileIo.openSync(url, fileIo.OpenMode.READ_ONLY);
          this.localFd = file.fd;
          const stat = fileIo.statSync(url);
          if (stat.size > 0) {
            console.info('AVPlayerWrapper: fdSrc fd=' + file.fd + ' size=' + stat.size);
            this.player.fdSrc = { fd: file.fd, offset: 0, length: stat.size };
            usedLocal = true;
          } else {
            console.error('AVPlayerWrapper: local file is empty, falling back to stream');
            this.closeLocalFd();
          }
        } else {
          console.error('AVPlayerWrapper: local file not accessible, falling back to stream');
        }
      } catch (e) {
        console.error('AVPlayerWrapper: local file failed: ' + JSON.stringify(e));
        this.closeLocalFd();
      }
    }
    if (!usedLocal) {
      const streamUrl = fallbackUrl !== undefined && fallbackUrl.length > 0 ? fallbackUrl : url;
      if (streamUrl.length === 0) {
        this.cancelWait('no URL');
        throw new Error('No URL available for playback');
      }
      console.info('AVPlayerWrapper: streaming url=' + streamUrl.substring(0, 80));
      this.player.url = streamUrl;
    }
    await initPromise;
  }

  async prepare(): Promise<void> {
    if (this.player === null) return;
    const preparedPromise = this.waitForState('prepared');
    await this.raceTimeout(this.player.prepare(), 10000, 'prepare');
    await preparedPromise;
  }

  // ===== 播放控制 =====

  play(): void {
    if (this.player === null) return;
    this.player.play();
  }

  pause(): void {
    if (this.player === null) return;
    const state = this.player.state;
    if (state === 'playing') {
      this.player.pause();
    }
  }

  stop(): void {
    if (this.player === null) return;
    const state = this.player.state;
    if (state === 'playing' || state === 'paused' || state === 'prepared') {
      this.player.stop();
    }
  }

  seekTo(positionMs: number): void {
    if (this.player === null) return;
    this.player.seek(positionMs);
  }

  // ===== 参数 =====

  setSpeed(speed: number): void {
    if (this.player === null) return;
    this.currentSpeed = speed;
    this.player.setSpeed(this.mapSpeed(speed));
  }

  getSpeed(): number {
    return this.currentSpeed;
  }

  setVolume(volume: number): void {
    if (this.player === null) return;
    this.currentVolume = volume;
    this.player.setVolume(volume);
  }

  // ===== 查询 =====

  getDuration(): number {
    if (this.player === null) return 0;
    return this.player.duration ?? 0;
  }

  getPosition(): number {
    if (this.player === null) return 0;
    return this.player.currentTime ?? 0;
  }

  getStatus(): PlayerStatus {
    return this.status;
  }

  isPlaying(): boolean {
    return this.status === PlayerStatus.PLAYING;
  }

  // ===== 内部方法 =====

  private setStatus(newStatus: PlayerStatus): void {
    if (newStatus === this.status) return;
    this.status = newStatus;
    this.onStatusChange(newStatus);
  }

  /**
   * 安全 reset：给 player.reset() 加超时，防止 Promise 永不 resolve 导致卡死
   */
  private async safeReset(): Promise<void> {
    if (this.player === null) return;

    // 如果已经是 idle，无需 reset
    if (this.player.state === 'idle') return;

    const idlePromise = this.waitForState('idle');
    try {
      await this.raceTimeout(this.player.reset(), 5000, 'reset');
    } catch (e) {
      console.error('AVPlayerWrapper: reset() timed out or failed, recreating player');
      this.cancelWait('reset failed');
      // reset 失败 → 销毁重建 AVPlayer
      try { this.player.release(); } catch (_) { /* ignore */ }
      this.player = await media.createAVPlayer();
      this.registerCallbacks();
      this.setStatus(PlayerStatus.STOPPED);
      return; // 新 player 已经是 idle 状态
    }
    await idlePromise;
  }

  /**
   * 给任意 Promise 加超时上限
   */
  private raceTimeout<T>(promise: Promise<T>, timeoutMs: number, label: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`AVPlayer ${label} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      promise.then((val: T) => {
        clearTimeout(timer);
        resolve(val);
      }).catch((err: Error) => {
        clearTimeout(timer);
        reject(err);
      });
    });
  }

  /**
   * 取消正在等待的 state promise（防止内存泄漏）
   */
  private cancelWait(reason: string): void {
    if (this.stateResolve !== null) {
      const rejector = this.stateReject;
      this.stateResolve = null;
      this.stateReject = null;
      this.waitingForState = '';
      if (rejector !== null) {
        rejector(new Error('Wait cancelled: ' + reason));
      }
    }
  }

  /**
   * 等待 AVPlayer 进入指定状态（超时 10 秒）
   */
  private waitForState(targetState: string): Promise<void> {
    if (this.player !== null && this.player.state === targetState) {
      return Promise.resolve();
    }
    return new Promise<void>((resolve, reject) => {
      this.waitingForState = targetState;
      this.stateResolve = resolve;
      this.stateReject = reject;
      setTimeout(() => {
        if (this.stateResolve !== null) {
          const waitedFor = this.waitingForState;
          this.stateResolve = null;
          this.stateReject = null;
          this.waitingForState = '';
          reject(new Error(`AVPlayer timeout waiting for state '${waitedFor}', current: ${this.player?.state}`));
        }
      }, 10000);
    });
  }

  private closeLocalFd(): void {
    if (this.localFd >= 0) {
      try {
        fileIo.closeSync(this.localFd);
      } catch (_e) {
        // ignore
      }
      this.localFd = -1;
    }
  }

  private mapSpeed(speed: number): media.PlaybackSpeed {
    if (speed <= 0.75) return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    if (speed <= 1.0) return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (speed <= 1.25) return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    if (speed <= 1.75) return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
  }

  /**
   * 注册 AVPlayer 事件回调
   */
  private registerCallbacks(): void {
    if (this.player === null) return;

    this.player.on('stateChange', (state: string) => {
      switch (state) {
        case 'idle':
          this.setStatus(PlayerStatus.STOPPED);
          break;
        case 'initialized':
          this.setStatus(PlayerStatus.INITIALIZING);
          break;
        case 'prepared':
          this.setStatus(PlayerStatus.PREPARED);
          break;
        case 'playing':
          this.setStatus(PlayerStatus.PLAYING);
          break;
        case 'paused':
          this.setStatus(PlayerStatus.PAUSED);
          break;
        case 'stopped':
          this.setStatus(PlayerStatus.STOPPED);
          break;
        case 'error':
          this.setStatus(PlayerStatus.ERROR);
          break;
        default:
          break;
      }

      if (this.stateResolve !== null) {
        if (state === this.waitingForState) {
          const resolver = this.stateResolve;
          this.stateResolve = null;
          this.stateReject = null;
          this.waitingForState = '';
          resolver();
        } else if (state === 'error') {
          const rejector = this.stateReject;
          this.stateResolve = null;
          this.stateReject = null;
          const waited = this.waitingForState;
          this.waitingForState = '';
          if (rejector !== null) {
            rejector(new Error(`AVPlayer error while waiting for '${waited}'`));
          }
        }
      }
    });

    this.player.on('timeUpdate', (timeMs: number) => {
      this.onPositionUpdate(timeMs, this.getDuration());
    });

    this.player.on('endOfStream', () => {
      this.onCompletion();
    });

    this.player.on('error', (err: Error) => {
      this.setStatus(PlayerStatus.ERROR);
      this.onError(err.message ?? 'Unknown playback error');
    });

    this.player.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (infoType === media.BufferingInfoType.BUFFERING_PERCENT) {
        this.onBufferingUpdate(value);
      }
    });
  }
}
