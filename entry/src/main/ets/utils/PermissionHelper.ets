import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

/**
 * 权限动态申请工具（#50）
 *
 * HarmonyOS 权限模型：
 * - system_grant：INTERNET、GET_NETWORK_INFO 等，声明即可
 * - user_grant：需动态申请
 * - 通知权限：使用 notificationManager.requestEnableNotification()
 */

/**
 * 检查并申请单个权限
 */
export async function requestPermissionIfNeeded(
  context: common.UIAbilityContext,
  permission: Permissions
): Promise<boolean> {
  const atManager = abilityAccessCtrl.createAtManager();

  try {
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    );
    const tokenId = bundleInfo.appInfo.accessTokenId;
    const result = atManager.checkAccessTokenSync(tokenId, permission);
    if (result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return true;
    }
  } catch (e) {
    console.error('PermissionHelper: checkAccessToken failed: ' + JSON.stringify(e));
  }

  try {
    const result = await atManager.requestPermissionsFromUser(context, [permission]);
    if (result.authResults.length > 0 && result.authResults[0] === 0) {
      return true;
    }
  } catch (e) {
    console.error('PermissionHelper: requestPermission failed: ' + JSON.stringify(e));
  }

  return false;
}

/**
 * 申请通知权限（HarmonyOS 使用 notificationManager API）
 */
export async function ensureNotificationPermission(context: common.UIAbilityContext): Promise<boolean> {
  try {
    const isEnabled = await notificationManager.isNotificationEnabled();
    if (isEnabled) return true;

    // 弹出系统通知开启弹窗
    await notificationManager.requestEnableNotification(context);
    return true;
  } catch (e) {
    console.error('PermissionHelper: notification permission: ' + JSON.stringify(e));
    promptAction.showToast({ message: '未开启通知权限，部分通知功能将不可用', duration: 2000 });
    return false;
  }
}
