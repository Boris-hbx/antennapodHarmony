import { util } from '@kit.ArkTS';
import { Feed, FeedState, EventBus, FEED_LIST_UPDATE, FEED_UPDATE_RUNNING } from 'common';
import type { FeedListUpdateData, FeedUpdateRunningData } from 'common';
import { getFeedList, addOrUpdateFeed, setFeedLastUpdateFailed } from 'datastore';
import { httpRequest } from './HttpClient';
import type { HttpResponse, HttpCredentials } from './HttpClient';
import { checkPermanentRedirect } from './RedirectChecker';
import { parseFeed } from '../parser/FeedHandler';
import { isFeedRefreshAllowed } from './NetworkUtils';

// ===== 刷新结果 =====

export interface FeedRefreshResult {
  feedId: number;
  success: boolean;
  updated: boolean;
  error?: string;
}

// ===== 单个 Feed 刷新 =====

/**
 * 刷新单个 Feed
 *
 * 流程：
 * 1. 构建 HTTP 请求（URL + lastModified + credentials）
 * 2. 发送请求
 * 3. 304 Not Modified → 返回（无更新）
 * 4. 200 → 解析 XML
 * 5. 检查永久重定向 → 更新 downloadUrl
 * 6. 调用 addOrUpdateFeed() 合并到数据库
 * 7. 检查 iTunes new-feed-url → 更新 downloadUrl
 */
export async function refreshFeed(feed: Feed): Promise<FeedRefreshResult> {
  if (feed.downloadUrl === null || feed.downloadUrl.length === 0) {
    return { feedId: feed.id, success: false, updated: false, error: 'No download URL' };
  }

  try {
    // 构建请求
    let credentials: HttpCredentials | undefined = undefined;
    if (feed.preferences !== null &&
      feed.preferences.username !== null && feed.preferences.password !== null) {
      const cred: HttpCredentials = { username: feed.preferences.username, password: feed.preferences.password };
      credentials = cred;
    }

    const response: HttpResponse = await httpRequest({
      url: feed.downloadUrl,
      method: 'GET',
      lastModified: feed.lastModified ?? undefined,
      credentials: credentials
    });

    // 304 Not Modified
    if (response.statusCode === 304) {
      return { feedId: feed.id, success: true, updated: false };
    }

    // 非 200 → 失败
    if (response.statusCode !== 200) {
      await setFeedLastUpdateFailed(feed.id, true);
      return {
        feedId: feed.id, success: false, updated: false,
        error: `HTTP ${response.statusCode}`
      };
    }

    // 解析 XML
    const xmlContent = typeof response.body === 'string'
      ? response.body
      : new util.TextDecoder().decode(new Uint8Array(response.body as ArrayBuffer));

    const parseResult = parseFeed(xmlContent, feed);
    const parsedFeed = parseResult.feed;

    // 更新 lastModified
    const etag = response.headers['etag'];
    const lastMod = response.headers['last-modified'];
    if (etag !== undefined && etag.length > 0) {
      parsedFeed.lastModified = etag;
    } else if (lastMod !== undefined && lastMod.length > 0) {
      parsedFeed.lastModified = lastMod;
    }

    // 检查永久重定向
    const permanentRedirect = checkPermanentRedirect(response, feed.downloadUrl);
    if (permanentRedirect !== null) {
      parsedFeed.downloadUrl = permanentRedirect;
    }

    // 检查 iTunes new-feed-url
    if (parseResult.redirectUrl !== null) {
      parsedFeed.downloadUrl = parseResult.redirectUrl;
    }

    // 合并到数据库
    parsedFeed.lastUpdateFailed = false;
    parsedFeed.lastRefreshAttempt = Date.now();
    await addOrUpdateFeed(parsedFeed);

    return { feedId: feed.id, success: true, updated: true };

  } catch (e) {
    // 标记更新失败
    await setFeedLastUpdateFailed(feed.id, true);
    const errorMsg = (e instanceof Error) ? e.message : String(e);
    return { feedId: feed.id, success: false, updated: false, error: errorMsg };
  }
}

// ===== 批量刷新 =====

/**
 * 刷新所有已订阅 Feed
 */
export async function refreshAllFeeds(): Promise<FeedRefreshResult[]> {
  // 检查网络
  const allowed = await isFeedRefreshAllowed();
  if (!allowed) {
    return [];
  }

  // 通知开始刷新
  EventBus.emit<FeedUpdateRunningData>(FEED_UPDATE_RUNNING, { running: true });

  try {
    const feeds = await getFeedList();
    const results: FeedRefreshResult[] = [];

    for (const feed of feeds) {
      // 跳过不参与刷新的 Feed
      if (feed.preferences !== null && !feed.preferences.keepUpdated) {
        continue;
      }

      const result = await refreshFeed(feed);
      results.push(result);
    }

    // 通知 Feed 列表更新
    const updatedIds = results.filter((r) => r.updated).map((r) => r.feedId);
    if (updatedIds.length > 0) {
      EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: updatedIds });
    }

    return results;
  } finally {
    // 通知刷新结束
    EventBus.emit<FeedUpdateRunningData>(FEED_UPDATE_RUNNING, { running: false });
  }
}

/**
 * 刷新指定 Feed 列表
 */
export async function refreshFeeds(feeds: Feed[]): Promise<FeedRefreshResult[]> {
  EventBus.emit<FeedUpdateRunningData>(FEED_UPDATE_RUNNING, { running: true });

  try {
    const results: FeedRefreshResult[] = [];
    for (const feed of feeds) {
      const result = await refreshFeed(feed);
      results.push(result);
    }

    const updatedIds = results.filter((r) => r.updated).map((r) => r.feedId);
    if (updatedIds.length > 0) {
      EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: updatedIds });
    }

    return results;
  } finally {
    EventBus.emit<FeedUpdateRunningData>(FEED_UPDATE_RUNNING, { running: false });
  }
}
