import { connection } from '@kit.NetworkKit';
import { commonEventManager } from '@kit.BasicServicesKit';
import { isAllowMobileAutoDownload, isEnableAutodownloadOnBattery } from 'datastore';

/**
 * 系统事件管理 — 网络变化 + 充电状态监听
 *
 * 网络变化：Wi-Fi连接 → 触发自动下载; 网络丢失 → 取消下载
 * 充电状态：充电开始 → 触发自动下载; 充电停止 → 按偏好决定
 */

const TAG = 'SystemEventManager';

export class SystemEventManager {
  onNetworkAvailable: ((isWifi: boolean) => void) | null = null;
  onNetworkLost: (() => void) | null = null;
  onChargingStart: (() => void) | null = null;
  onChargingStop: (() => void) | null = null;

  private netConn: connection.NetConnection | null = null;
  private chargingSubscriber: commonEventManager.CommonEventSubscriber | null = null;

  init(): void {
    this.initNetworkListener();
    this.initChargingListener();
    console.info(TAG, 'SystemEventManager initialized');
  }

  release(): void {
    if (this.netConn !== null) {
      this.netConn.unregister(() => {});
      this.netConn = null;
    }
    if (this.chargingSubscriber !== null) {
      commonEventManager.unsubscribe(this.chargingSubscriber);
      this.chargingSubscriber = null;
    }
    console.info(TAG, 'SystemEventManager released');
  }

  private initNetworkListener(): void {
    const specifier: connection.NetSpecifier = {
      netCapabilities: {
        bearerTypes: [connection.NetBearType.BEARER_WIFI, connection.NetBearType.BEARER_CELLULAR]
      }
    };
    this.netConn = connection.createNetConnection(specifier);
    this.netConn.register((err: Error) => {
      if (err) {
        console.error(TAG, 'NetConnection register failed: ' + err.message);
      } else {
        console.info(TAG, 'NetConnection registered');
      }
    });

    this.netConn.on('netAvailable', () => {
      console.info(TAG, 'Network available');
      // 判断是否 Wi-Fi
      connection.getDefaultNet().then((netHandle: connection.NetHandle) => {
        connection.getNetCapabilities(netHandle).then((caps: connection.NetCapabilities) => {
          const isWifi = caps.bearerTypes.includes(connection.NetBearType.BEARER_WIFI);
          const isCellular = caps.bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR);
          if (isWifi || (isCellular && isAllowMobileAutoDownload())) {
            this.onNetworkAvailable?.(isWifi);
          }
        }).catch(() => {});
      }).catch(() => {});
    });

    this.netConn.on('netLost', () => {
      console.info(TAG, 'Network lost');
      this.onNetworkLost?.();
    });
  }

  private initChargingListener(): void {
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['usual.event.CHARGING', 'usual.event.DISCHARGING']
    };
    commonEventManager.createSubscriber(subscribeInfo).then((subscriber: commonEventManager.CommonEventSubscriber) => {
      this.chargingSubscriber = subscriber;
      commonEventManager.subscribe(subscriber, (_err: Error, data: commonEventManager.CommonEventData) => {
        if (data.event === 'usual.event.CHARGING') {
          console.info(TAG, 'Charging started');
          this.onChargingStart?.();
        } else if (data.event === 'usual.event.DISCHARGING') {
          console.info(TAG, 'Charging stopped');
          this.onChargingStop?.();
        }
      });
      console.info(TAG, 'Charging listener registered');
    }).catch((e: Error) => {
      console.error(TAG, 'Failed to create charging subscriber: ' + e.message);
    });
  }

  /**
   * 判断当前是否允许自动下载
   */
  static isAutoDownloadAllowed(): boolean {
    try {
      const hasNet = connection.hasDefaultNetSync();
      if (!hasNet) return false;
      const netHandle = connection.getDefaultNetSync();
      const caps = connection.getNetCapabilitiesSync(netHandle);
      const isWifi = caps.bearerTypes.includes(connection.NetBearType.BEARER_WIFI);
      if (isWifi) return true;
      const isCellular = caps.bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR);
      return isCellular && isAllowMobileAutoDownload();
    } catch (_e) {
      return false;
    }
  }
}
