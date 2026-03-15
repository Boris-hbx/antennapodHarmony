import { relationalStore } from '@kit.ArkData';
import {
  Feed, FeedItem, FeedMedia, FeedPreferences, FeedState, PlayState,
  SortOrder, FeedItemFilter, TAG_QUEUE, TAG_FAVORITE
} from 'common';
import {
  getDatabaseSync, TABLE_FEEDS, TABLE_FEED_ITEMS, TABLE_FEED_MEDIA,
  TABLE_QUEUE, TABLE_FAVORITES, TABLE_SIMPLE_CHAPTERS, TABLE_DOWNLOAD_LOG,
  COL_ID, COL_FEED, COL_FEEDITEM, COL_READ, COL_PUB_DATE, COL_STATE,
  COL_CUSTOM_TITLE, COL_LAST_UPDATE_FAILED, COL_DOWNLOAD_URL, COL_DOWNLOADED,
  COL_TITLE, COL_DURATION, COL_POSITION, COL_PLAYED_DURATION, COL_LAST_PLAYED_TIME,
  COL_PLAYBACK_COMPLETION_DATE, COL_QUEUE_FEEDITEM, COL_QUEUE_FEED,
  COL_HIDE, COL_SORT_ORDER, COL_ITEM_IDENTIFIER, COL_MIME_TYPE, COL_FILESIZE,
  COL_FILE_URL, COL_AUTO_DOWNLOAD, COL_KEEP_UPDATED, COL_AUTO_DELETE_ACTION,
  COL_FEED_PLAYBACK_SPEED, COL_FEED_SKIP_SILENCE, COL_FEED_VOLUME_ADAPTION,
  COL_TAGS, COL_FEED_SKIP_INTRO, COL_FEED_SKIP_ENDING, COL_EPISODE_NOTIFICATION,
  COL_NEW_EPISODES_ACTION, COL_INCLUDE_FILTER, COL_EXCLUDE_FILTER,
  COL_MINIMAL_DURATION_FILTER, COL_USERNAME, COL_PASSWORD
} from './PodDBAdapter';
import {
  feedToValuesBucket, feedItemToValuesBucket, feedMediaToValuesBucket, chapterToValuesBucket
} from './ColumnMapping';

// ===== Interface for queue entries =====

interface QueueEntry {
  id: number;
  feeditem: number;
  feed: number;
}

// ===== 写操作串行队列 =====

type WriteTask = () => Promise<void>;
let writeQueue: WriteTask[] = [];
let isProcessing = false;

async function enqueueWrite(task: WriteTask): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    writeQueue.push(async () => {
      try {
        await task();
        resolve();
      } catch (e) {
        reject(e);
      }
    });
    processQueue();
  });
}

async function processQueue(): Promise<void> {
  if (isProcessing) return;
  isProcessing = true;
  while (writeQueue.length > 0) {
    const task = writeQueue.shift();
    if (task !== undefined) {
      await task();
    }
  }
  isProcessing = false;
}

// ===== 公开 API =====

/**
 * 新增或更新 Feed（含单集合并）
 */
export async function addOrUpdateFeed(feed: Feed): Promise<number> {
  return new Promise<number>((resolve, reject) => {
    enqueueWrite(async () => {
      try {
        const id = await addOrUpdateFeedInternal(feed);
        resolve(id);
      } catch (e) {
        reject(e);
      }
    });
  });
}

async function addOrUpdateFeedInternal(feed: Feed): Promise<number> {
  const db = getDatabaseSync();
  const bucket = feedToValuesBucket(feed);

  if (feed.id > 0) {
    // 更新
    const predicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
    predicates.equalTo(COL_ID, feed.id);
    await db.update(bucket, predicates);

    // 合并 items
    for (const item of feed.items) {
      item.feedId = feed.id;
      await addOrUpdateFeedItem(item);
    }
    return feed.id;
  }

  // 查找已存在的 Feed
  const existingId = await findFeedByIdentifyingValue(db, feed);
  if (existingId > 0) {
    feed.id = existingId;
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, existingId);
    await db.update(bucket, pred);
    for (const item of feed.items) {
      item.feedId = existingId;
      await addOrUpdateFeedItem(item);
    }
    return existingId;
  }

  // 新增
  const rowId = await db.insert(TABLE_FEEDS, bucket);
  feed.id = rowId;
  for (const item of feed.items) {
    item.feedId = rowId;
    await addOrUpdateFeedItem(item);
  }
  return rowId;
}

async function findFeedByIdentifyingValue(db: relationalStore.RdbStore, feed: Feed): Promise<number> {
  const idValue = feed.getIdentifyingValue();
  if (idValue === null) return 0;

  // 按 download_url 查找
  if (feed.downloadUrl !== null) {
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_DOWNLOAD_URL, feed.downloadUrl);
    const rs = await db.query(pred, [COL_ID]);
    if (rs.goToNextRow()) {
      const id = rs.getLong(rs.getColumnIndex(COL_ID));
      rs.close();
      return id;
    }
    rs.close();
  }
  return 0;
}

async function addOrUpdateFeedItem(item: FeedItem): Promise<void> {
  const db = getDatabaseSync();
  const bucket = feedItemToValuesBucket(item);

  if (item.id > 0) {
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    pred.equalTo(COL_ID, item.id);
    await db.update(bucket, pred);
  } else {
    // 重复检测
    const existingId = await findDuplicateItem(db, item);
    if (existingId > 0) {
      item.id = existingId;
      const pred = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
      pred.equalTo(COL_ID, existingId);
      await db.update(bucket, pred);
    } else {
      item.id = await db.insert(TABLE_FEED_ITEMS, bucket);
    }
  }

  // 处理关联 media
  if (item.media !== null) {
    item.media.itemId = item.id;
    await addOrUpdateFeedMedia(db, item.media);
  }
}

/**
 * 重复检测（需求 5）：
 * 1. itemIdentifier 相同
 * 2. media.downloadUrl 相同
 * 3. 标题相似 + 日期相近 + 时长差 < 10 分钟 + MIME 相似
 */
async function findDuplicateItem(db: relationalStore.RdbStore, item: FeedItem): Promise<number> {
  // 规则 1: itemIdentifier
  if (item.itemIdentifier !== null && item.itemIdentifier.length > 0) {
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    pred.equalTo(COL_FEED, item.feedId);
    pred.equalTo(COL_ITEM_IDENTIFIER, item.itemIdentifier);
    const rs = await db.query(pred, [COL_ID]);
    if (rs.goToNextRow()) {
      const id = rs.getLong(rs.getColumnIndex(COL_ID));
      rs.close();
      return id;
    }
    rs.close();
  }

  // 规则 2: media.downloadUrl
  if (item.media !== null && item.media.downloadUrl !== null) {
    const sql = `SELECT fi.${COL_ID} FROM ${TABLE_FEED_ITEMS} fi` +
      ` INNER JOIN ${TABLE_FEED_MEDIA} fm ON fi.${COL_ID} = fm.${COL_FEEDITEM}` +
      ` WHERE fi.${COL_FEED} = ${item.feedId}` +
      ` AND fm.${COL_DOWNLOAD_URL} = '${item.media.downloadUrl.replace(/'/g, "''")}'`;
    const rs = await db.querySql(sql);
    if (rs.goToNextRow()) {
      const id = rs.getLong(0);
      rs.close();
      return id;
    }
    rs.close();
  }

  // 规则 3: 标题相似 + 日期相近 + 时长差 < 10 分钟 + MIME 相似
  if (item.title !== null && item.title.length > 0 && item.pubDate !== null && item.media !== null) {
    const pubMs = item.pubDate.getTime();
    const dayMs = 86400000; // 1 天
    const tenMinMs = 600000; // 10 分钟
    const escapedTitle = item.title.replace(/'/g, "''");
    const sql = `SELECT fi.${COL_ID} FROM ${TABLE_FEED_ITEMS} fi` +
      ` INNER JOIN ${TABLE_FEED_MEDIA} fm ON fi.${COL_ID} = fm.${COL_FEEDITEM}` +
      ` WHERE fi.${COL_FEED} = ${item.feedId}` +
      ` AND fi.${COL_TITLE} = '${escapedTitle}'` +
      ` AND ABS(fi.${COL_PUB_DATE} - ${pubMs}) < ${dayMs}` +
      ` AND ABS(fm.${COL_DURATION} - ${item.media.duration}) < ${tenMinMs}`;
    const rs = await db.querySql(sql);
    if (rs.goToNextRow()) {
      const id = rs.getLong(0);
      rs.close();
      return id;
    }
    rs.close();
  }

  return 0;
}

async function addOrUpdateFeedMedia(db: relationalStore.RdbStore, media: FeedMedia): Promise<void> {
  const bucket = feedMediaToValuesBucket(media);
  if (media.id > 0) {
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    pred.equalTo(COL_ID, media.id);
    await db.update(bucket, pred);
  } else {
    // 检查是否已有该 item 的 media
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    pred.equalTo(COL_FEEDITEM, media.itemId);
    const rs = await db.query(pred, [COL_ID]);
    if (rs.goToNextRow()) {
      media.id = rs.getLong(rs.getColumnIndex(COL_ID));
      rs.close();
      const updatePred = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
      updatePred.equalTo(COL_ID, media.id);
      await db.update(bucket, updatePred);
    } else {
      rs.close();
      media.id = await db.insert(TABLE_FEED_MEDIA, bucket);
    }
  }
}

/**
 * 删除 Feed 及其所有数据
 */
export async function deleteFeed(feedId: number): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    // 删除队列中属于该 feed 的项
    const queuePred = new relationalStore.RdbPredicates(TABLE_QUEUE);
    queuePred.equalTo(COL_QUEUE_FEED, feedId);
    await db.delete(queuePred);

    // 删除收藏中属于该 feed 的项
    const favPred = new relationalStore.RdbPredicates(TABLE_FAVORITES);
    favPred.equalTo(COL_QUEUE_FEED, feedId);
    await db.delete(favPred);

    // 删除章节
    const chapterSql = `DELETE FROM ${TABLE_SIMPLE_CHAPTERS} WHERE ${COL_FEEDITEM} IN` +
      ` (SELECT ${COL_ID} FROM ${TABLE_FEED_ITEMS} WHERE ${COL_FEED} = ${feedId})`;
    await db.executeSql(chapterSql);

    // 删除媒体
    const mediaSql = `DELETE FROM ${TABLE_FEED_MEDIA} WHERE ${COL_FEEDITEM} IN` +
      ` (SELECT ${COL_ID} FROM ${TABLE_FEED_ITEMS} WHERE ${COL_FEED} = ${feedId})`;
    await db.executeSql(mediaSql);

    // 删除 items
    const itemPred = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    itemPred.equalTo(COL_FEED, feedId);
    await db.delete(itemPred);

    // 删除 feed
    const feedPred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    feedPred.equalTo(COL_ID, feedId);
    await db.delete(feedPred);
  });
}

/**
 * 设置自定义标题
 */
export async function setFeedCustomTitle(feedId: number, title: string | null): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, feedId);
    const bucket: relationalStore.ValuesBucket = { custom_title: title };
    await db.update(bucket, pred);
  });
}

/**
 * 设置订阅状态
 */
export async function setFeedState(feedId: number, state: FeedState): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, feedId);
    const bucket: relationalStore.ValuesBucket = { state: state as number };
    await db.update(bucket, pred);
  });
}

/**
 * 更新 Feed 偏好
 */
export async function setFeedPreferences(prefs: FeedPreferences): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, prefs.feedId);
    const bucket: relationalStore.ValuesBucket = {
      auto_download: prefs.autoDownload as number,
      username: prefs.username,
      password: prefs.password,
      keep_updated: prefs.keepUpdated ? 1 : 0,
      auto_delete_action: prefs.autoDeleteAction as number,
      feed_playback_speed: prefs.feedPlaybackSpeed,
      feed_skip_silence: prefs.feedSkipSilence as number,
      feed_volume_adaption: prefs.volumeAdaptionSetting as number,
      feed_skip_intro: prefs.feedSkipIntro,
      feed_skip_ending: prefs.feedSkipEnding,
      episode_notification: prefs.showEpisodeNotification ? 1 : 0,
      new_episodes_action: prefs.newEpisodesAction as number,
      include_filter: prefs.filter.includeFilter,
      exclude_filter: prefs.filter.excludeFilter,
      minimal_duration_filter: prefs.filter.minimalDuration,
      tags: prefs.tags.size > 0 ? Array.from(prefs.tags).join(',') : null
    };
    await db.update(bucket, pred);
  });
}

/**
 * 标记更新失败
 */
export async function setFeedLastUpdateFailed(feedId: number, failed: boolean): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, feedId);
    const bucket: relationalStore.ValuesBucket = { last_update_failed: failed ? 1 : 0 };
    await db.update(bucket, pred);
  });
}

/**
 * 标记播放状态
 */
export async function markItemPlayed(itemId: number, state: PlayState): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    pred.equalTo(COL_ID, itemId);
    const bucket: relationalStore.ValuesBucket = { read: state as number };
    await db.update(bucket, pred);
  });
}

/**
 * 添加到队列
 */
export async function addQueueItem(item: FeedItem, position?: number): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    // 检查是否已在队列中
    const checkPred = new relationalStore.RdbPredicates(TABLE_QUEUE);
    checkPred.equalTo(COL_QUEUE_FEEDITEM, item.id);
    const checkRs = await db.query(checkPred, [COL_ID]);
    if (checkRs.goToNextRow()) {
      checkRs.close();
      return; // 已在队列中
    }
    checkRs.close();

    let insertId: number;
    if (position !== undefined && position >= 0) {
      // 在指定位置插入：需要将后面的项后移
      // Queue 表的 id 用作排序顺序
      insertId = position;
    } else {
      // 末尾插入
      const maxRs = await db.querySql(`SELECT MAX(${COL_ID}) FROM ${TABLE_QUEUE}`);
      let maxId = 0;
      if (maxRs.goToNextRow()) {
        maxId = maxRs.getLong(0);
      }
      maxRs.close();
      insertId = maxId + 1;
    }

    const bucket: relationalStore.ValuesBucket = {
      id: insertId,
      feeditem: item.id,
      feed: item.feedId
    };
    await db.insert(TABLE_QUEUE, bucket);
    item.tags.add(TAG_QUEUE);
  });
}

/**
 * 从队列移除
 */
export async function removeQueueItem(item: FeedItem): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_QUEUE);
    pred.equalTo(COL_QUEUE_FEEDITEM, item.id);
    await db.delete(pred);
    item.tags.delete(TAG_QUEUE);
  });
}

/**
 * 移动队列项
 */
export async function moveQueueItem(fromPos: number, toPos: number): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    // 获取当前队列顺序
    const sql = `SELECT ${COL_ID}, ${COL_QUEUE_FEEDITEM}, ${COL_QUEUE_FEED} FROM ${TABLE_QUEUE} ORDER BY ${COL_ID} ASC`;
    const rs = await db.querySql(sql);
    const entries: Array<QueueEntry> = [];
    while (rs.goToNextRow()) {
      const entry: QueueEntry = {
        id: rs.getLong(0),
        feeditem: rs.getLong(1),
        feed: rs.getLong(2)
      };
      entries.push(entry);
    }
    rs.close();

    if (fromPos < 0 || fromPos >= entries.length || toPos < 0 || toPos >= entries.length) {
      return;
    }

    // 移动元素
    const moved = entries.splice(fromPos, 1)[0];
    entries.splice(toPos, 0, moved);

    // 重写队列
    await db.executeSql(`DELETE FROM ${TABLE_QUEUE}`);
    for (let i = 0; i < entries.length; i++) {
      const bucket: relationalStore.ValuesBucket = {
        id: i + 1,
        feeditem: entries[i].feeditem,
        feed: entries[i].feed
      };
      await db.insert(TABLE_QUEUE, bucket);
    }
  });
}

/**
 * 清空队列
 */
export async function clearQueue(): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    await db.executeSql(`DELETE FROM ${TABLE_QUEUE}`);
  });
}

/**
 * 添加收藏
 */
export async function addFavoriteItem(item: FeedItem): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    // 检查是否已收藏
    const checkPred = new relationalStore.RdbPredicates(TABLE_FAVORITES);
    checkPred.equalTo(COL_QUEUE_FEEDITEM, item.id);
    const checkRs = await db.query(checkPred, [COL_ID]);
    if (checkRs.goToNextRow()) {
      checkRs.close();
      return;
    }
    checkRs.close();

    const maxRs = await db.querySql(`SELECT MAX(${COL_ID}) FROM ${TABLE_FAVORITES}`);
    let maxId = 0;
    if (maxRs.goToNextRow()) maxId = maxRs.getLong(0);
    maxRs.close();

    const bucket: relationalStore.ValuesBucket = {
      id: maxId + 1,
      feeditem: item.id,
      feed: item.feedId
    };
    await db.insert(TABLE_FAVORITES, bucket);
    item.tags.add(TAG_FAVORITE);
  });
}

/**
 * 移除收藏
 */
export async function removeFavoriteItem(item: FeedItem): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FAVORITES);
    pred.equalTo(COL_QUEUE_FEEDITEM, item.id);
    await db.delete(pred);
    item.tags.delete(TAG_FAVORITE);
  });
}

/**
 * 添加播放历史
 */
export async function addItemToPlaybackHistory(item: FeedItem): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    if (item.media === null) return;
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    pred.equalTo(COL_ID, item.media.id);
    const now = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      playback_completion_date: now,
      last_played_time: now
    };
    await db.update(bucket, pred);
    item.media.lastPlayedTimeStatistics = now;
  });
}

/**
 * 更新播放进度
 */
export async function setFeedMediaPlaybackInfo(mediaId: number, position: number,
  duration: number, playedDuration: number): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    pred.equalTo(COL_ID, mediaId);
    const bucket: relationalStore.ValuesBucket = {
      position: position,
      duration: duration,
      played_duration: playedDuration,
      last_played_time: Date.now()
    };
    await db.update(bucket, pred);
  });
}

/**
 * 更新媒体下载信息（localFileUrl + downloadDate + size）
 */
export async function setFeedMediaDownloadInfo(mediaId: number, localFileUrl: string,
  downloadDate: number, size: number): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    pred.equalTo(COL_ID, mediaId);
    const bucket: relationalStore.ValuesBucket = {
      file_url: localFileUrl,
      downloaded: downloadDate,
      filesize: size
    };
    await db.update(bucket, pred);
  });
}

/**
 * 删除本地媒体文件记录
 */
export async function deleteFeedMediaOfItem(itemId: number): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const sql = `UPDATE ${TABLE_FEED_MEDIA} SET ${COL_DOWNLOADED} = 0, ${COL_FILE_URL} = NULL` +
      ` WHERE ${COL_FEEDITEM} = ${itemId}`;
    await db.executeSql(sql);
  });
}

/**
 * 设置单集过滤器
 */
export async function setFeedItemsFilter(feedId: number, filter: FeedItemFilter): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, feedId);
    const bucket: relationalStore.ValuesBucket = {
      hide: filter.toProperties().join(',')
    };
    await db.update(bucket, pred);
  });
}

/**
 * 设置排序方式
 */
export async function setFeedItemSortOrder(feedId: number, sortOrder: SortOrder | null): Promise<void> {
  await enqueueWrite(async () => {
    const db = getDatabaseSync();
    const pred = new relationalStore.RdbPredicates(TABLE_FEEDS);
    pred.equalTo(COL_ID, feedId);
    const bucket: relationalStore.ValuesBucket = {
      sort_order: sortOrder !== null ? sortOrder.toString() : null
    };
    await db.update(bucket, pred);
  });
}
