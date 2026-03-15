import { FeedItem } from './FeedItem';
import { FeedPreferences } from './FeedPreferences';
import { FeedFunding } from './FeedFunding';
import { FeedItemFilter } from './FeedItemFilter';
import { SortOrder } from './SortOrder';

/**
 * Feed 订阅状态
 */
export enum FeedState {
  SUBSCRIBED = 0,
  NOT_SUBSCRIBED = 1,
  ARCHIVED = 2
}

/**
 * Feed 类型常量
 */
export const TYPE_RSS2 = 'rss';
export const TYPE_ATOM1 = 'atom';
export const PREFIX_LOCAL_FOLDER = 'antennapod_local:';

/**
 * 一个播客订阅源
 */
export class Feed {
  id: number = 0;
  downloadUrl: string | null = null;
  feedTitle: string | null = null;
  customTitle: string | null = null;
  feedIdentifier: string | null = null;
  link: string | null = null;
  description: string | null = null;
  language: string | null = null;
  author: string | null = null;
  imageUrl: string | null = null;
  items: FeedItem[] = [];
  lastModified: string | null = null;
  lastRefreshAttempt: number = 0;
  fundingList: FeedFunding[] = [];
  type: string | null = null;
  preferences: FeedPreferences | null = null;
  paged: boolean = false;
  nextPageLink: string | null = null;
  lastUpdateFailed: boolean = false;
  itemFilter: FeedItemFilter | null = null;
  sortOrder: SortOrder | null = null;
  state: FeedState = FeedState.SUBSCRIBED;

  constructor(downloadUrl: string | null = null, lastModified: string | null = null) {
    this.downloadUrl = downloadUrl;
    this.lastModified = lastModified;
  }

  /**
   * 优先返回 customTitle，否则 feedTitle
   */
  getTitle(): string | null {
    if (this.customTitle !== null && this.customTitle.length > 0) {
      return this.customTitle;
    }
    return this.feedTitle;
  }

  /**
   * 按 feedIdentifier > downloadUrl > feedTitle > link 返回唯一标识
   */
  getIdentifyingValue(): string | null {
    if (this.feedIdentifier !== null && this.feedIdentifier.length > 0) {
      return this.feedIdentifier;
    }
    if (this.downloadUrl !== null && this.downloadUrl.length > 0) {
      return this.downloadUrl;
    }
    if (this.feedTitle !== null && this.feedTitle.length > 0) {
      return this.feedTitle;
    }
    return this.link;
  }

  /**
   * 合并字段（不更新 downloadUrl）
   */
  updateFromOther(other: Feed): void {
    if (other.feedTitle !== null) this.feedTitle = other.feedTitle;
    if (other.feedIdentifier !== null) this.feedIdentifier = other.feedIdentifier;
    if (other.link !== null) this.link = other.link;
    if (other.description !== null) this.description = other.description;
    if (other.language !== null) this.language = other.language;
    if (other.author !== null) this.author = other.author;
    if (other.imageUrl !== null) this.imageUrl = other.imageUrl;
    if (other.type !== null) this.type = other.type;
    if (other.fundingList.length > 0) this.fundingList = other.fundingList;
    this.paged = other.paged;
    if (other.nextPageLink !== null) this.nextPageLink = other.nextPageLink;
    // 注意：不更新 downloadUrl
  }

  /**
   * 返回 pubDate 最新的单集
   */
  getMostRecentItem(): FeedItem | null {
    if (this.items.length === 0) {
      return null;
    }
    let mostRecent: FeedItem | null = null;
    for (const item of this.items) {
      if (item.pubDate === null) continue;
      if (mostRecent === null || mostRecent.pubDate === null ||
        item.pubDate.getTime() > mostRecent.pubDate.getTime()) {
        mostRecent = item;
      }
    }
    return mostRecent;
  }

  /**
   * downloadUrl 是否以 PREFIX_LOCAL_FOLDER 开头
   */
  isLocalFeed(): boolean {
    return this.downloadUrl !== null && this.downloadUrl.startsWith(PREFIX_LOCAL_FOLDER);
  }
}
