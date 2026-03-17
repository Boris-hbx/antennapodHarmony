import { http } from '@kit.NetworkKit';
import { fileIo, statfs } from '@kit.CoreFileKit';
import { FeedItem, FeedMedia, EventBus, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE, DOWNLOAD_ERROR } from 'common';
import type { DownloadProgressData, DownloadCompleteData, DownloadErrorData } from 'common';
import { setFeedMediaDownloadInfo } from 'datastore';
import { getUserAgent } from '../http/HttpClient';

// ===== 接口定义 =====

interface DataReceiveProgressInfo {
  receiveSize: number;
  totalSize: number;
}

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
  let safe = name.replace(/[<>:"/\\|?*\x00-\x1f]/g, '_');
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
  return '.mp3';
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
const activeHttpRequests: Map<string, http.HttpRequest> = new Map();

// 进度节流：最多 200ms 发一次
let lastProgressEmitTime: number = 0;
const PROGRESS_THROTTLE_MS: number = 200;

/**
 * 手动下载单集 — 流式分块下载
 */
export async function downloadNow(item: FeedItem, feedTitle: string,
  filesDir: string): Promise<void> {
  if (item.media === null || item.media.downloadUrl === null) return;
  const media = item.media;
  const url = media.downloadUrl!;

  if (activeDownloads.has(url)) return;

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
    await executeStreamDownload(task, media);
  } catch (e) {
    task.isActive = false;
    const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
    const errorType = classifyError(msg);
    console.error('DownloadManager: download failed: ' + msg);
    EventBus.emit<DownloadErrorData>(DOWNLOAD_ERROR, {
      url: url,
      episodeTitle: task.itemTitle,
      errorType: errorType,
      message: msg
    });
  } finally {
    activeDownloads.delete(url);
    activeHttpRequests.delete(url);
    emitProgress();
  }
}

/**
 * 错误分类
 */
function classifyError(msg: string): string {
  const lower = msg.toLowerCase();
  if (lower.includes('timeout')) return 'timeout';
  if (lower.includes('network') || lower.includes('connect') || lower.includes('econnreset')) return 'network';
  if (lower.includes('space') || lower.includes('nospc') || lower.includes('disk')) return 'disk_full';
  if (lower.includes('404') || lower.includes('not found')) return 'not_found';
  if (lower.includes('401') || lower.includes('403') || lower.includes('auth')) return 'auth';
  return 'unknown';
}

/**
 * 流式分块下载（核心重写）
 *
 * 使用 http.requestInStream + on('dataReceive') 实现：
 * - 每收到一块数据立即写盘，内存占用恒定（仅一个 chunk 大小）
 * - 实时进度更新（节流 200ms）
 * - 断点续传（Range header + 追加写入）
 * - 支持取消（abort HTTP 请求）
 */
async function executeStreamDownload(task: DownloadTask, media: FeedMedia): Promise<void> {
  // 确保目录存在
  const dirPath = task.localPath.substring(0, task.localPath.lastIndexOf('/'));
  try {
    fileIo.mkdirSync(dirPath, true);
  } catch (_e) { /* 目录可能已存在 */ }

  // 检查已有文件大小（断点续传）
  let existingSize = 0;
  try {
    const stat = fileIo.statSync(task.localPath);
    existingSize = stat.size;
  } catch (_e) {
    existingSize = 0;
  }

  // 磁盘空间预检（需要至少 50MB 可用空间）
  try {
    const freeBytes = statfs.getFreeSizeSync(dirPath);
    if (freeBytes < 50 * 1024 * 1024) {
      throw new Error('磁盘空间不足（可用空间 < 50MB）');
    }
  } catch (e) {
    const msg = (e instanceof Error) ? e.message : '';
    if (msg.includes('磁盘空间不足')) throw new Error(msg);
    // statfs 可能不支持，忽略检查继续下载
  }

  // 构建请求
  const httpRequest = http.createHttp();
  activeHttpRequests.set(task.url, httpRequest);

  const headers: Record<string, string> = {
    'User-Agent': getUserAgent()
  };
  if (existingSize > 0) {
    headers['Range'] = `bytes=${existingSize}-`;
  }

  task.downloadedBytes = existingSize;

  return new Promise<void>((resolve, reject) => {
    // 打开文件准备写入
    let fd: fileIo.File | null = null;
    let totalSize = existingSize; // 初始已知大小
    let headerReceived = false;
    let needRestart = false;

    // 监听 header 获取总大小
    httpRequest.on('headersReceive', (header: Object) => {
      if (headerReceived) return;
      headerReceived = true;
      const respHeaders = header as Record<string, string>;

      // 获取 content-length
      const contentLength = respHeaders['content-length'] ?? respHeaders['Content-Length'] ?? '0';
      const bodySize = parseInt(contentLength, 10);

      // 获取 HTTP 状态码相关信息
      const contentRange = respHeaders['content-range'] ?? respHeaders['Content-Range'] ?? '';

      if (contentRange.length > 0) {
        // 206 Partial Content — 断点续传成功
        // content-range: bytes 12345-67890/67891
        const slashIdx = contentRange.indexOf('/');
        if (slashIdx >= 0) {
          const totalStr = contentRange.substring(slashIdx + 1);
          if (totalStr !== '*') {
            totalSize = parseInt(totalStr, 10);
          }
        }
      } else {
        // 200 OK — 服务器不支持 Range，需要从头下载
        if (existingSize > 0) {
          needRestart = true;
          existingSize = 0;
          task.downloadedBytes = 0;
        }
        totalSize = bodySize;
      }

      task.totalBytes = totalSize;

      // 打开文件
      try {
        if (needRestart) {
          // 从头开始：截断文件
          fd = fileIo.openSync(task.localPath,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        } else if (existingSize > 0) {
          // 追加写入
          fd = fileIo.openSync(task.localPath,
            fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.APPEND);
        } else {
          // 新文件
          fd = fileIo.openSync(task.localPath,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
        }
      } catch (e) {
        reject(e);
      }
    });

    // 监听数据块到达 — 每块立即写盘
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      if (!task.isActive) return; // 已取消

      if (fd !== null) {
        try {
          fileIo.writeSync(fd.fd, data);
        } catch (e) {
          reject(e);
          return;
        }
      }

      task.downloadedBytes += data.byteLength;
      if (task.totalBytes > 0) {
        task.progress = Math.round(task.downloadedBytes / task.totalBytes * 100);
      }

      // 节流发送进度
      const now = Date.now();
      if (now - lastProgressEmitTime >= PROGRESS_THROTTLE_MS) {
        lastProgressEmitTime = now;
        emitProgress();
      }
    });

    // 监听数据接收完成
    httpRequest.on('dataEnd', () => {
      // 关闭文件
      if (fd !== null) {
        try { fileIo.closeSync(fd); } catch (_e) { /* ignore */ }
        fd = null;
      }

      if (!task.isActive) {
        reject(new Error('Download cancelled'));
        return;
      }

      // 下载完成 → 更新数据库
      task.isActive = false;
      task.progress = 100;
      media.localFileUrl = task.localPath;
      media.downloadDate = Date.now();
      media.size = task.downloadedBytes;

      setFeedMediaDownloadInfo(media.id, task.localPath, media.downloadDate, media.size)
        .then(() => {
          emitProgress();
          EventBus.emit<DownloadCompleteData>(DOWNLOAD_COMPLETE, {
            episodeTitle: task.itemTitle,
            feedId: task.feedId
          });
          resolve();
        })
        .catch((e: Error) => { reject(e); });
    });

    // 监听数据接收进度（系统回调）
    httpRequest.on('dataReceiveProgress', (info: DataReceiveProgressInfo) => {
      if (info.totalSize > 0 && task.totalBytes === 0) {
        task.totalBytes = existingSize + info.totalSize;
      }
    });

    // 发起流式请求
    httpRequest.requestInStream(task.url, {
      method: http.RequestMethod.GET,
      header: headers,
      connectTimeout: 15000,
      readTimeout: 30000 // 每块 30s，不是整体超时
    }).then((statusCode: number) => {
      // 状态码检查
      if (statusCode === 416) {
        // Range 不满足 — 删除本地文件重试
        if (fd !== null) {
          try { fileIo.closeSync(fd); } catch (_e) { /* ignore */ }
          fd = null;
        }
        try { fileIo.unlinkSync(task.localPath); } catch (_e) { /* ignore */ }
        reject(new Error('Range not satisfiable (416), please retry'));
        return;
      }
      if (statusCode !== 200 && statusCode !== 206) {
        if (fd !== null) {
          try { fileIo.closeSync(fd); } catch (_e) { /* ignore */ }
          fd = null;
        }
        reject(new Error(`HTTP ${statusCode}`));
      }
      // 200/206 正常，等 dataEnd 回调
    }).catch((e: Error) => {
      if (fd !== null) {
        try { fileIo.closeSync(fd); } catch (_e) { /* ignore */ }
        fd = null;
      }
      reject(e);
    });
  });
}

/**
 * 取消下载 — 中止 HTTP 请求
 */
export function cancelDownload(downloadUrl: string): void {
  const task = activeDownloads.get(downloadUrl);
  if (task !== undefined) {
    task.isActive = false;
  }
  const httpReq = activeHttpRequests.get(downloadUrl);
  if (httpReq !== undefined) {
    try { httpReq.destroy(); } catch (_e) { /* ignore */ }
    activeHttpRequests.delete(downloadUrl);
  }
  activeDownloads.delete(downloadUrl);
  emitProgress();
}

/**
 * 取消所有下载
 */
export function cancelAllDownloads(): void {
  for (const task of activeDownloads.values()) {
    task.isActive = false;
  }
  for (const httpReq of activeHttpRequests.values()) {
    try { httpReq.destroy(); } catch (_e) { /* ignore */ }
  }
  activeDownloads.clear();
  activeHttpRequests.clear();
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
