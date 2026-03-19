import { http } from '@kit.NetworkKit';
import { fileIo, statfs } from '@kit.CoreFileKit';
import { FeedItem, FeedMedia, EventBus, DOWNLOAD_PROGRESS, DOWNLOAD_COMPLETE, DOWNLOAD_ERROR } from 'common';
import type { DownloadProgressData, DownloadCompleteData, DownloadErrorData } from 'common';
import { setFeedMediaDownloadInfo, addDownloadLog } from 'datastore';
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

// 停滞检测：60 秒无数据则判定为停滞
const STALL_TIMEOUT_MS: number = 60000;
// 整体超时：15 分钟
const OVERALL_TIMEOUT_MS: number = 15 * 60 * 1000;

// 下载开始/结束的回调，由 EntryAbility 注册
let onDownloadStartCallback: (() => void) | null = null;
let onDownloadEndCallback: (() => void) | null = null;

export function setDownloadLifecycleCallbacks(
  onStart: () => void, onEnd: () => void): void {
  onDownloadStartCallback = onStart;
  onDownloadEndCallback = onEnd;
}

// ===== 下载上下文：管理单次下载的定时器和 settle 状态 =====

class DownloadContext {
  settled: boolean = false;
  fd: fileIo.File | null = null;
  stallTimerId: number = -1;
  overallTimerId: number = -1;
  private resolveFunc: (() => void) | null = null;
  private rejectFunc: ((e: Error) => void) | null = null;
  private taskRef: DownloadTask;

  constructor(task: DownloadTask) {
    this.taskRef = task;
  }

  bind(resolveFn: () => void, rejectFn: (e: Error) => void): void {
    this.resolveFunc = resolveFn;
    this.rejectFunc = rejectFn;
  }

  safeReject(e: Error): void {
    if (this.settled) return;
    this.settled = true;
    this.clearTimers();
    this.closeFile();
    if (this.rejectFunc !== null) {
      this.rejectFunc(e);
    }
  }

  safeResolve(): void {
    if (this.settled) return;
    this.settled = true;
    this.clearTimers();
    if (this.resolveFunc !== null) {
      this.resolveFunc();
    }
  }

  resetStallTimer(): void {
    if (this.stallTimerId !== -1) {
      clearTimeout(this.stallTimerId);
    }
    const ctx = this;
    const task = this.taskRef;
    this.stallTimerId = setTimeout((): void => {
      if (ctx.settled || !task.isActive) return;
      console.error(`DownloadManager: stall detected for ${task.itemTitle}, no data for ${STALL_TIMEOUT_MS / 1000}s`);
      task.isActive = false;
      const httpReq = activeHttpRequests.get(task.url);
      if (httpReq !== undefined) {
        try { httpReq.destroy(); } catch (_e) { /* ignore */ }
      }
      ctx.safeReject(new Error(`Download stalled: no data received for ${STALL_TIMEOUT_MS / 1000} seconds`));
    }, STALL_TIMEOUT_MS);
  }

  startOverallTimer(): void {
    const ctx = this;
    const task = this.taskRef;
    this.overallTimerId = setTimeout((): void => {
      if (ctx.settled || !task.isActive) return;
      console.error(`DownloadManager: overall timeout for ${task.itemTitle} after ${OVERALL_TIMEOUT_MS / 60000} min`);
      task.isActive = false;
      const httpReq = activeHttpRequests.get(task.url);
      if (httpReq !== undefined) {
        try { httpReq.destroy(); } catch (_e) { /* ignore */ }
      }
      ctx.safeReject(new Error(`Download timed out after ${OVERALL_TIMEOUT_MS / 60000} minutes`));
    }, OVERALL_TIMEOUT_MS);
  }

  closeFile(): void {
    if (this.fd !== null) {
      try { fileIo.closeSync(this.fd); } catch (_e) { /* ignore */ }
      this.fd = null;
    }
  }

  private clearTimers(): void {
    if (this.stallTimerId !== -1) {
      clearTimeout(this.stallTimerId);
      this.stallTimerId = -1;
    }
    if (this.overallTimerId !== -1) {
      clearTimeout(this.overallTimerId);
      this.overallTimerId = -1;
    }
  }
}

/**
 * 手动下载单集 — 流式分块下载
 */
export async function downloadNow(item: FeedItem, feedTitle: string,
  filesDir: string): Promise<void> {
  if (item.media === null || item.media.downloadUrl === null) {
    console.warn('DownloadManager: skip — media or downloadUrl is null');
    return;
  }
  const media = item.media;
  const url = media.downloadUrl!;

  if (activeDownloads.has(url)) {
    console.info('DownloadManager: skip — already downloading: ' + url);
    return;
  }

  console.info(`DownloadManager: starting download "${item.title ?? ''}" url=${url.substring(0, 80)}`);
  console.info(`DownloadManager: filesDir="${filesDir}", feedTitle="${feedTitle}"`);

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

  // 通知生命周期：有下载开始
  if (onDownloadStartCallback !== null) {
    onDownloadStartCallback();
  }

  try {
    await executeStreamDownload(task, media);
  } catch (e) {
    const msg = extractErrorMessage(e as Object);
    console.error('DownloadManager: download failed: ' + msg);

    // 416 自动重试：删除残留文件后重新下载（不带 Range）
    if (msg.includes('416')) {
      console.info('DownloadManager: retrying without Range header...');
      try { fileIo.unlinkSync(task.localPath); } catch (_e) { /* ignore */ }
      task.isActive = true;
      task.downloadedBytes = 0;
      task.progress = 0;
      try {
        await executeStreamDownload(task, media);
      } catch (e2) {
        task.isActive = false;
        const msg2 = extractErrorMessage(e2 as Object);
        console.error('DownloadManager: retry also failed: ' + msg2);
        const errorType2 = classifyError(msg2);
        addDownloadLog(task.mediaId, 0, 1, false, msg2, task.itemTitle);
        EventBus.emit<DownloadErrorData>(DOWNLOAD_ERROR, {
          url: url,
          episodeTitle: task.itemTitle,
          errorType: errorType2,
          message: msg2
        });
      }
    } else {
      task.isActive = false;
      const errorType = classifyError(msg);
      addDownloadLog(task.mediaId, 0, 1, false, msg, task.itemTitle);
      EventBus.emit<DownloadErrorData>(DOWNLOAD_ERROR, {
        url: url,
        episodeTitle: task.itemTitle,
        errorType: errorType,
        message: msg
      });
    }
  } finally {
    activeDownloads.delete(url);
    activeHttpRequests.delete(url);
    emitProgress();

    // 通知生命周期：下载结束（可能需要停止后台任务）
    if (onDownloadEndCallback !== null) {
      onDownloadEndCallback();
    }
  }
}

/**
 * 从异常对象中提取错误信息（兼容 Error / BusinessError / 其他）
 */
function extractErrorMessage(e: Object): string {
  if (e instanceof Error) {
    return e.message;
  }
  // HarmonyOS BusinessError 有 message 属性但不是 Error 子类
  const obj = e as Record<string, Object>;
  if (obj['message'] !== undefined) {
    return String(obj['message']);
  }
  if (obj['code'] !== undefined) {
    return `ErrorCode: ${String(obj['code'])}`;
  }
  return String(e);
}

/**
 * 错误分类
 */
function classifyError(msg: string): string {
  const lower = msg.toLowerCase();
  if (lower.includes('timeout') || lower.includes('stall') || lower.includes('timed out')) return 'timeout';
  if (lower.includes('network') || lower.includes('connect') || lower.includes('econnreset')) return 'network';
  if (lower.includes('space') || lower.includes('nospc') || lower.includes('disk')) return 'disk_full';
  if (lower.includes('404') || lower.includes('not found')) return 'not_found';
  if (lower.includes('401') || lower.includes('403') || lower.includes('auth')) return 'auth';
  return 'unknown';
}

/**
 * 流式分块下载（核心）
 *
 * 使用 http.requestInStream + on('dataReceive') 实现：
 * - 每收到一块数据立即写盘，内存占用恒定
 * - 实时进度更新（节流 200ms）
 * - 断点续传（Range header + 追加写入）
 * - 支持取消（abort HTTP 请求）
 * - 停滞检测（60s 无数据自动取消）
 * - 整体超时（15 分钟自动取消）
 */
function executeStreamDownload(task: DownloadTask, media: FeedMedia): Promise<void> {
  // 确保目录存在
  const dirPath = task.localPath.substring(0, task.localPath.lastIndexOf('/'));
  try {
    fileIo.mkdirSync(dirPath, true);
  } catch (_e) { /* 目录可能已存在 */ }

  // 检查已有文件大小（断点续传）
  let existingSize = 0;
  try {
    const stat = fileIo.statSync(task.localPath);
    console.info(`DownloadManager: existing file found, size=${stat.size}, path=${task.localPath}`);
    existingSize = stat.size;
  } catch (_e) {
    existingSize = 0;
  }

  // 磁盘空间预检（需要至少 50MB 可用空间）
  try {
    const freeBytes = statfs.getFreeSizeSync(dirPath);
    if (freeBytes < 50 * 1024 * 1024) {
      return Promise.reject(new Error('磁盘空间不足（可用空间 < 50MB）'));
    }
  } catch (e) {
    const msg = (e instanceof Error) ? e.message : '';
    if (msg.includes('磁盘空间不足')) {
      return Promise.reject(new Error(msg));
    }
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

  const ctx = new DownloadContext(task);
  let totalSize = existingSize;
  let headerReceived = false;
  let needRestart = false;

  return new Promise<void>((resolve, reject) => {
    ctx.bind(resolve, reject);

    // 启动定时器
    ctx.startOverallTimer();
    ctx.resetStallTimer();

    // 监听 header 获取总大小
    httpRequest.on('headersReceive', (header: Object) => {
      if (headerReceived || ctx.settled) return;
      headerReceived = true;
      const respHeaders = header as Record<string, string>;

      // 获取 content-length
      const contentLength = respHeaders['content-length'] ?? respHeaders['Content-Length'] ?? '0';
      const bodySize = parseInt(contentLength, 10);

      // 获取 HTTP 状态码相关信息
      const contentRange = respHeaders['content-range'] ?? respHeaders['Content-Range'] ?? '';

      console.info(`DownloadManager: headers received, content-length=${bodySize}, content-range="${contentRange}"`);

      if (contentRange.length > 0) {
        // 206 Partial Content — 断点续传成功
        const slashIdx = contentRange.indexOf('/');
        if (slashIdx >= 0) {
          const totalStr = contentRange.substring(slashIdx + 1);
          if (totalStr !== '*') {
            totalSize = parseInt(totalStr, 10);
          }
        }
        console.info(`DownloadManager: resume mode, totalSize=${totalSize}, downloadedBytes=${task.downloadedBytes}`);
      } else {
        // 200 OK — 服务器不支持 Range，需要从头下载
        if (existingSize > 0) {
          console.info(`DownloadManager: server doesn't support Range, restarting from scratch`);
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
          ctx.fd = fileIo.openSync(task.localPath,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        } else if (existingSize > 0) {
          ctx.fd = fileIo.openSync(task.localPath,
            fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.APPEND);
        } else {
          ctx.fd = fileIo.openSync(task.localPath,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
        }
      } catch (e) {
        ctx.safeReject(new Error(extractErrorMessage(e as Object)));
      }
    });

    // 监听数据块到达 — 每块立即写盘
    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      if (!task.isActive || ctx.settled) return;

      // 收到数据，重置停滞定时器
      ctx.resetStallTimer();

      if (ctx.fd !== null) {
        try {
          fileIo.writeSync(ctx.fd.fd, data);
        } catch (e) {
          ctx.safeReject(new Error(extractErrorMessage(e as Object)));
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
      console.info(`DownloadManager: dataEnd for "${task.itemTitle}", downloaded=${task.downloadedBytes} bytes`);
      // 关闭文件
      ctx.closeFile();

      if (!task.isActive || ctx.settled) {
        ctx.safeReject(new Error('Download cancelled'));
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
          addDownloadLog(task.mediaId, 0, 0, true, '', task.itemTitle);
          emitProgress();
          EventBus.emit<DownloadCompleteData>(DOWNLOAD_COMPLETE, {
            episodeTitle: task.itemTitle,
            feedId: task.feedId
          });
          ctx.safeResolve();
        })
        .catch((e: Object) => { ctx.safeReject(new Error(extractErrorMessage(e))); });
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
      connectTimeout: 30000,
      readTimeout: 120000
    }).then((statusCode: number) => {
      console.info(`DownloadManager: HTTP status ${statusCode} for "${task.itemTitle}"`);
      if (statusCode === 416) {
        console.warn(`DownloadManager: 416 Range Not Satisfiable — deleting partial file and failing`);
        try { fileIo.unlinkSync(task.localPath); } catch (_e) { /* ignore */ }
        ctx.safeReject(new Error('Range not satisfiable (416), please retry'));
        return;
      }
      if (statusCode !== 200 && statusCode !== 206) {
        ctx.safeReject(new Error(`HTTP ${statusCode}`));
      }
    }).catch((e: Object) => {
      const msg = extractErrorMessage(e);
      console.error(`DownloadManager: request failed: ${msg}`);
      ctx.safeReject(new Error(msg));
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

/**
 * 主动请求发送一次当前下载进度（供页面恢复时调用）
 */
export function requestProgressUpdate(): void {
  emitProgress();
}

function emitProgress(): void {
  const urls = new Map<string, number>();
  for (const task of activeDownloads.values()) {
    urls.set(task.url, task.progress);
  }
  EventBus.emit<DownloadProgressData>(DOWNLOAD_PROGRESS, { urls: urls });
}
