/**
 * 字幕片段
 */
export class TranscriptSegment {
  startTime: number;
  endTime: number;
  words: string;
  speaker: string;

  constructor(startTime: number, endTime: number, words: string, speaker: string = '') {
    this.startTime = startTime;
    this.endTime = endTime;
    this.words = words;
    this.speaker = speaker;
  }

  append(newEndTime: number, wordsToAppend: string): void {
    this.endTime = newEndTime;
    this.words += wordsToAppend;
  }
}

/**
 * 字幕数据
 */
export class Transcript {
  segments: TranscriptSegment[];
  speakers: Set<string>;

  constructor(segments: TranscriptSegment[] = [], speakers: Set<string> = new Set()) {
    this.segments = segments;
    this.speakers = speakers;
  }

  /**
   * 二分查找：返回 startTime <= time 的最后一个片段的索引
   */
  findSegmentIndexBefore(time: number): number {
    if (this.segments.length === 0) {
      return -1;
    }
    let low = 0;
    let high = this.segments.length - 1;
    let result = -1;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (this.segments[mid].startTime <= time) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  /**
   * 获取指定时间点的片段
   */
  getSegmentAtTime(time: number): TranscriptSegment | null {
    const index = this.findSegmentIndexBefore(time);
    if (index < 0) {
      return null;
    }
    const segment = this.segments[index];
    if (time >= segment.startTime && time <= segment.endTime) {
      return segment;
    }
    return null;
  }
}
