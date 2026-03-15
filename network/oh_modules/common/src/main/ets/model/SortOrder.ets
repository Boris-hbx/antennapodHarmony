/**
 * 排序枚举
 * INTRA_FEED: Feed 内排序 (code 1-11)
 * INTER_FEED: 跨 Feed 排序 (code 101+)
 */
export enum SortOrder {
  // INTRA_FEED
  DATE_OLD_NEW = 1,
  DATE_NEW_OLD = 2,
  EPISODE_TITLE_A_Z = 3,
  EPISODE_TITLE_Z_A = 4,
  DURATION_SHORT_LONG = 5,
  DURATION_LONG_SHORT = 6,
  EPISODE_FILENAME_A_Z = 7,
  EPISODE_FILENAME_Z_A = 8,
  SIZE_SMALL_LARGE = 9,
  SIZE_LARGE_SMALL = 10,
  GLOBAL_DEFAULT = 11,
  // INTER_FEED
  FEED_TITLE_A_Z = 101,
  FEED_TITLE_Z_A = 102,
  RANDOM = 103,
  SMART_SHUFFLE_OLD_NEW = 104,
  SMART_SHUFFLE_NEW_OLD = 105,
  COMPLETION_DATE_NEW_OLD = 106
}

const codeToSortOrder = new Map<number, SortOrder>();
for (const key of Object.values(SortOrder)) {
  if (typeof key === 'number') {
    codeToSortOrder.set(key, key as SortOrder);
  }
}

export function sortOrderFromCodeString(s: string | null): SortOrder | null {
  if (s === null || s.length === 0) {
    return null;
  }
  const code = parseInt(s, 10);
  if (isNaN(code)) {
    return null;
  }
  return codeToSortOrder.get(code) ?? null;
}

export function sortOrderToCodeString(order: SortOrder | null): string {
  if (order === null) {
    return '';
  }
  return order.toString();
}

export function isIntraFeed(order: SortOrder): boolean {
  return order >= 1 && order <= 11;
}

export function isInterFeed(order: SortOrder): boolean {
  return order >= 101;
}
