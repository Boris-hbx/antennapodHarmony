import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { getActiveDownloadCount } from './DownloadManager';

/**
 * 后台下载保活（需求 4）
 *
 * 使用 ContinuousTask(DATA_TRANSFER) 保持下载在后台继续。
 * 需要在 module.json5 中声明 backgroundModes: ["dataTransfer"]
 */

let isRunning = false;

/**
 * 下载开始时申请后台任务
 */
export async function startBackgroundDownload(context: common.UIAbilityContext): Promise<void> {
  if (isRunning) return;

  try {
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    const agent = await wantAgent.getWantAgent(wantAgentInfo);
    await backgroundTaskManager.startBackgroundRunning(context,
      backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
    isRunning = true;
  } catch (_e) {
    // 后台任务申请失败不阻断下载
  }
}

/**
 * 所有下载完成时释放后台任务
 */
export async function stopBackgroundDownloadIfIdle(context: common.UIAbilityContext): Promise<void> {
  if (!isRunning) return;
  if (getActiveDownloadCount() > 0) return;

  try {
    await backgroundTaskManager.stopBackgroundRunning(context);
    isRunning = false;
  } catch (_e) {
    // ignore
  }
}
