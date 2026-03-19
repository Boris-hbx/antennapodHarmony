import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router, window } from '@kit.ArkUI';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { getDatabase, initUserPreferences, initPlaybackPreferences, getTheme, getUpdateInterval,
  isEnableAutodownloadOnBattery } from 'datastore';
import { PlaybackController } from 'playback';
import { refreshAllFeeds, cancelAllDownloads, setDownloadLifecycleCallbacks,
  startBackgroundDownload, stopBackgroundDownloadIfIdle } from 'network';
import { EventBus, DOWNLOAD_COMPLETE } from 'common';
import type { DownloadCompleteData } from 'common';
import { sendDownloadCompleteNotification } from '../components/NotificationHelper';
import { ensureNotificationPermission } from '../utils/PermissionHelper';

const DOMAIN = 0x0000;

// 全局 PlaybackController 单例
let globalController: PlaybackController | null = null;

export function getController(): PlaybackController {
  if (globalController === null) {
    throw new Error('PlaybackController not initialized');
  }
  return globalController;
}

export default class EntryAbility extends UIAbility {
  private downloadCompleteCallback: (data: DownloadCompleteData) => void = (data) => {
    sendDownloadCompleteNotification(data.episodeTitle);
  };
  private static readonly WORK_ID: number = 1001;
  private servicesReady: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // Deep Link: feed://xxx → 存储待处理 URL
    if (want.uri !== undefined && want.uri !== null && want.uri.length > 0) {
      AppStorage.setOrCreate('pendingFeedUrl', want.uri);
      hilog.info(DOMAIN, 'testTag', 'Deep link received: %{public}s', want.uri);
    }

    // Widget 操作：存储待执行动作
    if (want.parameters !== undefined && want.parameters !== null) {
      const widgetAction = want.parameters['widgetAction'] as string;
      if (widgetAction !== undefined && widgetAction !== null && widgetAction.length > 0) {
        AppStorage.setOrCreate('pendingWidgetAction', widgetAction);
      }
    }

    // 通知点击：存储待跳转页面，在 loadContent 后执行
    if (want.parameters !== undefined && want.parameters !== null) {
      const targetPage = want.parameters['targetPage'] as string;
      if (targetPage !== undefined && targetPage !== null && targetPage.length > 0) {
        AppStorage.setOrCreate('pendingNotificationPage', targetPage);
        if (want.parameters['feedId'] !== undefined) {
          AppStorage.setOrCreate('pendingNotificationFeedId', want.parameters['feedId'] as number);
        }
        if (want.parameters['feedTitle'] !== undefined) {
          AppStorage.setOrCreate('pendingNotificationFeedTitle', want.parameters['feedTitle'] as string);
        }
      }
    }
  }

  async initServices(): Promise<void> {
    try {
      await getDatabase(this.context);
      hilog.info(DOMAIN, 'testTag', 'Database initialized successfully.');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init database: %{public}s', JSON.stringify(err));
    }
    try {
      await initUserPreferences(this.context);
      await initPlaybackPreferences(this.context);
      hilog.info(DOMAIN, 'testTag', 'Preferences initialized successfully.');

      const theme = getTheme();
      const appCtx = this.context.getApplicationContext();
      if (theme === 'light') {
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (theme === 'dark') {
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init preferences: %{public}s', JSON.stringify(err));
    }

    // 初始化 PlaybackController
    try {
      globalController = new PlaybackController();
      await globalController.init(this.context);
      hilog.info(DOMAIN, 'testTag', 'PlaybackController initialized.');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init PlaybackController: %{public}s', JSON.stringify(err));
    }

    // 监听下载完成事件 → 发送通知
    EventBus.on<DownloadCompleteData>(DOWNLOAD_COMPLETE, this.downloadCompleteCallback);

    // 注册下载生命周期回调 → 后台保活
    const ctx = this.context;
    setDownloadLifecycleCallbacks(
      () => {
        // 下载开始 → 申请后台任务
        startBackgroundDownload(ctx).catch(() => {});
      },
      () => {
        // 下载结束 → 释放后台任务（如果没有其他活跃下载）
        stopBackgroundDownloadIfIdle(ctx).catch(() => {});
      }
    );

    // 标记服务就绪 + 注册 workScheduler 后台刷新 + 启动时即时刷新一次
    this.servicesReady = true;
    this.registerAutoRefreshWork();

    // 申请通知权限
    ensureNotificationPermission(this.context).catch(() => {});

    // 接通系统事件 → 自动下载链路
    if (globalController !== null) {
      const sysEvents = globalController.getSystemEventManager();
      const filesDir = this.context.filesDir;
      sysEvents.onNetworkAvailable = () => {
        hilog.info(DOMAIN, 'testTag', 'Network available → triggering auto download');
        // TODO: 调用 autodownloadUndownloadedItems(filesDir)
      };
      sysEvents.onNetworkLost = () => {
        hilog.info(DOMAIN, 'testTag', 'Network lost → cancelling downloads');
        cancelAllDownloads();
      };
      sysEvents.onChargingStart = () => {
        hilog.info(DOMAIN, 'testTag', 'Charging started → triggering auto download');
        // TODO: 调用 autodownloadUndownloadedItems(filesDir)
      };
      sysEvents.onChargingStop = () => {
        hilog.info(DOMAIN, 'testTag', 'Charging stopped');
        if (!isEnableAutodownloadOnBattery()) {
          hilog.info(DOMAIN, 'testTag', 'Battery download disabled → cancelling downloads');
          cancelAllDownloads();
        }
      };
    }
    // 启动时触发一次即时刷新（保留原有行为）
    refreshAllFeeds().then(() => {
      hilog.info(DOMAIN, 'testTag', 'Startup refresh: done');
    }).catch((e: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Startup refresh failed: %{public}s', e.message);
    });

    // 处理冷启动时的 Widget 操作
    const pendingAction = AppStorage.get<string>('pendingWidgetAction');
    if (pendingAction !== undefined && pendingAction.length > 0 && globalController !== null) {
      AppStorage.delete('pendingWidgetAction');
      switch (pendingAction) {
        case 'playPause': globalController.playPause(); break;
        case 'fastForward': globalController.seekDelta(30000); break;
        case 'skip': globalController.skip(); break;
        default: break;
      }
    }
  }

  onNewWant(want: Want): void {
    hilog.info(DOMAIN, 'testTag', 'onNewWant called');
    this.handleWidgetAction(want);
    this.handleNotificationNavigation(want);
  }

  private handleWidgetAction(want: Want): void {
    const params = want.parameters;
    if (params === undefined || params === null) return;
    const action = params['widgetAction'] as string;
    if (action === undefined || action === null || action.length === 0) return;
    if (globalController === null) return;

    hilog.info(DOMAIN, 'testTag', 'Widget action: %{public}s', action);
    switch (action) {
      case 'playPause':
        globalController.playPause();
        break;
      case 'fastForward':
        globalController.seekDelta(30000);
        break;
      case 'skip':
        globalController.skip();
        break;
      default:
        break;
    }
  }

  private handleNotificationNavigation(want: Want): void {
    const params = want.parameters;
    if (params === undefined || params === null) return;
    const targetPage = params['targetPage'] as string;
    if (targetPage === undefined || targetPage === null || targetPage.length === 0) return;

    hilog.info(DOMAIN, 'testTag', 'Notification navigation to: %{public}s', targetPage);
    const routeParams: Record<string, Object> = {};
    if (params['feedId'] !== undefined) {
      routeParams['feedId'] = params['feedId'] as number;
    }
    if (params['feedTitle'] !== undefined) {
      routeParams['feedTitle'] = params['feedTitle'] as string;
    }
    router.pushUrl({ url: targetPage, params: routeParams });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    EventBus.off(DOWNLOAD_COMPLETE, this.downloadCompleteCallback);
    if (globalController !== null) {
      globalController.release();
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.initServices().then(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  // ===== Task-032: workScheduler 系统级后台定时刷新 =====

  /**
   * 注册 workScheduler 周期任务。
   * intervalMinutes ≤ 0 表示"从不"，不注册。
   * workScheduler 系统最小间隔约 20 分钟，短于此的值由系统自动调整。
   */
  private registerAutoRefreshWork(): void {
    const intervalMinutes = getUpdateInterval();

    // 先停掉旧任务（不管是否存在，stopWork 对不存在的 workId 不报错）
    const stopInfo: workScheduler.WorkInfo = {
      workId: EntryAbility.WORK_ID,
      bundleName: 'com.antennapod.harmony',
      abilityName: 'FeedRefreshWorkAbility'
    };
    try {
      workScheduler.stopWork(stopInfo);
    } catch (_e) { /* 首次注册时可能不存在，忽略 */ }

    if (intervalMinutes <= 0) {
      hilog.info(DOMAIN, 'testTag', 'Auto refresh disabled (interval=0), workScheduler not registered');
      return;
    }

    const workInfo: workScheduler.WorkInfo = {
      workId: EntryAbility.WORK_ID,
      bundleName: 'com.antennapod.harmony',
      abilityName: 'FeedRefreshWorkAbility',
      isPersisted: true,
      isRepeat: true,
      repeatCycleTime: intervalMinutes * 60 * 1000,
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY
    };

    try {
      workScheduler.startWork(workInfo);
      hilog.info(DOMAIN, 'testTag', 'workScheduler registered: every %{public}d minutes', intervalMinutes);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      hilog.error(DOMAIN, 'testTag', 'workScheduler registration failed: %{public}s', msg);
    }
  }
}
