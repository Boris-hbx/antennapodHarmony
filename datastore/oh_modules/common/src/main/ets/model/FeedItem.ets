import { FeedMedia } from './FeedMedia';
import { Transcript } from './Transcript';
import { FeedItemFilterValues } from './FeedItemFilter';

/**
 * 播放状态枚举
 */
export enum PlayState {
  NEW = -1,
  UNPLAYED = 0,
  PLAYED = 1
}

/**
 * 标签常量
 */
export const TAG_QUEUE = 'Queue';
export const TAG_FAVORITE = 'Favorite';

/**
 * Feed 中的一个单集
 */
export class FeedItem {
  id: number = 0;
  itemIdentifier: string | null = null;
  title: string | null = null;
  description: string | null = null;
  link: string | null = null;
  pubDate: Date | null = null;
  media: FeedMedia | null = null;
  feedId: number = 0;
  podcastIndexChapterUrl: string | null = null;
  podcastIndexTranscriptUrl: string | null = null;
  podcastIndexTranscriptType: string | null = null;
  transcript: Transcript | null = null;
  state: PlayState = PlayState.UNPLAYED;
  hasChapters: boolean = false;
  imageUrl: string | null = null;
  autoDownloadEnabled: boolean = true;
  tags: Set<string> = new Set();

  // Feed 的 imageUrl，由外部设置用于 getImageLocation 回退
  private feedImageUrl: string | null = null;

  constructor(id: number = 0, title: string | null = null, feedId: number = 0) {
    this.id = id;
    this.title = title;
    this.feedId = feedId;
  }

  isNew(): boolean {
    return this.state === PlayState.NEW;
  }

  isPlayed(): boolean {
    return this.state === PlayState.PLAYED;
  }

  isInProgress(): boolean {
    return this.media !== null && this.media.position > 0;
  }

  isFavorite(): boolean {
    return this.tags.has(TAG_FAVORITE);
  }

  isQueued(): boolean {
    return this.tags.has(TAG_QUEUE);
  }

  isDownloaded(): boolean {
    return this.media !== null && this.media.isDownloaded();
  }

  /**
   * 设置媒体播放位置，同时将 NEW 状态改为 UNPLAYED
   */
  setMediaPosition(pos: number): void {
    if (this.media !== null) {
      this.media.setPosition(pos);
      if (this.state === PlayState.NEW && pos > 0) {
        this.state = PlayState.UNPLAYED;
      }
    }
  }

  /**
   * 按 imageUrl > 嵌入封面 > Feed.imageUrl 的优先级返回封面
   */
  getImageLocation(): string | null {
    if (this.imageUrl !== null) {
      return this.imageUrl;
    }
    if (this.media !== null && this.media.hasEmbeddedPicture === true) {
      return this.media.localFileUrl;
    }
    return this.feedImageUrl;
  }

  setFeedImageUrl(url: string | null): void {
    this.feedImageUrl = url;
  }

  /**
   * 按 itemIdentifier > title > media.downloadUrl > link 返回唯一标识
   */
  getIdentifyingValue(): string | null {
    if (this.itemIdentifier !== null && this.itemIdentifier.length > 0) {
      return this.itemIdentifier;
    }
    if (this.title !== null && this.title.length > 0) {
      return this.title;
    }
    if (this.media !== null && this.media.downloadUrl !== null) {
      return this.media.downloadUrl;
    }
    return this.link;
  }

  /**
   * 合并字段，含媒体合并逻辑
   */
  updateFromOther(other: FeedItem): void {
    if (other.title !== null) this.title = other.title;
    if (other.description !== null) this.description = other.description;
    if (other.link !== null) this.link = other.link;
    if (other.pubDate !== null) this.pubDate = other.pubDate;
    if (other.imageUrl !== null) this.imageUrl = other.imageUrl;
    if (other.podcastIndexChapterUrl !== null) {
      this.podcastIndexChapterUrl = other.podcastIndexChapterUrl;
    }
    if (other.podcastIndexTranscriptUrl !== null) {
      this.podcastIndexTranscriptUrl = other.podcastIndexTranscriptUrl;
      this.podcastIndexTranscriptType = other.podcastIndexTranscriptType;
    }
    if (other.media !== null) {
      if (this.media === null) {
        this.media = other.media;
      } else {
        if (other.media.downloadUrl !== null) {
          this.media.downloadUrl = other.media.downloadUrl;
        }
        if (other.media.mimeType !== null) {
          this.media.mimeType = other.media.mimeType;
        }
        if (other.media.size > 0) {
          this.media.size = other.media.size;
        }
        if (other.media.duration > 0) {
          this.media.duration = other.media.duration;
        }
      }
    }
  }

  /**
   * 生成过滤器所需的值对象
   */
  toFilterValues(): FeedItemFilterValues {
    return {
      isPlayed: this.isPlayed(),
      isNew: this.isNew(),
      isInProgress: this.isInProgress(),
      isFavorite: this.isFavorite(),
      hasMedia: this.media !== null,
      isQueued: this.isQueued(),
      isDownloaded: this.isDownloaded(),
      isInHistory: this.state === PlayState.PLAYED
    };
  }
}
