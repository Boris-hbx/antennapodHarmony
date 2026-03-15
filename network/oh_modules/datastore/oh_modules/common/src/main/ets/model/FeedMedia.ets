import { MediaType, mediaTypeFromMime } from './MediaType';

/**
 * 单集的媒体文件
 */
export class FeedMedia {
  id: number = 0;
  localFileUrl: string | null = null;
  downloadUrl: string | null = null;
  downloadDate: number = 0;
  duration: number = 0;
  position: number = 0;
  lastPlayedTimeStatistics: number = 0;
  playedDuration: number = 0;
  size: number = 0;
  mimeType: string | null = null;
  itemId: number = 0;
  hasEmbeddedPicture: boolean | null = null;

  // 播放统计临时变量
  private startPosition: number = 0;

  constructor(downloadUrl: string | null = null, size: number = 0,
    mimeType: string | null = null) {
    this.downloadUrl = downloadUrl;
    this.size = size;
    this.mimeType = mimeType;
  }

  getMediaType(): MediaType {
    return mediaTypeFromMime(this.mimeType);
  }

  isDownloaded(): boolean {
    return this.downloadDate > 0;
  }

  isInProgress(): boolean {
    return this.position > 0;
  }

  /**
   * 设置播放位置。
   * 注意：对应 FeedItem 的状态由 FeedItem.setMediaPosition() 处理。
   */
  setPosition(pos: number): void {
    this.position = pos;
  }

  onPlaybackStart(): void {
    this.startPosition = this.position;
  }

  onPlaybackCompleted(): void {
    const played = this.position - this.startPosition;
    if (played > 0) {
      this.playedDuration += played;
    }
    this.startPosition = this.position;
  }
}
