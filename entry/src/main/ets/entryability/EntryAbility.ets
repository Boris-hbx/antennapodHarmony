import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router, window } from '@kit.ArkUI';
import { getDatabase, initUserPreferences, initPlaybackPreferences, getTheme, getUpdateInterval } from 'datastore';
import { PlaybackController } from 'playback';
import { refreshAllFeeds } from 'network';
import { EventBus, DOWNLOAD_COMPLETE } from 'common';
import type { DownloadCompleteData } from 'common';
import { sendDownloadCompleteNotification } from '../components/NotificationHelper';

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
  private autoRefreshTimer: number = -1;
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

    // 标记服务就绪 + 启动自动定时刷新
    this.servicesReady = true;
    this.startAutoRefresh();

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
    this.stopAutoRefresh();
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
    // 回前台时重新读取刷新间隔（用户可能改了设置）
    // 首次启动时 initServices 尚未完成，servicesReady 为 false，跳过
    if (this.servicesReady) {
      this.startAutoRefresh();
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    this.stopAutoRefresh();
  }

  // ===== 自动定时刷新 =====

  private startAutoRefresh(): void {
    this.stopAutoRefresh();
    const intervalMinutes = getUpdateInterval();
    if (intervalMinutes <= 0) {
      hilog.info(DOMAIN, 'testTag', 'Auto refresh disabled (interval=0)');
      return;
    }
    const intervalMs = intervalMinutes * 60 * 1000;
    hilog.info(DOMAIN, 'testTag', 'Auto refresh started: every %{public}d minutes', intervalMinutes);
    this.autoRefreshTimer = setInterval(() => {
      hilog.info(DOMAIN, 'testTag', 'Auto refresh: refreshing all feeds...');
      refreshAllFeeds().then(() => {
        hilog.info(DOMAIN, 'testTag', 'Auto refresh: done');
      }).catch((e: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Auto refresh failed: %{public}s', e.message);
      });
    }, intervalMs);
  }

  private stopAutoRefresh(): void {
    if (this.autoRefreshTimer >= 0) {
      clearInterval(this.autoRefreshTimer);
      this.autoRefreshTimer = -1;
    }
  }
}
