import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { FeedItem, FeedMedia, EventBus, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE } from 'common';
import type { DownloadProgressData, DownloadCompleteData } from 'common';
import { setFeedMediaPlaybackInfo, setFeedMediaDownloadInfo } from 'datastore';
import { getUserAgent } from '../http/HttpClient';

// ===== 下载状态 =====

export interface DownloadTask {
  url: string;
  localPath: string;
  progress: number; // 0-100
  totalBytes: number;
  downloadedBytes: number;
  isActive: boolean;
  mediaId: number;
  itemTitle: string;
  feedId: number;
}

// ===== 文件命名 =====

function sanitizeFilename(name: string): string {
  // 去除非法字符
  let safe = name.replace(/[<>:"/\\|?*\x00-\x1f]/g, '_');
  // 限制长度
  if (safe.length > 200) {
    safe = safe.substring(0, 200);
  }
  if (safe.length === 0) {
    safe = 'episode';
  }
  return safe;
}

function getExtFromUrl(url: string): string {
  let path = url;
  const queryIdx = path.indexOf('?');
  if (queryIdx >= 0) path = path.substring(0, queryIdx);
  const dotIdx = path.lastIndexOf('.');
  if (dotIdx >= 0 && dotIdx > path.lastIndexOf('/')) {
    const ext = path.substring(dotIdx);
    if (ext.length <= 5) return ext;
  }
  return '.mp3'; // 默认
}

export function generateLocalPath(filesDir: string, feedTitle: string,
  episodeTitle: string, mediaId: number, downloadUrl: string): string {
  const safeFeed = sanitizeFilename(feedTitle);
  const safeEpisode = sanitizeFilename(episodeTitle);
  const ext = getExtFromUrl(downloadUrl);
  return `${filesDir}/media/${safeFeed}/${safeEpisode}_${mediaId}${ext}`;
}

// ===== 下载管理器 =====

const activeDownloads: Map<string, DownloadTask> = new Map();

/**
 * 手动下载单集
 */
export async function downloadNow(item: FeedItem, feedTitle: string,
  filesDir: string): Promise<void> {
  if (item.media === null || item.media.downloadUrl === null) return;
  const media = item.media;
  const url = media.downloadUrl!;

  if (activeDownloads.has(url)) return; // 已在下载中

  const localPath = generateLocalPath(filesDir, feedTitle,
    item.title ?? 'episode', media.id, url);

  const task: DownloadTask = {
    url: url,
    localPath: localPath,
    progress: 0,
    totalBytes: 0,
    downloadedBytes: 0,
    isActive: true,
    mediaId: media.id,
    itemTitle: item.title ?? '',
    feedId: item.feedId
  };
  activeDownloads.set(url, task);
  emitProgress();

  try {
    await executeDownload(task, media);
  } catch (e) {
    task.isActive = false;
    emitProgress();
  } finally {
    activeDownloads.delete(url);
    emitProgress();
  }
}

/**
 * 执行下载（支持断点续传）
 */
async function executeDownload(task: DownloadTask, media: FeedMedia): Promise<void> {
  // 确保目录存在
  const dirPath = task.localPath.substring(0, task.localPath.lastIndexOf('/'));
  try {
    fileIo.mkdirSync(dirPath, true);
  } catch (_e) {
    // 目录可能已存在
  }

  // 检查已有文件大小（断点续传）
  let existingSize = 0;
  try {
    const stat = fileIo.statSync(task.localPath);
    existingSize = stat.size;
  } catch (_e) {
    existingSize = 0;
  }

  // 构建请求
  const httpRequest = http.createHttp();
  const headers: Record<string, string> = {
    'User-Agent': getUserAgent()
  };
  if (existingSize > 0) {
    headers['Range'] = `bytes=${existingSize}-`;
  }

  try {
    const response = await httpRequest.request(task.url, {
      method: http.RequestMethod.GET,
      header: headers,
      connectTimeout: 15000,
      readTimeout: 300000,
      expectDataType: http.HttpDataType.ARRAY_BUFFER
    });

    const statusCode = response.responseCode;

    // 416: Range 不满足，重新下载
    if (statusCode === 416) {
      existingSize = 0;
      try { fileIo.unlinkSync(task.localPath); } catch (_e) { /* ignore */ }
    }

    // 200: 不支持 Range，重新下载
    if (statusCode === 200 && existingSize > 0) {
      existingSize = 0;
    }

    if (statusCode !== 200 && statusCode !== 206) {
      throw new Error(`HTTP ${statusCode}`);
    }

    // 获取总大小
    const respHeaders = response.header as Record<string, string>;
    const contentLength = respHeaders['content-length'];
    if (contentLength !== undefined) {
      task.totalBytes = existingSize + parseInt(contentLength, 10);
    }
    task.downloadedBytes = existingSize;

    // 写入文件
    const body = response.result as ArrayBuffer;
    const mode = existingSize > 0 ? fileIo.OpenMode.APPEND : fileIo.OpenMode.CREATE;
    const fd = fileIo.openSync(task.localPath, fileIo.OpenMode.READ_WRITE | mode);
    try {
      fileIo.writeSync(fd.fd, body);
      task.downloadedBytes += body.byteLength;
      if (task.totalBytes > 0) {
        task.progress = Math.round(task.downloadedBytes / task.totalBytes * 100);
      } else {
        task.progress = 100;
      }
      emitProgress();
    } finally {
      fileIo.closeSync(fd);
    }

    // 下载完成 → 更新数据库
    task.isActive = false;
    task.progress = 100;
    media.localFileUrl = task.localPath;
    media.downloadDate = Date.now();
    media.size = task.downloadedBytes;
    await setFeedMediaDownloadInfo(media.id, task.localPath, media.downloadDate, media.size);

    emitProgress();

    // 通知下载完成
    EventBus.emit<DownloadCompleteData>(DOWNLOAD_COMPLETE, {
      episodeTitle: task.itemTitle,
      feedId: task.feedId
    });
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 取消下载
 */
export function cancelDownload(downloadUrl: string): void {
  const task = activeDownloads.get(downloadUrl);
  if (task !== undefined) {
    task.isActive = false;
    activeDownloads.delete(downloadUrl);
    emitProgress();
  }
}

/**
 * 取消所有下载
 */
export function cancelAllDownloads(): void {
  for (const task of activeDownloads.values()) {
    task.isActive = false;
  }
  activeDownloads.clear();
  emitProgress();
}

/**
 * 是否正在下载
 */
export function isDownloading(downloadUrl: string): boolean {
  return activeDownloads.has(downloadUrl);
}

/**
 * 获取下载进度
 */
export function getDownloadProgress(downloadUrl: string): number {
  const task = activeDownloads.get(downloadUrl);
  return task !== undefined ? task.progress : 0;
}

/**
 * 活跃下载数
 */
export function getActiveDownloadCount(): number {
  return activeDownloads.size;
}

/**
 * 获取所有活跃下载任务
 */
export function getActiveDownloads(): DownloadTask[] {
  const result: DownloadTask[] = [];
  for (const task of activeDownloads.values()) {
    result.push(task);
  }
  return result;
}

function emitProgress(): void {
  const urls = new Map<string, number>();
  for (const task of activeDownloads.values()) {
    urls.set(task.url, task.progress);
  }
  EventBus.emit<DownloadProgressData>(DOWNLOAD_PROGRESS, { urls: urls });
}
