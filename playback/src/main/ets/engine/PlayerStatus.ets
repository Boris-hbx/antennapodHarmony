/**
 * 播放器状态机（需求 1）
 *
 * 合法转换：
 * STOPPED → INITIALIZING → PREPARING → PREPARED → PLAYING ↔ PAUSED
 * 任意状态 → STOPPED（stop）
 * 任意状态 → ERROR（出错）
 * ERROR → STOPPED（重置）
 */
export enum PlayerStatus {
  ERROR = -1,
  STOPPED = 0,
  INITIALIZING = 1,
  PREPARING = 2,
  PREPARED = 3,
  PAUSED = 4,
  PLAYING = 5
}

/**
 * 检查状态转换是否合法
 */
export function isValidTransition(from: PlayerStatus, to: PlayerStatus): boolean {
  // 任意状态 → STOPPED
  if (to === PlayerStatus.STOPPED) return true;
  // 任意状态 → ERROR
  if (to === PlayerStatus.ERROR) return true;

  switch (from) {
    case PlayerStatus.ERROR:
      return false; // ERROR can only go to STOPPED (handled above)
    case PlayerStatus.STOPPED:
      return to === PlayerStatus.INITIALIZING;
    case PlayerStatus.INITIALIZING:
      return to === PlayerStatus.PREPARING;
    case PlayerStatus.PREPARING:
      return to === PlayerStatus.PREPARED;
    case PlayerStatus.PREPARED:
      return to === PlayerStatus.PLAYING || to === PlayerStatus.PAUSED;
    case PlayerStatus.PLAYING:
      return to === PlayerStatus.PAUSED;
    case PlayerStatus.PAUSED:
      return to === PlayerStatus.PLAYING || to === PlayerStatus.PREPARED;
    default:
      return false;
  }
}
