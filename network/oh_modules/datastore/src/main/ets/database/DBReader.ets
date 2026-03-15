import { relationalStore } from '@kit.ArkData';
import {
  Feed, FeedItem, FeedMedia, Chapter, FeedState, PlayState,
  SortOrder, FeedItemFilter, TAG_QUEUE, TAG_FAVORITE
} from 'common';
import {
  getDatabaseSync, TABLE_FEEDS, TABLE_FEED_ITEMS, TABLE_FEED_MEDIA,
  TABLE_QUEUE, TABLE_FAVORITES, TABLE_SIMPLE_CHAPTERS, TABLE_DOWNLOAD_LOG,
  COL_ID, COL_FEED, COL_FEEDITEM, COL_READ, COL_PUB_DATE, COL_STATE,
  COL_DOWNLOAD_URL, COL_DOWNLOADED, COL_TITLE, COL_DURATION,
  COL_PLAYBACK_COMPLETION_DATE, COL_PLAYED_DURATION, COL_LAST_PLAYED_TIME,
  COL_QUEUE_FEEDITEM, COL_QUEUE_FEED,
  COL_AUTHOR, COL_FILESIZE
} from './PodDBAdapter';
import {
  feedFromResultSet, feedItemFromResultSet, feedMediaFromResultSet, chapterFromResultSet
} from './ColumnMapping';

// ===== 辅助：读取 ResultSet 为数组 =====

function collectAll<T>(rs: relationalStore.ResultSet, mapper: (rs: relationalStore.ResultSet) => T): T[] {
  const result: T[] = [];
  while (rs.goToNextRow()) {
    result.push(mapper(rs));
  }
  rs.close();
  return result;
}

function collectFirst<T>(rs: relationalStore.ResultSet, mapper: (rs: relationalStore.ResultSet) => T): T | null {
  if (rs.goToNextRow()) {
    const item = mapper(rs);
    rs.close();
    return item;
  }
  rs.close();
  return null;
}

// ===== 排序与过滤 SQL 辅助 =====

function sortOrderToSql(sortOrder: SortOrder | null): string {
  switch (sortOrder) {
    case SortOrder.DATE_OLD_NEW: return `${COL_PUB_DATE} ASC`;
    case SortOrder.DATE_NEW_OLD: return `${COL_PUB_DATE} DESC`;
    case SortOrder.EPISODE_TITLE_A_Z: return `${COL_TITLE} ASC`;
    case SortOrder.EPISODE_TITLE_Z_A: return `${COL_TITLE} DESC`;
    case SortOrder.DURATION_SHORT_LONG: return `${COL_DURATION} ASC`;
    case SortOrder.DURATION_LONG_SHORT: return `${COL_DURATION} DESC`;
    case SortOrder.SIZE_SMALL_LARGE: return `filesize ASC`;
    case SortOrder.SIZE_LARGE_SMALL: return `filesize DESC`;
    default: return `${COL_PUB_DATE} DESC`;
  }
}

function filterToWhereClause(filter: FeedItemFilter | null): string {
  if (filter === null) return '';
  const conditions: string[] = [];
  if (filter.showPlayed) conditions.push(`${COL_READ} = ${PlayState.PLAYED}`);
  if (filter.showUnplayed) conditions.push(`${COL_READ} = ${PlayState.UNPLAYED}`);
  if (filter.showNew) conditions.push(`${COL_READ} = ${PlayState.NEW}`);
  if (filter.showPaused) {
    conditions.push(`${TABLE_FEED_MEDIA}.position > 0`);
  }
  if (filter.showNotPaused) {
    conditions.push(`(${TABLE_FEED_MEDIA}.position IS NULL OR ${TABLE_FEED_MEDIA}.position = 0)`);
  }
  if (filter.showDownloaded) conditions.push(`${TABLE_FEED_MEDIA}.${COL_DOWNLOADED} > 0`);
  if (filter.showNotDownloaded) {
    conditions.push(`(${TABLE_FEED_MEDIA}.${COL_DOWNLOADED} IS NULL OR ${TABLE_FEED_MEDIA}.${COL_DOWNLOADED} = 0)`);
  }
  if (filter.showHasMedia) conditions.push(`${TABLE_FEED_MEDIA}.${COL_ID} IS NOT NULL`);
  if (filter.showNoMedia) conditions.push(`${TABLE_FEED_MEDIA}.${COL_ID} IS NULL`);
  if (filter.showIsFavorite) {
    conditions.push(`${TABLE_FAVORITES}.${COL_ID} IS NOT NULL`);
  }
  if (filter.showNotFavorite) {
    conditions.push(`${TABLE_FAVORITES}.${COL_ID} IS NULL`);
  }
  if (filter.showQueued) {
    conditions.push(`${TABLE_QUEUE}.${COL_ID} IS NOT NULL`);
  }
  if (filter.showNotQueued) {
    conditions.push(`${TABLE_QUEUE}.${COL_ID} IS NULL`);
  }
  if (conditions.length === 0) return '';
  return ' AND ' + conditions.join(' AND ');
}

// ===== 内部辅助：为 FeedItem 加载关联的 media 和 tags =====

async function loadItemMedia(db: relationalStore.RdbStore, items: FeedItem[]): Promise<void> {
  if (items.length === 0) return;
  const itemIds = items.map((i) => i.id);
  const predicates = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
  predicates.in(COL_FEEDITEM, itemIds);
  const rs = await db.query(predicates);
  const mediaMap = new Map<number, FeedMedia>();
  while (rs.goToNextRow()) {
    const media = feedMediaFromResultSet(rs);
    mediaMap.set(media.itemId, media);
  }
  rs.close();
  for (const item of items) {
    const media = mediaMap.get(item.id);
    if (media !== undefined) {
      item.media = media;
    }
  }
}

async function loadItemTags(db: relationalStore.RdbStore, items: FeedItem[]): Promise<void> {
  if (items.length === 0) return;
  const itemIds = items.map((i) => i.id);

  // Queue tags
  const queuePred = new relationalStore.RdbPredicates(TABLE_QUEUE);
  queuePred.in(COL_QUEUE_FEEDITEM, itemIds);
  const queueRs = await db.query(queuePred);
  const queuedIds = new Set<number>();
  while (queueRs.goToNextRow()) {
    queuedIds.add(queueRs.getLong(queueRs.getColumnIndex(COL_QUEUE_FEEDITEM)));
  }
  queueRs.close();

  // Favorite tags
  const favPred = new relationalStore.RdbPredicates(TABLE_FAVORITES);
  favPred.in(COL_QUEUE_FEEDITEM, itemIds);
  const favRs = await db.query(favPred);
  const favIds = new Set<number>();
  while (favRs.goToNextRow()) {
    favIds.add(favRs.getLong(favRs.getColumnIndex(COL_QUEUE_FEEDITEM)));
  }
  favRs.close();

  for (const item of items) {
    if (queuedIds.has(item.id)) item.tags.add(TAG_QUEUE);
    if (favIds.has(item.id)) item.tags.add(TAG_FAVORITE);
  }
}

async function loadItemsFull(db: relationalStore.RdbStore, items: FeedItem[]): Promise<void> {
  await loadItemMedia(db, items);
  await loadItemTags(db, items);
}

// ===== 公开 API =====

/**
 * 获取全部已订阅 Feed（不含 items）
 */
export async function getFeedList(): Promise<Feed[]> {
  const db = getDatabaseSync();
  const predicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
  predicates.equalTo(COL_STATE, FeedState.SUBSCRIBED);
  const rs = await db.query(predicates);
  return collectAll(rs, feedFromResultSet);
}

/**
 * 获取单个 Feed 含 items
 */
export async function getFeed(feedId: number, filter?: FeedItemFilter | null,
  sortOrder?: SortOrder | null, offset?: number, limit?: number): Promise<Feed | null> {
  const db = getDatabaseSync();
  const feedPred = new relationalStore.RdbPredicates(TABLE_FEEDS);
  feedPred.equalTo(COL_ID, feedId);
  const feedRs = await db.query(feedPred);
  const feed = collectFirst(feedRs, feedFromResultSet);
  if (feed === null) return null;

  feed.items = await getFeedItemList(feedId, filter ?? null, sortOrder ?? null,
    offset ?? 0, limit ?? 0);
  return feed;
}

/**
 * 某 Feed 的单集列表
 */
export async function getFeedItemList(feedId: number, filter: FeedItemFilter | null,
  sortOrder: SortOrder | null, offset: number, limit: number): Promise<FeedItem[]> {
  const db = getDatabaseSync();
  const orderBy = sortOrderToSql(sortOrder);
  const filterClause = filterToWhereClause(filter);
  const limitClause = limit > 0 ? ` LIMIT ${limit} OFFSET ${offset}` : '';

  let sql = `SELECT ${TABLE_FEED_ITEMS}.* FROM ${TABLE_FEED_ITEMS}`;
  // joins for filter
  if (filter !== null && (filter.showPaused || filter.showNotPaused ||
    filter.showDownloaded || filter.showNotDownloaded ||
    filter.showHasMedia || filter.showNoMedia)) {
    sql += ` LEFT JOIN ${TABLE_FEED_MEDIA} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_FEED_MEDIA}.${COL_FEEDITEM}`;
  }
  if (filter !== null && (filter.showIsFavorite || filter.showNotFavorite)) {
    sql += ` LEFT JOIN ${TABLE_FAVORITES} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_FAVORITES}.${COL_QUEUE_FEEDITEM}`;
  }
  if (filter !== null && (filter.showQueued || filter.showNotQueued)) {
    sql += ` LEFT JOIN ${TABLE_QUEUE} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_QUEUE}.${COL_QUEUE_FEEDITEM}`;
  }
  sql += ` WHERE ${TABLE_FEED_ITEMS}.${COL_FEED} = ${feedId}${filterClause}`;
  sql += ` ORDER BY ${orderBy}${limitClause}`;

  const rs = await db.querySql(sql);
  const items = collectAll(rs, feedItemFromResultSet);
  await loadItemsFull(db, items);
  return items;
}

/**
 * 获取播放队列（含完整数据）
 */
export async function getQueue(): Promise<FeedItem[]> {
  const db = getDatabaseSync();
  const sql = `SELECT ${TABLE_FEED_ITEMS}.* FROM ${TABLE_QUEUE}` +
    ` INNER JOIN ${TABLE_FEED_ITEMS} ON ${TABLE_QUEUE}.${COL_QUEUE_FEEDITEM} = ${TABLE_FEED_ITEMS}.${COL_ID}` +
    ` ORDER BY ${TABLE_QUEUE}.${COL_ID} ASC`;
  const rs = await db.querySql(sql);
  const items = collectAll(rs, feedItemFromResultSet);
  for (const item of items) {
    item.tags.add(TAG_QUEUE);
  }
  await loadItemMedia(db, items);
  await loadItemTags(db, items);
  return items;
}

/**
 * 队列 ID 列表（轻量）
 */
export async function getQueueIdList(): Promise<number[]> {
  const db = getDatabaseSync();
  const sql = `SELECT ${COL_QUEUE_FEEDITEM} FROM ${TABLE_QUEUE} ORDER BY ${COL_ID} ASC`;
  const rs = await db.querySql(sql);
  const ids: number[] = [];
  while (rs.goToNextRow()) {
    ids.push(rs.getLong(0));
  }
  rs.close();
  return ids;
}

/**
 * 跨 Feed 单集列表
 */
export async function getEpisodes(offset: number, limit: number,
  filter: FeedItemFilter | null, sortOrder: SortOrder | null): Promise<FeedItem[]> {
  const db = getDatabaseSync();
  const orderBy = sortOrderToSql(sortOrder);
  const filterClause = filterToWhereClause(filter);
  const subscribeClause = (filter !== null && filter.includeNotSubscribed)
    ? '' : ` AND ${TABLE_FEEDS}.${COL_STATE} = ${FeedState.SUBSCRIBED}`;

  let sql = `SELECT ${TABLE_FEED_ITEMS}.* FROM ${TABLE_FEED_ITEMS}`;
  sql += ` INNER JOIN ${TABLE_FEEDS} ON ${TABLE_FEED_ITEMS}.${COL_FEED} = ${TABLE_FEEDS}.${COL_ID}`;
  if (filter !== null && (filter.showPaused || filter.showNotPaused ||
    filter.showDownloaded || filter.showNotDownloaded ||
    filter.showHasMedia || filter.showNoMedia)) {
    sql += ` LEFT JOIN ${TABLE_FEED_MEDIA} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_FEED_MEDIA}.${COL_FEEDITEM}`;
  }
  if (filter !== null && (filter.showIsFavorite || filter.showNotFavorite)) {
    sql += ` LEFT JOIN ${TABLE_FAVORITES} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_FAVORITES}.${COL_QUEUE_FEEDITEM}`;
  }
  if (filter !== null && (filter.showQueued || filter.showNotQueued)) {
    sql += ` LEFT JOIN ${TABLE_QUEUE} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_QUEUE}.${COL_QUEUE_FEEDITEM}`;
  }
  sql += ` WHERE 1=1${subscribeClause}${filterClause}`;
  sql += ` ORDER BY ${orderBy}`;
  if (limit > 0) {
    sql += ` LIMIT ${limit} OFFSET ${offset}`;
  }

  const rs = await db.querySql(sql);
  const items = collectAll(rs, feedItemFromResultSet);
  await loadItemsFull(db, items);
  return items;
}

/**
 * 单集总数
 */
export async function getTotalEpisodeCount(filter: FeedItemFilter | null): Promise<number> {
  const db = getDatabaseSync();
  const filterClause = filterToWhereClause(filter);
  let sql = `SELECT COUNT(*) FROM ${TABLE_FEED_ITEMS}`;
  sql += ` INNER JOIN ${TABLE_FEEDS} ON ${TABLE_FEED_ITEMS}.${COL_FEED} = ${TABLE_FEEDS}.${COL_ID}`;
  if (filter !== null && (filter.showPaused || filter.showNotPaused ||
    filter.showDownloaded || filter.showNotDownloaded ||
    filter.showHasMedia || filter.showNoMedia)) {
    sql += ` LEFT JOIN ${TABLE_FEED_MEDIA} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_FEED_MEDIA}.${COL_FEEDITEM}`;
  }
  if (filter !== null && (filter.showIsFavorite || filter.showNotFavorite)) {
    sql += ` LEFT JOIN ${TABLE_FAVORITES} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_FAVORITES}.${COL_QUEUE_FEEDITEM}`;
  }
  if (filter !== null && (filter.showQueued || filter.showNotQueued)) {
    sql += ` LEFT JOIN ${TABLE_QUEUE} ON ${TABLE_FEED_ITEMS}.${COL_ID} = ${TABLE_QUEUE}.${COL_QUEUE_FEEDITEM}`;
  }
  sql += ` WHERE ${TABLE_FEEDS}.${COL_STATE} = ${FeedState.SUBSCRIBED}${filterClause}`;
  const rs = await db.querySql(sql);
  let count = 0;
  if (rs.goToNextRow()) {
    count = rs.getLong(0);
  }
  rs.close();
  return count;
}

/**
 * 获取单个单集
 */
export async function getFeedItem(itemId: number): Promise<FeedItem | null> {
  const db = getDatabaseSync();
  const predicates = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
  predicates.equalTo(COL_ID, itemId);
  const rs = await db.query(predicates);
  const item = collectFirst(rs, feedItemFromResultSet);
  if (item !== null) {
    await loadItemsFull(db, [item]);
  }
  return item;
}

/**
 * 队列中下一个
 */
export async function getNextInQueue(currentItem: FeedItem): Promise<FeedItem | null> {
  const queueIds = await getQueueIdList();
  const idx = queueIds.indexOf(currentItem.id);
  if (idx < 0 || idx >= queueIds.length - 1) {
    return null;
  }
  return getFeedItem(queueIds[idx + 1]);
}

/**
 * 获取媒体对象
 */
export async function getFeedMedia(mediaId: number): Promise<FeedMedia | null> {
  const db = getDatabaseSync();
  const predicates = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
  predicates.equalTo(COL_ID, mediaId);
  const rs = await db.query(predicates);
  return collectFirst(rs, feedMediaFromResultSet);
}

/**
 * 懒加载章节
 */
export async function loadChaptersOfFeedItem(itemId: number): Promise<Chapter[]> {
  const db = getDatabaseSync();
  const predicates = new relationalStore.RdbPredicates(TABLE_SIMPLE_CHAPTERS);
  predicates.equalTo(COL_FEEDITEM, itemId);
  predicates.orderByAsc('start');
  const rs = await db.query(predicates);
  return collectAll(rs, chapterFromResultSet);
}

/**
 * 下载日志（最多 200 条）
 */
export async function getDownloadLog(): Promise<relationalStore.ResultSet> {
  const db = getDatabaseSync();
  const sql = `SELECT * FROM ${TABLE_DOWNLOAD_LOG} ORDER BY ${COL_ID} DESC LIMIT 200`;
  return db.querySql(sql);
}

/**
 * 搜索单集
 */
export async function searchFeedItems(feedId: number | null, query: string): Promise<FeedItem[]> {
  const db = getDatabaseSync();
  const escapedQuery = query.replace(/'/g, "''");
  let sql = `SELECT ${TABLE_FEED_ITEMS}.* FROM ${TABLE_FEED_ITEMS}`;
  sql += ` INNER JOIN ${TABLE_FEEDS} ON ${TABLE_FEED_ITEMS}.${COL_FEED} = ${TABLE_FEEDS}.${COL_ID}`;
  sql += ` WHERE ${TABLE_FEEDS}.${COL_STATE} = ${FeedState.SUBSCRIBED}`;
  if (feedId !== null) {
    sql += ` AND ${TABLE_FEED_ITEMS}.${COL_FEED} = ${feedId}`;
  }
  sql += ` AND (${TABLE_FEED_ITEMS}.${COL_TITLE} LIKE '%${escapedQuery}%'` +
    ` OR ${TABLE_FEED_ITEMS}.description LIKE '%${escapedQuery}%')`;
  sql += ` ORDER BY ${COL_PUB_DATE} DESC`;

  const rs = await db.querySql(sql);
  const items = collectAll(rs, feedItemFromResultSet);
  await loadItemsFull(db, items);
  return items;
}

/**
 * 搜索 Feed
 */
export async function searchFeeds(query: string): Promise<Feed[]> {
  const db = getDatabaseSync();
  const escapedQuery = query.replace(/'/g, "''");
  const sql = `SELECT * FROM ${TABLE_FEEDS}` +
    ` WHERE ${COL_STATE} = ${FeedState.SUBSCRIBED}` +
    ` AND (${COL_TITLE} LIKE '%${escapedQuery}%' OR ${COL_DOWNLOAD_URL} LIKE '%${escapedQuery}%'` +
    ` OR ${COL_AUTHOR} LIKE '%${escapedQuery}%')`;
  const rs = await db.querySql(sql);
  return collectAll(rs, feedFromResultSet);
}

/**
 * 导航数据
 */
export interface NavDrawerData {
  feeds: Feed[];
  queueSize: number;
  newCount: number;
  downloadedCount: number;
}

export async function getNavDrawerData(): Promise<NavDrawerData> {
  const db = getDatabaseSync();

  const feeds = await getFeedList();

  // Queue size
  const queueRs = await db.querySql(`SELECT COUNT(*) FROM ${TABLE_QUEUE}`);
  let queueSize = 0;
  if (queueRs.goToNextRow()) queueSize = queueRs.getLong(0);
  queueRs.close();

  // New count
  const newRs = await db.querySql(
    `SELECT COUNT(*) FROM ${TABLE_FEED_ITEMS}` +
    ` INNER JOIN ${TABLE_FEEDS} ON ${TABLE_FEED_ITEMS}.${COL_FEED} = ${TABLE_FEEDS}.${COL_ID}` +
    ` WHERE ${TABLE_FEEDS}.${COL_STATE} = ${FeedState.SUBSCRIBED}` +
    ` AND ${TABLE_FEED_ITEMS}.${COL_READ} = ${PlayState.NEW}`
  );
  let newCount = 0;
  if (newRs.goToNextRow()) newCount = newRs.getLong(0);
  newRs.close();

  // Downloaded count
  const dlRs = await db.querySql(
    `SELECT COUNT(*) FROM ${TABLE_FEED_MEDIA}` +
    ` INNER JOIN ${TABLE_FEED_ITEMS} ON ${TABLE_FEED_MEDIA}.${COL_FEEDITEM} = ${TABLE_FEED_ITEMS}.${COL_ID}` +
    ` INNER JOIN ${TABLE_FEEDS} ON ${TABLE_FEED_ITEMS}.${COL_FEED} = ${TABLE_FEEDS}.${COL_ID}` +
    ` WHERE ${TABLE_FEEDS}.${COL_STATE} = ${FeedState.SUBSCRIBED}` +
    ` AND ${TABLE_FEED_MEDIA}.${COL_DOWNLOADED} > 0`
  );
  let downloadedCount = 0;
  if (dlRs.goToNextRow()) downloadedCount = dlRs.getLong(0);
  dlRs.close();

  return { feeds, queueSize, newCount, downloadedCount };
}

/**
 * 播放统计
 */
export interface StatisticsItem {
  feed: Feed;
  totalTime: number;
  episodesStarted: number;
  totalDownloadSize: number;
}

export async function getStatistics(includeMarkedAsPlayed: boolean,
  startMs: number, endMs: number): Promise<StatisticsItem[]> {
  const db = getDatabaseSync();
  const feeds = await getFeedList();
  const result: StatisticsItem[] = [];

  for (const feed of feeds) {
    let sql: string;
    if (includeMarkedAsPlayed) {
      sql = `SELECT SUM(CASE WHEN ${COL_LAST_PLAYED_TIME} >= ${startMs} AND ${COL_LAST_PLAYED_TIME} <= ${endMs}` +
        ` THEN ${COL_PLAYED_DURATION} ELSE 0 END) as total_time,` +
        ` COUNT(CASE WHEN ${COL_PLAYED_DURATION} > 0 OR ${COL_PLAYBACK_COMPLETION_DATE} > 0 THEN 1 END) as started,` +
        ` SUM(CASE WHEN ${COL_DOWNLOADED} > 0 THEN ${COL_FILESIZE} ELSE 0 END) as dl_size` +
        ` FROM ${TABLE_FEED_MEDIA}` +
        ` INNER JOIN ${TABLE_FEED_ITEMS} ON ${TABLE_FEED_MEDIA}.${COL_FEEDITEM} = ${TABLE_FEED_ITEMS}.${COL_ID}` +
        ` WHERE ${TABLE_FEED_ITEMS}.${COL_FEED} = ${feed.id}`;
    } else {
      sql = `SELECT SUM(CASE WHEN ${COL_LAST_PLAYED_TIME} >= ${startMs} AND ${COL_LAST_PLAYED_TIME} <= ${endMs}` +
        ` THEN ${COL_PLAYED_DURATION} ELSE 0 END) as total_time,` +
        ` COUNT(CASE WHEN ${COL_PLAYED_DURATION} > 0 THEN 1 END) as started,` +
        ` SUM(CASE WHEN ${COL_DOWNLOADED} > 0 THEN ${COL_FILESIZE} ELSE 0 END) as dl_size` +
        ` FROM ${TABLE_FEED_MEDIA}` +
        ` INNER JOIN ${TABLE_FEED_ITEMS} ON ${TABLE_FEED_MEDIA}.${COL_FEEDITEM} = ${TABLE_FEED_ITEMS}.${COL_ID}` +
        ` WHERE ${TABLE_FEED_ITEMS}.${COL_FEED} = ${feed.id}`;
    }
    const rs = await db.querySql(sql);
    if (rs.goToNextRow()) {
      result.push({
        feed: feed,
        totalTime: rs.getLong(0),
        episodesStarted: rs.getLong(1),
        totalDownloadSize: rs.getLong(2)
      });
    }
    rs.close();
  }
  return result;
}
