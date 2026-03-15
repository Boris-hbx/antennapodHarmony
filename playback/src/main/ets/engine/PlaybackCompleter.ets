import { FeedItem, FeedMedia, PlayState, TAG_QUEUE } from 'common';
import {
  markItemPlayed, deleteFeedMediaOfItem, removeQueueItem,
  addItemToPlaybackHistory, setFeedMediaPlaybackInfo,
  getNextInQueue, getFeed, getSmartMarkAsPlayedSecs,
  isFollowQueue
} from 'datastore';
import type { AutoDeleteAction } from 'common';

/**
 * 播放结束处理（需求 10）
 *
 * 流程：
 * 1. 保存最终播放位置
 * 2. 标记为 PLAYED
 * 3. 如果设置了自动删除 → 删除本地文件
 * 4. 如果在队列中 → 从队列移除
 * 5. 记录播放历史
 * 6. 返回是否应继续播放下一集
 */

export interface CompletionResult {
  shouldPlayNext: boolean;
  nextItem: FeedItem | null;
}

/**
 * 处理单集播放结束
 */
export async function handlePlaybackCompletion(item: FeedItem,
  media: FeedMedia, feedId: number): Promise<CompletionResult> {

  // 1. 保存最终位置
  await setFeedMediaPlaybackInfo(media.id, media.duration, media.duration,
    media.playedDuration);

  // 2. 标记为 PLAYED
  await markItemPlayed(item.id, PlayState.PLAYED);

  // 3. 自动删除检查
  const feed = await getFeed(feedId);
  if (feed !== null && feed.preferences !== null) {
    const deleteAction = feed.preferences.autoDeleteAction;
    // AutoDeleteAction.ALWAYS = 1
    if (deleteAction === 1 && media.localFileUrl !== null) {
      await deleteFeedMediaOfItem(item.id);
    }
  }

  // 4. 从队列移除
  if (item.isQueued()) {
    await removeQueueItem(item);
  }

  // 5. 记录播放历史
  await addItemToPlaybackHistory(item);

  // 6. 判断是否继续播放
  const followQueue = isFollowQueue();
  if (followQueue) {
    const next = await getNextInQueue(item);
    if (next !== null && next.media !== null) {
      return { shouldPlayNext: true, nextItem: next };
    }
  }

  return { shouldPlayNext: false, nextItem: null };
}

/**
 * 智能标记已播（需求 10 补充）
 *
 * 如果剩余时长 < smartMarkAsPlayedSecs → 直接标记为已播放
 */
export function shouldSmartMarkAsPlayed(positionMs: number, durationMs: number): boolean {
  if (durationMs <= 0 || positionMs <= 0) return false;
  const remainingMs = durationMs - positionMs;
  const thresholdMs = getSmartMarkAsPlayedSecs() * 1000;
  return remainingMs > 0 && remainingMs < thresholdMs;
}
