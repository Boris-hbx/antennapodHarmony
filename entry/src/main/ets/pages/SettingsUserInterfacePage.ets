import { router, promptAction } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import {
  getTheme, setTheme,
  isEpisodeCover, setEpisodeCover,
  isShowTimeLeft, setShowTimeLeft,
  isBottomNavigation, setBottomNavigation,
  getDefaultPage, setDefaultPage,
  isStreamOverDownload, setStreamOverDownload
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

  aboutToAppear(): void {
    this.currentTheme = getTheme();
    this.episodeCover = isEpisodeCover();
    this.showTimeLeft = isShowTimeLeft();
    this.bottomNav = isBottomNavigation();
    this.defaultPage = getDefaultPage();
    this.streamOverDownload = isStreamOverDownload();
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
}
