import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { FeedMedia, FeedItem, Feed, EventBus, PLAYER_STATUS, PLAYBACK_POSITION } from 'common';
import type { PlaybackPositionData } from 'common';
import {
  getFeed, getFeedItem, getNextInQueue, removeQueueItem,
  setFeedMediaPlaybackInfo, writeMediaPlaying, writeNoMediaPlaying,
  getPlaybackSpeed, getFastForwardSecs, getRewindSecs
} from 'datastore';
import { AVPlayerWrapper } from './AVPlayerWrapper';
import { PlayerStatus } from './PlayerStatus';
import { startBackgroundPlayback, stopBackgroundPlayback } from './BackgroundPlayback';
import { calculateRewindPosition } from './RewindAfterPause';
import { SleepTimer } from './SleepTimer';
import { handlePlaybackCompletion, shouldSmartMarkAsPlayed } from './PlaybackCompleter';
import {
  initSession, releaseSession, setSessionMetadata,
  updateSessionPlaybackState, setSessionCallbacks
} from '../session/SessionManager';
import type { SessionCallbacks } from '../session/SessionManager';

/**
 * 播放控制器（需求 3）
 *
 * UI 层与播放引擎的中间层。
 * 管理播放生命周期、进度保存、后台播放和 AVSession。
 */
export class PlaybackController {
  private engine: AVPlayerWrapper = new AVPlayerWrapper();
  private context: common.UIAbilityContext | null = null;
  private currentMedia: FeedMedia | null = null;
  private currentItem: FeedItem | null = null;
  private currentFeed: Feed | null = null;
  private currentFeedId: number = 0;
  private positionSaveTimer: number = -1;
  private pausedAt: number = 0; // 暂停时间戳，用于暂停回退
  private transientPause: boolean = false; // 音频焦点打断标记
  private isSkipping: boolean = false; // BUG-5: 防止并发 skip
  private sleepTimer: SleepTimer = new SleepTimer();

  /**
   * 初始化
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    await this.engine.init();
    await initSession(context);

    // 设置引擎回调
    this.registerEngineCallbacks();

    // 睡眠定时器到时回调
    this.sleepTimer.onTimerEnd = () => {
      this.pause();
    };

    // 设置 AVSession 控制回调
    const cb: SessionCallbacks = {
      play: () => this.resume(),
      pause: () => this.pause(),
      seek: (timeMs: number) => this.seekTo(timeMs),
      fastForward: () => this.seekDelta(getFastForwardSecs() * 1000),
      rewind: () => this.seekDelta(-getRewindSecs() * 1000),
      playNext: () => this.skip()
    };
    setSessionCallbacks(cb);

    // 音频焦点由 AVPlayer 内部管理（HarmonyOS AVPlayer 自动处理 interrupt）
    // 耳机/蓝牙断开暂停由 AVPlayer stateChange 触发
  }

  /**
   * 释放资源
   */
  async release(): Promise<void> {
    this.stopPositionSaveTimer();
    await this.savePosition();
    // 音频焦点由 AVPlayer 内部管理
    await this.engine.release();
    await releaseSession();
    if (this.context !== null) {
      await stopBackgroundPlayback(this.context);
    }
    await writeNoMediaPlaying();
  }

  // ===== 播放控制 =====

  /**
   * 播放媒体
   */
  async playMedia(media: FeedMedia, feedId: number, stream: boolean): Promise<void> {
    // 停止当前播放
    if (this.currentMedia !== null) {
      await this.savePosition();
      this.stopPositionSaveTimer();
    }

    this.currentMedia = media;
    this.currentFeedId = feedId;

    // 加载 feed 和 item 信息
    this.currentFeed = await getFeed(feedId);
    if (media.itemId > 0) {
      this.currentItem = await getFeedItem(media.itemId);
    }

    // 记录播放状态
    await writeMediaPlaying(media, feedId);

    // 设置数据源 — 播放前验证本地文件完整性
    let isLocal = !stream && media.localFileUrl !== null && media.localFileUrl.length > 0;
    if (isLocal) {
      try {
        const stat = fileIo.statSync(media.localFileUrl!);
        if (stat.size === 0 || (media.size > 0 && stat.size < media.size * 0.95)) {
          console.error('PlaybackController: local file incomplete (' + stat.size + '/' + media.size + '), fallback to stream');
          isLocal = false;
        }
      } catch (_e) {
        console.error('PlaybackController: local file not accessible, fallback to stream');
        isLocal = false;
      }
    }
    const url = isLocal ? media.localFileUrl! : (media.downloadUrl ?? '');
    if (url.length === 0 && (media.downloadUrl ?? '').length === 0) {
      console.error('PlaybackController: Cannot play - no URL available for media id=' + media.id);
      return;
    }
    const fallbackUrl = media.downloadUrl ?? '';
    console.info('PlaybackController: playMedia url=' + url.substring(0, 80) + ' isLocal=' + isLocal);

    // BUG-5 修复：AVPlayer 状态转换可能超时或失败，包裹 try-catch 防止卡死
    try {
      await this.engine.setDataSource(url, isLocal, fallbackUrl);
      await this.engine.prepare();
    } catch (e) {
      console.error('PlaybackController: setDataSource/prepare failed: ' + (e instanceof Error ? e.message : JSON.stringify(e)));
      // 尝试重建 AVPlayer 后重试一次
      try {
        await this.engine.release();
        await this.engine.init();
        this.registerEngineCallbacks();
        await this.engine.setDataSource(url, isLocal, fallbackUrl);
        await this.engine.prepare();
      } catch (retryError) {
        console.error('PlaybackController: retry also failed: ' + (retryError instanceof Error ? retryError.message : JSON.stringify(retryError)));
        return; // 放弃播放，不卡死 UI
      }
    }

    // 跳过片头
    if (this.currentFeed?.preferences !== null && this.currentFeed?.preferences !== undefined) {
      const skipIntro = this.currentFeed.preferences.feedSkipIntro;
      if (skipIntro > 0) {
        this.engine.seekTo(skipIntro * 1000);
      }
    }

    // 恢复上次位置
    if (media.position > 0) {
      this.engine.seekTo(media.position);
    }

    // 设置播放速度
    const speed = this.currentFeed?.preferences?.feedPlaybackSpeed ?? -1;
    const globalSpeed = getPlaybackSpeed();
    this.engine.setSpeed(speed > 0 ? speed : globalSpeed);

    // 开始播放
    this.engine.play();

    // 启动后台播放
    if (this.context !== null) {
      await startBackgroundPlayback(this.context);
    }

    // 设置 AVSession 元数据
    await setSessionMetadata(media, this.currentItem, this.currentFeed);

    // 启动进度保存定时器
    this.startPositionSaveTimer();
  }

  playPause(): void {
    if (this.engine.isPlaying()) {
      this.pause();
    } else if (this.engine.getStatus() === PlayerStatus.PAUSED) {
      this.resume();
    }
  }

  pause(): void {
    this.engine.pause();
    this.pausedAt = Date.now();
    this.savePosition();
  }

  resume(): void {
    // 暂停回退（需求 7）
    if (this.pausedAt > 0) {
      const currentPos = this.engine.getPosition();
      const rewindPos = calculateRewindPosition(currentPos, this.pausedAt);
      if (rewindPos < currentPos) {
        this.engine.seekTo(rewindPos);
      }
      this.pausedAt = 0;
    }
    this.engine.play();
    this.transientPause = false;
  }

  seekTo(positionMs: number): void {
    this.engine.seekTo(Math.max(0, positionMs));
  }

  seekDelta(deltaMs: number): void {
    const current = this.engine.getPosition();
    const target = current + deltaMs;
    this.seekTo(Math.max(0, Math.min(target, this.engine.getDuration())));
  }

  setSpeed(speed: number): void {
    this.engine.setSpeed(speed);
  }

  /**
   * 跳到队列下一个
   * BUG-5 修复：
   *  - isSkipping 防并发（连按不会同时操作 AVPlayer）
   *  - 未下载 → stream = true（避免 fdSrc 拿到损坏/不存在的本地文件）
   *  - try-catch 全包裹 + safeStopPlayback 兜底
   */
  async skip(): Promise<void> {
    // 防止并发：skip 进行中直接忽略
    if (this.isSkipping) return;
    this.isSkipping = true;

    try {
      if (this.currentItem === null) {
        await this.safeStopPlayback();
        return;
      }

      const next = await getNextInQueue(this.currentItem);
      if (next === null || next.media === null) {
        await this.safeStopPlayback();
        return;
      }

      // 判断下一集是否已下载：没有本地文件 → stream 模式
      const hasLocalFile = next.media.localFileUrl !== null
        && next.media.localFileUrl.length > 0;
      const shouldStream = !hasLocalFile;

      // 先停止当前播放，让 AVPlayer 回到干净状态
      await this.safeStopPlayback();

      // 播放下一集
      await this.playMedia(next.media, next.feedId, shouldStream);
    } catch (e) {
      console.error('PlaybackController.skip() failed: ' +
        (e instanceof Error ? e.message : JSON.stringify(e)));
      await this.safeStopPlayback();
    } finally {
      this.isSkipping = false;
    }
  }

  // ===== 查询 =====

  getPosition(): number {
    return this.engine.getPosition();
  }

  getDuration(): number {
    return this.engine.getDuration();
  }

  getStatus(): PlayerStatus {
    return this.engine.getStatus();
  }

  getCurrentMedia(): FeedMedia | null {
    return this.currentMedia;
  }

  getCurrentItem(): FeedItem | null {
    return this.currentItem;
  }

  getCurrentFeed(): Feed | null {
    return this.currentFeed;
  }

  isPlaying(): boolean {
    return this.engine.isPlaying();
  }

  // ===== 睡眠定时器（需求 8） =====

  setSleepTimer(durationMs: number): void {
    this.sleepTimer.start(durationMs, false);
  }

  setSleepTimerEpisodes(count: number): void {
    this.sleepTimer.start(count, true);
  }

  cancelSleepTimer(): void {
    this.sleepTimer.stop();
  }

  getSleepTimerTimeLeft(): number {
    return this.sleepTimer.getTimeLeft();
  }

  isSleepTimerActive(): boolean {
    return this.sleepTimer.isActive();
  }

  // ===== 音频焦点（需求 9） =====

  /**
   * 因音频焦点被打断而暂停
   */
  handleAudioInterruptPause(): void {
    if (this.engine.isPlaying()) {
      this.engine.pause();
      this.transientPause = true;
    }
  }

  /**
   * 音频焦点恢复
   */
  handleAudioInterruptResume(): void {
    if (this.transientPause && this.engine.getStatus() === PlayerStatus.PAUSED) {
      this.engine.play();
      this.transientPause = false;
    }
  }

  /**
   * 注册系统音频打断事件监听
   */
  // ===== 内部方法 =====

  private registerEngineCallbacks(): void {
    this.engine.onStatusChange = (status: PlayerStatus) => {
      this.handleStatusChange(status);
    };
    this.engine.onPositionUpdate = (posMs: number, durMs: number) => {
      EventBus.emit<PlaybackPositionData>(PLAYBACK_POSITION, {
        position: posMs, duration: durMs
      });
      if (shouldSmartMarkAsPlayed(posMs, durMs)) {
        this.handleCompletion();
      }
    };
    this.engine.onCompletion = () => {
      this.handleCompletion();
    };
    this.engine.onError = (error: string) => {
      console.error('Playback error: ' + error);
    };
  }

  private async stopPlayback(): Promise<void> {
    this.stopPositionSaveTimer();
    await this.savePosition();
    this.engine.stop();
    this.currentMedia = null;
    this.currentItem = null;
    this.currentFeed = null;
    await writeNoMediaPlaying();
    if (this.context !== null) {
      await stopBackgroundPlayback(this.context);
    }
  }

  /**
   * 安全停止：即使 engine.stop() 抛异常也不会传播（BUG-5 修复）
   */
  private async safeStopPlayback(): Promise<void> {
    try {
      await this.stopPlayback();
    } catch (e) {
      console.error('safeStopPlayback error: ' + (e instanceof Error ? e.message : JSON.stringify(e)));
      // 强制清理状态，即使 stop 失败
      this.stopPositionSaveTimer();
      this.currentMedia = null;
      this.currentItem = null;
      this.currentFeed = null;
      try { await writeNoMediaPlaying(); } catch (_) { /* ignore */ }
    }
  }

  private handleStatusChange(status: PlayerStatus): void {
    EventBus.emit<void>(PLAYER_STATUS);
    updateSessionPlaybackState(status, this.engine.getSpeed(), this.engine.getPosition());
  }

  private async handleCompletion(): Promise<void> {
    this.stopPositionSaveTimer();
    EventBus.emit<void>(PLAYER_STATUS);

    if (this.currentItem === null || this.currentMedia === null) {
      await this.stopPlayback();
      return;
    }

    // 睡眠定时器：集数模式递减
    const shouldStop = this.sleepTimer.onEpisodeCompleted();

    // 播放结束处理（需求 10）
    const result = await handlePlaybackCompletion(
      this.currentItem, this.currentMedia, this.currentFeedId);

    if (shouldStop) {
      await this.stopPlayback();
      return;
    }

    // 继续播放下一集 — 和 skip() 同样逻辑：未下载用 stream 模式
    if (result.shouldPlayNext && result.nextItem !== null && result.nextItem.media !== null) {
      const nextMedia = result.nextItem.media;
      const hasLocal = nextMedia.localFileUrl !== null && nextMedia.localFileUrl.length > 0;
      try {
        await this.playMedia(nextMedia, result.nextItem.feedId, !hasLocal);
      } catch (e) {
        console.error('handleCompletion: playNext failed: ' +
          (e instanceof Error ? e.message : JSON.stringify(e)));
        await this.safeStopPlayback();
      }
    } else {
      await this.stopPlayback();
    }
  }

  private async savePosition(): Promise<void> {
    if (this.currentMedia === null) return;
    const pos = this.engine.getPosition();
    const dur = this.engine.getDuration();
    if (pos > 0) {
      this.currentMedia.position = pos;
      this.currentMedia.duration = dur;
      await setFeedMediaPlaybackInfo(this.currentMedia.id, pos, dur,
        this.currentMedia.playedDuration);
    }
  }

  private startPositionSaveTimer(): void {
    this.stopPositionSaveTimer();
    this.positionSaveTimer = setInterval(() => {
      this.savePosition();
    }, 5000);
  }

  private stopPositionSaveTimer(): void {
    if (this.positionSaveTimer >= 0) {
      clearInterval(this.positionSaveTimer);
      this.positionSaveTimer = -1;
    }
  }
}
