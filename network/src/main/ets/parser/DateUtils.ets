/**
 * 健壮的日期解析器，支持多种格式
 */

// 月份缩写映射
const MONTH_MAP: Record<string, string> = {
  'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
  'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
  'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
  'sept': '09' // 特殊缩写
};

// 时区映射
const TZ_MAP: Record<string, string> = {
  'EST': '-0500', 'EDT': '-0400', 'CST': '-0600', 'CDT': '-0500',
  'MST': '-0700', 'MDT': '-0600', 'PST': '-0800', 'PDT': '-0700',
  'GMT': '+0000', 'UTC': '+0000', 'UT': '+0000',
  'CET': '+0100', 'CEST': '+0200', 'EET': '+0200', 'EEST': '+0300',
  'JST': '+0900', 'KST': '+0900', 'IST': '+0530', 'CST_CN': '+0800'
};

/**
 * 解析日期字符串，支持：
 * - RFC 822: "EEE, dd MMM yyyy HH:mm:ss Z"
 * - ISO 8601: "yyyy-MM-dd'T'HH:mm:ssZ"
 * - 简写格式: "dd MMM yyyy", "yyyy-MM-dd"
 * - 特殊格式: "dd/MM/yyyy"
 *
 * 如果解析后日期在未来 → 返回 null
 */
export function parseDate(dateStr: string | null): Date | null {
  if (dateStr === null || dateStr.trim().length === 0) {
    return null;
  }

  const normalized = normalizeDateString(dateStr.trim());
  let date: Date | null = null;

  // 尝试 ISO 8601
  date = tryParseIso8601(normalized);
  if (date !== null) return validateDate(date);

  // 尝试 RFC 822
  date = tryParseRfc822(normalized);
  if (date !== null) return validateDate(date);

  // 尝试简单格式
  date = tryParseSimple(normalized);
  if (date !== null) return validateDate(date);

  // 最后尝试 Date 构造函数
  try {
    const d = new Date(dateStr.trim());
    if (!isNaN(d.getTime())) {
      return validateDate(d);
    }
  } catch {
    // ignore
  }

  return null;
}

function validateDate(date: Date): Date | null {
  if (date.getTime() > Date.now() + 86400000) { // 超过未来 1 天
    return null;
  }
  return date;
}

function normalizeDateString(s: string): string {
  let result = s;
  // 去除星期前缀
  result = result.replace(/^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*,?\s*/i, '');
  // / → -
  result = result.replace(/\//g, '-');
  // Sept → Sep
  result = result.replace(/Sept\b/gi, 'Sep');
  // 修复时区中的冒号 +08:00 → +0800
  result = result.replace(/([+-]\d{2}):(\d{2})$/, '$1$2');
  return result.trim();
}

function tryParseIso8601(s: string): Date | null {
  // yyyy-MM-ddTHH:mm:ss[.sss][Z|±HHMM]
  const match = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})[T ](\d{1,2}):(\d{2})(?::(\d{2}))?(?:\.(\d+))?(.*)$/);
  if (match === null) return null;

  const year = match[1];
  const month = match[2].padStart(2, '0');
  const day = match[3].padStart(2, '0');
  const hour = match[4].padStart(2, '0');
  const min = match[5];
  const sec = match[6] ?? '00';
  let tz = match[8].trim();

  if (tz === '' || tz === 'Z') {
    tz = '+0000';
  }

  const isoStr = `${year}-${month}-${day}T${hour}:${min}:${sec}${formatTzOffset(tz)}`;
  try {
    const d = new Date(isoStr);
    if (!isNaN(d.getTime())) return d;
  } catch {
    // ignore
  }
  return null;
}

function tryParseRfc822(s: string): Date | null {
  // dd MMM yyyy HH:mm:ss [TZ]
  const match = s.match(/^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(.*)$/);
  if (match === null) return null;

  const day = match[1].padStart(2, '0');
  const monthStr = match[2].toLowerCase();
  const month = MONTH_MAP[monthStr];
  if (month === undefined) return null;

  const year = match[3];
  const hour = match[4].padStart(2, '0');
  const min = match[5];
  const sec = match[6] ?? '00';
  const tz = match[7].trim();

  const offset = formatTzOffset(tz);
  const isoStr = `${year}-${month}-${day}T${hour}:${min}:${sec}${offset}`;
  try {
    const d = new Date(isoStr);
    if (!isNaN(d.getTime())) return d;
  } catch {
    // ignore
  }
  return null;
}

function tryParseSimple(s: string): Date | null {
  // yyyy-MM-dd
  let match = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (match !== null) {
    const isoStr = `${match[1]}-${match[2].padStart(2, '0')}-${match[3].padStart(2, '0')}T00:00:00Z`;
    try {
      const d = new Date(isoStr);
      if (!isNaN(d.getTime())) return d;
    } catch { /* ignore */ }
  }

  // dd MMM yyyy
  match = s.match(/^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/);
  if (match !== null) {
    const month = MONTH_MAP[match[2].toLowerCase()];
    if (month !== undefined) {
      const isoStr = `${match[3]}-${month}-${match[1].padStart(2, '0')}T00:00:00Z`;
      try {
        const d = new Date(isoStr);
        if (!isNaN(d.getTime())) return d;
      } catch { /* ignore */ }
    }
  }

  // dd-MM-yyyy
  match = s.match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  if (match !== null) {
    const isoStr = `${match[3]}-${match[2].padStart(2, '0')}-${match[1].padStart(2, '0')}T00:00:00Z`;
    try {
      const d = new Date(isoStr);
      if (!isNaN(d.getTime())) return d;
    } catch { /* ignore */ }
  }

  return null;
}

function formatTzOffset(tz: string): string {
  if (tz.length === 0 || tz === 'Z') {
    return 'Z';
  }
  // 已经是 ±HHMM 或 ±HH:MM 格式
  if (/^[+-]\d{4}$/.test(tz)) {
    return tz.substring(0, 3) + ':' + tz.substring(3);
  }
  if (/^[+-]\d{2}:\d{2}$/.test(tz)) {
    return tz;
  }
  // 命名时区
  const upper = tz.toUpperCase();
  const mapped = TZ_MAP[upper];
  if (mapped !== undefined) {
    return mapped.substring(0, 3) + ':' + mapped.substring(3);
  }
  return 'Z';
}
