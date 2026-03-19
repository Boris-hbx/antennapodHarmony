import { router } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { HomePage } from './HomePage';
import { SubscriptionsPage } from './SubscriptionsPage';
import { InboxPage } from './InboxPage';
import { QueuePage } from './QueuePage';
import { MorePage } from './MorePage';
import { MiniPlayer } from '../components/MiniPlayer';
import { EventBus, PLAYBACK_POSITION, PLAYER_STATUS } from 'common';
import type { PlaybackPositionData } from 'common';
import { getFastForwardSecs, getRewindSecs } from 'datastore';

/**
 * 主页面 — Tabs + MiniPlayer 架构（ADR-002）
 *
 * 5 个 Tab：首页 / 订阅 / 收件箱 / 队列 / 更多
 * 底部常驻 MiniPlayer（有媒体播放时显示）
 * MiniPlayer 通过 EventBus 监听 PLAYBACK_POSITION + PLAYER_STATUS 实时更新
 */
@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  private tabController: TabsController = new TabsController();
  @State miniPlayerVisible: boolean = false;
  @State miniPlayerTitle: string = '';
  @State miniPlayerFeedTitle: string = '';
  @State miniPlayerIsPlaying: boolean = false;
  @State miniPlayerProgress: number = 0;
  @State miniPlayerImageUrl: string = '';

  private positionCallback: (data: PlaybackPositionData) => void = (data: PlaybackPositionData) => {
    // 更新进度
    this.miniPlayerProgress = data.duration > 0 ? data.position / data.duration : 0;
    // 第一次收到位置事件时，刷新元信息并显示
    if (!this.miniPlayerVisible) {
      this.miniPlayerVisible = true;
      this.refreshMiniPlayerInfo();
    }
  };

  private statusCallback: () => void = () => {
    const ctrl = getController();
    this.miniPlayerIsPlaying = ctrl.isPlaying();
    const item = ctrl.getCurrentItem();
    if (item !== null) {
      this.miniPlayerVisible = true;
      this.refreshMiniPlayerInfo();
    } else {
      // 播放停止且没有当前 item → 隐藏
      this.miniPlayerVisible = false;
    }
  };

  private refreshMiniPlayerInfo(): void {
    const ctrl = getController();
    const item = ctrl.getCurrentItem();
    const feed = ctrl.getCurrentFeed();
    if (item !== null) {
      this.miniPlayerTitle = item.title ?? '';
      this.miniPlayerFeedTitle = feed !== null ? (feed.getTitle() ?? '') : '';
      this.miniPlayerImageUrl = item.getImageLocation() ?? (feed !== null ? (feed.imageUrl ?? '') : '');
      this.miniPlayerIsPlaying = ctrl.isPlaying();
    }
  }

  aboutToAppear(): void {
    // EventBus 监听播放位置 + 状态
    EventBus.on<PlaybackPositionData>(PLAYBACK_POSITION, this.positionCallback);
    EventBus.on<void>(PLAYER_STATUS, this.statusCallback);

    // 若 App 启动时已有播放内容（后台恢复），立刻刷新 MiniPlayer
    const item = getController().getCurrentItem();
    if (item !== null) {
      this.miniPlayerVisible = true;
      this.refreshMiniPlayerInfo();
    }

    // 处理通知点击跳转（冷启动）
    const pendingPage = AppStorage.get<string>('pendingNotificationPage');
    if (pendingPage !== undefined && pendingPage.length > 0) {
      AppStorage.delete('pendingNotificationPage');
      const params: Record<string, Object> = {};
      const feedId = AppStorage.get<number>('pendingNotificationFeedId');
      if (feedId !== undefined) {
        params['feedId'] = feedId;
        AppStorage.delete('pendingNotificationFeedId');
      }
      const feedTitle = AppStorage.get<string>('pendingNotificationFeedTitle');
      if (feedTitle !== undefined) {
        params['feedTitle'] = feedTitle;
        AppStorage.delete('pendingNotificationFeedTitle');
      }
      // 延迟跳转，等页面渲染完成
      setTimeout(() => {
        router.pushUrl({ url: pendingPage, params: params });
      }, 300);
    }
  }

  aboutToDisappear(): void {
    EventBus.off(PLAYBACK_POSITION, this.positionCallback);
    EventBus.off(PLAYER_STATUS, this.statusCallback);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 主内容区 — Tabs
      Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex, controller: this.tabController }) {
        TabContent() {
          HomePage({
            onSwitchTab: (index: number) => {
              this.currentTabIndex = index;
              this.tabController.changeIndex(index);
            }
          })
        }
        .tabBar(this.tabBarBuilder($r('app.string.tab_home'), 0))
        .padding({ bottom: this.miniPlayerVisible ? 80 : 0 })

        TabContent() {
          QueuePage()
        }
        .tabBar(this.tabBarBuilder($r('app.string.tab_queue'), 1))
        .padding({ bottom: this.miniPlayerVisible ? 80 : 0 })

        TabContent() {
          InboxPage()
        }
        .tabBar(this.tabBarBuilder($r('app.string.tab_inbox'), 2))
        .padding({ bottom: this.miniPlayerVisible ? 80 : 0 })

        TabContent() {
          SubscriptionsPage()
        }
        .tabBar(this.tabBarBuilder($r('app.string.tab_subscriptions'), 3))
        .padding({ bottom: this.miniPlayerVisible ? 80 : 0 })

        TabContent() {
          MorePage()
        }
        .tabBar(this.tabBarBuilder($r('app.string.tab_more'), 4))
        .padding({ bottom: this.miniPlayerVisible ? 80 : 0 })
      }
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentTabIndex = index;
      })
      .width('100%')
      .height('100%')

      // 迷你播放器 — 位于 Tab Bar 上方
      Column() {
        MiniPlayer({
          isVisible: this.miniPlayerVisible,
          title: this.miniPlayerTitle,
          feedTitle: this.miniPlayerFeedTitle,
          imageUrl: this.miniPlayerImageUrl,
          isPlaying: this.miniPlayerIsPlaying,
          progress: this.miniPlayerProgress,
          onPlayPause: () => {
            getController().playPause();
          },
          onRewind: () => {
            getController().seekDelta(-getRewindSecs() * 1000);
          },
          onFastForward: () => {
            getController().seekDelta(getFastForwardSecs() * 1000);
          },
          onDismiss: () => {
            // 左右滑动消失：暂停播放 + 隐藏 MiniPlayer（对标 Android STATE_HIDDEN）
            getController().pause();
            this.miniPlayerVisible = false;
          },
          onTap: () => {
            router.pushUrl({ url: 'pages/FullPlayerPage' });
          }
        })
      }
      .margin({ bottom: 80 }) // Tab bar 高度 (M3 NavigationBar)
    }
    .width('100%')
    .height('100%')
  }

  // DR-001: 使用 HarmonyOS 系统符号替代 emoji
  private tabSymbols: Resource[] = [
    $r('sys.symbol.house'),                              // 首页
    $r('sys.symbol.music_note_list'),                    // 队列
    $r('sys.symbol.envelope'),                           // 收件箱
    $r('sys.symbol.circle_grid_2x2'),                   // 订阅
    $r('sys.symbol.dot_grid_2x2')                       // 更多
  ];

  @Builder
  tabBarBuilder(title: string | Resource, index: number) {
    Column() {
      SymbolGlyph(this.tabSymbols[index])
        .fontSize(24)
        .fontColor([this.currentTabIndex === index ? '#0078C2' : '#444444'])
      Text(title)
        .fontSize(11)
        .fontColor(this.currentTabIndex === index ? '#0078C2' : '#444444')
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .margin({ top: 2 })
    }
    .width('100%')
    .height(80)
    .justifyContent(FlexAlign.Center)
  }
}
