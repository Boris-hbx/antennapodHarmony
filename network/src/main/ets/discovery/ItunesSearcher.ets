import { httpRequest } from '../http/HttpClient';

/**
 * iTunes 播客搜索 API
 *
 * 使用 Apple iTunes Search API 搜索播客。
 * API: https://itunes.apple.com/search?term={query}&media=podcast&limit=25
 */

export interface ItunesResult {
  trackName: string;       // 播客名称
  artistName: string;      // 作者
  artworkUrl100: string;   // 封面 100px
  artworkUrl600: string;   // 封面 600px
  feedUrl: string;          // RSS URL
  trackCount: number;      // 剧集数
  genres: string[];        // 分类
}

/**
 * 搜索播客
 */
export async function searchPodcasts(query: string): Promise<ItunesResult[]> {
  if (query.trim().length === 0) {
    return [];
  }

  const encoded = encodeURIComponent(query.trim());
  const url = `https://itunes.apple.com/search?term=${encoded}&media=podcast&limit=25`;

  const response = await httpRequest({ url: url, method: 'GET' });

  if (response.statusCode !== 200) {
    return [];
  }

  const body = typeof response.body === 'string' ? response.body : '';
  if (body.length === 0) return [];

  try {
    const json = JSON.parse(body) as SearchResponse;
    const results: ItunesResult[] = [];

    if (json.results !== undefined) {
      for (let i = 0; i < json.results.length; i++) {
        const item = json.results[i];
        if (item.feedUrl !== undefined && item.feedUrl.length > 0) {
          const result: ItunesResult = {
            trackName: item.trackName ?? '',
            artistName: item.artistName ?? '',
            artworkUrl100: item.artworkUrl100 ?? '',
            artworkUrl600: item.artworkUrl600 ?? '',
            feedUrl: item.feedUrl,
            trackCount: item.trackCount ?? 0,
            genres: item.genres ?? []
          };
          results.push(result);
        }
      }
    }
    return results;
  } catch (_e) {
    return [];
  }
}

interface SearchResponse {
  resultCount: number;
  results: SearchResultItem[];
}

interface SearchResultItem {
  trackName: string;
  artistName: string;
  artworkUrl100: string;
  artworkUrl600: string;
  feedUrl: string;
  trackCount: number;
  genres: string[];
}
