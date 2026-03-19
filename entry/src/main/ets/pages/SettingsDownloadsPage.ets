import { router, promptAction } from '@kit.ArkUI';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  isAutoDownloadEnabled, setAutoDownloadEnabled,
  getEpisodeCacheSize, setEpisodeCacheSize,
  getUpdateInterval, setUpdateInterval,
  getEpisodeCleanup, setEpisodeCleanup
} from 'datastore';

/**
 * 设置 — 下载
 * 对照 Android DownloadsPreferencesFragment
 */
@Entry
@Component
struct SettingsDownloadsPage {
  @State autoDownload: boolean = false;
  @State cacheSize: number = 20;
  @State updateInterval: number = 720;
  @State episodeCleanup: number = -2;

  aboutToAppear(): void {
    this.autoDownload = isAutoDownloadEnabled();
    this.cacheSize = getEpisodeCacheSize();
    this.updateInterval = getUpdateInterval();
    this.episodeCleanup = getEpisodeCleanup();
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .alignContent(Alignment.Center)
        .onClick(() => { router.back(); })

        Text('下载')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // ===== 更新 =====
        ListItem() { this.sectionHeader('更新') }

        ListItem() {
          this.navRow('自动更新频率', this.getIntervalLabel(), () => {
            this.showIntervalPicker();
          })
        }

        // ===== 自动下载 =====
        ListItem() { this.sectionHeader('自动下载') }

        ListItem() {
          this.switchRow('自动下载', '新单集自动下载',
            this.autoDownload, async (v: boolean) => {
              this.autoDownload = v;
              await setAutoDownloadEnabled(v);
            })
        }

        ListItem() {
          this.navRow('缓存大小', `最多保留 ${this.cacheSize} 集`, () => {
            this.showCachePicker();
          })
        }

        // ===== 自动删除 =====
        ListItem() { this.sectionHeader('自动删除') }

        ListItem() {
          this.navRow('自动删除策略', this.getCleanupLabel(), () => {
            this.showCleanupPicker();
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
  }

  // ===== Builders =====

  @Builder
  sectionHeader(title: string) {
    Column() {
      Text(title).fontSize(13).fontColor('#888888').margin({ bottom: 4 })
    }
    .padding({ left: 16, right: 16, top: 20, bottom: 4 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  switchRow(title: string, subtitle: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#1A1A1A')
        Text(subtitle).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#0078C2')
        .onChange((value: boolean) => { onChange(value); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  navRow(title: string, subtitle: string, onClick: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#1A1A1A')
        Text(subtitle).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16).fontColor(['#CCCCCC'])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => { onClick(); })
  }

  // ===== Logic =====

  getIntervalLabel(): string {
    if (this.updateInterval <= 0) return '手动';
    if (this.updateInterval < 60) return `每 ${this.updateInterval} 分钟`;
    const h = this.updateInterval / 60;
    return `每 ${h} 小时`;
  }

  showIntervalPicker(): void {
    ActionSheet.show({
      title: '自动更新频率',
      message: '检查订阅更新的频率',
      sheets: [
        { title: '手动', action: () => { this.setInterval(0); } },
        { title: '每 1 小时', action: () => { this.setInterval(60); } },
        { title: '每 2 小时', action: () => { this.setInterval(120); } },
        { title: '每 4 小时', action: () => { this.setInterval(240); } },
        { title: '每 8 小时', action: () => { this.setInterval(480); } },
        { title: '每 12 小时', action: () => { this.setInterval(720); } },
        { title: '每 24 小时', action: () => { this.setInterval(1440); } }
      ]
    });
  }

  async setInterval(mins: number): Promise<void> {
    this.updateInterval = mins;
    await setUpdateInterval(mins);
    // Task-032: 重新注册 workScheduler（stopWork → startWork）
    this.reRegisterWorkScheduler(mins);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }

  private reRegisterWorkScheduler(intervalMinutes: number): void {
    const WORK_ID = 1001;
    const stopInfo: workScheduler.WorkInfo = {
      workId: WORK_ID,
      bundleName: 'com.antennapod.harmony',
      abilityName: 'FeedRefreshWorkAbility'
    };
    try {
      workScheduler.stopWork(stopInfo);
    } catch (_e) { /* ignore */ }

    if (intervalMinutes <= 0) {
      hilog.info(0x0000, 'Settings', 'workScheduler stopped (interval=0)');
      return;
    }

    const workInfo: workScheduler.WorkInfo = {
      workId: WORK_ID,
      bundleName: 'com.antennapod.harmony',
      abilityName: 'FeedRefreshWorkAbility',
      isPersisted: true,
      isRepeat: true,
      repeatCycleTime: intervalMinutes * 60 * 1000,
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY
    };

    try {
      workScheduler.startWork(workInfo);
      hilog.info(0x0000, 'Settings', 'workScheduler re-registered: every %{public}d minutes', intervalMinutes);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      hilog.error(0x0000, 'Settings', 'workScheduler re-registration failed: %{public}s', msg);
    }
  }

  showCachePicker(): void {
    ActionSheet.show({
      title: '缓存大小',
      message: '本地最多保留的单集数量',
      sheets: [
        { title: '5 集', action: () => { this.setCache(5); } },
        { title: '10 集', action: () => { this.setCache(10); } },
        { title: '20 集', action: () => { this.setCache(20); } },
        { title: '50 集', action: () => { this.setCache(50); } },
        { title: '100 集', action: () => { this.setCache(100); } },
        { title: '不限制', action: () => { this.setCache(9999); } }
      ]
    });
  }

  async setCache(size: number): Promise<void> {
    this.cacheSize = size;
    await setEpisodeCacheSize(size);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }

  getCleanupLabel(): string {
    switch (this.episodeCleanup) {
      case -1: return '队列中的除外';
      case -2: return '不自动删除';
      case 0: return '播完立即删除';
      default:
        if (this.episodeCleanup > 0) return `保留 ${this.episodeCleanup} 小时后删除`;
        return '不自动删除';
    }
  }

  showCleanupPicker(): void {
    ActionSheet.show({
      title: '自动删除策略',
      message: '播放完成后何时自动删除本地文件',
      sheets: [
        { title: '不自动删除', action: () => { this.setCleanup(-2); } },
        { title: '队列中的除外', action: () => { this.setCleanup(-1); } },
        { title: '播完立即删除', action: () => { this.setCleanup(0); } },
        { title: '保留 12 小时', action: () => { this.setCleanup(12); } },
        { title: '保留 24 小时', action: () => { this.setCleanup(24); } },
        { title: '保留 3 天', action: () => { this.setCleanup(72); } },
        { title: '保留 1 周', action: () => { this.setCleanup(168); } }
      ]
    });
  }

  async setCleanup(value: number): Promise<void> {
    this.episodeCleanup = value;
    await setEpisodeCleanup(value);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }
}
