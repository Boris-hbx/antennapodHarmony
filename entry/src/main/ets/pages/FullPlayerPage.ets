import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { ShareSheet } from '../components/ShareSheet';
import { getController } from '../entryability/EntryAbility';
import { EventBus, PLAYBACK_POSITION, PLAYER_STATUS, TAG_FAVORITE } from 'common';
import type { PlaybackPositionData } from 'common';
import { SLEEP_TIMER_UPDATE } from 'playback';
import type { SleepTimerData } from 'playback';
import {
  getFastForwardSecs, getRewindSecs, getPlaybackSpeed, getPlaybackSpeedArray,
  addFavoriteItem, removeFavoriteItem, getFeedItem
} from 'datastore';

/**
 * 全屏播放器页面（#16 PL1-PL9 精确对标 Android AudioPlayerFragment）
 */
@Entry
@Component
struct FullPlayerPage {
  @State title: string = '';
  @State feedTitle: string = '';
  @State imageUrl: string = '';
  @State positionMs: number = 0;
  @State durationMs: number = 0;
  @State isPlaying: boolean = false;
  @State currentSpeed: number = 1.0;
  @State showSpeedPicker: boolean = false;
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
    const params = router.getParams() as Record<string, Object>;
    if (params !== null && params !== undefined) {
      this.title = params['title'] as string ?? '';
      this.feedTitle = params['feedTitle'] as string ?? '';
      this.imageUrl = params['imageUrl'] as string ?? '';
      this.positionMs = params['position'] as number ?? 0;
      this.durationMs = params['duration'] as number ?? 0;
      this.isPlaying = params['isPlaying'] as boolean ?? false;
      this.isFavorite = params['isFavorite'] as boolean ?? false;
      this.pubDateStr = params['pubDate'] as string ?? '';
      this.itemLink = params['itemLink'] as string ?? '';
      this.mediaUrl = params['mediaUrl'] as string ?? '';
      this.currentItemId = params['itemId'] as number ?? 0;
    }
    this.currentSpeed = getPlaybackSpeed();
    this.isPlaying = getController().isPlaying();
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
      // PL7: 顶栏 56vp + 图标统一用 action_icon_color
      Row() {
        Text('˅')
          .fontSize(28)
          .fontColor('#000000')
          .width(48).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); })

        Blank()

        Text(this.isFavorite ? '★' : '☆')
          .fontSize(22)
          .fontColor(this.isFavorite ? '#FFC107' : '#000000')
          .width(48).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.toggleFavorite(); })

        Text('zzᶻ')
          .fontSize(14)
          .fontColor(this.sleepTimerActive ? '#0078C2' : '#000000')
          .fontWeight(FontWeight.Bold)
          .width(48).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showSleepTimer = !this.showSleepTimer; this.showSpeedPicker = false; })

        Text('↗')
          .fontSize(20)
          .fontColor('#000000')
          .width(48).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showShareSheet = !this.showShareSheet; this.showSleepTimer = false; this.showSpeedPicker = false; })

        Text('⋮')
          .fontSize(22)
          .fontColor('#000000')
          .width(48).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showSpeedPicker = !this.showSpeedPicker; this.showSleepTimer = false; })
      }
      .width('100%')
      .height(56)

      // PL4: 封面区 — 水平 margin=32vp
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
            Text('🎙️')
              .fontSize(80)
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

      // PL2: 信息区 — 播客名 14fp + 标题 14fp
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

        // PL3: 单集说明按钮 36vp, 16fp, 最小宽度 150vp
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

      // PL8: 进度条 — selectedColor 用主色，时间用 #444444
      Column() {
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

      // PL1+PL6: 控制按钮行 — 48vp 按钮, 64vp 播放(透明底无边框), marginBottom=24
      Row() {
        // 倍速 48x48
        Column() {
          Text('⏲')
            .fontSize(22)
            .fontColor('#000000')
          Text(`${this.currentSpeed.toFixed(2)}`)
            .fontSize(10)
            .fontColor('#444444')
            .margin({ top: 2 })
        }
        .width(48).height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showSpeedPicker = !this.showSpeedPicker; this.showSleepTimer = false; })

        Blank()

        // 快退 48x48
        Column() {
          Text('◁◁')
            .fontSize(24)
            .fontColor('#000000')
          Text(`${getRewindSecs()}`)
            .fontSize(10)
            .fontColor('#444444')
            .margin({ top: 2 })
        }
        .width(48).height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { getController().seekDelta(-getRewindSecs() * 1000); })

        // PL1: 播放/暂停 64x64 — 透明底+深色图标, 无边框无阴影
        Text(this.isPlaying ? '⏸' : '▶')
          .fontSize(40)
          .fontColor('#000000')
          .width(64).height(64)
          .textAlign(TextAlign.Center)
          .margin({ left: 12, right: 12 })
          .onClick(() => { getController().playPause(); })

        // 快进 48x48
        Column() {
          Text('▷▷')
            .fontSize(24)
            .fontColor('#000000')
          Text(`${getFastForwardSecs()}`)
            .fontSize(10)
            .fontColor('#444444')
            .margin({ top: 2 })
        }
        .width(48).height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { getController().seekDelta(getFastForwardSecs() * 1000); })

        Blank()

        // 跳过 48x48
        Text('⏭')
          .fontSize(22)
          .fontColor('#000000')
          .width(48).height(48)
          .textAlign(TextAlign.Center)
          .onClick(() => { getController().skip(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })
      .margin({ bottom: 24 })

      // 倍速选择器
      if (this.showSpeedPicker) {
        Row() {
          ForEach(getPlaybackSpeedArray(), (speed: number) => {
            Text(`${speed.toFixed(1)}x`)
              .fontSize(14)
              .fontColor(Math.abs(this.currentSpeed - speed) < 0.01 ? '#0078C2' : '#444444')
              .fontWeight(Math.abs(this.currentSpeed - speed) < 0.01 ? FontWeight.Bold : FontWeight.Normal)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onClick(() => {
                this.currentSpeed = speed;
                getController().setSpeed(speed);
                this.showSpeedPicker = false;
              })
          }, (speed: number) => speed.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F7FA')
        .padding(8)
      }

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
          isDownloaded: false,
          positionMs: this.positionMs,
          onClose: () => { this.showShareSheet = false; }
        })
      }

      Column().height(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F9FCFF')
  }

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
