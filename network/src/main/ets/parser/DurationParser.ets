/**
 * 时长解析器
 *
 * 支持格式：
 * - "3600"    → 3600000 ms（纯秒数）
 * - "45.5"    → 45500 ms（含小数）
 * - "30:00"   → 1800000 ms（MM:SS）
 * - "1:30:00" → 5400000 ms（HH:MM:SS）
 */
export function parseDuration(str: string | null): number {
  if (str === null || str.trim().length === 0) {
    return 0;
  }

  const trimmed = str.trim();

  // 包含冒号 → HH:MM:SS 或 MM:SS
  if (trimmed.includes(':')) {
    return parseColonFormat(trimmed);
  }

  // 纯数字（可能含小数）→ 秒数
  const seconds = parseFloat(trimmed);
  if (isNaN(seconds) || seconds < 0) {
    return 0;
  }
  return Math.round(seconds * 1000);
}

function parseColonFormat(s: string): number {
  const parts = s.split(':');
  if (parts.length === 2) {
    // MM:SS
    const min = parseInt(parts[0], 10);
    const sec = parseFloat(parts[1]);
    if (isNaN(min) || isNaN(sec)) return 0;
    return Math.round((min * 60 + sec) * 1000);
  }
  if (parts.length === 3) {
    // HH:MM:SS
    const hour = parseInt(parts[0], 10);
    const min = parseInt(parts[1], 10);
    const sec = parseFloat(parts[2]);
    if (isNaN(hour) || isNaN(min) || isNaN(sec)) return 0;
    return Math.round((hour * 3600 + min * 60 + sec) * 1000);
  }
  return 0;
}
