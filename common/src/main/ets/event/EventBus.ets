/**
 * 轻量事件总线，替代 Android EventBus。
 * 支持类型安全的事件订阅/发布。
 * PLAYBACK_POSITION 等高频事件同步 emit，不阻塞调用线程。
 */

// ===== 事件类型常量 =====

export const FEED_LIST_UPDATE = 'FEED_LIST_UPDATE';
export const FEED_ITEM_UPDATE = 'FEED_ITEM_UPDATE';
export const QUEUE_UPDATE = 'QUEUE_UPDATE';
export const FAVORITES_UPDATE = 'FAVORITES_UPDATE';
export const UNREAD_UPDATE = 'UNREAD_UPDATE';
export const PLAYBACK_POSITION = 'PLAYBACK_POSITION';
export const PLAYER_STATUS = 'PLAYER_STATUS';
export const DOWNLOAD_PROGRESS = 'DOWNLOAD_PROGRESS';
export const FEED_UPDATE_RUNNING = 'FEED_UPDATE_RUNNING';
export const DOWNLOAD_COMPLETE = 'DOWNLOAD_COMPLETE';

// ===== 事件数据类型 =====

export interface FeedListUpdateData {
  feedIds: number[];
}

export interface FeedItemUpdateData {
  items: import('../model/FeedItem').FeedItem[];
}

export interface QueueUpdateData {
  action: string;
}

export interface PlaybackPositionData {
  position: number;
  duration: number;
}

export interface DownloadProgressData {
  urls: Map<string, number>;
}

export interface FeedUpdateRunningData {
  running: boolean;
}

export interface DownloadCompleteData {
  episodeTitle: string;
  feedId: number;
}

// ===== 事件总线实现 =====

type Callback = (data?: Object) => void;

const listeners = new Map<string, Set<Callback>>();

export class EventBus {
  /**
   * 订阅事件
   */
  static on<T>(eventType: string, callback: (data: T) => void): void {
    let set = listeners.get(eventType);
    if (set === undefined) {
      set = new Set<Callback>();
      listeners.set(eventType, set);
    }
    set.add(callback as Callback);
  }

  /**
   * 取消订阅
   */
  static off(eventType: string, callback: Function): void {
    const set = listeners.get(eventType);
    if (set !== undefined) {
      set.delete(callback as Callback);
      if (set.size === 0) {
        listeners.delete(eventType);
      }
    }
  }

  /**
   * 发布事件。同步调用所有回调，不阻塞调用线程。
   * 高频事件（如 PLAYBACK_POSITION）直接同步派发，无额外开销。
   */
  static emit<T>(eventType: string, data?: T): void {
    const set = listeners.get(eventType);
    if (set === undefined || set.size === 0) {
      return;
    }
    for (const cb of set) {
      try {
        cb(data as Object);
      } catch (_e) {
        // 防止单个回调异常阻断其他订阅者
      }
    }
  }

  /**
   * 移除某事件的所有订阅者（测试/清理用）
   */
  static removeAllListeners(eventType?: string): void {
    if (eventType !== undefined) {
      listeners.delete(eventType);
    } else {
      listeners.clear();
    }
  }
}
