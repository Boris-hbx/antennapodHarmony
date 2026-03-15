import { router } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { HomePage } from './HomePage';
import { SubscriptionsPage } from './SubscriptionsPage';
import { InboxPage } from './InboxPage';
import { QueuePage } from './QueuePage';
import { MorePage } from './MorePage';
import { MiniPlayer } from '../components/MiniPlayer';

/**
 * 主页面 — Tabs + MiniPlayer 架构（ADR-002）
 *
 * 5 个 Tab：首页 / 订阅 / 收件箱 / 队列 / 更多
 * 底部常驻 MiniPlayer（有媒体播放时显示）
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

  aboutToAppear(): void {
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
          onTap: () => {
            router.pushUrl({
              url: 'pages/FullPlayerPage',
              params: {
                title: this.miniPlayerTitle,
                feedTitle: this.miniPlayerFeedTitle,
                isPlaying: this.miniPlayerIsPlaying,
                position: 0,
                duration: 0,
                imageUrl: this.miniPlayerImageUrl
              }
            });
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
    $r('sys.symbol.music_note_list'),                    // 队列（播放列表）
    $r('sys.symbol.tray'),                               // 收件箱
    $r('sys.symbol.square_stack'),                       // 订阅
    $r('sys.symbol.ellipsis')                            // 更多
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
