/**
 * URL 处理工具
 */

// 需要规范化的协议前缀
const PROTOCOL_MAP: [string, string][] = [
  ['feed://', 'http://'],
  ['pcast://', 'http://'],
  ['itpc://', 'http://'],
  ['antennapod-subscribe://', 'http://']
];

/**
 * 规范化 URL 协议。
 * feed://、pcast://、itpc://、antennapod-subscribe:// → http://
 * 无协议 → 添加 http://
 */
export function prepareUrl(url: string): string {
  const trimmed = url.trim();

  for (let i = 0; i < PROTOCOL_MAP.length; i++) {
    const prefix = PROTOCOL_MAP[i][0];
    const replacement = PROTOCOL_MAP[i][1];
    if (trimmed.toLowerCase().startsWith(prefix)) {
      return replacement + trimmed.substring(prefix.length);
    }
  }

  // 已有 http/https → 不变
  if (trimmed.toLowerCase().startsWith('http://') ||
    trimmed.toLowerCase().startsWith('https://')) {
    return trimmed;
  }

  // 无协议 → 添加 http://
  return 'http://' + trimmed;
}

/**
 * 比较两个 URL 是否等价：
 * - Host 不区分大小写
 * - 规范化路径（去除末尾 /）
 * - 比较 query 参数
 */
export function urlEquals(url1: string, url2: string): boolean {
  if (url1 === url2) return true;

  try {
    const u1 = parseUrlParts(url1.toLowerCase());
    const u2 = parseUrlParts(url2.toLowerCase());
    return u1.host === u2.host && u1.path === u2.path && u1.query === u2.query;
  } catch {
    return url1 === url2;
  }
}

interface UrlParts {
  host: string;
  path: string;
  query: string;
}

function parseUrlParts(url: string): UrlParts {
  // 去除协议
  let rest = url;
  const protoIdx = rest.indexOf('://');
  if (protoIdx >= 0) {
    rest = rest.substring(protoIdx + 3);
  }

  // 分离 query
  let query = '';
  const queryIdx = rest.indexOf('?');
  if (queryIdx >= 0) {
    query = rest.substring(queryIdx + 1);
    rest = rest.substring(0, queryIdx);
  }

  // 分离 host 和 path
  const pathIdx = rest.indexOf('/');
  let host: string;
  let path: string;
  if (pathIdx >= 0) {
    host = rest.substring(0, pathIdx);
    path = rest.substring(pathIdx);
  } else {
    host = rest;
    path = '/';
  }

  // 规范化路径：去除末尾 /（除非只有 /）
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  return { host, path, query };
}
