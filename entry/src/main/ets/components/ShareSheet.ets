import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';

/**
 * 分享弹窗组件（#12.5 — 对照 Android ShareDialog 复刻）
 *
 * 三种分享卡片：社交信息 / 媒体地址 / 媒体文件
 */
@Component
export struct ShareSheet {
  @Prop feedTitle: string = '';
  @Prop episodeTitle: string = '';
  @Prop episodeLink: string = '';
  @Prop mediaUrl: string = '';
  @Prop isDownloaded: boolean = false;
  @Prop positionMs: number = 0;
  @State includePosition: boolean = false;

  onClose?: () => void;

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('分享')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('✕')
          .fontSize(20)
          .fontColor('#444444')
          .onClick(() => { this.onClose?.(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      // 卡片 1：社交信息
      this.shareCard(
        '社交信息',
        this.buildSocialText(),
        () => { this.copyToClipboard(this.buildSocialText()); }
      )

      // 卡片 2：媒体地址（有 URL 时显示）
      if (this.mediaUrl.length > 0) {
        this.shareCard(
          '媒体地址',
          this.includePosition ? `${this.mediaUrl}#t=${Math.floor(this.positionMs / 1000)}` : this.mediaUrl,
          () => {
            const url = this.includePosition ? `${this.mediaUrl}#t=${Math.floor(this.positionMs / 1000)}` : this.mediaUrl;
            this.copyToClipboard(url);
          }
        )
      }

      // 卡片 3：媒体文件（已下载时显示）
      if (this.isDownloaded) {
        this.shareCard(
          '媒体文件',
          '分享已下载的音频文件',
          () => { promptAction.showToast({ message: '文件分享功能开发中', duration: 1500 }); }
        )
      }

      // 包括播放位置 CheckBox
      Row() {
        Checkbox()
          .select(this.includePosition)
          .onChange((value: boolean) => {
            this.includePosition = value;
          })
          .width(20)
          .height(20)
        Text('包括播放位置')
          .fontSize(14)
          .fontColor('#444444')
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 20 })

    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  shareCard(cardTitle: string, content: string, onShare: () => void) {
    Column() {
      Row() {
        Text(cardTitle)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
        Blank()
        Text('↗')
          .fontSize(18)
          .fontColor('#0078C2')
          .onClick(() => { onShare(); })
      }
      .width('100%')

      Text(content)
        .fontSize(12)
        .fontColor('#444444')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
    }
    .width('100%')
    .padding(14)
    .margin({ left: 16, right: 16, top: 8 })
    .backgroundColor('#F8F9FA')
    .borderRadius(12)
    .borderWidth(1)
    .borderColor('#E8EAED')
  }

  buildSocialText(): string {
    let text = `${this.feedTitle}: ${this.episodeTitle}`;
    if (this.includePosition && this.positionMs > 0) {
      text += `\nStarting position: ${this.formatTime(this.positionMs)}`;
    }
    if (this.episodeLink.length > 0) {
      text += `\n\nEpisode website: ${this.episodeLink}`;
    }
    if (this.mediaUrl.length > 0) {
      let url = this.mediaUrl;
      if (this.includePosition && this.positionMs > 0) {
        url += `#t=${Math.floor(this.positionMs / 1000)}`;
      }
      text += `\n\nMedia file: ${url}`;
    }
    return text;
  }

  copyToClipboard(text: string): void {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
      promptAction.showToast({ message: '已复制到剪贴板', duration: 1500 });
    } catch (_e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  formatTime(ms: number): string {
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    const s = totalSec % 60;
    const sStr = s.toString().padStart(2, '0');
    if (h > 0) {
      return `${h}:${m.toString().padStart(2, '0')}:${sStr}`;
    }
    return `${m}:${sStr}`;
  }
}
