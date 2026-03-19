import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { ShareSheet } from '../components/ShareSheet';
import { getController } from '../entryability/EntryAbility';
import { EventBus, PLAYBACK_POSITION, PLAYER_STATUS, TAG_FAVORITE, PlayState } from 'common';
import type { PlaybackPositionData } from 'common';
import { SLEEP_TIMER_UPDATE } from 'playback';
import type { SleepTimerData } from 'playback';
import {
  getFastForwardSecs, getRewindSecs, getPlaybackSpeed, getPlaybackSpeedArray,
  addFavoriteItem, removeFavoriteItem, getFeedItem, markItemPlayed,
  isSleepTimerAutoEnable, setSleepTimerAutoEnable,
  getSleepTimerAutoEnableFrom, setSleepTimerAutoEnableFrom,
  getSleepTimerAutoEnableTo, setSleepTimerAutoEnableTo,
  deleteFeedMediaOfItem
} from 'datastore';

/**
 * 全屏播放器 — 独立路由页面，从 PlaybackController 单例读取当前播放状态
 */
@Entry
@Component
struct FullPlayerPage {
  build() {
    Column() {
      FullPlayerContent({
        onClose: () => { router.back(); }
      })
    }
  }
}

@Component
export struct FullPlayerContent {
  onClose?: () => void;

  @State title: string = '';
  @State feedTitle: string = '';
  @State imageUrl: string = '';
  @State positionMs: number = 0;
  @State durationMs: number = 0;
  @State isPlaying: boolean = false;
  @State currentSpeed: number = 1.0;
  @State showSheet: boolean = false;
  @State activeSheet: string = '';
  @State showSleepTimer: boolean = false;
  @State sleepTimerLeft: number = 0;
  @State sleepTimerActive: boolean = false;
  @State isSeeking: boolean = false;
  @State seekPosition: number = 0;
  @State showTimeLeft: boolean = false;
  @State isFavorite: boolean = false;
  @State showShareSheet: boolean = false;
  @State sleepTimerInput: string = '15';
  @State pubDateStr: string = '';
  @State itemLink: string = '';
  @State mediaUrl: string = '';
  @State currentItemId: number = 0;
  @State isBuffering: boolean = false;
  @State feedId: number = 0;

  // Task-026: 睡眠定时自动启用
  @State autoSleepEnabled: boolean = false;
  @State autoSleepStartHour: number = 22;
  @State autoSleepEndHour: number = 7;

  private positionCallback: (data: PlaybackPositionData) => void = (data: PlaybackPositionData) => {
    if (!this.isSeeking) {
      this.positionMs = data.position;
      this.durationMs = data.duration;
    }
  };
  private statusCallback: () => void = () => {
    this.isPlaying = getController().isPlaying();
  };
  private sleepCallback: (data: SleepTimerData) => void = (data: SleepTimerData) => {
    this.sleepTimerLeft = data.timeLeft;
    this.sleepTimerActive = data.isActive;
  };

  aboutToAppear(): void {
    // Task-034: 直接从 PlaybackController 读取当前播放状态，不再依赖 router params
    const ctrl = getController();
    const item = ctrl.getCurrentItem();
    const feed = ctrl.getCurrentFeed();
    const media = ctrl.getCurrentMedia();
    if (item !== null) {
      this.title = item.title ?? '';
      this.currentItemId = item.id;
      this.isFavorite = item.isFavorite();
      this.imageUrl = item.getImageLocation() ?? (feed !== null ? (feed.imageUrl ?? '') : '');
      this.itemLink = item.link ?? '';
      this.feedId = item.feedId;
      if (item.pubDate !== null) {
        const d = item.pubDate;
        this.pubDateStr = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
      }
    }
    if (feed !== null) {
      this.feedTitle = feed.getTitle() ?? '';
    }
    if (media !== null) {
      this.mediaUrl = media.downloadUrl ?? '';
    }
    this.positionMs = ctrl.getPosition();
    this.durationMs = ctrl.getDuration();
    this.isPlaying = ctrl.isPlaying();
    this.currentSpeed = getPlaybackSpeed();
    this.autoSleepEnabled = isSleepTimerAutoEnable();
    this.autoSleepStartHour = getSleepTimerAutoEnableFrom();
    this.autoSleepEndHour = getSleepTimerAutoEnableTo();
    EventBus.on<PlaybackPositionData>(PLAYBACK_POSITION, this.positionCallback);
    EventBus.on<void>(PLAYER_STATUS, this.statusCallback);
    EventBus.on<SleepTimerData>(SLEEP_TIMER_UPDATE, this.sleepCallback);
  }

  aboutToDisappear(): void {
    EventBus.off(PLAYBACK_POSITION, this.positionCallback);
    EventBus.off(PLAYER_STATUS, this.statusCallback);
    EventBus.off(SLEEP_TIMER_UPDATE, this.sleepCallback);
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(24)
            .fontColor(['#000000'])
        }
        .width(48).height(56)
        .onClick(() => { this.onClose?.(); })

        Blank()

        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph(this.isFavorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(24)
            .fontColor([this.isFavorite ? '#FFC107' : '#000000'])
        }
        .width(48).height(56)
        .onClick(() => { this.toggleFavorite(); })

        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.timer'))
            .fontSize(24)
            .fontColor([this.sleepTimerActive ? '#0078C2' : '#000000'])
        }
        .width(48).height(56)
        .onClick(() => { this.showSleepTimer = !this.showSleepTimer; })

        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(24)
            .fontColor(['#000000'])
        }
        .width(48).height(56)
        .onClick(() => { this.showShareSheet = !this.showShareSheet; this.showSleepTimer = false; })

        // Task-026: ⋮ 更多菜单
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
            .fontSize(24)
            .fontColor(['#000000'])
        }
        .width(48).height(56)
        .bindMenu([
          {
            value: '标记已播',
            action: () => { this.togglePlayed(); }
          },
          {
            value: '分享',
            action: () => { this.showShareSheet = true; }
          },
          {
            value: '跳转播客详情',
            action: () => { this.goToFeedDetail(); }
          },
          {
            value: '删除本地文件',
            action: () => { this.confirmDeleteLocal(); }
          },
        ])
      }
      .width('100%')
      .height(56)

      // 封面区
      Column() {
        if (this.imageUrl.length > 0) {
          Image(this.imageUrl)
            .width('100%')
            .aspectRatio(1)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .shadow({ radius: 16, color: '#30000000', offsetY: 8 })
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.mic'))
              .fontSize(80)
              .fontColor(['#AAAAAA'])
          }
          .width('100%')
          .aspectRatio(1)
          .borderRadius(16)
          .backgroundColor('#F0F0F0')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 32, right: 32 })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 信息区
      Column() {
        Text(this.pubDateStr.length > 0 ? `${this.feedTitle} · ${this.pubDateStr}` : this.feedTitle)
          .fontSize(14)
          .fontColor('#444444')
          .maxLines(1)
          .textAlign(TextAlign.Center)

        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Normal)
          .fontColor('#000000')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })

        Button('ⓘ 单集说明')
          .type(ButtonType.Normal)
          .height(36)
          .fontSize(16)
          .fontColor('#444444')
          .backgroundColor('transparent')
          .borderWidth(1)
          .borderColor('#BFBFBF')
          .borderRadius(18)
          .constraintSize({ minWidth: 150 })
          .margin({ top: 10 })
          .onClick(() => {
            if (this.currentItemId > 0) {
              router.pushUrl({ url: 'pages/EpisodeDetailPage', params: { itemId: this.currentItemId } });
            }
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .alignItems(HorizontalAlign.Center)

      // 进度条
      Column() {
        if (this.isSeeking) {
          Text(this.formatTime(this.seekPosition))
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#333333')
            .borderRadius(8)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .margin({ bottom: 4 })
        } else {
          Column().height(32)
        }

        Slider({
          value: this.isSeeking ? this.seekPosition : this.positionMs,
          min: 0,
          max: this.durationMs > 0 ? this.durationMs : 1,
          step: 1000
        })
          .width('100%')
          .trackThickness(4)
          .selectedColor('#0078C2')
          .trackColor('#D0D5DA')
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Begin) {
              this.isSeeking = true;
              this.seekPosition = value;
            } else if (mode === SliderChangeMode.Moving) {
              this.seekPosition = value;
            } else if (mode === SliderChangeMode.End) {
              this.isSeeking = false;
              this.positionMs = value;
              getController().seekTo(value);
            }
          })

        Row() {
          Text(this.formatTime(this.isSeeking ? this.seekPosition : this.positionMs))
            .fontSize(12)
            .fontColor('#444444')
          Blank()
          Text(this.showTimeLeft
            ? '-' + this.formatTime(this.durationMs - (this.isSeeking ? this.seekPosition : this.positionMs))
            : this.formatTime(this.durationMs))
            .fontSize(12)
            .fontColor('#444444')
            .onClick(() => { this.showTimeLeft = !this.showTimeLeft; })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12 })
      .alignItems(HorizontalAlign.Center)

      // 控制按钮行
      Row() {
        // Task-026: 倍速按钮 — 点击弹出弹窗而非直接循环
        Column() {
          SymbolGlyph($r('sys.symbol.timer'))
            .fontSize(22)
            .fontColor(['#000000'])
          Text(`${this.currentSpeed.toFixed(2)}`)
            .fontSize(10)
            .fontColor('#444444')
            .margin({ top: 2 })
        }
        .width(48).height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.activeSheet = 'speed'; this.showSheet = true; })

        Blank()

        // 快退
        Column() {
          SymbolGlyph($r('sys.symbol.gobackward_15'))
            .fontSize(24)
            .fontColor(['#000000'])
          Text(`${getRewindSecs()}`)
            .fontSize(10)
            .fontColor('#444444')
            .margin({ top: 2 })
        }
        .width(48).height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { getController().seekDelta(-getRewindSecs() * 1000); })

        // 播放/暂停
        Stack() {
          Progress({ value: 0, total: 100, type: ProgressType.Ring })
            .width(64)
            .height(64)
            .color('#0078C2')
            .backgroundColor('transparent')
            .style({ strokeWidth: 3 })
            .visibility(this.isBuffering ? Visibility.Visible : Visibility.Hidden)
          SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(32)
            .fontColor(['#000000'])
        }
        .width(64).height(64)
        .borderRadius(32)
        .borderWidth(2)
        .borderColor('#000000')
        .backgroundColor(Color.White)
        .margin({ left: 12, right: 12 })
        .onClick(() => { getController().playPause(); })

        // 快进
        Column() {
          SymbolGlyph($r('sys.symbol.goforward_30'))
            .fontSize(24)
            .fontColor(['#000000'])
          Text(`${getFastForwardSecs()}`)
            .fontSize(10)
            .fontColor('#444444')
            .margin({ top: 2 })
        }
        .width(48).height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { getController().seekDelta(getFastForwardSecs() * 1000); })

        Blank()

        // 下一集
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(22)
            .fontColor(['#000000'])
        }
        .width(48).height(48)
        .onClick(() => { getController().skip(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })
      .margin({ bottom: 24 })

      // 睡眠定时器
      if (this.showSleepTimer) {
        Column() {
          if (this.sleepTimerActive) {
            Text(this.formatTime(this.sleepTimerLeft))
              .fontSize(32).fontWeight(FontWeight.Bold).fontColor('#0078C2').margin({ bottom: 12 })
            Row() {
              Button('+5').type(ButtonType.Normal).height(32).fontSize(13).fontColor('#0078C2')
                .backgroundColor('#D6E6F3').borderRadius(16).margin({ right: 8 })
                .onClick(() => { getController().setSleepTimer(this.sleepTimerLeft + 300000); })
              Button('+10').type(ButtonType.Normal).height(32).fontSize(13).fontColor('#0078C2')
                .backgroundColor('#D6E6F3').borderRadius(16).margin({ right: 8 })
                .onClick(() => { getController().setSleepTimer(this.sleepTimerLeft + 600000); })
              Button('+30').type(ButtonType.Normal).height(32).fontSize(13).fontColor('#0078C2')
                .backgroundColor('#D6E6F3').borderRadius(16)
                .onClick(() => { getController().setSleepTimer(this.sleepTimerLeft + 1800000); })
            }
            Button('取消定时器')
              .type(ButtonType.Normal).width('80%').height(40).fontSize(14).fontColor('#CF1800')
              .backgroundColor('#FFEBEE').borderRadius(20).margin({ top: 12 })
              .onClick(() => { getController().cancelSleepTimer(); this.showSleepTimer = false; })
          } else {
            Text('睡眠定时器').fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
            Row() {
              TextInput({ text: this.sleepTimerInput, placeholder: '15' })
                .type(InputType.Number).width(80).height(40).fontSize(18)
                .textAlign(TextAlign.Center).borderRadius(8)
                .onChange((value: string) => { this.sleepTimerInput = value; })
              Text('分钟').fontSize(14).fontColor('#444444').margin({ left: 8 })
            }
            .margin({ bottom: 12 })
            Button('设置睡眠定时器')
              .type(ButtonType.Normal).width('80%').height(44).fontSize(15)
              .fontColor('#FFFFFF').backgroundColor('#0078C2').borderRadius(22)
              .onClick(() => {
                const mins = parseInt(this.sleepTimerInput, 10);
                if (!isNaN(mins) && mins > 0) {
                  getController().setSleepTimer(mins * 60 * 1000);
                  this.showSleepTimer = false;
                }
              })
            Row() {
              ForEach([15, 30, 45, 60, 90], (mins: number) => {
                Text(`${mins}`).fontSize(13).fontColor('#0078C2')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor('#D6E6F3').borderRadius(14).margin({ right: 6 })
                  .onClick(() => {
                    this.sleepTimerInput = mins.toString();
                    getController().setSleepTimer(mins * 60 * 1000);
                    this.showSleepTimer = false;
                  })
              }, (mins: number) => mins.toString())
            }
            .margin({ top: 12 })
          }

          // Task-026: 自动启用时间范围
          Divider().margin({ top: 16, bottom: 12 })
          Row() {
            Text('自动启用').fontSize(14).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.autoSleepEnabled })
              .onChange((isOn: boolean) => {
                this.autoSleepEnabled = isOn;
                setSleepTimerAutoEnable(isOn);
              })
          }
          .width('90%')
          .padding({ top: 4, bottom: 4 })

          if (this.autoSleepEnabled) {
            Row() {
              Text('时间范围').fontSize(14).fontColor('#666666').layoutWeight(1)
              Text(`${this.padHour(this.autoSleepStartHour)}:00 - ${this.padHour(this.autoSleepEndHour)}:00`)
                .fontSize(14)
                .fontColor('#0078C2')
                .onClick(() => { this.activeSheet = 'autoSleep'; this.showSheet = true; })
            }
            .width('90%')
            .padding({ top: 4, bottom: 8 })
          }
        }
        .width('100%').padding(16).backgroundColor('#F5F7FA').alignItems(HorizontalAlign.Center)
      }

      // 分享弹窗
      if (this.showShareSheet) {
        ShareSheet({
          feedTitle: this.feedTitle,
          episodeTitle: this.title,
          episodeLink: this.itemLink,
          mediaUrl: this.mediaUrl,
          isDownloaded: (getController().getCurrentMedia()?.localFileUrl ?? '').length > 0,
          localFilePath: getController().getCurrentMedia()?.localFileUrl ?? '',
          positionMs: this.positionMs,
          onClose: () => { this.showShareSheet = false; }
        })
      }

      Column().height(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F9FCFF')
    // 统一 bindSheet — ArkUI 一个组件只能绑一个 bindSheet
    .bindSheet($$this.showSheet, () => { this.SheetDispatcher(); }, { detents: [SheetSize.FIT_CONTENT], showClose: true, dragBar: true })
  }

  // ===== 弹窗统一分发 =====
  @Builder SheetDispatcher() {
    if (this.activeSheet === 'speed') {
      this.SpeedSheetBuilder()
    } else if (this.activeSheet === 'autoSleep') {
      this.AutoSleepTimeSheetBuilder()
    }
  }

  // ===== Task-026: 倍速选择弹窗（6 档固定速度）=====
  @Builder SpeedSheetBuilder() {
    Column() {
      Text('播放速度').fontSize(18).fontWeight(FontWeight.Bold).padding(16)

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], (speed: number) => {
          Button(`${speed}x`)
            .width(88).height(40).margin(6)
            .type(ButtonType.Normal)
            .borderRadius(20)
            .backgroundColor(Math.abs(this.currentSpeed - speed) < 0.01 ? '#0078C2' : '#F0F0F0')
            .fontColor(Math.abs(this.currentSpeed - speed) < 0.01 ? '#FFFFFF' : '#333333')
            .fontSize(15)
            .onClick(() => {
              this.currentSpeed = speed;
              getController().setSpeed(speed);
              this.showSheet = false;
            })
        }, (speed: number) => speed.toString())
      }.padding(16)

      Text('注：受平台限制，仅支持以上 6 档速度')
        .fontSize(12).fontColor('#888888').padding({ left: 16, bottom: 16 })
    }
  }

  // ===== Task-026: 自动启用时间范围弹窗 =====
  @Builder AutoSleepTimeSheetBuilder() {
    Column() {
      Text('设置自动启用时间范围').fontSize(16).fontWeight(FontWeight.Bold).padding(16)

      Row() {
        Text('开始时间').fontSize(14).width(80)
        Counter() {
          Text(`${this.padHour(this.autoSleepStartHour)}:00`).fontSize(16)
        }
        .onInc(() => { this.autoSleepStartHour = (this.autoSleepStartHour + 1) % 24; })
        .onDec(() => { this.autoSleepStartHour = (this.autoSleepStartHour + 23) % 24; })
      }
      .width('90%')
      .padding({ top: 12, bottom: 8 })

      Row() {
        Text('结束时间').fontSize(14).width(80)
        Counter() {
          Text(`${this.padHour(this.autoSleepEndHour)}:00`).fontSize(16)
        }
        .onInc(() => { this.autoSleepEndHour = (this.autoSleepEndHour + 1) % 24; })
        .onDec(() => { this.autoSleepEndHour = (this.autoSleepEndHour + 23) % 24; })
      }
      .width('90%')
      .padding({ top: 8, bottom: 16 })

      Button('确定')
        .width('80%').height(40).fontSize(15)
        .fontColor('#FFFFFF').backgroundColor('#0078C2').borderRadius(20)
        .margin({ bottom: 16 })
        .onClick(async () => {
          await setSleepTimerAutoEnableFrom(this.autoSleepStartHour);
          await setSleepTimerAutoEnableTo(this.autoSleepEndHour);
          this.showSheet = false;
        })
    }
  }

  // ===== 操作方法 =====
  async toggleFavorite(): Promise<void> {
    if (this.currentItemId <= 0) return;
    try {
      const item = await getFeedItem(this.currentItemId);
      if (item === null) return;
      if (this.isFavorite) {
        await removeFavoriteItem(item);
        this.isFavorite = false;
        promptAction.showToast({ message: '已取消收藏', duration: 1500 });
      } else {
        await addFavoriteItem(item);
        this.isFavorite = true;
        promptAction.showToast({ message: '已收藏', duration: 1500 });
      }
    } catch (_e) { /* ignore */ }
  }

  async togglePlayed(): Promise<void> {
    if (this.currentItemId <= 0) return;
    try {
      const item = await getFeedItem(this.currentItemId);
      if (item === null) return;
      const newState = item.isPlayed() ? PlayState.UNPLAYED : PlayState.PLAYED;
      await markItemPlayed(this.currentItemId, newState);
      const msg = newState === PlayState.PLAYED ? '已标记为已播' : '已标记为未播';
      promptAction.showToast({ message: msg, duration: 1500 });
    } catch (_e) { /* ignore */ }
  }

  goToFeedDetail(): void {
    if (this.feedId > 0) {
      router.pushUrl({
        url: 'pages/EpisodeListPage',
        params: { feedId: this.feedId, feedTitle: this.feedTitle }
      });
    }
  }

  confirmDeleteLocal(): void {
    if (this.currentItemId <= 0) return;
    AlertDialog.show({
      title: '删除本地文件',
      message: '确定要删除此单集的本地文件吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#F44336',
        action: async () => {
          await deleteFeedMediaOfItem(this.currentItemId);
          promptAction.showToast({ message: '已删除本地文件', duration: 1500 });
        }
      }
    });
  }

  shareEpisode(): void {
    const shareText = `${this.feedTitle}: ${this.title}\n${this.itemLink}`;
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, shareText);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
      promptAction.showToast({ message: '已复制到剪贴板', duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  padHour(h: number): string {
    return h < 10 ? `0${h}` : `${h}`;
  }

  formatTime(ms: number): string {
    if (ms <= 0) return '0:00';
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    const s = totalSec % 60;
    const sStr = s.toString().padStart(2, '0');
    if (h > 0) {
      const mStr = m.toString().padStart(2, '0');
      return `${h}:${mStr}:${sStr}`;
    }
    return `${m}:${sStr}`;
  }
}
