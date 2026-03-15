// 播放器状态机
export { PlayerStatus, isValidTransition } from './engine/PlayerStatus';

// AVPlayer 封装
export { AVPlayerWrapper } from './engine/AVPlayerWrapper';

// 播放控制器
export { PlaybackController } from './engine/PlaybackController';

// 后台播放
export { startBackgroundPlayback, stopBackgroundPlayback,
  isBackgroundPlaybackRunning } from './engine/BackgroundPlayback';

// 媒体会话
export { initSession, releaseSession, setSessionMetadata,
  updateSessionPlaybackState, setSessionCallbacks } from './session/SessionManager';

// 暂停回退
export { calculateRewindPosition } from './engine/RewindAfterPause';

// 睡眠定时器
export { SleepTimer, SLEEP_TIMER_UPDATE } from './engine/SleepTimer';
export type { SleepTimerData } from './engine/SleepTimer';

// 播放结束处理
export { handlePlaybackCompletion, shouldSmartMarkAsPlayed } from './engine/PlaybackCompleter';
export type { CompletionResult } from './engine/PlaybackCompleter';
