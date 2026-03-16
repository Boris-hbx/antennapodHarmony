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

/**
 * 获取国家/地区热门播客（iTunes RSS Feed Generator）
 */
export async function getTopPodcasts(countryCode: string, limit: number = 25): Promise<ItunesResult[]> {
  const url = `https://itunes.apple.com/${countryCode}/rss/toppodcasts/limit=${limit}/json`;
  const response = await httpRequest({ url: url, method: 'GET' });
  if (response.statusCode !== 200) return [];

  const body = typeof response.body === 'string' ? response.body : '';
  if (body.length === 0) return [];

  try {
    // iTunes Top Podcasts API 返回的 JSON 使用带冒号的键名（如 "im:name"），
    // ArkTS 不支持 indexed access，所以先用字符串替换将键名规范化
    const normalized = body
      .replace(/"im:name"/g, '"imName"')
      .replace(/"im:artist"/g, '"imArtist"')
      .replace(/"im:image"/g, '"imImage"')
      .replace(/"im:id"/g, '"imId"');
    const json = JSON.parse(normalized) as TopPodcastsResponse;
    const results: ItunesResult[] = [];
    if (json.feed !== undefined && json.feed.entry !== undefined) {
      for (const entry of json.feed.entry) {
        const imgArr = entry.imImage;
        const artUrl = imgArr !== undefined && imgArr.length > 0
          ? imgArr[imgArr.length - 1].label : '';
        const result: ItunesResult = {
          trackName: entry.imName?.label ?? '',
          artistName: entry.imArtist?.label ?? '',
          artworkUrl100: artUrl,
          artworkUrl600: artUrl.replace('/100x100', '/600x600'),
          feedUrl: entry.id?.attributes?.imId ?? '',
          trackCount: 0,
          genres: []
        };
        // feedUrl from top podcasts is actually the iTunes ID, we need the link
        if (entry.link !== undefined && entry.link.length > 0) {
          for (const lk of entry.link) {
            if (lk.attributes?.type === 'text/html') {
              result.feedUrl = lk.attributes.href ?? '';
              break;
            }
          }
        }
        // 从 id 中提取真实 URL
        if (entry.id?.label !== undefined) {
          result.feedUrl = entry.id.label;
        }
        results.push(result);
      }
    }
    return results;
  } catch (_e) {
    return [];
  }
}

interface TopPodcastsResponse {
  feed: TopPodcastsFeed;
}

interface TopPodcastsFeed {
  entry: TopPodcastEntry[];
}

interface ImLabel {
  label: string;
}

interface ImIdAttributes {
  imId: string;
}

interface ImId {
  label: string;
  attributes: ImIdAttributes;
}

interface LinkAttributes {
  href: string;
  type: string;
}

interface PodcastLink {
  attributes: LinkAttributes;
}

interface TopPodcastEntry {
  imName: ImLabel;
  imArtist: ImLabel;
  imImage: ImLabel[];
  id: ImId;
  link: PodcastLink[];
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
