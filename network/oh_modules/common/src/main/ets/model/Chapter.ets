/**
 * 播客章节
 */
export class Chapter {
  id: number = 0;
  start: number;
  title: string | null;
  link: string | null;
  imageUrl: string | null;
  chapterId: string | null;

  constructor(start: number, title: string | null = null, link: string | null = null,
    imageUrl: string | null = null) {
    this.start = start;
    this.title = title;
    this.link = link;
    this.imageUrl = imageUrl;
    this.chapterId = null;
  }

  /**
   * 二分查找当前播放位置所在的章节索引。
   * 返回 start <= position 的最后一个章节的索引。
   */
  static getAfterPosition(chapters: Chapter[], position: number): number {
    if (chapters.length === 0) {
      return -1;
    }
    // 如果在第一个章节之前
    if (position < chapters[0].start) {
      return 0;
    }
    let low = 0;
    let high = chapters.length - 1;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (chapters[mid].start <= position) {
        if (mid === chapters.length - 1 || chapters[mid + 1].start > position) {
          return mid;
        }
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}
