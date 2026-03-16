import { router, promptAction } from '@kit.ArkUI';
import {
  getPlaybackSpeed, setPlaybackSpeed,
  getFastForwardSecs, setFastForwardSecs,
  getRewindSecs, setRewindSecs,
  isSkipSilence, setSkipSilence,
  isFollowQueue, setFollowQueue,
  isPauseOnHeadsetDisconnect, setPauseOnHeadsetDisconnect,
  isUnpauseOnHeadsetReconnect, setUnpauseOnHeadsetReconnect,
  isUnpauseOnBluetoothReconnect, setUnpauseOnBluetoothReconnect,
  getSmartMarkAsPlayedSecs, setSmartMarkAsPlayedSecs,
  getEnqueueLocation, setEnqueueLocation, EnqueueLocation,
  isEnqueueDownloaded, setEnqueueDownloaded
} from 'datastore';

/**
 * 设置 — 播放
 * 对照 Android PlaybackPreferencesFragment
 */
@Entry
@Component
struct SettingsPlaybackPage {
  @State playbackSpeed: number = 1.0;
  @State fastForwardSecs: number = 30;
  @State rewindSecs: number = 10;
  @State skipSilence: boolean = false;
  @State followQueue: boolean = true;
  @State pauseOnHeadset: boolean = true;
  @State unpauseOnHeadset: boolean = true;
  @State unpauseOnBluetooth: boolean = false;
  @State smartMarkSecs: number = 30;
  @State enqueueLocation: EnqueueLocation = EnqueueLocation.BACK;
  @State enqueueDownloaded: boolean = true;

  // 弹窗
  @State showSpeedSheet: boolean = false;
  @State showFfSheet: boolean = false;
  @State showRwSheet: boolean = false;
  @State showSmartMarkSheet: boolean = false;

  aboutToAppear(): void {
    this.playbackSpeed = getPlaybackSpeed();
    this.fastForwardSecs = getFastForwardSecs();
    this.rewindSecs = getRewindSecs();
    this.skipSilence = isSkipSilence();
    this.followQueue = isFollowQueue();
    this.pauseOnHeadset = isPauseOnHeadsetDisconnect();
    this.unpauseOnHeadset = isUnpauseOnHeadsetReconnect();
    this.unpauseOnBluetooth = isUnpauseOnBluetoothReconnect();
    this.smartMarkSecs = getSmartMarkAsPlayedSecs();
    this.enqueueLocation = getEnqueueLocation();
    this.enqueueDownloaded = isEnqueueDownloaded();
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

        Text('播放')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // ===== 播放控制 =====
        ListItem() { this.sectionHeader('播放控制') }

        ListItem() {
          this.navRow('播放速度', `${this.playbackSpeed.toFixed(2)}x`, () => {
            this.showSpeedSheet = true;
          })
        }
        ListItem() {
          this.navRow('快进秒数', `${this.fastForwardSecs} 秒`, () => {
            this.showFfSheet = true;
          })
        }
        ListItem() {
          this.navRow('倒退秒数', `${this.rewindSecs} 秒`, () => {
            this.showRwSheet = true;
          })
        }
        ListItem() {
          this.switchRow('跳过静音', '自动跳过无声片段',
            this.skipSilence, async (v: boolean) => {
              this.skipSilence = v;
              await setSkipSilence(v);
            })
        }

        // ===== 中断行为 =====
        ListItem() { this.sectionHeader('中断行为') }

        ListItem() {
          this.switchRow('拔出耳机时暂停', '断开有线耳机时暂停播放',
            this.pauseOnHeadset, async (v: boolean) => {
              this.pauseOnHeadset = v;
              await setPauseOnHeadsetDisconnect(v);
            })
        }
        ListItem() {
          this.switchRow('插入耳机时恢复', '连接有线耳机时恢复播放',
            this.unpauseOnHeadset, async (v: boolean) => {
              this.unpauseOnHeadset = v;
              await setUnpauseOnHeadsetReconnect(v);
            })
        }
        ListItem() {
          this.switchRow('蓝牙连接时恢复', '连接蓝牙音频时恢复播放',
            this.unpauseOnBluetooth, async (v: boolean) => {
              this.unpauseOnBluetooth = v;
              await setUnpauseOnBluetoothReconnect(v);
            })
        }

        // ===== 队列 =====
        ListItem() { this.sectionHeader('队列') }

        ListItem() {
          this.switchRow('连续播放', '播完当前集后自动播放队列中下一集',
            this.followQueue, async (v: boolean) => {
              this.followQueue = v;
              await setFollowQueue(v);
            })
        }
        ListItem() {
          this.navRow('入队位置', this.getEnqueueLabel(), () => {
            this.showEnqueuePicker();
          })
        }
        ListItem() {
          this.switchRow('下载后自动入队', '下载完成的单集自动加入队列',
            this.enqueueDownloaded, async (v: boolean) => {
              this.enqueueDownloaded = v;
              await setEnqueueDownloaded(v);
            })
        }
        ListItem() {
          this.navRow('智能标记已播', `剩余 ${this.smartMarkSecs} 秒时自动标记`, () => {
            this.showSmartMarkSheet = true;
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showSpeedSheet, () => { this.SpeedSheetBuilder(); }, {
      detents: [SheetSize.FIT_CONTENT], showClose: true, dragBar: true
    })
    .bindSheet($$this.showFfSheet, () => { this.SecsSheetBuilder('快进秒数',
      [10, 15, 20, 30, 45, 60], this.fastForwardSecs,
      async (v: number) => { this.fastForwardSecs = v; await setFastForwardSecs(v); this.showFfSheet = false; }); }, {
      detents: [SheetSize.FIT_CONTENT], showClose: true, dragBar: true
    })
    .bindSheet($$this.showRwSheet, () => { this.SecsSheetBuilder('倒退秒数',
      [5, 10, 15, 20, 30, 60], this.rewindSecs,
      async (v: number) => { this.rewindSecs = v; await setRewindSecs(v); this.showRwSheet = false; }); }, {
      detents: [SheetSize.FIT_CONTENT], showClose: true, dragBar: true
    })
    .bindSheet($$this.showSmartMarkSheet, () => { this.SecsSheetBuilder('智能标记已播',
      [0, 10, 15, 30, 60, 120], this.smartMarkSecs,
      async (v: number) => { this.smartMarkSecs = v; await setSmartMarkAsPlayedSecs(v); this.showSmartMarkSheet = false; }); }, {
      detents: [SheetSize.FIT_CONTENT], showClose: true, dragBar: true
    })
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

  @Builder
  SpeedSheetBuilder() {
    Column() {
      Text('播放速度').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 16, bottom: 16 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5], (speed: number) => {
          Button(`${speed}x`)
            .width(72).height(40).margin(6)
            .backgroundColor(this.playbackSpeed === speed ? '#0078C2' : '#F0F0F0')
            .fontColor(this.playbackSpeed === speed ? '#FFFFFF' : '#333333')
            .fontSize(14).borderRadius(8)
            .onClick(async () => {
              this.playbackSpeed = speed;
              await setPlaybackSpeed(speed);
              this.showSpeedSheet = false;
              promptAction.showToast({ message: '已保存', duration: 1500 });
            })
        })
      }.width('100%').padding({ left: 16, right: 16 })
      Blank().height(24)
    }.width('100%')
  }

  @Builder
  SecsSheetBuilder(title: string, options: number[], current: number, onSelect: (v: number) => void) {
    Column() {
      Text(title).fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 16, bottom: 16 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(options, (secs: number) => {
          Button(secs === 0 ? '关闭' : `${secs} 秒`)
            .width(80).height(40).margin(6)
            .backgroundColor(current === secs ? '#0078C2' : '#F0F0F0')
            .fontColor(current === secs ? '#FFFFFF' : '#333333')
            .fontSize(14).borderRadius(8)
            .onClick(() => {
              onSelect(secs);
              promptAction.showToast({ message: '已保存', duration: 1500 });
            })
        })
      }.width('100%').padding({ left: 16, right: 16 })
      Blank().height(24)
    }.width('100%')
  }

  // ===== Logic =====

  getEnqueueLabel(): string {
    switch (this.enqueueLocation) {
      case EnqueueLocation.FRONT: return '队列前端';
      case EnqueueLocation.AFTER_CURRENTLY_PLAYING: return '当前播放之后';
      case EnqueueLocation.RANDOM: return '随机';
      default: return '队列末尾';
    }
  }

  showEnqueuePicker(): void {
    ActionSheet.show({
      title: '入队位置',
      message: '新加入队列的单集放在什么位置',
      sheets: [
        { title: '队列末尾', action: () => { this.setEnqueue(EnqueueLocation.BACK); } },
        { title: '队列前端', action: () => { this.setEnqueue(EnqueueLocation.FRONT); } },
        { title: '当前播放之后', action: () => { this.setEnqueue(EnqueueLocation.AFTER_CURRENTLY_PLAYING); } },
        { title: '随机', action: () => { this.setEnqueue(EnqueueLocation.RANDOM); } }
      ]
    });
  }

  async setEnqueue(loc: EnqueueLocation): Promise<void> {
    this.enqueueLocation = loc;
    await setEnqueueLocation(loc);
    promptAction.showToast({ message: '已保存', duration: 1500 });
  }
}
