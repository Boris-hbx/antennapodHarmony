/**
 * 暂停后回退计算（需求 7）
 *
 * 根据暂停时长自动回退：
 * - < 1 分钟：0（不回退）
 * - 1 分钟 ~ 1 小时：3 秒
 * - 1 小时 ~ 1 天：10 秒
 * - > 1 天：20 秒
 */

const ONE_MINUTE = 60 * 1000;
const ONE_HOUR = 60 * ONE_MINUTE;
const ONE_DAY = 24 * ONE_HOUR;

/**
 * 计算恢复播放时应回退到的位置（纯函数）
 * @param currentPosition 当前播放位置（ms）
 * @param lastPlayedTime 上次播放时间戳（ms）
 * @returns 回退后的位置（ms）
 */
export function calculateRewindPosition(currentPosition: number, lastPlayedTime: number): number {
  if (lastPlayedTime <= 0) {
    return currentPosition;
  }

  const pauseDuration = Date.now() - lastPlayedTime;
  let rewindMs = 0;

  if (pauseDuration < ONE_MINUTE) {
    rewindMs = 0;
  } else if (pauseDuration < ONE_HOUR) {
    rewindMs = 3000;
  } else if (pauseDuration < ONE_DAY) {
    rewindMs = 10000;
  } else {
    rewindMs = 20000;
  }

  return Math.max(0, currentPosition - rewindMs);
}
