import { preferences } from '@kit.ArkData';

const PREFS_NAME = 'default';
const SLEEP_TIMER_PREFS_NAME = 'SleepTimer';

let defaultPrefs: preferences.Preferences | null = null;
let sleepTimerPrefs: preferences.Preferences | null = null;

// ===== 入队位置枚举 =====

export enum EnqueueLocation {
  BACK = 'BACK',
  FRONT = 'FRONT',
  AFTER_CURRENTLY_PLAYING = 'AFTER_CURRENTLY_PLAYING',
  RANDOM = 'RANDOM'
}

// ===== 初始化 =====

export async function init(context: Context): Promise<void> {
  defaultPrefs = await preferences.getPreferences(context, PREFS_NAME);
  sleepTimerPrefs = await preferences.getPreferences(context, SLEEP_TIMER_PREFS_NAME);
}

function getDefault(): preferences.Preferences {
  if (defaultPrefs === null) {
    throw new Error('UserPreferences not initialized. Call init(context) first.');
  }
  return defaultPrefs;
}

function getSleepTimer(): preferences.Preferences {
  if (sleepTimerPrefs === null) {
    throw new Error('UserPreferences not initialized. Call init(context) first.');
  }
  return sleepTimerPrefs;
}

// ===== 6.1 核心播放设置 =====

export function getPlaybackSpeed(): number {
  const str = getDefault().getSync('prefPlaybackSpeed', '1.00') as string;
  const val = parseFloat(str);
  return isNaN(val) ? 1.0 : val;
}

export async function setPlaybackSpeed(speed: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefPlaybackSpeed', speed.toFixed(2));
  await prefs.flush();
}

export function getPlaybackSpeedArray(): number[] {
  const json = getDefault().getSync('prefPlaybackSpeedArray', '[1.0,1.25,1.5]') as string;
  try {
    return JSON.parse(json) as number[];
  } catch {
    return [1.0, 1.25, 1.5];
  }
}

export async function setPlaybackSpeedArray(speeds: number[]): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefPlaybackSpeedArray', JSON.stringify(speeds));
  await prefs.flush();
}

export function getFastForwardSecs(): number {
  return getDefault().getSync('prefFastForwardSecs', 30) as number;
}

export async function setFastForwardSecs(secs: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefFastForwardSecs', secs);
  await prefs.flush();
}

export function getRewindSecs(): number {
  return getDefault().getSync('prefRewindSecs', 10) as number;
}

export async function setRewindSecs(secs: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefRewindSecs', secs);
  await prefs.flush();
}

export function isSkipSilence(): boolean {
  return getDefault().getSync('prefSkipSilence', false) as boolean;
}

export async function setSkipSilence(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefSkipSilence', enabled);
  await prefs.flush();
}

export function isFollowQueue(): boolean {
  return getDefault().getSync('prefFollowQueue', true) as boolean;
}

export async function setFollowQueue(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefFollowQueue', enabled);
  await prefs.flush();
}

export function isPauseOnHeadsetDisconnect(): boolean {
  return getDefault().getSync('prefPauseOnHeadsetDisconnect', true) as boolean;
}

export async function setPauseOnHeadsetDisconnect(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefPauseOnHeadsetDisconnect', enabled);
  await prefs.flush();
}

export function isUnpauseOnHeadsetReconnect(): boolean {
  return getDefault().getSync('prefUnpauseOnHeadsetReconnect', true) as boolean;
}

export async function setUnpauseOnHeadsetReconnect(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefUnpauseOnHeadsetReconnect', enabled);
  await prefs.flush();
}

export function isUnpauseOnBluetoothReconnect(): boolean {
  return getDefault().getSync('prefUnpauseOnBluetoothReconnect', false) as boolean;
}

export async function setUnpauseOnBluetoothReconnect(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefUnpauseOnBluetoothReconnect', enabled);
  await prefs.flush();
}

export function isStreamOverDownload(): boolean {
  return getDefault().getSync('prefStreamOverDownload', false) as boolean;
}

export async function setStreamOverDownload(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefStreamOverDownload', enabled);
  await prefs.flush();
}

export function getSmartMarkAsPlayedSecs(): number {
  const str = getDefault().getSync('prefSmartMarkAsPlayedSecs', '30') as string;
  const val = parseInt(str, 10);
  return isNaN(val) ? 30 : val;
}

export async function setSmartMarkAsPlayedSecs(secs: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefSmartMarkAsPlayedSecs', secs.toString());
  await prefs.flush();
}

// ===== 6.2 下载与网络设置 =====

export function isAutoDownloadEnabled(): boolean {
  return getDefault().getSync('prefEnableAutoDl', false) as boolean;
}

export async function setAutoDownloadEnabled(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefEnableAutoDl', enabled);
  await prefs.flush();
}

export function getEpisodeCacheSize(): number {
  const str = getDefault().getSync('prefEpisodeCacheSize', '20') as string;
  const val = parseInt(str, 10);
  return isNaN(val) ? 20 : val;
}

export async function setEpisodeCacheSize(size: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefEpisodeCacheSize', size.toString());
  await prefs.flush();
}

export function getEpisodeCleanup(): number {
  const str = getDefault().getSync('prefEpisodeCleanup', '-2') as string;
  const val = parseInt(str, 10);
  return isNaN(val) ? -2 : val;
}

export async function setEpisodeCleanup(value: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefEpisodeCleanup', value.toString());
  await prefs.flush();
}

export function isEnqueueDownloaded(): boolean {
  return getDefault().getSync('prefEnqueueDownloaded', true) as boolean;
}

export async function setEnqueueDownloaded(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefEnqueueDownloaded', enabled);
  await prefs.flush();
}

export function getEnqueueLocation(): EnqueueLocation {
  const str = getDefault().getSync('prefEnqueueLocation', 'BACK') as string;
  switch (str) {
    case 'FRONT': return EnqueueLocation.FRONT;
    case 'AFTER_CURRENTLY_PLAYING': return EnqueueLocation.AFTER_CURRENTLY_PLAYING;
    case 'RANDOM': return EnqueueLocation.RANDOM;
    default: return EnqueueLocation.BACK;
  }
}

export async function setEnqueueLocation(location: EnqueueLocation): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefEnqueueLocation', location as string);
  await prefs.flush();
}

export function getUpdateInterval(): number {
  const str = getDefault().getSync('prefAutoUpdateIntervall', '720') as string;
  const val = parseInt(str, 10);
  return isNaN(val) ? 720 : val;
}

export async function setUpdateInterval(minutes: number): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefAutoUpdateIntervall', minutes.toString());
  await prefs.flush();
}

export function getMobileUpdateTypes(): string[] {
  const json = getDefault().getSync('prefMobileUpdateTypes', '["images"]') as string;
  try {
    return JSON.parse(json) as string[];
  } catch {
    return ['images'];
  }
}

export async function setMobileUpdateTypes(types: string[]): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefMobileUpdateTypes', JSON.stringify(types));
  await prefs.flush();
}

// ===== 6.3 UI 设置 =====

export function getTheme(): string {
  return getDefault().getSync('prefTheme', 'system') as string;
}

export async function setTheme(theme: string): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefTheme', theme);
  await prefs.flush();
}

export function getDefaultPage(): string {
  return getDefault().getSync('prefDefaultPage', 'HomeFragment') as string;
}

export async function setDefaultPage(page: string): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefDefaultPage', page);
  await prefs.flush();
}

export function isBottomNavigation(): boolean {
  return getDefault().getSync('prefBottomNavigation', true) as boolean;
}

export async function setBottomNavigation(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefBottomNavigation', enabled);
  await prefs.flush();
}

export function isShowTimeLeft(): boolean {
  return getDefault().getSync('showTimeLeft', false) as boolean;
}

export async function setShowTimeLeft(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('showTimeLeft', enabled);
  await prefs.flush();
}

export function isEpisodeCover(): boolean {
  return getDefault().getSync('prefEpisodeCover', true) as boolean;
}

export async function setEpisodeCover(enabled: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefEpisodeCover', enabled);
  await prefs.flush();
}

// ===== 6.5 睡眠定时器设置 =====

export function getSleepTimerLastValue(): number {
  const str = getSleepTimer().getSync('LastValue', '15') as string;
  const val = parseInt(str, 10);
  return isNaN(val) ? 15 : val;
}

export async function setSleepTimerLastValue(minutes: number): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('LastValue', minutes.toString());
  await prefs.flush();
}

export function getSleepTimerLastValueEpisodes(): number {
  const str = getSleepTimer().getSync('LastValueEpisodes', '1') as string;
  const val = parseInt(str, 10);
  return isNaN(val) ? 1 : val;
}

export async function setSleepTimerLastValueEpisodes(episodes: number): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('LastValueEpisodes', episodes.toString());
  await prefs.flush();
}

export function getSleepTimerType(): number {
  return getSleepTimer().getSync('sleepTimerType', 0) as number;
}

export async function setSleepTimerType(type: number): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('sleepTimerType', type);
  await prefs.flush();
}

export function isSleepTimerShakeToReset(): boolean {
  return getSleepTimer().getSync('ShakeToReset', true) as boolean;
}

export async function setSleepTimerShakeToReset(enabled: boolean): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('ShakeToReset', enabled);
  await prefs.flush();
}

export function isSleepTimerAutoEnable(): boolean {
  return getSleepTimer().getSync('AutoEnable', false) as boolean;
}

export async function setSleepTimerAutoEnable(enabled: boolean): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('AutoEnable', enabled);
  await prefs.flush();
}

export function getSleepTimerAutoEnableFrom(): number {
  return getSleepTimer().getSync('AutoEnableFrom', 22) as number;
}

export async function setSleepTimerAutoEnableFrom(hour: number): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('AutoEnableFrom', hour);
  await prefs.flush();
}

export function getSleepTimerAutoEnableTo(): number {
  return getSleepTimer().getSync('AutoEnableTo', 6) as number;
}

export async function setSleepTimerAutoEnableTo(hour: number): Promise<void> {
  const prefs = getSleepTimer();
  prefs.putSync('AutoEnableTo', hour);
  await prefs.flush();
}

// ===== 6.6 首页 Section 排序 =====

const DEFAULT_SECTION_ORDER = '["queue","surprise","inbox","subscriptions","downloads"]';

export function getHomeSectionOrder(): string[] {
  const json = getDefault().getSync('prefHomeSectionOrder', DEFAULT_SECTION_ORDER) as string;
  try {
    return JSON.parse(json) as string[];
  } catch {
    return JSON.parse(DEFAULT_SECTION_ORDER) as string[];
  }
}

export async function setHomeSectionOrder(order: string[]): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefHomeSectionOrder', JSON.stringify(order));
  await prefs.flush();
}

// ===== 6.7 队列锁定 =====

export function isQueueLocked(): boolean {
  return getDefault().getSync('prefQueueLocked', false) as boolean;
}

export async function setQueueLocked(locked: boolean): Promise<void> {
  const prefs = getDefault();
  prefs.putSync('prefQueueLocked', locked);
  await prefs.flush();
}
