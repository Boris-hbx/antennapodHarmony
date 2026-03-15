import { fileIo } from '@kit.CoreFileKit';
import { FeedItem, FeedMedia, PlayState, TAG_QUEUE, TAG_FAVORITE } from 'common';
import {
  getFeedList, getFeedItemList, getEpisodeCacheSize, getEpisodeCleanup,
  deleteFeedMediaOfItem
} from 'datastore';

/**
 * 存储清理（需求 3）
 *
 * 4 种策略：
 * - EPISODE_CLEANUP_NULL(-2): 不清理
 * - EPISODE_CLEANUP_QUEUE(-1): 删除不在队列中的最旧已播放
 * - EPISODE_CLEANUP_EXCEPT_FAVORITE(-3): 删除非收藏的最旧已播放
 * - N (>0): 删除下载超过 N 天的已播放
 */

const CLEANUP_NULL = -2;
const CLEANUP_QUEUE = -1;
const CLEANUP_EXCEPT_FAVORITE = -3;

interface DownloadedItem {
  item: FeedItem;
  media: FeedMedia;
  downloadDate: number;
}

/**
 * 执行存储清理
 * @returns 删除的文件数
 */
export async function runStorageCleanup(): Promise<number> {
  const cleanupPolicy = getEpisodeCleanup();

  // 不清理
  if (cleanupPolicy === CLEANUP_NULL) {
    return 0;
  }

  const cacheSize = getEpisodeCacheSize();
  const feeds = await getFeedList();

  // 收集所有已下载的单集
  const downloaded: DownloadedItem[] = [];
  for (const feed of feeds) {
    const items = await getFeedItemList(feed.id, null, null, 0, 0);
    for (const item of items) {
      if (item.media !== null && item.media.isDownloaded() && item.media.localFileUrl !== null) {
        const dlItem: DownloadedItem = {
          item: item,
          media: item.media,
          downloadDate: item.media.downloadDate
        };
        downloaded.push(dlItem);
      }
    }
  }

  // 如果未超过缓存上限，不需要清理
  if (downloaded.length <= cacheSize) {
    return 0;
  }

  // 筛选可删除的单集
  const deletable: DownloadedItem[] = [];
  const now = Date.now();

  for (const dl of downloaded) {
    // 只删已播放的
    if (dl.item.state !== PlayState.PLAYED) continue;

    switch (cleanupPolicy) {
      case CLEANUP_QUEUE:
        // 不在队列中才可删
        if (!dl.item.isQueued()) {
          deletable.push(dl);
        }
        break;
      case CLEANUP_EXCEPT_FAVORITE:
        // 非收藏才可删
        if (!dl.item.isFavorite()) {
          deletable.push(dl);
        }
        break;
      default:
        // 按天数：下载超过 N 天
        if (cleanupPolicy > 0) {
          const daysSinceDownload = (now - dl.downloadDate) / 86400000;
          if (daysSinceDownload > cleanupPolicy) {
            deletable.push(dl);
          }
        }
        break;
    }
  }

  // 按下载时间升序（最旧优先删）
  deletable.sort((a: DownloadedItem, b: DownloadedItem) => a.downloadDate - b.downloadDate);

  // 删除到缓存上限以下
  let deletedCount = 0;
  const targetDelete = downloaded.length - cacheSize;

  for (const dl of deletable) {
    if (deletedCount >= targetDelete) break;

    // 删除本地文件
    try {
      if (dl.media.localFileUrl !== null) {
        fileIo.unlinkSync(dl.media.localFileUrl);
      }
    } catch (_e) {
      // 文件可能已不存在
    }

    // 更新数据库
    await deleteFeedMediaOfItem(dl.item.id);
    deletedCount++;
  }

  return deletedCount;
}
