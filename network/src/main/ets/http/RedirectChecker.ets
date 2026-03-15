import { HttpResponse } from './HttpClient';

/**
 * 检测 HTTP 永久重定向，用于自动更新 Feed URL。
 *
 * 规则：
 * - 301/308 → 永久重定向 → 返回新 URL
 * - 302/307 + http→https（同 host+path） → 视为永久 → 返回新 URL
 * - 其他 → 非永久 → 返回 null
 */
export function checkPermanentRedirect(response: HttpResponse, originalUrl: string): string | null {
  const location = response.redirectUrl ?? response.headers['location'];
  if (location === undefined || location === null || location.length === 0) {
    return null;
  }

  // 301 / 308 → 永久重定向
  if (response.statusCode === 301 || response.statusCode === 308) {
    return location;
  }

  // 302 / 307 + http→https 升级视为永久
  if (response.statusCode === 302 || response.statusCode === 307) {
    if (isHttpToHttpsUpgrade(originalUrl, location)) {
      return location;
    }
  }

  return null;
}

/**
 * 判断是否为 http → https 的同 host+path 升级
 */
function isHttpToHttpsUpgrade(originalUrl: string, newUrl: string): boolean {
  const origLower = originalUrl.toLowerCase();
  const newLower = newUrl.toLowerCase();

  if (!origLower.startsWith('http://') || !newLower.startsWith('https://')) {
    return false;
  }

  // 去掉协议后比较
  const origRest = origLower.substring('http://'.length);
  const newRest = newLower.substring('https://'.length);

  return origRest === newRest;
}
