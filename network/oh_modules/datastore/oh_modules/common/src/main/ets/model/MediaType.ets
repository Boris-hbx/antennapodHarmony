/**
 * 媒体类型枚举，根据 MIME 类型判断
 */
export enum MediaType {
  AUDIO,
  VIDEO,
  UNKNOWN
}

const AUDIO_APPLICATION_MIME: string[] = [
  'application/ogg',
  'application/opus',
  'application/x-flac'
];

const VIDEO_APPLICATION_MIME: string[] = [
  'application/x-shockwave-flash'
];

export function mediaTypeFromMime(mimeType: string | null): MediaType {
  if (mimeType === null || mimeType.length === 0) {
    return MediaType.UNKNOWN;
  }
  if (mimeType.startsWith('audio/')) {
    return MediaType.AUDIO;
  }
  if (mimeType.startsWith('video/')) {
    return MediaType.VIDEO;
  }
  if (AUDIO_APPLICATION_MIME.includes(mimeType)) {
    return MediaType.AUDIO;
  }
  if (VIDEO_APPLICATION_MIME.includes(mimeType)) {
    return MediaType.VIDEO;
  }
  return MediaType.UNKNOWN;
}
