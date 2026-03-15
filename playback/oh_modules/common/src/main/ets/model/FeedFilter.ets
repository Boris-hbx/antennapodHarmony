/**
 * 自动下载过滤器
 */
export class FeedFilter {
  includeFilter: string;
  excludeFilter: string;
  minimalDuration: number;

  constructor(includeFilter: string = '', excludeFilter: string = '', minimalDuration: number = -1) {
    this.includeFilter = includeFilter;
    this.excludeFilter = excludeFilter;
    this.minimalDuration = minimalDuration;
  }

  /**
   * 判断单集是否应该自动下载。
   * 过滤逻辑：时长检查 → 排除词 → 包含词
   */
  shouldAutoDownload(itemTitle: string | null, itemDurationMs: number): boolean {
    // 1. 时长检查：如果设置了最小时长且单集时长不足则排除
    if (this.minimalDuration > 0 && itemDurationMs > 0) {
      if (itemDurationMs < this.minimalDuration * 1000) {
        return false;
      }
    }

    const title = (itemTitle ?? '').toLowerCase();

    // 2. 排除词检查
    if (this.excludeFilter.length > 0) {
      const excludeTerms = this.excludeFilter.split(',')
        .map((t) => t.trim().toLowerCase())
        .filter((t) => t.length > 0);
      for (const term of excludeTerms) {
        if (title.includes(term)) {
          return false;
        }
      }
    }

    // 3. 包含词检查：如果设置了包含词，标题必须包含其中之一
    if (this.includeFilter.length > 0) {
      const includeTerms = this.includeFilter.split(',')
        .map((t) => t.trim().toLowerCase())
        .filter((t) => t.length > 0);
      if (includeTerms.length > 0) {
        let found = false;
        for (const term of includeTerms) {
          if (title.includes(term)) {
            found = true;
            break;
          }
        }
        if (!found) {
          return false;
        }
      }
    }

    return true;
  }
}
