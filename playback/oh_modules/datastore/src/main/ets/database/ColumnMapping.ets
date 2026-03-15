import { relationalStore } from '@kit.ArkData';
import {
  Feed, FeedState, FeedItem, PlayState, FeedMedia, FeedPreferences, FeedFunding,
  Chapter, FeedFilter, FeedItemFilter, SortOrder, sortOrderFromCodeString,
  AutoDownloadSetting, AutoDeleteAction, NewEpisodesAction, SkipSilence,
  VolumeAdaptionSetting
} from 'common';
import {
  COL_ID, COL_TITLE, COL_CUSTOM_TITLE, COL_DOWNLOAD_URL, COL_LINK, COL_DESCRIPTION,
  COL_LAST_UPDATE, COL_LANGUAGE, COL_AUTHOR, COL_IMAGE_URL, COL_TYPE, COL_FEED_IDENTIFIER,
  COL_AUTO_DOWNLOAD, COL_USERNAME, COL_PASSWORD, COL_INCLUDE_FILTER, COL_EXCLUDE_FILTER,
  COL_MINIMAL_DURATION_FILTER, COL_KEEP_UPDATED, COL_IS_PAGED, COL_NEXT_PAGE_LINK,
  COL_HIDE, COL_SORT_ORDER, COL_LAST_UPDATE_FAILED, COL_AUTO_DELETE_ACTION,
  COL_FEED_PLAYBACK_SPEED, COL_FEED_SKIP_SILENCE, COL_FEED_VOLUME_ADAPTION, COL_TAGS,
  COL_FEED_SKIP_INTRO, COL_FEED_SKIP_ENDING, COL_EPISODE_NOTIFICATION, COL_STATE,
  COL_NEW_EPISODES_ACTION, COL_PAYMENT_LINK,
  COL_PUB_DATE, COL_READ, COL_FEED, COL_HAS_SIMPLE_CHAPTERS, COL_ITEM_IDENTIFIER,
  COL_PODCASTINDEX_CHAPTER_URL, COL_PODCASTINDEX_TRANSCRIPT_TYPE,
  COL_PODCASTINDEX_TRANSCRIPT_URL, COL_AUTO_DOWNLOAD as COL_ITEM_AUTO_DOWNLOAD,
  COL_DURATION, COL_FILE_URL, COL_DOWNLOADED, COL_POSITION, COL_FILESIZE,
  COL_MIME_TYPE, COL_PLAYBACK_COMPLETION_DATE, COL_FEEDITEM, COL_PLAYED_DURATION,
  COL_HAS_EMBEDDED_PICTURE, COL_LAST_PLAYED_TIME,
  COL_START
} from './PodDBAdapter';

// ===== ResultSet 辅助 =====

function getString(rs: relationalStore.ResultSet, col: string): string | null {
  const idx = rs.getColumnIndex(col);
  if (rs.isColumnNull(idx)) {
    return null;
  }
  return rs.getString(idx);
}

function getNumber(rs: relationalStore.ResultSet, col: string): number {
  const idx = rs.getColumnIndex(col);
  if (rs.isColumnNull(idx)) {
    return 0;
  }
  return rs.getLong(idx);
}

function getDouble(rs: relationalStore.ResultSet, col: string): number {
  const idx = rs.getColumnIndex(col);
  if (rs.isColumnNull(idx)) {
    return 0;
  }
  return rs.getDouble(idx);
}

function getBoolean(rs: relationalStore.ResultSet, col: string): boolean {
  return getNumber(rs, col) !== 0;
}

function getNullableBoolean(rs: relationalStore.ResultSet, col: string): boolean | null {
  const idx = rs.getColumnIndex(col);
  if (rs.isColumnNull(idx)) {
    return null;
  }
  const val = rs.getLong(idx);
  if (val < 0) {
    return null;
  }
  return val !== 0;
}

// ===== Feed 映射 =====

export function feedFromResultSet(rs: relationalStore.ResultSet): Feed {
  const feed = new Feed();
  feed.id = getNumber(rs, COL_ID);
  feed.feedTitle = getString(rs, COL_TITLE);
  feed.customTitle = getString(rs, COL_CUSTOM_TITLE);
  feed.downloadUrl = getString(rs, COL_DOWNLOAD_URL);
  feed.link = getString(rs, COL_LINK);
  feed.description = getString(rs, COL_DESCRIPTION);
  feed.lastModified = getString(rs, COL_LAST_UPDATE);
  feed.language = getString(rs, COL_LANGUAGE);
  feed.author = getString(rs, COL_AUTHOR);
  feed.imageUrl = getString(rs, COL_IMAGE_URL);
  feed.type = getString(rs, COL_TYPE);
  feed.feedIdentifier = getString(rs, COL_FEED_IDENTIFIER);
  feed.paged = getBoolean(rs, COL_IS_PAGED);
  feed.nextPageLink = getString(rs, COL_NEXT_PAGE_LINK);
  feed.lastUpdateFailed = getBoolean(rs, COL_LAST_UPDATE_FAILED);
  feed.state = getNumber(rs, COL_STATE) as FeedState;

  // sortOrder
  const sortStr = getString(rs, COL_SORT_ORDER);
  feed.sortOrder = sortOrderFromCodeString(sortStr);

  // itemFilter from hide column
  const hideStr = getString(rs, COL_HIDE);
  if (hideStr !== null && hideStr.length > 0) {
    feed.itemFilter = new FeedItemFilter(hideStr.split(','));
  }

  // funding from payment_link
  const paymentLink = getString(rs, COL_PAYMENT_LINK);
  if (paymentLink !== null && paymentLink.length > 0) {
    feed.fundingList = [new FeedFunding(paymentLink, '')];
  }

  // preferences
  const prefs = new FeedPreferences(feed.id);
  prefs.autoDownload = getNumber(rs, COL_AUTO_DOWNLOAD) as AutoDownloadSetting;
  prefs.username = getString(rs, COL_USERNAME);
  prefs.password = getString(rs, COL_PASSWORD);
  prefs.keepUpdated = getBoolean(rs, COL_KEEP_UPDATED);
  prefs.autoDeleteAction = getNumber(rs, COL_AUTO_DELETE_ACTION) as AutoDeleteAction;
  prefs.feedPlaybackSpeed = getDouble(rs, COL_FEED_PLAYBACK_SPEED);
  prefs.feedSkipSilence = getNumber(rs, COL_FEED_SKIP_SILENCE) as SkipSilence;
  prefs.volumeAdaptionSetting = getNumber(rs, COL_FEED_VOLUME_ADAPTION) as VolumeAdaptionSetting;
  prefs.feedSkipIntro = getNumber(rs, COL_FEED_SKIP_INTRO);
  prefs.feedSkipEnding = getNumber(rs, COL_FEED_SKIP_ENDING);
  prefs.showEpisodeNotification = getBoolean(rs, COL_EPISODE_NOTIFICATION);
  prefs.newEpisodesAction = getNumber(rs, COL_NEW_EPISODES_ACTION) as NewEpisodesAction;
  prefs.filter = new FeedFilter(
    getString(rs, COL_INCLUDE_FILTER) ?? '',
    getString(rs, COL_EXCLUDE_FILTER) ?? '',
    getNumber(rs, COL_MINIMAL_DURATION_FILTER)
  );
  const tagsStr = getString(rs, COL_TAGS);
  if (tagsStr !== null && tagsStr.length > 0) {
    prefs.tags = new Set(tagsStr.split(',').map((t) => t.trim()).filter((t) => t.length > 0));
  }
  feed.preferences = prefs;

  return feed;
}

export function feedToValuesBucket(feed: Feed): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {
    title: feed.feedTitle,
    custom_title: feed.customTitle,
    download_url: feed.downloadUrl,
    link: feed.link,
    description: feed.description,
    last_update: feed.lastModified,
    language: feed.language,
    author: feed.author,
    image_url: feed.imageUrl,
    type: feed.type,
    feed_identifier: feed.feedIdentifier,
    is_paged: feed.paged ? 1 : 0,
    next_page_link: feed.nextPageLink,
    last_update_failed: feed.lastUpdateFailed ? 1 : 0,
    state: feed.state as number,
    sort_order: feed.sortOrder !== null ? feed.sortOrder.toString() : null,
    hide: feed.itemFilter !== null ? feed.itemFilter.toProperties().join(',') : null,
    payment_link: feed.fundingList.length > 0 ? feed.fundingList[0].url : null
  };

  if (feed.preferences !== null) {
    const prefs = feed.preferences;
    bucket.auto_download = prefs.autoDownload as number;
    bucket.username = prefs.username;
    bucket.password = prefs.password;
    bucket.keep_updated = prefs.keepUpdated ? 1 : 0;
    bucket.auto_delete_action = prefs.autoDeleteAction as number;
    bucket.feed_playback_speed = prefs.feedPlaybackSpeed;
    bucket.feed_skip_silence = prefs.feedSkipSilence as number;
    bucket.feed_volume_adaption = prefs.volumeAdaptionSetting as number;
    bucket.feed_skip_intro = prefs.feedSkipIntro;
    bucket.feed_skip_ending = prefs.feedSkipEnding;
    bucket.episode_notification = prefs.showEpisodeNotification ? 1 : 0;
    bucket.new_episodes_action = prefs.newEpisodesAction as number;
    bucket.include_filter = prefs.filter.includeFilter;
    bucket.exclude_filter = prefs.filter.excludeFilter;
    bucket.minimal_duration_filter = prefs.filter.minimalDuration;
    bucket.tags = prefs.tags.size > 0 ? Array.from(prefs.tags).join(',') : null;
  }

  return bucket;
}

// ===== FeedItem 映射 =====

export function feedItemFromResultSet(rs: relationalStore.ResultSet): FeedItem {
  const item = new FeedItem();
  item.id = getNumber(rs, COL_ID);
  item.title = getString(rs, COL_TITLE);
  item.link = getString(rs, COL_LINK);
  item.description = getString(rs, COL_DESCRIPTION);
  item.feedId = getNumber(rs, COL_FEED);
  item.itemIdentifier = getString(rs, COL_ITEM_IDENTIFIER);
  item.imageUrl = getString(rs, COL_IMAGE_URL);
  item.autoDownloadEnabled = getBoolean(rs, COL_ITEM_AUTO_DOWNLOAD);
  item.podcastIndexChapterUrl = getString(rs, COL_PODCASTINDEX_CHAPTER_URL);
  item.podcastIndexTranscriptType = getString(rs, COL_PODCASTINDEX_TRANSCRIPT_TYPE);
  item.podcastIndexTranscriptUrl = getString(rs, COL_PODCASTINDEX_TRANSCRIPT_URL);
  item.hasChapters = getBoolean(rs, COL_HAS_SIMPLE_CHAPTERS);

  const pubDateMs = getNumber(rs, COL_PUB_DATE);
  item.pubDate = pubDateMs > 0 ? new Date(pubDateMs) : null;

  item.state = getNumber(rs, COL_READ) as PlayState;

  return item;
}

export function feedItemToValuesBucket(item: FeedItem): relationalStore.ValuesBucket {
  return {
    title: item.title,
    pubDate: item.pubDate !== null ? item.pubDate.getTime() : 0,
    read: item.state as number,
    link: item.link,
    description: item.description,
    feed: item.feedId,
    has_simple_chapters: item.hasChapters ? 1 : 0,
    item_identifier: item.itemIdentifier,
    image_url: item.imageUrl,
    auto_download: item.autoDownloadEnabled ? 1 : 0,
    podcastindex_chapter_url: item.podcastIndexChapterUrl,
    podcastindex_transcript_type: item.podcastIndexTranscriptType,
    podcastindex_transcript_url: item.podcastIndexTranscriptUrl
  };
}

// ===== FeedMedia 映射 =====

export function feedMediaFromResultSet(rs: relationalStore.ResultSet): FeedMedia {
  const media = new FeedMedia();
  media.id = getNumber(rs, COL_ID);
  media.duration = getNumber(rs, COL_DURATION);
  media.localFileUrl = getString(rs, COL_FILE_URL);
  media.downloadUrl = getString(rs, COL_DOWNLOAD_URL);
  media.downloadDate = getNumber(rs, COL_DOWNLOADED);
  media.position = getNumber(rs, COL_POSITION);
  media.size = getNumber(rs, COL_FILESIZE);
  media.mimeType = getString(rs, COL_MIME_TYPE);
  media.itemId = getNumber(rs, COL_FEEDITEM);
  media.playedDuration = getNumber(rs, COL_PLAYED_DURATION);
  media.hasEmbeddedPicture = getNullableBoolean(rs, COL_HAS_EMBEDDED_PICTURE);
  media.lastPlayedTimeStatistics = getNumber(rs, COL_LAST_PLAYED_TIME);
  return media;
}

export function feedMediaToValuesBucket(media: FeedMedia): relationalStore.ValuesBucket {
  return {
    duration: media.duration,
    file_url: media.localFileUrl,
    download_url: media.downloadUrl,
    downloaded: media.downloadDate,
    position: media.position,
    filesize: media.size,
    mime_type: media.mimeType,
    feeditem: media.itemId,
    played_duration: media.playedDuration,
    has_embedded_picture: media.hasEmbeddedPicture === null ? -1 :
      (media.hasEmbeddedPicture ? 1 : 0),
    last_played_time: media.lastPlayedTimeStatistics
  };
}

// ===== Chapter 映射 =====

export function chapterFromResultSet(rs: relationalStore.ResultSet): Chapter {
  const ch = new Chapter(getNumber(rs, COL_START), getString(rs, COL_TITLE),
    getString(rs, COL_LINK), getString(rs, COL_IMAGE_URL));
  ch.id = getNumber(rs, COL_ID);
  return ch;
}

export function chapterToValuesBucket(ch: Chapter, feedItemId: number): relationalStore.ValuesBucket {
  return {
    title: ch.title,
    start: ch.start,
    feeditem: feedItemId,
    link: ch.link,
    image_url: ch.imageUrl
  };
}
