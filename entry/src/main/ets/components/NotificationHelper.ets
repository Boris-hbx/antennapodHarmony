import { notificationManager } from '@kit.NotificationKit';

/**
 * 通知管理（P6）
 *
 * 播放通知由 AVSession 自动生成。
 * 这里处理新单集通知和下载完成通知。
 */

let notificationId = 1000;

/**
 * 发送新单集通知
 */
export async function sendNewEpisodeNotification(feedTitle: string, count: number): Promise<void> {
  try {
    const normalContent: notificationManager.NotificationBasicContent = {
      title: feedTitle,
      text: `有 ${count} 集新单集`
    };
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: normalContent
    };
    const request: notificationManager.NotificationRequest = {
      id: notificationId++,
      content: content
    };
    await notificationManager.publish(request);
  } catch (_e) {
    // 通知发送失败不影响主流程
  }
}

/**
 * 发送下载完成通知
 */
export async function sendDownloadCompleteNotification(episodeTitle: string): Promise<void> {
  try {
    const normalContent: notificationManager.NotificationBasicContent = {
      title: '下载完成',
      text: episodeTitle
    };
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: normalContent
    };
    const request: notificationManager.NotificationRequest = {
      id: notificationId++,
      content: content
    };
    await notificationManager.publish(request);
  } catch (_e) {
    // ignore
  }
}
