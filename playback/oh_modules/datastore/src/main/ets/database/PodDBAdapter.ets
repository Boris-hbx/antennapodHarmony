import { relationalStore } from '@kit.ArkData';

const DB_NAME = 'AntennaPod.db';
const DB_VERSION = 1;

// ===== 表名常量 =====
export const TABLE_FEEDS = 'Feeds';
export const TABLE_FEED_ITEMS = 'FeedItems';
export const TABLE_FEED_MEDIA = 'FeedMedia';
export const TABLE_QUEUE = 'Queue';
export const TABLE_FAVORITES = 'Favorites';
export const TABLE_SIMPLE_CHAPTERS = 'SimpleChapters';
export const TABLE_DOWNLOAD_LOG = 'DownloadLog';

// ===== 列名常量 =====

// Feeds 列
export const COL_ID = 'id';
export const COL_TITLE = 'title';
export const COL_CUSTOM_TITLE = 'custom_title';
export const COL_FILE_URL = 'file_url';
export const COL_DOWNLOAD_URL = 'download_url';
export const COL_DOWNLOADED = 'downloaded';
export const COL_LINK = 'link';
export const COL_DESCRIPTION = 'description';
export const COL_PAYMENT_LINK = 'payment_link';
export const COL_LAST_UPDATE = 'last_update';
export const COL_LANGUAGE = 'language';
export const COL_AUTHOR = 'author';
export const COL_IMAGE_URL = 'image_url';
export const COL_TYPE = 'type';
export const COL_FEED_IDENTIFIER = 'feed_identifier';
export const COL_AUTO_DOWNLOAD = 'auto_download';
export const COL_USERNAME = 'username';
export const COL_PASSWORD = 'password';
export const COL_INCLUDE_FILTER = 'include_filter';
export const COL_EXCLUDE_FILTER = 'exclude_filter';
export const COL_MINIMAL_DURATION_FILTER = 'minimal_duration_filter';
export const COL_KEEP_UPDATED = 'keep_updated';
export const COL_IS_PAGED = 'is_paged';
export const COL_NEXT_PAGE_LINK = 'next_page_link';
export const COL_HIDE = 'hide';
export const COL_SORT_ORDER = 'sort_order';
export const COL_LAST_UPDATE_FAILED = 'last_update_failed';
export const COL_AUTO_DELETE_ACTION = 'auto_delete_action';
export const COL_FEED_PLAYBACK_SPEED = 'feed_playback_speed';
export const COL_FEED_SKIP_SILENCE = 'feed_skip_silence';
export const COL_FEED_VOLUME_ADAPTION = 'feed_volume_adaption';
export const COL_TAGS = 'tags';
export const COL_FEED_SKIP_INTRO = 'feed_skip_intro';
export const COL_FEED_SKIP_ENDING = 'feed_skip_ending';
export const COL_EPISODE_NOTIFICATION = 'episode_notification';
export const COL_STATE = 'state';
export const COL_NEW_EPISODES_ACTION = 'new_episodes_action';

// FeedItems 列
export const COL_PUB_DATE = 'pubDate';
export const COL_READ = 'read';
export const COL_FEED = 'feed';
export const COL_HAS_SIMPLE_CHAPTERS = 'has_simple_chapters';
export const COL_ITEM_IDENTIFIER = 'item_identifier';
export const COL_PODCASTINDEX_CHAPTER_URL = 'podcastindex_chapter_url';
export const COL_PODCASTINDEX_TRANSCRIPT_TYPE = 'podcastindex_transcript_type';
export const COL_PODCASTINDEX_TRANSCRIPT_URL = 'podcastindex_transcript_url';
export const COL_SOCIAL_INTERACT_URL = 'social_interact_url';

// FeedMedia 列
export const COL_DURATION = 'duration';
export const COL_POSITION = 'position';
export const COL_FILESIZE = 'filesize';
export const COL_MIME_TYPE = 'mime_type';
export const COL_PLAYBACK_COMPLETION_DATE = 'playback_completion_date';
export const COL_FEEDITEM = 'feeditem';
export const COL_PLAYED_DURATION = 'played_duration';
export const COL_HAS_EMBEDDED_PICTURE = 'has_embedded_picture';
export const COL_LAST_PLAYED_TIME = 'last_played_time';

// Queue / Favorites 列
export const COL_QUEUE_FEEDITEM = 'feeditem';
export const COL_QUEUE_FEED = 'feed';

// SimpleChapters 列
export const COL_START = 'start';

// DownloadLog 列
export const COL_FEEDFILE = 'feedfile';
export const COL_FEEDFILE_TYPE = 'feedfile_type';
export const COL_REASON = 'reason';
export const COL_SUCCESSFUL = 'successful';
export const COL_COMPLETION_DATE = 'completion_date';
export const COL_REASON_DETAILED = 'reason_detailed';

// ===== 建表 SQL =====

const CREATE_TABLE_FEEDS = `CREATE TABLE IF NOT EXISTS ${TABLE_FEEDS} (
  ${COL_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${COL_TITLE} TEXT,
  ${COL_CUSTOM_TITLE} TEXT,
  ${COL_FILE_URL} TEXT,
  ${COL_DOWNLOAD_URL} TEXT,
  ${COL_DOWNLOADED} INTEGER DEFAULT 0,
  ${COL_LINK} TEXT,
  ${COL_DESCRIPTION} TEXT,
  ${COL_PAYMENT_LINK} TEXT,
  ${COL_LAST_UPDATE} TEXT,
  ${COL_LANGUAGE} TEXT,
  ${COL_AUTHOR} TEXT,
  ${COL_IMAGE_URL} TEXT,
  ${COL_TYPE} TEXT,
  ${COL_FEED_IDENTIFIER} TEXT,
  ${COL_AUTO_DOWNLOAD} INTEGER DEFAULT 1,
  ${COL_USERNAME} TEXT,
  ${COL_PASSWORD} TEXT,
  ${COL_INCLUDE_FILTER} TEXT DEFAULT '',
  ${COL_EXCLUDE_FILTER} TEXT DEFAULT '',
  ${COL_MINIMAL_DURATION_FILTER} INTEGER DEFAULT -1,
  ${COL_KEEP_UPDATED} INTEGER DEFAULT 1,
  ${COL_IS_PAGED} INTEGER DEFAULT 0,
  ${COL_NEXT_PAGE_LINK} TEXT,
  ${COL_HIDE} TEXT,
  ${COL_SORT_ORDER} TEXT,
  ${COL_LAST_UPDATE_FAILED} INTEGER DEFAULT 0,
  ${COL_AUTO_DELETE_ACTION} INTEGER DEFAULT 0,
  ${COL_FEED_PLAYBACK_SPEED} REAL DEFAULT -1,
  ${COL_FEED_SKIP_SILENCE} INTEGER DEFAULT 1,
  ${COL_FEED_VOLUME_ADAPTION} INTEGER DEFAULT 0,
  ${COL_TAGS} TEXT,
  ${COL_FEED_SKIP_INTRO} INTEGER DEFAULT 0,
  ${COL_FEED_SKIP_ENDING} INTEGER DEFAULT 0,
  ${COL_EPISODE_NOTIFICATION} INTEGER DEFAULT 0,
  ${COL_STATE} INTEGER DEFAULT 0,
  ${COL_NEW_EPISODES_ACTION} INTEGER DEFAULT 0
)`;

const CREATE_TABLE_FEED_ITEMS = `CREATE TABLE IF NOT EXISTS ${TABLE_FEED_ITEMS} (
  ${COL_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${COL_TITLE} TEXT,
  ${COL_PUB_DATE} INTEGER,
  ${COL_READ} INTEGER DEFAULT 0,
  ${COL_LINK} TEXT,
  ${COL_DESCRIPTION} TEXT,
  ${COL_PAYMENT_LINK} TEXT,
  ${COL_FEED} INTEGER,
  ${COL_HAS_SIMPLE_CHAPTERS} INTEGER DEFAULT 0,
  ${COL_ITEM_IDENTIFIER} TEXT,
  ${COL_IMAGE_URL} TEXT,
  ${COL_AUTO_DOWNLOAD} INTEGER DEFAULT 1,
  ${COL_PODCASTINDEX_CHAPTER_URL} TEXT,
  ${COL_PODCASTINDEX_TRANSCRIPT_TYPE} TEXT,
  ${COL_PODCASTINDEX_TRANSCRIPT_URL} TEXT,
  ${COL_SOCIAL_INTERACT_URL} TEXT
)`;

const CREATE_TABLE_FEED_MEDIA = `CREATE TABLE IF NOT EXISTS ${TABLE_FEED_MEDIA} (
  ${COL_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${COL_DURATION} INTEGER DEFAULT 0,
  ${COL_FILE_URL} TEXT,
  ${COL_DOWNLOAD_URL} TEXT,
  ${COL_DOWNLOADED} INTEGER DEFAULT 0,
  ${COL_POSITION} INTEGER DEFAULT 0,
  ${COL_FILESIZE} INTEGER DEFAULT 0,
  ${COL_MIME_TYPE} TEXT,
  ${COL_PLAYBACK_COMPLETION_DATE} INTEGER DEFAULT 0,
  ${COL_FEEDITEM} INTEGER,
  ${COL_PLAYED_DURATION} INTEGER DEFAULT 0,
  ${COL_HAS_EMBEDDED_PICTURE} INTEGER DEFAULT -1,
  ${COL_LAST_PLAYED_TIME} INTEGER DEFAULT 0
)`;

const CREATE_TABLE_QUEUE = `CREATE TABLE IF NOT EXISTS ${TABLE_QUEUE} (
  ${COL_ID} INTEGER PRIMARY KEY,
  ${COL_QUEUE_FEEDITEM} INTEGER,
  ${COL_QUEUE_FEED} INTEGER
)`;

const CREATE_TABLE_FAVORITES = `CREATE TABLE IF NOT EXISTS ${TABLE_FAVORITES} (
  ${COL_ID} INTEGER PRIMARY KEY,
  ${COL_QUEUE_FEEDITEM} INTEGER,
  ${COL_QUEUE_FEED} INTEGER
)`;

const CREATE_TABLE_SIMPLE_CHAPTERS = `CREATE TABLE IF NOT EXISTS ${TABLE_SIMPLE_CHAPTERS} (
  ${COL_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${COL_TITLE} TEXT,
  ${COL_START} INTEGER,
  ${COL_FEEDITEM} INTEGER,
  ${COL_LINK} TEXT,
  ${COL_IMAGE_URL} TEXT
)`;

const CREATE_TABLE_DOWNLOAD_LOG = `CREATE TABLE IF NOT EXISTS ${TABLE_DOWNLOAD_LOG} (
  ${COL_ID} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${COL_FEEDFILE} INTEGER,
  ${COL_FEEDFILE_TYPE} INTEGER,
  ${COL_REASON} INTEGER,
  ${COL_SUCCESSFUL} INTEGER,
  ${COL_COMPLETION_DATE} INTEGER,
  ${COL_REASON_DETAILED} TEXT,
  ${COL_TITLE} TEXT
)`;

// ===== 索引 =====

const CREATE_INDEXES: string[] = [
  `CREATE INDEX IF NOT EXISTS idx_FeedItems_feed ON ${TABLE_FEED_ITEMS} (${COL_FEED})`,
  `CREATE INDEX IF NOT EXISTS idx_FeedItems_pubDate ON ${TABLE_FEED_ITEMS} (${COL_PUB_DATE})`,
  `CREATE INDEX IF NOT EXISTS idx_FeedItems_read ON ${TABLE_FEED_ITEMS} (${COL_READ})`,
  `CREATE INDEX IF NOT EXISTS idx_Queue_feeditem ON ${TABLE_QUEUE} (${COL_QUEUE_FEEDITEM})`,
  `CREATE INDEX IF NOT EXISTS idx_FeedMedia_feeditem ON ${TABLE_FEED_MEDIA} (${COL_FEEDITEM})`,
  `CREATE INDEX IF NOT EXISTS idx_SimpleChapters_feeditem ON ${TABLE_SIMPLE_CHAPTERS} (${COL_FEEDITEM})`
];

// ===== 数据库适配器 =====

let rdbStore: relationalStore.RdbStore | null = null;

/**
 * 获取数据库实例（单例）
 */
export async function getDatabase(context: Context): Promise<relationalStore.RdbStore> {
  if (rdbStore !== null) {
    return rdbStore;
  }

  const config: relationalStore.StoreConfig = {
    name: DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  };

  rdbStore = await relationalStore.getRdbStore(context, config);
  await createTables(rdbStore);
  return rdbStore;
}

/**
 * 获取已初始化的数据库实例（同步，用于已确认初始化后的调用）
 */
export function getDatabaseSync(): relationalStore.RdbStore {
  if (rdbStore === null) {
    throw new Error('Database not initialized. Call getDatabase(context) first.');
  }
  return rdbStore;
}

async function createTables(db: relationalStore.RdbStore): Promise<void> {
  const statements = [
    CREATE_TABLE_FEEDS,
    CREATE_TABLE_FEED_ITEMS,
    CREATE_TABLE_FEED_MEDIA,
    CREATE_TABLE_QUEUE,
    CREATE_TABLE_FAVORITES,
    CREATE_TABLE_SIMPLE_CHAPTERS,
    CREATE_TABLE_DOWNLOAD_LOG,
    ...CREATE_INDEXES
  ];
  for (const sql of statements) {
    await db.executeSql(sql);
  }
}

/**
 * 关闭数据库（应用退出时调用）
 */
export async function closeDatabase(): Promise<void> {
  if (rdbStore !== null) {
    rdbStore = null;
  }
}
