import { audio } from '@kit.AudioKit';
import { vibrator } from '@kit.SensorServiceKit';
import { isPauseOnHeadsetDisconnect, isUnpauseOnHeadsetReconnect,
  isUnpauseOnBluetoothReconnect } from 'datastore';

/**
 * 音频设备变化监听 — 耳机/蓝牙断开暂停、重连恢复
 *
 * HarmonyOS 统一使用 AudioRoutingManager.on('deviceChange') 处理
 * 所有音频设备变化（有线耳机 + 蓝牙 A2DP），比 Android 3 个 Receiver 简洁。
 */

const TAG = 'AudioDeviceManager';

export class AudioDeviceManager {
  onDeviceDisconnect: (() => void) | null = null;
  onDeviceConnect: ((isBluetooth: boolean) => void) | null = null;

  private routingManager: audio.AudioRoutingManager | null = null;
  private deviceChangeCallback: ((info: audio.DeviceChangeAction) => void) | null = null;

  init(): void {
    try {
      const audioManager = audio.getAudioManager();
      this.routingManager = audioManager.getRoutingManager();
      this.deviceChangeCallback = (info: audio.DeviceChangeAction): void => {
        this.handleDeviceChange(info);
      };
      this.routingManager.on('deviceChange', audio.DeviceFlag.OUTPUT_DEVICES_FLAG, this.deviceChangeCallback);
      console.info(TAG, 'Audio device change listener registered');
    } catch (e) {
      console.error(TAG, 'Failed to init: ' + JSON.stringify(e));
    }
  }

  release(): void {
    if (this.routingManager !== null && this.deviceChangeCallback !== null) {
      try {
        this.routingManager.off('deviceChange', this.deviceChangeCallback);
      } catch (_e) { /* ignore */ }
    }
    this.routingManager = null;
    this.deviceChangeCallback = null;
    console.info(TAG, 'Audio device change listener released');
  }

  private handleDeviceChange(info: audio.DeviceChangeAction): void {
    const isConnect = info.type === audio.DeviceChangeType.CONNECT;
    const descriptors = info.deviceDescriptors;

    let isBluetooth = false;
    for (const desc of descriptors) {
      if (desc.deviceType === audio.DeviceType.BLUETOOTH_A2DP) {
        isBluetooth = true;
        break;
      }
    }

    if (isConnect) {
      console.info(TAG, `Device connected: bluetooth=${isBluetooth}`);
      this.onDeviceConnect?.(isBluetooth);
    } else {
      console.info(TAG, `Device disconnected: bluetooth=${isBluetooth}`);
      this.onDeviceDisconnect?.();
    }
  }

  /**
   * 耳机/蓝牙断开 → 根据偏好暂停
   */
  static shouldPauseOnDisconnect(): boolean {
    return isPauseOnHeadsetDisconnect();
  }

  /**
   * 设备重连 → 根据偏好和类型决定是否恢复
   */
  static shouldResumeOnConnect(isBluetooth: boolean): boolean {
    if (isBluetooth) {
      return isUnpauseOnBluetoothReconnect();
    }
    return isUnpauseOnHeadsetReconnect();
  }

  /**
   * 蓝牙重连时震动 500ms
   */
  static vibrateForBluetooth(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 500
      }, {
        id: 0,
        usage: 'unknown'
      });
    } catch (e) {
      console.error(TAG, 'Vibrate failed: ' + JSON.stringify(e));
    }
  }
}
