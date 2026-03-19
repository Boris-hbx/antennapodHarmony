import { router, promptAction } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import {
  getTheme, setTheme,
  isEpisodeCover, setEpisodeCover,
  isShowTimeLeft, setShowTimeLeft,
  isBottomNavigation, setBottomNavigation,
  getDefaultPage, setDefaultPage,
  isStreamOverDownload, setStreamOverDownload,
  isAmoledBlack, setAmoledBlack,
  isTimeRespectSpeed, setTimeRespectSpeed,
  getGlobalSortOrder, setGlobalSortOrder,
  getDownloadButtonAction, setDownloadButtonAction
} from 'datastore';

/**
 * 设置 — 用户界面
 * 对照 Android UserInterfacePreferencesFragment
 */
@Entry
@Component
struct SettingsUserInterfacePage {
  @State currentTheme: string = 'system';
  @State episodeCover: boolean = true;
  @State showTimeLeft: boolean = false;
  @State bottomNav: boolean = true;
  @State defaultPage: string = 'HomeFragment';
  @State streamOverDownload: boolean = false;
  @State amoledBlack: boolean = false;
  @State timeRespectSpeed: boolean = false;
  @State globalSortOrder: string = 'DATE_NEW_OLD';
  @State downloadButtonAction: string = 'ALWAYS_DOWNLOAD';

  aboutToAppear(): void {
    this.currentTheme = getTheme();
    this.episodeCover = isEpisodeCover();
    this.showTimeLeft = isShowTimeLeft();
    this.bottomNav = isBottomNavigation();
    this.defaultPage = getDefaultPage();
    this.streamOverDownload = isStreamOverDownload();
    this.amoledBlack = isAmoledBlack();
    this.timeRespectSpeed = isTimeRespectSpeed();
    this.globalSortOrder = getGlobalSortOrder();
    this.downloadButtonAction = getDownloadButtonAction();
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

        Text('用户界面')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // ===== 主题 =====
        ListItem() {
          this.sectionHeader('主题')
        }
        ListItem() {
          this.themeOption('跟随系统', 'system')
        }
        ListItem() {
          this.themeOption('浅色模式', 'light')
        }
        ListItem() {
          this.themeOption('深色模式', 'dark')
        }
        ListItem() {
          this.switchRow('AMOLED 纯黑模式', '深色模式下使用纯黑背景（更省电）',
            this.amoledBlack, async (v: boolean) => {
              this.amoledBlack = v;
              await setAmoledBlack(v);
            })
        }

        // ===== 单集信息 =====
        ListItem() {
          this.sectionHeader('单集信息')
        }
        ListItem() {
          this.switchRow('显示单集封面', '在列表中显示每集单独的封面',
            this.episodeCover, async (v: boolean) => {
              this.episodeCover = v;
              await setEpisodeCover(v);
            })
        }
        ListItem() {
          this.switchRow('显示剩余时间', '播放时显示剩余时间而非总时长',
            this.showTimeLeft, async (v: boolean) => {
              this.showTimeLeft = v;
              await setShowTimeLeft(v);
            })
        }
        ListItem() {
          this.switchRow('剩余时间考虑倍速', '显示的剩余时间按当前播放速度计算',
            this.timeRespectSpeed, async (v: boolean) => {
              this.timeRespectSpeed = v;
              await setTimeRespectSpeed(v);
            })
        }

        // ===== 导航 =====
        ListItem() {
          this.sectionHeader('导航')
        }
        ListItem() {
          this.navRow('默认页面', this.getDefaultPageLabel(), () => {
            this.showDefaultPagePicker();
          })
        }
        ListItem() {
          this.switchRow('底部导航栏', '使用底部导航栏替代侧边栏',
            this.bottomNav, async (v: boolean) => {
              this.bottomNav = v;
              await setBottomNavigation(v);
            })
        }

        // ===== 播放行为 =====
        ListItem() {
          this.sectionHeader('播放行为')
        }
        ListItem() {
          this.switchRow('优先在线播放', '点击单集时优先流式播放而非下载',
            this.streamOverDownload, async (v: boolean) => {
              this.streamOverDownload = v;
              await setStreamOverDownload(v);
            })
        }
        ListItem() {
          this.navRow('下载按钮行为', this.getDownloadButtonLabel(), () => {
            this.showDownloadButtonPicker();
          })
        }

        // ===== 列表排序与操作 =====
        ListItem() {
          this.sectionHeader('列表排序与操作')
        }
        ListItem() {
          this.navRow('全局排序顺序', this.getGlobalSortLabel(), () => {
            this.showGlobalSortPicker();
          })
        }
        ListItem() {
          this.descRow('列表项滑动操作', '左滑：收藏/取消收藏  右滑：下载/播放')
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
      Text(title)
        .fontSize(13)
        .fontColor('#888888')
        .margin({ bottom: 4 })
    }
    .padding({ left: 16, right: 16, top: 20, bottom: 4 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  themeOption(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .layoutWeight(1)
      if (this.currentTheme === value) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor(['#0078C2'])
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => { this.applyTheme(value); })
  }

  @Builder
  switchRow(title: string, subtitle: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#1A1A1A')
        Text(subtitle).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

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
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#CCCCCC'])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => { onClick(); })
  }

  @Builder
  descRow(title: string, subtitle: string) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#1A1A1A')
        Text(subtitle).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  // ===== Logic =====

  async applyTheme(theme: string): Promise<void> {
    this.currentTheme = theme;
    await setTheme(theme);
    try {
      const appCtx = getContext(this).getApplicationContext();
      switch (theme) {
        case 'light':
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          break;
        case 'dark':
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          break;
        default:
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
          break;
      }
    } catch (_e) { /* ignore */ }
  }

  getDefaultPageLabel(): string {
    switch (this.defaultPage) {
      case 'QueueFragment': return '队列';
      case 'InboxFragment': return '收件箱';
      case 'SubscriptionFragment': return '订阅';
      case 'EpisodesFragment': return '单集';
      default: return '首页';
    }
  }

  showDefaultPagePicker(): void {
    ActionSheet.show({
      title: '默认页面',
      message: '启动时显示的页面',
      sheets: [
        { title: '首页', action: () => { this.setPage('HomeFragment'); } },
        { title: '队列', action: () => { this.setPage('QueueFragment'); } },
        { title: '收件箱', action: () => { this.setPage('InboxFragment'); } },
        { title: '订阅', action: () => { this.setPage('SubscriptionFragment'); } },
        { title: '单集', action: () => { this.setPage('EpisodesFragment'); } }
      ]
    });
  }

  async setPage(page: string): Promise<void> {
    this.defaultPage = page;
    await setDefaultPage(page);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }

  getGlobalSortLabel(): string {
    switch (this.globalSortOrder) {
      case 'DATE_OLD_NEW': return '日期(旧→新)';
      case 'TITLE_AZ': return '标题(A-Z)';
      case 'TITLE_ZA': return '标题(Z-A)';
      case 'DURATION_LONG_SHORT': return '时长(长→短)';
      default: return '日期(新→旧)';
    }
  }

  showGlobalSortPicker(): void {
    ActionSheet.show({
      title: '全局排序顺序',
      message: '选择单集列表默认排序方式',
      sheets: [
        { title: '日期(新→旧)', action: () => { this.applyGlobalSort('DATE_NEW_OLD'); } },
        { title: '日期(旧→新)', action: () => { this.applyGlobalSort('DATE_OLD_NEW'); } },
        { title: '标题(A-Z)', action: () => { this.applyGlobalSort('TITLE_AZ'); } },
        { title: '标题(Z-A)', action: () => { this.applyGlobalSort('TITLE_ZA'); } },
        { title: '时长(长→短)', action: () => { this.applyGlobalSort('DURATION_LONG_SHORT'); } }
      ]
    });
  }

  async applyGlobalSort(order: string): Promise<void> {
    this.globalSortOrder = order;
    await setGlobalSortOrder(order);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }

  getDownloadButtonLabel(): string {
    switch (this.downloadButtonAction) {
      case 'ALWAYS_STREAM': return '总是流式播放';
      case 'WIFI_AUTO_DOWNLOAD': return '仅Wi-Fi下自动下载';
      default: return '总是下载';
    }
  }

  showDownloadButtonPicker(): void {
    ActionSheet.show({
      title: '下载按钮行为',
      message: '选择点击下载按钮时的默认行为',
      sheets: [
        { title: '总是流式播放', action: () => { this.applyDownloadAction('ALWAYS_STREAM'); } },
        { title: '总是下载', action: () => { this.applyDownloadAction('ALWAYS_DOWNLOAD'); } },
        { title: '仅Wi-Fi下自动下载', action: () => { this.applyDownloadAction('WIFI_AUTO_DOWNLOAD'); } }
      ]
    });
  }

  async applyDownloadAction(action: string): Promise<void> {
    this.downloadButtonAction = action;
    await setDownloadButtonAction(action);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }
}
