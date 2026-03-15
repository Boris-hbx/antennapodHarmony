/**
 * UI 列表过滤器，支持 15 种过滤属性
 */
export class FeedItemFilter {
  showPlayed: boolean = false;
  showUnplayed: boolean = false;
  showNew: boolean = false;
  showPaused: boolean = false;
  showNotPaused: boolean = false;
  showIsFavorite: boolean = false;
  showNotFavorite: boolean = false;
  showHasMedia: boolean = false;
  showNoMedia: boolean = false;
  showQueued: boolean = false;
  showNotQueued: boolean = false;
  showDownloaded: boolean = false;
  showNotDownloaded: boolean = false;
  showIsInHistory: boolean = false;
  includeNotSubscribed: boolean = false;

  constructor(properties: string[] = []) {
    for (const prop of properties) {
      switch (prop) {
        case 'played': this.showPlayed = true; break;
        case 'unplayed': this.showUnplayed = true; break;
        case 'new': this.showNew = true; break;
        case 'paused': this.showPaused = true; break;
        case 'not_paused': this.showNotPaused = true; break;
        case 'is_favorite': this.showIsFavorite = true; break;
        case 'not_favorite': this.showNotFavorite = true; break;
        case 'has_media': this.showHasMedia = true; break;
        case 'no_media': this.showNoMedia = true; break;
        case 'queued': this.showQueued = true; break;
        case 'not_queued': this.showNotQueued = true; break;
        case 'downloaded': this.showDownloaded = true; break;
        case 'not_downloaded': this.showNotDownloaded = true; break;
        case 'is_in_history': this.showIsInHistory = true; break;
        case 'include_not_subscribed': this.includeNotSubscribed = true; break;
        default: break;
      }
    }
  }

  /**
   * 检查单集是否匹配过滤条件。
   * 接收一个 FeedItemFilterValues 对象来避免循环依赖。
   */
  matches(values: FeedItemFilterValues): boolean {
    if (this.showPlayed && !values.isPlayed) return false;
    if (this.showUnplayed && values.isPlayed) return false;
    if (this.showNew && !values.isNew) return false;
    if (this.showPaused && !values.isInProgress) return false;
    if (this.showNotPaused && values.isInProgress) return false;
    if (this.showIsFavorite && !values.isFavorite) return false;
    if (this.showNotFavorite && values.isFavorite) return false;
    if (this.showHasMedia && !values.hasMedia) return false;
    if (this.showNoMedia && values.hasMedia) return false;
    if (this.showQueued && !values.isQueued) return false;
    if (this.showNotQueued && values.isQueued) return false;
    if (this.showDownloaded && !values.isDownloaded) return false;
    if (this.showNotDownloaded && values.isDownloaded) return false;
    if (this.showIsInHistory && !values.isInHistory) return false;
    return true;
  }

  toProperties(): string[] {
    const result: string[] = [];
    if (this.showPlayed) result.push('played');
    if (this.showUnplayed) result.push('unplayed');
    if (this.showNew) result.push('new');
    if (this.showPaused) result.push('paused');
    if (this.showNotPaused) result.push('not_paused');
    if (this.showIsFavorite) result.push('is_favorite');
    if (this.showNotFavorite) result.push('not_favorite');
    if (this.showHasMedia) result.push('has_media');
    if (this.showNoMedia) result.push('no_media');
    if (this.showQueued) result.push('queued');
    if (this.showNotQueued) result.push('not_queued');
    if (this.showDownloaded) result.push('downloaded');
    if (this.showNotDownloaded) result.push('not_downloaded');
    if (this.showIsInHistory) result.push('is_in_history');
    if (this.includeNotSubscribed) result.push('include_not_subscribed');
    return result;
  }
}

/**
 * 过滤所需的值对象，由 FeedItem 提供，用于解除循环依赖
 */
export interface FeedItemFilterValues {
  isPlayed: boolean;
  isNew: boolean;
  isInProgress: boolean;
  isFavorite: boolean;
  hasMedia: boolean;
  isQueued: boolean;
  isDownloaded: boolean;
  isInHistory: boolean;
}
