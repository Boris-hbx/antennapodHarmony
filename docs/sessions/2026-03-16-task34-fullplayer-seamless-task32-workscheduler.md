# 2026-03-16: Task #34 MiniPlayer 无缝衔接 + Task #32 workScheduler

## 完成任务

### Task #34: MiniPlayer→全屏播放器无缝衔接（P0）

**问题**：点击 MiniPlayer 通过 `router.pushUrl` 跳转到 FullPlayerPage，导致音频从头播放、有割裂感。

**解决方案**：将 FullPlayerPage 从独立路由页面改为 `bindSheet` 内嵌组件。

**修改文件**：
| 文件 | 操作 |
|------|------|
| `entry/src/main/ets/pages/FullPlayerPage.ets` | @Entry → @Component export struct FullPlayerContent；router.getParams → PlaybackController 直接读取；router.back → onClose 回调 |
| `entry/src/main/ets/pages/Index.ets` | 添加 showFullPlayer 状态 + bindSheet(height:'100%')；onTap 改为 showFullPlayer=true |
| `entry/src/main/ets/components/MiniPlayer.ets` | 播放按钮 stopPropagation + hitTestBehavior(Block) 防止冒泡 |
| `entry/src/main/resources/base/profile/main_pages.json` | 移除 FullPlayerPage 路由 |

### Task #32: 自动定时刷新升级为 workScheduler

**问题**：原来用 `setInterval` 仅前台有效，App 关闭后无法刷新。

**解决方案**：用 HarmonyOS `workScheduler` 注册系统级后台周期任务。

**修改文件**：
| 文件 | 操作 |
|------|------|
| `entry/src/main/ets/workers/FeedRefreshWorkAbility.ets` | 新建：WorkSchedulerExtensionAbility，onWorkStart 调用 refreshAllFeeds |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 移除 setInterval，改用 workScheduler.startWork；启动时即时刷新一次 |
| `entry/src/main/module.json5` | 注册 FeedRefreshWorkAbility 扩展 |
| `entry/src/main/ets/pages/SettingsDownloadsPage.ets` | 修改间隔时 stopWork → startWork 重新注册 |

## 记录经验

- PAT-016: Router 页面转 bindSheet 内嵌组件模式
