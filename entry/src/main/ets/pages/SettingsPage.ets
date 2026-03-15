import { router, promptAction } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { getTheme, setTheme, getFeedList, exportOpml, parseOpml, addOrUpdateFeed } from 'datastore';
import type { OpmlItem } from 'datastore';
import { Feed, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';

/**
 * 设置页面（P6）
 *
 * 提供主题切换（浅色/深色/跟随系统）及其他设置。
 */
@Entry
@Component
struct SettingsPage {
  @State currentTheme: string = 'system';

  aboutToAppear(): void {
    this.currentTheme = getTheme();
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button('←')
          .type(ButtonType.Circle)
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .fontColor('#333')
          .fontSize(20)
          .onClick(() => { router.back(); })
        Text($r('app.string.title_settings'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // 主题设置
        ListItem() {
          Column() {
            Text('外观')
              .fontSize(13)
              .fontColor('#444444')
              .margin({ bottom: 8 })
          }
          .padding({ left: 16, right: 16, top: 16, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
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

        // 其他设置分组
        ListItem() {
          Column() {
            Text('播放')
              .fontSize(13)
              .fontColor('#444444')
              .margin({ bottom: 8 })
          }
          .padding({ left: 16, right: 16, top: 20, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          this.settingItem('连续播放', '播完自动播下一集')
        }
        ListItem() {
          this.settingItem('跳过静音', '自动跳过无声片段')
        }
        ListItem() {
          this.settingItem('快进秒数', '30 秒')
        }
        ListItem() {
          this.settingItem('倒退秒数', '10 秒')
        }
        ListItem() {
          this.settingItem('智能标记已播', '剩余 30 秒时自动标记')
        }

        // 下载
        ListItem() {
          Column() {
            Text($r('app.string.title_downloads'))
              .fontSize(13)
              .fontColor('#444444')
              .margin({ bottom: 8 })
          }
          .padding({ left: 16, right: 16, top: 20, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          this.settingItem('自动下载', '新单集自动下载')
        }
        ListItem() {
          this.settingItem('缓存大小', '最多保留 20 集')
        }
        ListItem() {
          this.settingItem('仅 WiFi 下载', '移动网络不自动下载')
        }

        // 通知
        ListItem() {
          Column() {
            Text('通知')
              .fontSize(13)
              .fontColor('#444444')
              .margin({ bottom: 8 })
          }
          .padding({ left: 16, right: 16, top: 20, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          this.settingItem('新单集通知', '订阅更新时推送通知')
        }
        ListItem() {
          this.settingItem('下载完成通知', '下载完成后提醒')
        }

        // 数据管理
        ListItem() {
          Column() {
            Text('数据管理')
              .fontSize(13)
              .fontColor('#444444')
              .margin({ bottom: 8 })
          }
          .padding({ left: 16, right: 16, top: 20, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          this.settingItem('导出订阅 (OPML)', '备份订阅列表到文件')
        }
        .onClick(() => {
          this.doExport();
        })

        ListItem() {
          this.settingItem('导入订阅 (OPML)', '从 OPML 文件导入订阅')
        }
        .onClick(() => {
          this.doImport();
        })

        ListItem() {
          Column() {
            Text('关于')
              .fontSize(13)
              .fontColor('#444444')
              .margin({ bottom: 8 })
          }
          .padding({ left: 16, right: 16, top: 20, bottom: 4 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        ListItem() {
          Column() {
            Text('AntennaPod for HarmonyOS')
              .fontSize(14)
            Text('版本 1.0.0')
              .fontSize(12)
              .fontColor('#444444')
              .margin({ top: 2 })
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  themeOption(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .layoutWeight(1)
      if (this.currentTheme === value) {
        Text('✓')
          .fontSize(16)
          .fontColor('#0078C2')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.applyTheme(value);
    })
  }

  @Builder
  settingItem(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(15)
      Text(subtitle)
        .fontSize(12)
        .fontColor('#444444')
        .margin({ top: 2 })
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  async applyTheme(theme: string): Promise<void> {
    this.currentTheme = theme;
    await setTheme(theme);

    // 通过 getContext 设置应用颜色模式
    const ctx = getContext(this);
    try {
      const appCtx = ctx.getApplicationContext();
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
    } catch (_e) {
      // ignore
    }
  }

  async doExport(): Promise<void> {
    try {
      const feeds = await getFeedList();
      if (feeds.length === 0) {
        promptAction.showToast({ message: '没有订阅可导出', duration: 1500 });
        return;
      }
      const opmlContent = exportOpml(feeds);

      // 写入应用目录
      const ctx = getContext(this);
      const filePath = ctx.filesDir + '/antennapod_subscriptions.opml';
      const fd = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(fd.fd, opmlContent);
      fileIo.closeSync(fd);

      promptAction.showToast({ message: `已导出 ${feeds.length} 个订阅到 ${filePath}`, duration: 3000 });
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '导出失败: ' + msg, duration: 2000 });
    }
  }

  async doImport(): Promise<void> {
    try {
      // 从应用目录读取（简化版，后续可接入文件选择器）
      const ctx = getContext(this);
      const filePath = ctx.filesDir + '/antennapod_subscriptions.opml';

      let content: string;
      try {
        const fd = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(filePath);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(fd.fd, buf);
        fileIo.closeSync(fd);
        content = String.fromCharCode(...new Uint8Array(buf));
      } catch (_e) {
        promptAction.showToast({ message: '未找到 OPML 文件，请先导出或将文件放到应用目录', duration: 2500 });
        return;
      }

      const items = parseOpml(content);
      if (items.length === 0) {
        promptAction.showToast({ message: 'OPML 文件中没有订阅', duration: 1500 });
        return;
      }

      let imported = 0;
      for (const item of items) {
        const feed = new Feed(item.xmlUrl);
        feed.feedTitle = item.title;
        feed.link = item.htmlUrl;
        await addOrUpdateFeed(feed);
        imported++;
      }

      EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: [] });
      promptAction.showToast({ message: `已导入 ${imported} 个订阅`, duration: 2000 });
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '导入失败: ' + msg, duration: 2000 });
    }
  }
}
