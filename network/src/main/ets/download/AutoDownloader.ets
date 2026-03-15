import { Feed, FeedItem, FeedMedia, PlayState } from 'common';
import {
  getFeedList, getFeedItemList, isAutoDownloadEnabled, getEpisodeCacheSize
} from 'datastore';
import { isAutoDownloadAllowed } from '../http/NetworkUtils';
import { downloadNow } from './DownloadManager';

/**
 * 自动下载（需求 2）
 *
 * 触发条件（全部满足）：
 * 1. 全局自动下载开关开启
 * 2. Feed 的 autoDownload 不是 DISABLED
 * 3. FeedFilter.shouldAutoDownload() 通过
 * 4. 网络允许自动下载
 * 5. 已下载数未超过缓存上限
 */

/**
 * 执行自动下载检查
 * @param filesDir 应用文件目录
 */
export async function runAutoDownload(filesDir: string): Promise<number> {
  // 条件 1: 全局开关
  if (!isAutoDownloadEnabled()) {
    return 0;
  }

  // 条件 4: 网络允许
  const networkAllowed = await isAutoDownloadAllowed();
  if (!networkAllowed) {
    return 0;
  }

  // 获取缓存上限
  const cacheSize = getEpisodeCacheSize();

  // 获取所有 Feed
  const feeds = await getFeedList();
  let downloadedCount = 0;

  // 统计已下载总数
  let totalDownloaded = 0;
  for (const feed of feeds) {
    const items = await getFeedItemList(feed.id, null, null, 0, 0);
    for (const item of items) {
      if (item.media !== null && item.media.isDownloaded()) {
        totalDownloaded++;
      }
    }
  }

  for (const feed of feeds) {
    // 条件 2: Feed 级别 autoDownload 不是 DISABLED (0)
    if (feed.preferences !== null && feed.preferences.autoDownload === 0) {
      continue;
    }

    // 获取未下载的单集，按日期降序（最新优先）
    const items = await getFeedItemList(feed.id, null, null, 0, 0);
    const candidates: FeedItem[] = [];

    for (const item of items) {
      if (item.media === null || item.media.downloadUrl === null) continue;
      if (item.media.isDownloaded()) continue;
      if (item.state === PlayState.PLAYED) continue;

      // 条件 3: FeedFilter 检查
      if (feed.preferences !== null) {
        const filter = feed.preferences.filter;
        const shouldDl = filter.shouldAutoDownload(item.title,
          item.media !== null ? item.media.duration : 0);
        if (!shouldDl) continue;
      }

      candidates.push(item);
    }

    // 按 pubDate 降序
    candidates.sort((a: FeedItem, b: FeedItem) => {
      const aTime = a.pubDate !== null ? a.pubDate.getTime() : 0;
      const bTime = b.pubDate !== null ? b.pubDate.getTime() : 0;
      return bTime - aTime;
    });

    // 条件 5: 缓存上限
    for (const item of candidates) {
      if (totalDownloaded >= cacheSize) break;

      await downloadNow(item, feed.getTitle() ?? 'podcast', filesDir);
      totalDownloaded++;
      downloadedCount++;
    }
  }

  return downloadedCount;
}
