import { preferences } from '@kit.ArkData';
import { FeedMedia } from 'common';

const PREFS_NAME = 'default';

let prefs: preferences.Preferences | null = null;

// 播放器状态常量
export const PLAYER_STATUS_PLAYING = 1;
export const PLAYER_STATUS_PAUSED = 2;
export const PLAYER_STATUS_OTHER = 3;

// ===== 初始化 =====

export async function init(context: Context): Promise<void> {
  prefs = await preferences.getPreferences(context, PREFS_NAME);
}

function getPrefs(): preferences.Preferences {
  if (prefs === null) {
    throw new Error('PlaybackPreferences not initialized. Call init(context) first.');
  }
  return prefs;
}

// ===== 6.4 播放状态持久化 =====

/**
 * 记录当前播放的媒体
 */
export async function writeMediaPlaying(media: FeedMedia, feedId: number): Promise<void> {
  const p = getPrefs();
  p.putSync('lastPlayedFeedMediaId', media.id);
  p.putSync('lastPlayedFeedId', feedId);
  p.putSync('currentPlayerStatus', PLAYER_STATUS_PLAYING);
  await p.flush();
}

/**
 * 清除播放状态
 */
export async function writeNoMediaPlaying(): Promise<void> {
  const p = getPrefs();
  p.putSync('lastPlayedFeedMediaId', -1);
  p.putSync('lastPlayedFeedId', -1);
  p.putSync('currentPlayerStatus', PLAYER_STATUS_OTHER);
  await p.flush();
}

/**
 * 更新播放器状态
 */
export async function writePlayerStatus(status: number): Promise<void> {
  const p = getPrefs();
  p.putSync('currentPlayerStatus', status);
  await p.flush();
}

/**
 * 获取当前播放的媒体 ID
 */
export function getCurrentlyPlayingFeedMediaId(): number {
  return getPrefs().getSync('lastPlayedFeedMediaId', -1) as number;
}

/**
 * 获取当前播放的 Feed ID
 */
export function getLastPlayedFeedId(): number {
  return getPrefs().getSync('lastPlayedFeedId', -1) as number;
}

/**
 * 获取当前播放器状态
 */
export function getCurrentPlayerStatus(): number {
  return getPrefs().getSync('currentPlayerStatus', PLAYER_STATUS_OTHER) as number;
}
