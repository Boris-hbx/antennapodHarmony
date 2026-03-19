import { avSession } from '@kit.AVSessionKit';
import { FeedMedia, FeedItem, Feed } from 'common';
import { PlayerStatus } from '../engine/PlayerStatus';
import { getFastForwardSecs, getRewindSecs } from 'datastore';

/**
 * 媒体会话管理（需求 5 + 需求 9 控制命令）
 *
 * 创建 AVSession，使播放状态同步到系统媒体控制中心
 * （锁屏、通知栏、蓝牙设备）。
 */

let session: avSession.AVSession | null = null;

// 控制回调（由 PlaybackController 设置）
export let onSessionPlay: () => void = () => {};
export let onSessionPause: () => void = () => {};
export let onSessionSeek: (timeMs: number) => void = () => {};
export let onSessionFastForward: () => void = () => {};
export let onSessionRewind: () => void = () => {};
export let onSessionPlayNext: () => void = () => {};
export let onSessionStop: () => void = () => {};
export let onSessionPlayPrevious: () => void = () => {};
export let onSessionSetSpeed: (speed: number) => void = () => {};

export interface SessionCallbacks {
  play: () => void;
  pause: () => void;
  seek: (timeMs: number) => void;
  fastForward: () => void;
  rewind: () => void;
  playNext: () => void;
  stop: () => void;
  playPrevious: () => void;
  setSpeed: (speed: number) => void;
}

export function setSessionCallbacks(callbacks: SessionCallbacks): void {
  onSessionPlay = callbacks.play;
  onSessionPause = callbacks.pause;
  onSessionSeek = callbacks.seek;
  onSessionFastForward = callbacks.fastForward;
  onSessionRewind = callbacks.rewind;
  onSessionPlayNext = callbacks.playNext;
  onSessionStop = callbacks.stop;
  onSessionPlayPrevious = callbacks.playPrevious;
  onSessionSetSpeed = callbacks.setSpeed;
}

/**
 * 初始化媒体会话
 */
export async function initSession(context: Context): Promise<void> {
  if (session !== null) return;

  session = await avSession.createAVSession(context, 'AntennaPod', 'audio');
  await session.activate();
  registerControlCommands();
}

/**
 * 释放媒体会话
 */
export async function releaseSession(): Promise<void> {
  if (session === null) return;
  await session.deactivate();
  await session.destroy();
  session = null;
}

/**
 * 设置媒体元数据（播放新媒体时调用）
 */
export async function setSessionMetadata(media: FeedMedia, item: FeedItem | null,
  feed: Feed | null): Promise<void> {
  if (session === null) return;

  const metadata: avSession.AVMetadata = {
    assetId: media.id.toString(),
    title: item?.title ?? 'Unknown',
    artist: feed?.author ?? '',
    album: feed?.getTitle() ?? '',
    duration: media.duration
  };

  // 封面图片
  const imageLocation = item?.getImageLocation();
  if (imageLocation !== null && imageLocation !== undefined) {
    metadata.mediaImage = imageLocation;
  }

  await session.setAVMetadata(metadata);
}

/**
 * 同步播放状态
 */
export async function updateSessionPlaybackState(status: PlayerStatus, speed: number,
  positionMs: number): Promise<void> {
  if (session === null) return;

  let state: avSession.PlaybackState;
  switch (status) {
    case PlayerStatus.PLAYING:
      state = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
      break;
    case PlayerStatus.PAUSED:
      state = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
      break;
    case PlayerStatus.STOPPED:
      state = avSession.PlaybackState.PLAYBACK_STATE_STOP;
      break;
    case PlayerStatus.PREPARING:
    case PlayerStatus.INITIALIZING:
      state = avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
      break;
    default:
      state = avSession.PlaybackState.PLAYBACK_STATE_IDLE;
      break;
  }

  await session.setAVPlaybackState({
    state: state,
    speed: speed,
    position: {
      elapsedTime: positionMs,
      updateTime: Date.now()
    }
  });
}

/**
 * 注册控制命令响应
 */
function registerControlCommands(): void {
  if (session === null) return;

  session.on('play', () => {
    onSessionPlay();
  });

  session.on('pause', () => {
    onSessionPause();
  });

  session.on('seek', (time: number) => {
    onSessionSeek(time);
  });

  session.on('fastForward', () => {
    onSessionFastForward();
  });

  session.on('rewind', () => {
    onSessionRewind();
  });

  session.on('playNext', () => {
    onSessionPlayNext();
  });

  session.on('stop', () => {
    onSessionStop();
  });

  session.on('playPrevious', () => {
    onSessionPlayPrevious();
  });

  session.on('setSpeed', (speed: number) => {
    onSessionSetSpeed(speed);
  });
}
