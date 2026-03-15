import { connection } from '@kit.NetworkKit';
import { getMobileUpdateTypes } from 'datastore';

/**
 * 网络是否可用
 */
export async function isNetworkAvailable(): Promise<boolean> {
  try {
    const hasNet = await connection.hasDefaultNet();
    return hasNet;
  } catch {
    return false;
  }
}

/**
 * 是否为受限网络（蜂窝/计量）
 */
export async function isNetworkRestricted(): Promise<boolean> {
  try {
    const netHandle = await connection.getDefaultNet();
    const caps = await connection.getNetCapabilities(netHandle);
    // 如果有 WiFi 或以太网能力，视为不受限
    if (caps.bearerTypes !== undefined) {
      for (const bearer of caps.bearerTypes) {
        if (bearer === connection.NetBearType.BEARER_WIFI ||
          bearer === connection.NetBearType.BEARER_ETHERNET) {
          return false;
        }
      }
    }
    return true; // 蜂窝或其他网络视为受限
  } catch {
    return true;
  }
}

async function isMobileTypeAllowed(type: string): Promise<boolean> {
  const restricted = await isNetworkRestricted();
  if (!restricted) {
    return true; // WiFi/以太网全部允许
  }
  const allowedTypes = getMobileUpdateTypes();
  return allowedTypes.includes(type);
}

/**
 * 是否允许自动下载
 */
export async function isAutoDownloadAllowed(): Promise<boolean> {
  return isMobileTypeAllowed('auto_download');
}

/**
 * 是否允许手动下载
 */
export async function isEpisodeDownloadAllowed(): Promise<boolean> {
  return isMobileTypeAllowed('episode_download');
}

/**
 * 是否允许加载图片
 */
export async function isImageAllowed(): Promise<boolean> {
  return isMobileTypeAllowed('images');
}

/**
 * 是否允许流媒体
 */
export async function isStreamingAllowed(): Promise<boolean> {
  return isMobileTypeAllowed('streaming');
}

/**
 * 是否允许刷新 Feed
 */
export async function isFeedRefreshAllowed(): Promise<boolean> {
  return isMobileTypeAllowed('feed_refresh');
}
