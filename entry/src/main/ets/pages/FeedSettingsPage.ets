import { router, promptAction } from '@kit.ArkUI';
import { Feed, FeedPreferences, AutoDeleteAction, NewEpisodesAction, AutoDownloadSetting } from 'common';
import { getFeed, setFeedPreferences } from 'datastore';

/**
 * Feed 设置页 — 9 个设置项，对照 Android FeedSettingsPreferenceFragment
 */
@Entry
@Component
struct FeedSettingsPage {
  @State feedId: number = 0;
  @State feedTitle: string = '';
  @State feed: Feed | null = null;
  @State prefs: FeedPreferences | null = null;

  // 弹窗状态 — 统一管理，避免多 bindSheet 冲突（PIT: ArkUI 一个组件只能绑一个 bindSheet）
  @State activeSheet: string = '';
  @State showSheet: boolean = false;

  // 跳过弹窗临时值
  @State skipIntroSeconds: number = 0;
  @State skipEndingSeconds: number = 0;

  // 身份验证临时值
  @State authUsername: string = '';
  @State authPassword: string = '';

  // 过滤器临时值
  @State filterInclude: string = '';
  @State filterExclude: string = '';
  @State filterMinDuration: number = -1; // Task-031: 最小时长（秒），-1=不限

  // 标签临时值
  @State tagInput: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.feedId = params['feedId'] as number ?? 0;
      this.feedTitle = params['feedTitle'] as string ?? '';
    }
    this.loadFeed();
  }

  /**
   * Clone FeedPreferences to trigger @State reactivity.
   * ArkTS does not allow object spread {...obj}.
   */
  clonePrefs(src: FeedPreferences): FeedPreferences {
    const copy = new FeedPreferences(src.feedId);
    copy.autoDownload = src.autoDownload;
    copy.keepUpdated = src.keepUpdated;
    copy.autoDeleteAction = src.autoDeleteAction;
    copy.volumeAdaptionSetting = src.volumeAdaptionSetting;
    copy.newEpisodesAction = src.newEpisodesAction;
    copy.username = src.username;
    copy.password = src.password;
    copy.feedPlaybackSpeed = src.feedPlaybackSpeed;
    copy.feedSkipIntro = src.feedSkipIntro;
    copy.feedSkipEnding = src.feedSkipEnding;
    copy.feedSkipSilence = src.feedSkipSilence;
    copy.showEpisodeNotification = src.showEpisodeNotification;
    copy.tags = src.tags;
    copy.filter = src.filter;
    return copy;
  }

  async loadFeed(): Promise<void> {
    this.feed = await getFeed(this.feedId);
    if (this.feed !== null) {
      this.feedTitle = this.feed.getTitle() ?? '';
      if (this.feed.preferences !== null) {
        this.prefs = this.feed.preferences;
      } else {
        this.prefs = new FeedPreferences(this.feedId);
      }
      this.skipIntroSeconds = this.prefs!.feedSkipIntro;
      this.skipEndingSeconds = this.prefs!.feedSkipEnding;
      this.authUsername = this.prefs!.username ?? '';
      this.authPassword = this.prefs!.password ?? '';
      this.filterInclude = this.prefs!.filter.includeFilter;
      this.filterExclude = this.prefs!.filter.excludeFilter;
      this.filterMinDuration = this.prefs!.filter.minimalDuration;
    }
  }

  async savePrefs(): Promise<void> {
    if (this.prefs === null) return;
    try {
      await setFeedPreferences(this.prefs);
      promptAction.showToast({ message: '已保存', duration: 1500 });
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '保存失败: ' + msg, duration: 2000 });
    }
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

        Text(this.feedTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      // 设置列表
      List() {
        // 1. 单集通知 — Switch
        ListItem() {
          this.SwitchRow('单集通知', '新单集发布时推送通知',
            this.prefs?.showEpisodeNotification ?? false, (v: boolean) => {
              if (this.prefs !== null) {
                this.prefs.showEpisodeNotification = v;
                this.savePrefs();
              }
            })
        }

        // 2. 身份验证
        ListItem() {
          this.NavRow('身份验证',
            (this.prefs?.username ?? '').length > 0 ? this.prefs!.username! : '未设置',
            () => { this.openSheet('auth'); })
        }

        // 3. 标签
        ListItem() {
          this.NavRow('标签',
            this.prefs !== null && this.prefs.tags.size > 0
              ? Array.from(this.prefs.tags).join(', ') : '无标签',
            () => { this.openSheet('tags'); })
        }

        // 4. 播放速度
        ListItem() {
          this.NavRow('播放速度',
            this.prefs !== null && this.prefs.feedPlaybackSpeed !== -1
              ? `${this.prefs.feedPlaybackSpeed}x` : '使用全局设置',
            () => { this.openSheet('speed'); })
        }

        // 5. 跳过片头/片尾
        ListItem() {
          this.NavRow('跳过片头/片尾',
            `片头 ${this.prefs?.feedSkipIntro ?? 0}s / 片尾 ${this.prefs?.feedSkipEnding ?? 0}s`,
            () => {
              this.skipIntroSeconds = this.prefs?.feedSkipIntro ?? 0;
              this.skipEndingSeconds = this.prefs?.feedSkipEnding ?? 0;
              this.openSheet('skip');
            })
        }

        // 6. 播放后删除
        ListItem() {
          this.NavRow('播放后删除', this.getAutoDeleteLabel(), () => {
            this.showAutoDeletePicker();
          })
        }

        // 7. 新单集操作
        ListItem() {
          this.NavRow('新单集操作', this.getNewEpisodeActionLabel(), () => {
            this.showNewEpisodeActionPicker();
          })
        }

        // 8. 自动下载 — Switch
        ListItem() {
          this.SwitchRow('自动下载', '自动下载新单集',
            this.prefs !== null && this.prefs.autoDownload === AutoDownloadSetting.ENABLED,
            (v: boolean) => {
              if (this.prefs !== null) {
                this.prefs.autoDownload = v ? AutoDownloadSetting.ENABLED : AutoDownloadSetting.GLOBAL;
                this.savePrefs();
              }
            })
        }

        // 9. 自动下载过滤器
        ListItem() {
          this.NavRow('自动下载过滤器',
            this.getFilterLabel(),
            () => {
              this.filterInclude = this.prefs?.filter.includeFilter ?? '';
              this.filterExclude = this.prefs?.filter.excludeFilter ?? '';
              this.filterMinDuration = this.prefs?.filter.minimalDuration ?? -1;
              this.openSheet('filter');
            })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
    // 统一 bindSheet — ArkUI 一个组件只能绑一个 bindSheet
    .bindSheet($$this.showSheet, () => { this.SheetDispatcher(); }, {
      detents: [SheetSize.FIT_CONTENT],
      showClose: true,
      dragBar: true
    })
  }

  // ===== 弹窗统一管理 =====

  private openSheet(name: string): void {
    this.activeSheet = name;
    this.showSheet = true;
  }

  @Builder
  SheetDispatcher() {
    if (this.activeSheet === 'speed') {
      this.SpeedDialogBuilder()
    } else if (this.activeSheet === 'skip') {
      this.SkipDialogBuilder()
    } else if (this.activeSheet === 'auth') {
      this.AuthDialogBuilder()
    } else if (this.activeSheet === 'tags') {
      this.TagsDialogBuilder()
    } else if (this.activeSheet === 'filter') {
      this.FilterDialogBuilder()
    }
  }

  // ===== 通用行组件 =====

  @Builder
  SwitchRow(title: string, subtitle: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#444444')
          .margin({ top: 2 })
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
  NavRow(title: string, subtitle: string, onClick: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#444444')
          .margin({ top: 2 })
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

  // ===== 标签文本 =====

  getAutoDeleteLabel(): string {
    if (this.prefs === null) return '使用全局设置';
    switch (this.prefs.autoDeleteAction) {
      case AutoDeleteAction.ALWAYS: return '总是删除';
      case AutoDeleteAction.NEVER: return '从不删除';
      default: return '使用全局设置';
    }
  }

  getNewEpisodeActionLabel(): string {
    if (this.prefs === null) return '使用全局设置';
    switch (this.prefs.newEpisodesAction) {
      case NewEpisodesAction.ADD_TO_INBOX: return '加入收件箱';
      case NewEpisodesAction.ADD_TO_QUEUE: return '加入队列';
      case NewEpisodesAction.NOTHING: return '不执行操作';
      default: return '使用全局设置';
    }
  }

  getFilterLabel(): string {
    if (this.prefs === null) return '未设置';
    const inc = this.prefs.filter.includeFilter;
    const exc = this.prefs.filter.excludeFilter;
    const dur = this.prefs.filter.minimalDuration;
    if (inc.length === 0 && exc.length === 0 && dur <= 0) return '未设置';
    const parts: string[] = [];
    if (inc.length > 0) parts.push(`包含: ${inc}`);
    if (exc.length > 0) parts.push(`排除: ${exc}`);
    if (dur > 0) parts.push(`最短 ${dur}s`);
    return parts.join(' / ');
  }

  // ===== ActionSheet 选择器 =====

  showAutoDeletePicker(): void {
    ActionSheet.show({
      title: '播放后删除',
      message: '请选择播放后删除策略',
      sheets: [
        {
          title: '使用全局设置',
          action: () => { this.setAutoDelete(AutoDeleteAction.GLOBAL); }
        },
        {
          title: '总是删除',
          action: () => { this.setAutoDelete(AutoDeleteAction.ALWAYS); }
        },
        {
          title: '从不删除',
          action: () => { this.setAutoDelete(AutoDeleteAction.NEVER); }
        }
      ]
    });
  }

  setAutoDelete(action: AutoDeleteAction): void {
    if (this.prefs !== null) {
      this.prefs.autoDeleteAction = action;
      this.prefs = this.clonePrefs(this.prefs);
      this.savePrefs();
    }
  }

  showNewEpisodeActionPicker(): void {
    ActionSheet.show({
      title: '新单集操作',
      message: '请选择新单集的处理方式',
      sheets: [
        {
          title: '使用全局设置',
          action: () => { this.setNewEpisodeAction(NewEpisodesAction.GLOBAL); }
        },
        {
          title: '加入收件箱',
          action: () => { this.setNewEpisodeAction(NewEpisodesAction.ADD_TO_INBOX); }
        },
        {
          title: '加入队列',
          action: () => { this.setNewEpisodeAction(NewEpisodesAction.ADD_TO_QUEUE); }
        }
      ]
    });
  }

  setNewEpisodeAction(action: NewEpisodesAction): void {
    if (this.prefs !== null) {
      this.prefs.newEpisodesAction = action;
      this.prefs = this.clonePrefs(this.prefs);
      this.savePrefs();
    }
  }

  // ===== 播放速度弹窗 =====

  @Builder
  SpeedDialogBuilder() {
    Column() {
      Text('播放速度')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5], (speed: number) => {
          Button(`${speed}x`)
            .width(72)
            .height(40)
            .margin(6)
            .backgroundColor(this.prefs?.feedPlaybackSpeed === speed ? '#0078C2' : '#F0F0F0')
            .fontColor(this.prefs?.feedPlaybackSpeed === speed ? '#FFFFFF' : '#333333')
            .fontSize(14)
            .borderRadius(8)
            .onClick(() => { this.setPlaybackSpeed(speed); })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Button('使用全局设置')
        .width('80%')
        .height(44)
        .margin({ top: 16 })
        .backgroundColor(this.prefs?.feedPlaybackSpeed === -1 ? '#0078C2' : '#F0F0F0')
        .fontColor(this.prefs?.feedPlaybackSpeed === -1 ? '#FFFFFF' : '#333333')
        .fontSize(14)
        .borderRadius(8)
        .onClick(() => { this.setPlaybackSpeed(-1); })

      Blank().height(24)
    }
    .width('100%')
  }

  setPlaybackSpeed(speed: number): void {
    if (this.prefs !== null) {
      this.prefs.feedPlaybackSpeed = speed;
      this.prefs = this.clonePrefs(this.prefs);
      this.showSheet = false;
      this.savePrefs();
    }
  }

  // ===== 跳过片头/片尾弹窗 =====

  @Builder
  SkipDialogBuilder() {
    Column() {
      Text('自动跳过')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      Row() {
        Text('片头')
          .fontSize(15)
          .width(60)
        TextInput({ text: `${this.skipIntroSeconds}` })
          .type(InputType.Number)
          .width(100)
          .height(40)
          .onChange((v: string) => { this.skipIntroSeconds = parseInt(v) || 0; })
        Text('秒')
          .fontSize(15)
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })

      Row() {
        Text('片尾')
          .fontSize(15)
          .width(60)
        TextInput({ text: `${this.skipEndingSeconds}` })
          .type(InputType.Number)
          .width(100)
          .height(40)
          .onChange((v: string) => { this.skipEndingSeconds = parseInt(v) || 0; })
        Text('秒')
          .fontSize(15)
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .alignItems(VerticalAlign.Center)

      Row() {
        Button('取消')
          .width(100)
          .height(40)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => { this.showSheet = false; })

        Blank().width(24)

        Button('确定')
          .width(100)
          .height(40)
          .backgroundColor('#0078C2')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => { this.saveSkipSettings(); })
      }
      .margin({ top: 24, bottom: 24 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  saveSkipSettings(): void {
    if (this.prefs !== null) {
      this.prefs.feedSkipIntro = this.skipIntroSeconds;
      this.prefs.feedSkipEnding = this.skipEndingSeconds;
      this.prefs = this.clonePrefs(this.prefs);
      this.showSheet = false;
      this.savePrefs();
    }
  }

  // ===== 身份验证弹窗 =====

  @Builder
  AuthDialogBuilder() {
    Column() {
      Text('身份验证')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      TextInput({ placeholder: '用户名', text: this.authUsername })
        .width('80%')
        .height(44)
        .margin({ bottom: 12 })
        .onChange((v: string) => { this.authUsername = v; })

      TextInput({ placeholder: '密码', text: this.authPassword })
        .width('80%')
        .height(44)
        .type(InputType.Password)
        .onChange((v: string) => { this.authPassword = v; })

      Row() {
        Button('取消')
          .width(100)
          .height(40)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => { this.showSheet = false; })

        Blank().width(24)

        Button('保存')
          .width(100)
          .height(40)
          .backgroundColor('#0078C2')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => { this.saveAuth(); })
      }
      .margin({ top: 24, bottom: 24 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  saveAuth(): void {
    if (this.prefs !== null) {
      this.prefs.username = this.authUsername.length > 0 ? this.authUsername : null;
      this.prefs.password = this.authPassword.length > 0 ? this.authPassword : null;
      this.prefs = this.clonePrefs(this.prefs);
      this.showSheet = false;
      this.savePrefs();
    }
  }

  // ===== 标签弹窗 =====

  @Builder
  TagsDialogBuilder() {
    Column() {
      Text('标签')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      // 已有标签（点击删除）
      if (this.prefs !== null && this.prefs.tags.size > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(Array.from(this.prefs!.tags), (tag: string) => {
            Row() {
              Text(tag)
                .fontSize(13)
                .fontColor('#333333')
              Text(' ✕')
                .fontSize(13)
                .fontColor('#999999')
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#F0F0F0')
            .borderRadius(14)
            .margin(4)
            .onClick(() => {
              if (this.prefs !== null) {
                this.prefs.tags.delete(tag);
                this.prefs = this.clonePrefs(this.prefs);
                this.savePrefs();
              }
            })
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 12 })
      }

      // 添加标签
      Row() {
        TextInput({ placeholder: '输入新标签', text: this.tagInput })
          .layoutWeight(1)
          .height(40)
          .onChange((v: string) => { this.tagInput = v; })

        Button('添加')
          .height(40)
          .margin({ left: 8 })
          .backgroundColor('#0078C2')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => {
            if (this.tagInput.trim().length > 0 && this.prefs !== null) {
              this.prefs.tags.add(this.tagInput.trim());
              this.tagInput = '';
              this.prefs = this.clonePrefs(this.prefs);
              this.savePrefs();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Blank().height(24)
    }
    .width('100%')
  }

  // ===== 过滤器弹窗 =====

  @Builder
  FilterDialogBuilder() {
    Column() {
      Text('自动下载过滤器')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      Text('标题包含关键词（用空格分隔）')
        .fontSize(13)
        .fontColor('#444444')
        .width('80%')
        .margin({ bottom: 4 })

      TextInput({ placeholder: '包含关键词', text: this.filterInclude })
        .width('80%')
        .height(44)
        .margin({ bottom: 16 })
        .onChange((v: string) => { this.filterInclude = v; })

      Text('标题不包含关键词（用空格分隔）')
        .fontSize(13)
        .fontColor('#444444')
        .width('80%')
        .margin({ bottom: 4 })

      TextInput({ placeholder: '排除关键词', text: this.filterExclude })
        .width('80%')
        .height(44)
        .onChange((v: string) => { this.filterExclude = v; })

      // Task-031: 最小时长过滤
      Text('最小时长（秒，-1 表示不限）')
        .fontSize(13)
        .fontColor('#444444')
        .width('80%')
        .margin({ top: 16, bottom: 4 })

      TextInput({
        placeholder: '不限',
        text: this.filterMinDuration > 0 ? `${this.filterMinDuration}` : ''
      })
        .width('80%')
        .height(44)
        .type(InputType.Number)
        .onChange((v: string) => {
          const val = parseInt(v, 10);
          this.filterMinDuration = isNaN(val) || val <= 0 ? -1 : val;
        })

      Row() {
        Button('取消')
          .width(100)
          .height(40)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => { this.showSheet = false; })

        Blank().width(24)

        Button('保存')
          .width(100)
          .height(40)
          .backgroundColor('#0078C2')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => { this.saveFilter(); })
      }
      .margin({ top: 24, bottom: 24 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  saveFilter(): void {
    if (this.prefs !== null) {
      this.prefs.filter.includeFilter = this.filterInclude.trim();
      this.prefs.filter.excludeFilter = this.filterExclude.trim();
      this.prefs.filter.minimalDuration = this.filterMinDuration;
      this.prefs = this.clonePrefs(this.prefs);
      this.showSheet = false;
      this.savePrefs();
    }
  }
}
