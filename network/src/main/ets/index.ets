// HTTP 客户端
export { httpRequest, setUserAgent, getUserAgent } from './http/HttpClient';
export type { HttpClientOptions, HttpResponse } from './http/HttpClient';

// 网络状态
export {
  isNetworkAvailable, isNetworkRestricted,
  isAutoDownloadAllowed, isEpisodeDownloadAllowed,
  isImageAllowed, isStreamingAllowed, isFeedRefreshAllowed
} from './http/NetworkUtils';

// URL 处理
export { prepareUrl, urlEquals } from './http/UrlUtils';

// 重定向检测
export { checkPermanentRedirect } from './http/RedirectChecker';

// Feed 解析器
export { parseFeed } from './parser/FeedHandler';
export type { FeedParseResult } from './parser/FeedHandler';

// 解析工具
export { parseDate } from './parser/DateUtils';
export { parseDuration } from './parser/DurationParser';
export { isMediaFile, isImageFile, getMimeType } from './parser/MimeTypeUtils';
export { htmlToPlainText, decodeHtmlEntities, stripHtmlTags } from './parser/HtmlUtils';

// Feed 刷新
export { refreshFeed, refreshAllFeeds, refreshFeeds } from './http/FeedRefresher';
export type { FeedRefreshResult } from './http/FeedRefresher';

// 下载管理
export {
  downloadNow, cancelDownload, cancelAllDownloads,
  isDownloading, getDownloadProgress, getActiveDownloadCount,
  getActiveDownloads, generateLocalPath
} from './download/DownloadManager';
export type { DownloadTask } from './download/DownloadManager';

// 自动下载
export { runAutoDownload } from './download/AutoDownloader';

// 存储清理
export { runStorageCleanup } from './download/StorageCleaner';

// 后台下载
export { startBackgroundDownload, stopBackgroundDownloadIfIdle } from './download/BackgroundDownload';

// 播客搜索
export { searchPodcasts } from './discovery/ItunesSearcher';
export type { ItunesResult } from './discovery/ItunesSearcher';
