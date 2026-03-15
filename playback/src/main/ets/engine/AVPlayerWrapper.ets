import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { PlayerStatus } from './PlayerStatus';

/**
 * AVPlayer 封装（需求 2）
 *
 * 封装 @ohos.multimedia.media.AVPlayer，提供统一的播放引擎接口。
 * 关键：AVPlayer 的状态变化通过回调异步通知，操作前必须等待正确状态。
 */
export class AVPlayerWrapper {
  private player: media.AVPlayer | null = null;
  private status: PlayerStatus = PlayerStatus.STOPPED;
  private currentSpeed: number = 1.0;
  private currentVolume: number = 1.0;
  private localFd: number = -1; // 本地文件 fd，播放完需关闭

  // 状态等待 Promise resolver
  private stateResolve: (() => void) | null = null;
  private waitingForState: string = '';

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
      await this.player.release();
      this.player = null;
    }
    this.closeLocalFd();
    this.setStatus(PlayerStatus.STOPPED);
  }

  // ===== 媒体加载 =====

  async setDataSource(url: string, isLocal: boolean, fallbackUrl?: string): Promise<void> {
    if (this.player === null) return;

    // 关闭之前的本地文件 fd
    this.closeLocalFd();

    // 重置到 idle 状态并等待
    await this.player.reset();
    await this.waitForState('idle');

    // 设置数据源（AVPlayer 自动转为 initialized 状态）
    let usedLocal = false;
    if (isLocal) {
      try {
        // 本地文件用 fdSrc，player.url 只支持 http(s)
        const file = fileIo.openSync(url, fileIo.OpenMode.READ_ONLY);
        this.localFd = file.fd;
        const stat = fileIo.statSync(url);
        console.info('AVPlayerWrapper: fdSrc fd=' + file.fd + ' size=' + stat.size + ' path=' + url);
        this.player.fdSrc = { fd: file.fd, offset: 0, length: stat.size };
        usedLocal = true;
      } catch (e) {
        console.error('AVPlayerWrapper: local file failed, falling back to stream: ' + JSON.stringify(e));
        this.closeLocalFd();
      }
    }
    if (!usedLocal) {
      // 网络 URL 或本地降级
      const streamUrl = fallbackUrl !== undefined && fallbackUrl.length > 0 ? fallbackUrl : url;
      console.info('AVPlayerWrapper: streaming url=' + streamUrl.substring(0, 80));
      this.player.url = streamUrl;
    }
    await this.waitForState('initialized');
  }

  async prepare(): Promise<void> {
    if (this.player === null) return;
    await this.player.prepare();
    await this.waitForState('prepared');
  }

  // ===== 播放控制 =====

  play(): void {
    if (this.player === null) return;
    this.player.play();
  }

  pause(): void {
    if (this.player === null) return;
    this.player.pause();
  }

  stop(): void {
    if (this.player === null) return;
    this.player.stop();
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
   * 等待 AVPlayer 进入指定状态（超时 5 秒）
   */
  private waitForState(targetState: string): Promise<void> {
    return new Promise<void>((resolve) => {
      this.waitingForState = targetState;
      this.stateResolve = resolve;
      // 超时保护
      setTimeout(() => {
        if (this.stateResolve !== null) {
          this.stateResolve = null;
          this.waitingForState = '';
          resolve(); // 超时也继续，不阻塞
        }
      }, 5000);
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

    // 状态变化
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

      // 检查是否有等待该状态的 Promise
      if (this.stateResolve !== null && state === this.waitingForState) {
        const resolver = this.stateResolve;
        this.stateResolve = null;
        this.waitingForState = '';
        resolver();
      }
    });

    // 播放进度
    this.player.on('timeUpdate', (timeMs: number) => {
      this.onPositionUpdate(timeMs, this.getDuration());
    });

    // 播放完成
    this.player.on('endOfStream', () => {
      this.onCompletion();
    });

    // 错误
    this.player.on('error', (err: Error) => {
      this.setStatus(PlayerStatus.ERROR);
      this.onError(err.message ?? 'Unknown playback error');
    });

    // 缓冲进度
    this.player.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (infoType === media.BufferingInfoType.BUFFERING_PERCENT) {
        this.onBufferingUpdate(value);
      }
    });
  }
}
