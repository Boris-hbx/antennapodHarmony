/**
 * HTML 工具：解码实体 + 去标签
 */

const ENTITY_MAP: Record<string, string> = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&#39;': "'",
  '&nbsp;': ' '
};

/**
 * 解码 HTML 实体
 */
export function decodeHtmlEntities(text: string): string {
  let result = text;
  const entities = Object.keys(ENTITY_MAP);
  for (let i = 0; i < entities.length; i++) {
    const entity = entities[i];
    const char = ENTITY_MAP[entity];
    result = result.split(entity).join(char);
  }
  // 数字实体 &#NNN; 和 &#xHHH;
  result = result.replace(/&#(\d+);/g, (_match: string, num: string) => {
    return String.fromCharCode(parseInt(num, 10));
  });
  result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, hex: string) => {
    return String.fromCharCode(parseInt(hex, 16));
  });
  return result;
}

/**
 * 去除 HTML 标签，返回纯文本
 */
export function stripHtmlTags(html: string): string {
  return html.replace(/<[^>]*>/g, '').trim();
}

/**
 * HTML 解码：去标签 + 解码实体
 */
export function htmlToPlainText(html: string): string {
  return decodeHtmlEntities(stripHtmlTags(html));
}
