import { promptAction } from '@kit.ArkUI';
import { getController } from '../entryability/EntryAbility';
import { FeedItem } from 'common';
import { getFeedItem } from 'datastore';
import { downloadNow, cancelDownload } from 'network';

/**
 * 统一的剧集操作按钮 — 下载/取消/播放/暂停 四态自动切换
 *
 * 状态机：
 *   NOT_DOWNLOADED  → 点击 → DOWNLOADING
 *   DOWNLOADING     → 点击 → 取消下载 → NOT_DOWNLOADED
 *   DOWNLOADING     → 完成 → DOWNLOADED
 *   DOWNLOADED      → 点击 → PLAYING
 *   PLAYING         → 点击 → PAUSED
 */
@Component
export struct EpisodeActionButton {
  @Prop itemId: number = 0;
  @Prop downloadUrl: string = '';
  @Prop isItemDownloaded: boolean = false;
  @Prop feedId: number = 0;
  @Prop feedTitle: string = '';
  @Prop filesDir: string = '';
  @Prop itemTitle: string = '';
  // 下载进度（0-100），由父组件从 downloadingUrls Map 中取值传入
  @Prop @Watch('onProgressChange') downloadProgress: number = -1; // -1 表示未在下载
  // 是否是当前正在播放的剧集
  @Prop isCurrentPlaying: boolean = false;
  // 内部状态：点击下载后立即标记，防止父组件 re-render 导致状态回退
  @State localDownloading: boolean = false;
  // 是否曾收到过进度（用于检测下载失败后的回退）
  private hadProgress: boolean = false;

  onProgressChange(): void {
    if (this.downloadProgress >= 0) {
      this.hadProgress = true;
    } else if (this.hadProgress && this.localDownloading) {
      // 进度从 >=0 变回 -1 → 下载完成或失败，重置本地状态
      this.localDownloading = false;
      this.hadProgress = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.getButtonState() === 'downloading') {
        // 下载中：显示进度环
        Progress({
          value: this.downloadProgress > 0 ? this.downloadProgress : 1,
          total: 100,
          type: ProgressType.Ring
        })
          .width(40).height(40)
          .color('#0078C2')
          .backgroundColor('#D0D0D0')
          .style({ strokeWidth: 3 })
      } else {
        // 非下载状态：静态圆形背景（无动画）
        Circle()
          .width(40).height(40)
          .fill(Color.Transparent)
          .stroke(this.getButtonState() === 'download' ? '#D0D0D0' : '#000000')
          .strokeWidth(this.getButtonState() === 'download' ? 1 : 3)
      }

      SymbolGlyph(this.getIcon())
        .fontSize(18)
        .fontColor([this.getIconColor()])
    }
    .width(48).height(48)
    .onClick(() => { this.handleClick(); })
  }

  private getButtonState(): string {
    // 正在播放当前剧集
    if (this.isCurrentPlaying) {
      return 'pause';
    }
    // 正在下载（父组件传入的进度 OR 本地立即标记）
    if (this.downloadProgress >= 0 || this.localDownloading) {
      return 'downloading';
    }
    // 已下载
    if (this.isItemDownloaded) {
      return 'play';
    }
    return 'download';
  }

  private getIcon(): Resource {
    const state = this.getButtonState();
    if (state === 'download') return $r('sys.symbol.arrow_down');
    if (state === 'downloading') return $r('sys.symbol.xmark');
    if (state === 'pause') return $r('sys.symbol.pause_fill');
    return $r('sys.symbol.play_fill'); // play
  }

  private getIconColor(): string {
    const state = this.getButtonState();
    if (state === 'download') return '#444444';
    return '#000000';
  }

  private handleClick(): void {
    const state = this.getButtonState();
    if (state === 'download') {
      this.startDownload();
    } else if (state === 'downloading') {
      cancelDownload(this.downloadUrl);
      this.localDownloading = false;
      promptAction.showToast({ message: '已取消下载', duration: 1500 });
    } else if (state === 'play') {
      this.startPlayback(false);
    } else if (state === 'pause') {
      getController().playPause();
    }
  }

  private startDownload(): void {
    if (this.downloadUrl.length === 0) return;
    // 立即标记为下载中，防止父组件 re-render 导致按钮回退
    this.localDownloading = true;
    // 安全超时：如果 10 秒后仍未收到任何进度事件，重置状态（防止永久卡住）
    setTimeout(() => {
      if (this.localDownloading && !this.hadProgress) {
        this.localDownloading = false;
      }
    }, 10000);
    getFeedItem(this.itemId).then((item: FeedItem | null) => {
      if (item !== null && item.media !== null) {
        downloadNow(item, this.feedTitle, this.filesDir);
        promptAction.showToast({ message: '开始下载', duration: 1500 });
      } else {
        this.localDownloading = false;
      }
    }).catch(() => {
      this.localDownloading = false;
    });
  }

  private startPlayback(stream: boolean): void {
    getFeedItem(this.itemId).then((item: FeedItem | null) => {
      if (item !== null && item.media !== null) {
        getController().playMedia(item.media, item.feedId, stream).then(() => {
          promptAction.showToast({ message: '正在播放', duration: 1500 });
        }).catch((e: Error) => {
          promptAction.showToast({ message: '播放失败: ' + e.message, duration: 3000 });
        });
      }
    }).catch(() => {});
  }
}
