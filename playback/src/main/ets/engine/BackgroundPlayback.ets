import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { WantAgent, wantAgent, common } from '@kit.AbilityKit';

/**
 * 后台播放管理（需求 4）
 *
 * 使用 ContinuousTask（长时任务）保持应用在后台播放音频。
 * 需要在 entry 的 module.json5 中声明 backgroundModes: ["audioPlayback"]
 */

let isBackgroundRunning = false;

/**
 * 开始后台播放保活
 * @param context 必须传入 UIAbilityContext（含 abilityInfo）
 */
export async function startBackgroundPlayback(context: common.UIAbilityContext): Promise<void> {
  if (isBackgroundRunning) return;

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
      backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
    isBackgroundRunning = true;
  } catch (e) {
    console.error('Failed to start background playback: ' + (e as Error).message);
  }
}

/**
 * 停止后台播放保活
 */
export async function stopBackgroundPlayback(context: common.UIAbilityContext): Promise<void> {
  if (!isBackgroundRunning) return;

  try {
    await backgroundTaskManager.stopBackgroundRunning(context);
    isBackgroundRunning = false;
  } catch (e) {
    console.error('Failed to stop background playback: ' + (e as Error).message);
  }
}

/**
 * 查询后台播放状态
 */
export function isBackgroundPlaybackRunning(): boolean {
  return isBackgroundRunning;
}
