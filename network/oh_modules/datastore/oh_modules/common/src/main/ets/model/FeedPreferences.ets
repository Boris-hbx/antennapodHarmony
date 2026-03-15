import { FeedFilter } from './FeedFilter';

/**
 * 自动下载设置
 */
export enum AutoDownloadSetting {
  DISABLED = 0,
  GLOBAL = 1,
  ENABLED = 2
}

/**
 * 自动删除行为
 */
export enum AutoDeleteAction {
  GLOBAL = 0,
  ALWAYS = 1,
  NEVER = 2
}

/**
 * 新单集处理方式
 */
export enum NewEpisodesAction {
  GLOBAL = 0,
  ADD_TO_INBOX = 1,
  NOTHING = 2,
  ADD_TO_QUEUE = 3
}

/**
 * 跳过静音设置
 */
export enum SkipSilence {
  OFF = 0,
  GLOBAL = 1,
  AGGRESSIVE = 2
}

/**
 * 音量调节设置
 */
export enum VolumeAdaptionSetting {
  OFF = 0,
  LIGHT_REDUCTION = 1,
  HEAVY_REDUCTION = 2,
  LIGHT_BOOST = 3,
  MEDIUM_BOOST = 4,
  HEAVY_BOOST = 5
}

/**
 * 每个 Feed 的个性化设置
 */
export class FeedPreferences {
  feedId: number = 0;
  autoDownload: AutoDownloadSetting = AutoDownloadSetting.GLOBAL;
  keepUpdated: boolean = true;
  autoDeleteAction: AutoDeleteAction = AutoDeleteAction.GLOBAL;
  volumeAdaptionSetting: VolumeAdaptionSetting = VolumeAdaptionSetting.OFF;
  newEpisodesAction: NewEpisodesAction = NewEpisodesAction.GLOBAL;
  username: string | null = null;
  password: string | null = null;
  feedPlaybackSpeed: number = -1; // USE_GLOBAL
  feedSkipIntro: number = 0;
  feedSkipEnding: number = 0;
  feedSkipSilence: SkipSilence = SkipSilence.GLOBAL;
  showEpisodeNotification: boolean = false;
  tags: Set<string> = new Set();
  filter: FeedFilter = new FeedFilter();

  constructor(feedId: number = 0) {
    this.feedId = feedId;
  }
}
