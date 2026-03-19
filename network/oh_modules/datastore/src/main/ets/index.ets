// 数据库 — 初始化与 Schema
export { getDatabase, getDatabaseSync, closeDatabase } from './database/PodDBAdapter';
export {
  TABLE_FEEDS, TABLE_FEED_ITEMS, TABLE_FEED_MEDIA,
  TABLE_QUEUE, TABLE_FAVORITES, TABLE_SIMPLE_CHAPTERS, TABLE_DOWNLOAD_LOG
} from './database/PodDBAdapter';

// 数据库 — 列映射
export {
  feedFromResultSet, feedToValuesBucket,
  feedItemFromResultSet, feedItemToValuesBucket,
  feedMediaFromResultSet, feedMediaToValuesBucket,
  chapterFromResultSet, chapterToValuesBucket
} from './database/ColumnMapping';

// 数据库 — 读操作
export {
  getFeedList, getFeed, getFeedItemList, getQueue, getQueueIdList,
  getEpisodes, getTotalEpisodeCount, getFeedItem, getNextInQueue,
  getFeedMedia, loadChaptersOfFeedItem, getDownloadLog,
  searchFeedItems, searchFeeds, getNavDrawerData, getStatistics
} from './database/DBReader';
export type { NavDrawerData, StatisticsItem } from './database/DBReader';

// 数据库 — 写操作
export {
  addOrUpdateFeed, deleteFeed, setFeedCustomTitle, setFeedState,
  setFeedPreferences, setFeedLastUpdateFailed,
  markItemPlayed, addQueueItem, removeQueueItem, moveQueueItem, clearQueue,
  addFavoriteItem, removeFavoriteItem, addItemToPlaybackHistory,
  setFeedMediaPlaybackInfo, setFeedMediaDownloadInfo, deleteFeedMediaOfItem,
  setFeedItemsFilter, setFeedItemSortOrder, addDownloadLog
} from './database/DBWriter';

// 偏好设置 — UserPreferences
export {
  init as initUserPreferences,
  EnqueueLocation,
  getPlaybackSpeed, setPlaybackSpeed,
  getPlaybackSpeedArray, setPlaybackSpeedArray,
  getFastForwardSecs, setFastForwardSecs,
  getRewindSecs, setRewindSecs,
  isSkipSilence, setSkipSilence,
  isFollowQueue, setFollowQueue,
  isPauseOnHeadsetDisconnect, setPauseOnHeadsetDisconnect,
  isUnpauseOnHeadsetReconnect, setUnpauseOnHeadsetReconnect,
  isUnpauseOnBluetoothReconnect, setUnpauseOnBluetoothReconnect,
  isStreamOverDownload, setStreamOverDownload,
  getSmartMarkAsPlayedSecs, setSmartMarkAsPlayedSecs,
  isAutoDownloadEnabled, setAutoDownloadEnabled,
  getEpisodeCacheSize, setEpisodeCacheSize,
  getEpisodeCleanup, setEpisodeCleanup,
  isEnqueueDownloaded, setEnqueueDownloaded,
  getEnqueueLocation, setEnqueueLocation,
  getUpdateInterval, setUpdateInterval,
  getMobileUpdateTypes, setMobileUpdateTypes,
  getTheme, setTheme,
  getDefaultPage, setDefaultPage,
  isBottomNavigation, setBottomNavigation,
  isShowTimeLeft, setShowTimeLeft,
  isEpisodeCover, setEpisodeCover,
  isAmoledBlack, setAmoledBlack,
  isTimeRespectSpeed, setTimeRespectSpeed,
  getGlobalSortOrder, setGlobalSortOrder,
  getDownloadButtonAction, setDownloadButtonAction,
  getSleepTimerLastValue, setSleepTimerLastValue,
  getSleepTimerLastValueEpisodes, setSleepTimerLastValueEpisodes,
  getSleepTimerType, setSleepTimerType,
  isSleepTimerShakeToReset, setSleepTimerShakeToReset,
  isSleepTimerAutoEnable, setSleepTimerAutoEnable,
  getSleepTimerAutoEnableFrom, setSleepTimerAutoEnableFrom,
  getSleepTimerAutoEnableTo, setSleepTimerAutoEnableTo,
  getHomeSectionOrder, setHomeSectionOrder,
  isQueueLocked, setQueueLocked,
  isAllowMobileAutoDownload, setAllowMobileAutoDownload,
  isEnableAutodownloadOnBattery, setEnableAutodownloadOnBattery,
  shouldPauseForFocusLoss, setShouldPauseForFocusLoss,
  getNotifyNewEpisodes, setNotifyNewEpisodes,
  getNotifyDownloadComplete, setNotifyDownloadComplete,
  getNotifyDownloadError, setNotifyDownloadError,
  getNotifySyncError, setNotifySyncError
} from './preferences/UserPreferences';

// 偏好设置 — PlaybackPreferences
export {
  init as initPlaybackPreferences,
  PLAYER_STATUS_PLAYING, PLAYER_STATUS_PAUSED, PLAYER_STATUS_OTHER,
  writeMediaPlaying, writeNoMediaPlaying, writePlayerStatus,
  getCurrentlyPlayingFeedMediaId, getLastPlayedFeedId, getCurrentPlayerStatus
} from './preferences/PlaybackPreferences';

// OPML 导入/导出
export { exportOpml, parseOpml } from './importexport/OpmlHelper';
export type { OpmlItem } from './importexport/OpmlHelper';

// 数据库导出/导入
export { exportDatabase, importDatabase } from './importexport/DatabaseExporter';
