import { router, promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { getFeedList, exportOpml, parseOpml, addOrUpdateFeed,
  exportDatabase, importDatabase } from 'datastore';
import { Feed, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';

/**
 * 设置 — 备份和恢复
 * 对照 Android ImportExportPreferencesFragment
 */
@Entry
@Component
struct SettingsBackupPage {
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

        Text('备份和恢复')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      List() {
        // OPML
        ListItem() { this.sectionHeader('OPML') }

        ListItem() {
          this.actionRow('导出订阅 (OPML)', '将订阅列表导出为 OPML 文件', 'sys.symbol.arrow_up_doc')
        }.onClick(() => { this.doExport(); })

        ListItem() {
          this.actionRow('导入订阅 (OPML)', '从 OPML 文件导入订阅列表', 'sys.symbol.arrow_down_doc')
        }.onClick(() => { this.doImport(); })

        // 数据库（预留）
        ListItem() { this.sectionHeader('数据库') }

        ListItem() {
          this.actionRow('导出数据库', '完整备份所有数据（订阅、单集、播放进度）', 'sys.symbol.arrow_up_doc')
        }.onClick(() => { this.doDbExport(); })

        ListItem() {
          this.actionRow('导入数据库', '从备份文件恢复所有数据', 'sys.symbol.arrow_down_doc')
        }.onClick(() => { this.confirmDbImport(); })

        // 下载日志入口
        ListItem() { this.sectionHeader('日志') }
        ListItem() {
          this.actionRow('下载日志', '查看下载历史记录', 'sys.symbol.list_bullet')
        }.onClick(() => {
          router.pushUrl({ url: 'pages/DownloadLogPage' });
        })
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
  }

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
  actionRow(title: string, subtitle: string, icon: string) {
    Row() {
      SymbolGlyph($r(icon))
        .fontSize(20)
        .fontColor(['#333333'])
        .margin({ right: 16 })
      Column() {
        Text(title).fontSize(15).fontColor('#1A1A1A')
        Text(subtitle).fontSize(12).fontColor('#444444').margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  // ===== OPML 导入/导出（从原 SettingsPage 迁移）=====

  async doExport(): Promise<void> {
    try {
      const feeds = await getFeedList();
      if (feeds.length === 0) {
        promptAction.showToast({ message: '没有订阅可导出', duration: 1500 });
        return;
      }
      const opmlContent = exportOpml(feeds);
      const ctx = getContext(this);
      const filePath = ctx.filesDir + '/antennapod_subscriptions.opml';
      const fd = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(fd.fd, opmlContent);
      fileIo.closeSync(fd);
      promptAction.showToast({ message: `已导出 ${feeds.length} 个订阅`, duration: 3000 });
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '导出失败: ' + msg, duration: 2000 });
    }
  }

  async doImport(): Promise<void> {
    try {
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

  // ===== 数据库导出/导入 =====

  async doDbExport(): Promise<void> {
    try {
      const ctx = getContext(this);
      const path = await exportDatabase(ctx);
      promptAction.showToast({ message: `备份已保存到:\n${path}`, duration: 3000 });
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '备份失败: ' + msg, duration: 2000 });
    }
  }

  confirmDbImport(): void {
    AlertDialog.show({
      title: '导入数据库',
      message: '导入将覆盖当前所有数据（订阅、播放进度、队列、收藏）。\n\n确定继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确定导入',
        fontColor: '#F44336',
        action: () => { this.doDbImport(); }
      }
    });
  }

  async doDbImport(): Promise<void> {
    try {
      const ctx = getContext(this);
      // 从沙箱 backup 目录查找最新的备份文件
      const backupDir = ctx.filesDir + '/backup';
      const files = fileIo.listFileSync(backupDir);
      const dbFiles = files.filter((f: string) => f.endsWith('.db'));
      if (dbFiles.length === 0) {
        promptAction.showToast({ message: '未找到备份文件，请先导出', duration: 2000 });
        return;
      }
      // 取最新的（按名称排序，日期在文件名中）
      dbFiles.sort();
      const latestFile = dbFiles[dbFiles.length - 1];
      const sourcePath = backupDir + '/' + latestFile;

      await importDatabase(ctx, sourcePath);

      AlertDialog.show({
        title: '导入成功',
        message: '数据库已恢复。请手动关闭并重新打开应用以使更改生效。',
        primaryButton: { value: '知道了', action: () => {} }
      });
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '导入失败: ' + msg, duration: 2000 });
    }
  }
}
