import { Feed } from 'common';

/**
 * OPML 导入/导出
 */

export interface OpmlItem {
  title: string;
  xmlUrl: string;
  htmlUrl: string;
}

/**
 * 导出：将 Feed 列表生成 OPML XML 字符串
 */
export function exportOpml(feeds: Feed[]): string {
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<opml version="2.0">\n';
  xml += '  <head>\n';
  xml += '    <title>AntennaPod Subscriptions</title>\n';
  xml += '  </head>\n';
  xml += '  <body>\n';

  for (const feed of feeds) {
    const title = escapeXml(feed.getTitle() ?? '');
    const xmlUrl = escapeXml(feed.downloadUrl ?? '');
    const htmlUrl = escapeXml(feed.link ?? '');
    xml += `    <outline text="${title}" xmlUrl="${xmlUrl}" htmlUrl="${htmlUrl}" type="rss"/>\n`;
  }

  xml += '  </body>\n';
  xml += '</opml>\n';
  return xml;
}

/**
 * 导入：解析 OPML XML 字符串为订阅列表
 */
export function parseOpml(xmlContent: string): OpmlItem[] {
  const items: OpmlItem[] = [];

  // 简单正则解析 <outline> 标签
  const outlineRegex = /<outline[^>]*>/gi;
  let match = outlineRegex.exec(xmlContent);
  while (match !== null) {
    const tag = match[0];
    const xmlUrl = extractAttr(tag, 'xmlUrl') || extractAttr(tag, 'xmlurl') || extractAttr(tag, 'url');
    if (xmlUrl.length > 0) {
      const title = extractAttr(tag, 'text') || extractAttr(tag, 'title') || xmlUrl;
      const htmlUrl = extractAttr(tag, 'htmlUrl') || extractAttr(tag, 'htmlurl') || '';
      const item: OpmlItem = { title: title, xmlUrl: xmlUrl, htmlUrl: htmlUrl };
      items.push(item);
    }
    match = outlineRegex.exec(xmlContent);
  }

  return items;
}

function extractAttr(tag: string, attrName: string): string {
  // 匹配 attrName="value" 或 attrName='value'
  const regex = new RegExp(attrName + '=["\']([^"\']*)["\']', 'i');
  const match = regex.exec(tag);
  if (match !== null && match.length > 1) {
    return unescapeXml(match[1]);
  }
  return '';
}

function escapeXml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function unescapeXml(str: string): string {
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}
