import { WorkSchedulerExtensionAbility, workScheduler } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getDatabase, initUserPreferences } from 'datastore';
import { refreshAllFeeds } from 'network';

const DOMAIN = 0x0000;
const TAG = 'FeedRefreshWork';

/**
 * Task-032: workScheduler 后台定时刷新订阅
 * 系统在设定间隔后唤醒此 ExtensionAbility，执行 refreshAllFeeds()
 */
export default class FeedRefreshWorkAbility extends WorkSchedulerExtensionAbility {
  async onWorkStart(work: workScheduler.WorkInfo): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onWorkStart: workId=%{public}d', work.workId);
    try {
      // 后台任务需要独立初始化 DB 和 Preferences
      await getDatabase(this.context);
      await initUserPreferences(this.context);
      hilog.info(DOMAIN, TAG, 'DB & Preferences initialized for background refresh');

      const results = await refreshAllFeeds();
      const updatedCount = results.filter((r) => r.success && r.updated).length;
      hilog.info(DOMAIN, TAG, 'Background refresh done: %{public}d feeds updated out of %{public}d total',
        updatedCount, results.length);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'Background refresh failed: %{public}s', msg);
    }
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
    hilog.info(DOMAIN, TAG, 'onWorkStop: workId=%{public}d', work.workId);
  }
}
