/**
 * MIME 类型工具
 */

const AUDIO_EXTENSIONS = new Set([
  '3gp', 'aac', 'amr', 'flac', 'm4a', 'm4b', 'mp3', 'mp4',
  'oga', 'ogg', 'opus', 'wav'
]);

const VIDEO_EXTENSIONS = new Set([
  '3gp', 'mkv', 'mp4', 'ogg', 'ogv', 'webm'
]);

/**
 * 判断是否为媒体文件（音频或视频）
 */
export function isMediaFile(mimeType: string | null): boolean {
  if (mimeType === null || mimeType.length === 0) {
    return false;
  }
  const lower = mimeType.toLowerCase();
  if (lower.startsWith('audio/') || lower.startsWith('video/')) {
    return true;
  }
  // 特殊 application 类型
  if (lower === 'application/ogg' || lower === 'application/opus' ||
    lower === 'application/x-flac' || lower === 'application/x-shockwave-flash') {
    return true;
  }
  return false;
}

/**
 * 判断是否为图片文件
 */
export function isImageFile(mimeType: string | null): boolean {
  if (mimeType === null || mimeType.length === 0) {
    return false;
  }
  return mimeType.toLowerCase().startsWith('image/');
}

/**
 * 综合 MIME 类型和文件名推导最终 MIME
 */
export function getMimeType(type: string | null, filename: string | null): string | null {
  if (type !== null && type.length > 0 && isMediaFile(type)) {
    return type;
  }

  if (filename !== null && filename.length > 0) {
    const ext = getExtension(filename);
    if (ext !== null) {
      if (AUDIO_EXTENSIONS.has(ext)) {
        return extensionToMime(ext, 'audio');
      }
      if (VIDEO_EXTENSIONS.has(ext)) {
        return extensionToMime(ext, 'video');
      }
    }
  }

  return type;
}

function getExtension(filename: string): string | null {
  // 去除 query 参数
  let name = filename;
  const queryIdx = name.indexOf('?');
  if (queryIdx >= 0) {
    name = name.substring(0, queryIdx);
  }
  const dotIdx = name.lastIndexOf('.');
  if (dotIdx < 0 || dotIdx >= name.length - 1) {
    return null;
  }
  return name.substring(dotIdx + 1).toLowerCase();
}

function extensionToMime(ext: string, defaultType: string): string {
  switch (ext) {
    case 'mp3': return 'audio/mpeg';
    case 'mp4': return defaultType === 'audio' ? 'audio/mp4' : 'video/mp4';
    case 'ogg': return defaultType === 'audio' ? 'audio/ogg' : 'video/ogg';
    case 'opus': return 'audio/opus';
    case 'flac': return 'audio/flac';
    case 'aac': return 'audio/aac';
    case 'm4a': return 'audio/mp4';
    case 'm4b': return 'audio/mp4';
    case 'wav': return 'audio/wav';
    case 'oga': return 'audio/ogg';
    case 'amr': return 'audio/amr';
    case '3gp': return 'audio/3gpp';
    case 'mkv': return 'video/x-matroska';
    case 'webm': return 'video/webm';
    case 'ogv': return 'video/ogg';
    default: return `${defaultType}/${ext}`;
  }
}
