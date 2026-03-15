import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

const CONNECT_TIMEOUT = 10000;
const READ_TIMEOUT = 30000;

let userAgent = 'AntennaPod/1.0';

/**
 * 设置 User-Agent（应用启动时调用，传入实际版本号）
 */
export function setUserAgent(version: string): void {
  userAgent = `AntennaPod/${version}`;
}

export function getUserAgent(): string {
  return userAgent;
}

// ===== 类型定义 =====

export interface HttpCredentials {
  username: string;
  password: string;
}

export interface HttpClientOptions {
  url: string;
  method?: 'GET' | 'HEAD' | 'POST';
  headers?: Record<string, string>;
  credentials?: HttpCredentials;
  lastModified?: string;
}

export interface HttpResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string | ArrayBuffer;
  redirectUrl?: string;
}

// ===== 认证编码 =====

function encodeCredentials(username: string, password: string): string {
  const raw = `${username}:${password}`;
  const encoder = new util.Base64Helper();
  const uint8 = new util.TextEncoder().encodeInto(raw);
  const base64 = encoder.encodeToStringSync(uint8);
  return `Basic ${base64}`;
}

// ===== HTTP 请求核心 =====

async function doRequest(options: HttpClientOptions,
  authHeader?: string): Promise<HttpResponse> {
  const httpRequest = http.createHttp();

  try {
    const headers: Record<string, string> = {
      'User-Agent': userAgent
    };
    if (options.headers !== undefined) {
      const keys = Object.keys(options.headers);
      for (let i = 0; i < keys.length; i++) {
        headers[keys[i]] = options.headers[keys[i]];
      }
    }

    // 条件请求
    if (options.lastModified !== undefined && options.lastModified.length > 0) {
      if (options.lastModified.startsWith('"') || options.lastModified.startsWith('W/')) {
        headers['If-None-Match'] = options.lastModified;
      } else {
        headers['If-Modified-Since'] = options.lastModified;
      }
    }

    // 认证头
    if (authHeader !== undefined) {
      headers['Authorization'] = authHeader;
    }

    let method = http.RequestMethod.GET;
    if (options.method === 'HEAD') {
      method = http.RequestMethod.HEAD;
    } else if (options.method === 'POST') {
      method = http.RequestMethod.POST;
    }

    const response = await httpRequest.request(options.url, {
      method: method,
      header: headers,
      connectTimeout: CONNECT_TIMEOUT,
      readTimeout: READ_TIMEOUT
    });

    // 转换响应头
    const respHeaders: Record<string, string> = {};
    if (response.header !== undefined && response.header !== null) {
      const headerObj = response.header as Record<string, string>;
      for (const key of Object.keys(headerObj)) {
        respHeaders[key.toLowerCase()] = headerObj[key];
      }
    }

    return {
      statusCode: response.responseCode,
      headers: respHeaders,
      body: response.result as string | ArrayBuffer,
      redirectUrl: respHeaders['location']
    };
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 发送 HTTP 请求，自动处理认证重试。
 *
 * 认证流程：
 * 1. 发送请求
 * 2. 如果 401 且提供了 credentials → 用凭证重试
 * 3. 如果仍然 401 → 返回 401 响应
 */
export async function httpRequest(options: HttpClientOptions): Promise<HttpResponse> {
  // 第一次请求（无认证或已有认证头）
  let response = await doRequest(options);

  // 401 + 有凭证 → 自动重试
  if (response.statusCode === 401 && options.credentials !== undefined) {
    const authHeader = encodeCredentials(
      options.credentials.username, options.credentials.password);
    response = await doRequest(options, authHeader);

    // 仍然 401 → 第三次不再重试
  }

  return response;
}
