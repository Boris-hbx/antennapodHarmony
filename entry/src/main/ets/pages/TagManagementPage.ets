import { router, promptAction } from '@kit.ArkUI';
import { Feed, FeedPreferences, EventBus, FEED_LIST_UPDATE } from 'common';
import type { FeedListUpdateData } from 'common';
import { getFeedList, setFeedPreferences } from 'datastore';

/**
 * 全局标签管理页 — Task-031: 批量查看/重命名/删除标签
 */
interface TagEntry {
  name: string;
  feedCount: number;
  feedIds: number[];
}

@Entry
@Component
struct TagManagementPage {
  @State tags: TagEntry[] = [];
  @State allFeeds: Feed[] = [];
  @State showRenameSheet: boolean = false;
  @State selectedTag: string = '';
  @State renameText: string = '';
  @State newTagInput: string = '';

  aboutToAppear(): void {
    this.loadTags();
  }

  async loadTags(): Promise<void> {
    this.allFeeds = await getFeedList();
    const tagMap = new Map<string, number[]>();
    for (const feed of this.allFeeds) {
      if (feed.preferences !== null) {
        feed.preferences.tags.forEach((tag: string) => {
          if (tag.length > 0) {
            const existing = tagMap.get(tag) ?? [];
            existing.push(feed.id);
            tagMap.set(tag, existing);
          }
        });
      }
    }
    const result: TagEntry[] = [];
    tagMap.forEach((feedIds: number[], name: string) => {
      result.push({ name: name, feedCount: feedIds.length, feedIds: feedIds });
    });
    result.sort((a: TagEntry, b: TagEntry) => {
      if (a.name < b.name) return -1;
      if (a.name > b.name) return 1;
      return 0;
    });
    this.tags = result;
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor(['#333333'])
        }
        .width(40).height(40)
        .onClick(() => { router.back(); })

        Text('标签管理')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      // 添加新标签
      Row() {
        TextInput({ placeholder: '输入新标签名称', text: this.newTagInput })
          .layoutWeight(1)
          .height(40)
          .borderRadius(8)
          .onChange((v: string) => { this.newTagInput = v; })
        Button('创建')
          .height(40)
          .margin({ left: 8 })
          .backgroundColor('#0078C2')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .borderRadius(8)
          .onClick(() => {
            if (this.newTagInput.trim().length > 0) {
              // 标签只有在绑定到 feed 时才有意义，这里创建一个空标签提示
              const exists = this.tags.find((t: TagEntry) => t.name === this.newTagInput.trim());
              if (exists !== undefined) {
                promptAction.showToast({ message: '标签已存在', duration: 1500 });
              } else {
                promptAction.showToast({ message: '请在 Feed 设置中为订阅添加此标签', duration: 2000 });
              }
              this.newTagInput = '';
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (this.tags.length === 0) {
        Column() {
          Text('暂无标签')
            .fontSize(16)
            .fontColor('#888888')
            .margin({ top: 60 })
          Text('在 Feed 设置中为订阅添加标签')
            .fontSize(13)
            .fontColor('#BBBBBB')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.tags, (entry: TagEntry) => {
            ListItem() {
              Row() {
                SymbolGlyph($r('sys.symbol.star'))
                  .fontSize(18)
                  .fontColor(['#0078C2'])
                  .margin({ right: 12 })
                Column() {
                  Text(entry.name)
                    .fontSize(16)
                    .fontColor('#1A1A1A')
                  Text(`${entry.feedCount} 个订阅`)
                    .fontSize(12)
                    .fontColor('#888888')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 重命名
                Stack({ alignContent: Alignment.Center }) {
                  SymbolGlyph($r('sys.symbol.star'))
                    .fontSize(16)
                    .fontColor(['#444444'])
                }
                .width(36).height(36)
                .onClick(() => {
                  this.selectedTag = entry.name;
                  this.renameText = entry.name;
                  this.showRenameSheet = true;
                })

                // 删除
                Stack({ alignContent: Alignment.Center }) {
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(16)
                    .fontColor(['#F44336'])
                }
                .width(36).height(36)
                .margin({ left: 4 })
                .onClick(() => {
                  this.confirmDeleteTag(entry);
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
          }, (entry: TagEntry) => entry.name)
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showRenameSheet, this.RenameSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      showClose: true
    })
  }

  // 重命名弹窗
  @Builder RenameSheetBuilder() {
    Column() {
      Text('重命名标签').fontSize(18).fontWeight(FontWeight.Bold).padding(16)
      Text(`当前标签: ${this.selectedTag}`)
        .fontSize(13).fontColor('#888888').padding({ left: 16, bottom: 8 })
      TextInput({ placeholder: '新标签名', text: this.renameText })
        .width('90%')
        .height(44)
        .borderRadius(8)
        .onChange((v: string) => { this.renameText = v; })
      Row() {
        Button('取消')
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .height(40).fontSize(15)
          .fontColor('#333333').backgroundColor('#F0F0F0').borderRadius(20)
          .margin({ right: 8 })
          .onClick(() => { this.showRenameSheet = false; })
        Button('确定')
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .height(40).fontSize(15)
          .fontColor('#FFFFFF').backgroundColor('#0078C2').borderRadius(20)
          .margin({ left: 8 })
          .onClick(async () => {
            await this.renameTag(this.selectedTag, this.renameText.trim());
            this.showRenameSheet = false;
          })
      }
      .width('90%')
      .padding({ top: 16, bottom: 16 })
    }
  }

  async renameTag(oldName: string, newName: string): Promise<void> {
    if (newName.length === 0 || oldName === newName) return;
    for (const feed of this.allFeeds) {
      if (feed.preferences !== null && feed.preferences.tags.has(oldName)) {
        feed.preferences.tags.delete(oldName);
        feed.preferences.tags.add(newName);
        await setFeedPreferences(feed.preferences);
      }
    }
    await this.loadTags();
    promptAction.showToast({ message: `已将「${oldName}」重命名为「${newName}」`, duration: 1500 });
    EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: [] });
  }

  confirmDeleteTag(entry: TagEntry): void {
    AlertDialog.show({
      title: '删除标签',
      message: `确定删除标签「${entry.name}」吗？将从 ${entry.feedCount} 个订阅中移除。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#F44336',
        action: async () => {
          await this.deleteTag(entry.name);
        }
      }
    });
  }

  async deleteTag(tagName: string): Promise<void> {
    for (const feed of this.allFeeds) {
      if (feed.preferences !== null && feed.preferences.tags.has(tagName)) {
        feed.preferences.tags.delete(tagName);
        await setFeedPreferences(feed.preferences);
      }
    }
    await this.loadTags();
    promptAction.showToast({ message: `已删除标签「${tagName}」`, duration: 1500 });
    EventBus.emit<FeedListUpdateData>(FEED_LIST_UPDATE, { feedIds: [] });
  }
}
