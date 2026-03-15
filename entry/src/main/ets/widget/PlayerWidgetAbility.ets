import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData } from '@kit.FormKit';

/**
 * 播放器 Widget 的 FormExtensionAbility
 */
export default class PlayerWidgetAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const data: Record<string, string | boolean> = {
      'title': '未在播放',
      'feedTitle': 'AntennaPod',
      'isPlaying': false
    };
    return formBindingData.createFormBindingData(data);
  }

  onRemoveForm(formId: string): void {
    // 卡片被移除
  }

  onUpdateForm(formId: string): void {
    const data: Record<string, string | boolean> = {
      'title': '未在播放',
      'feedTitle': 'AntennaPod',
      'isPlaying': false
    };
    const bindingData = formBindingData.createFormBindingData(data);
  }
}
