import { xml, util } from '@kit.ArkTS';
import { Feed, FeedItem, FeedMedia, FeedFunding, Chapter } from 'common';
import { htmlToPlainText, decodeHtmlEntities } from './HtmlUtils';
import { parseDate } from './DateUtils';
import { parseDuration } from './DurationParser';
import { isMediaFile, getMimeType } from './MimeTypeUtils';

// ===== 命名空间 URI 关键字 =====

const NS_ITUNES = 'itunes.com/dtds/podcast';
const NS_PODCAST_INDEX = 'podcastindex.org';
const NS_CONTENT = 'purl.org/rss/1.0/modules/content';
const NS_DUBLIN_CORE = 'purl.org/dc/elements';
const NS_MEDIA = 'search.yahoo.com/mrss';
const NS_SIMPLE_CHAPTERS = 'podlove.org/simple-chapters';
const NS_ATOM = 'www.w3.org/2005/Atom';

// ===== Feed 类型 =====

enum FeedType {
  RSS20,
  ATOM
}

// ===== 解析结果 =====

export interface FeedParseResult {
  feed: Feed;
  alternateFeedUrls: Map<string, string>;
  redirectUrl: string | null;
}

// ===== 解析状态 =====

class ParseState {
  feed: Feed;
  currentItem: FeedItem | null = null;
  currentMedia: FeedMedia | null = null;
  alternateFeedUrls: Map<string, string> = new Map();
  redirectUrl: string | null = null;
  feedType: FeedType = FeedType.RSS20;

  // 文本累积
  textContent: string = '';

  // 元素路径栈
  elementStack: string[] = [];

  // 状态标志
  inChannel: boolean = false;
  inItem: boolean = false;
  inImage: boolean = false; // RSS channel > image

  // 用于判断 description 是否已由 content:encoded 覆盖
  itemDescriptionSet: boolean = false;

  // 当前元素的属性（由 attributeValueCallbackFunction 填充）
  currentAttributes: Map<string, string> = new Map();

  // 延迟属性处理：START_TAG 时记录，下个事件时处理
  pendingAttrName: string = '';
  pendingAttrNs: string = '';
  hasPendingAttrs: boolean = false;

  constructor(feed: Feed) {
    this.feed = feed;
  }

  get currentElement(): string {
    return this.elementStack.length > 0 ? this.elementStack[this.elementStack.length - 1] : '';
  }

  get isFeedLevel(): boolean {
    return this.inChannel && !this.inItem;
  }
}

// ===== 入口 =====

/**
 * 解析 Feed XML 内容
 */
export function parseFeed(xmlContent: string, feed: Feed): FeedParseResult {
  const state = new ParseState(feed);

  // 转换为 ArrayBuffer
  const encoder = new util.TextEncoder();
  const uint8 = encoder.encodeInto(xmlContent);
  const buffer = uint8.buffer as ArrayBuffer;

  const parser = new xml.XmlPullParser(buffer, 'utf-8');

  parser.parse({
    supportDoctype: false,
    ignoreNameSpace: false,
    attributeValueCallbackFunction: (name: string, value: string): boolean => {
      state.currentAttributes.set(name.toLowerCase(), value);
      return true;
    },
    tokenValueCallbackFunction: (eventType: xml.EventType, parseInfo: xml.ParseInfo): boolean => {
      // 先处理上一个 START_TAG 的延迟属性（属性回调在 START_TAG 之后触发）
      if (state.hasPendingAttrs) {
        handleAttributes(state.pendingAttrName, state.pendingAttrNs, state);
        state.currentAttributes.clear();
        state.hasPendingAttrs = false;
      }

      switch (eventType) {
        case xml.EventType.START_TAG:
          handleStartTag(parseInfo, state);
          // 记录当前元素，等属性收集完毕后再处理
          state.pendingAttrName = parseInfo.getName().toLowerCase();
          state.pendingAttrNs = parseInfo.getNamespace();
          state.hasPendingAttrs = true;
          break;
        case xml.EventType.END_TAG:
          handleEndTag(parseInfo, state);
          break;
        case xml.EventType.TEXT:
        case xml.EventType.CDSECT:
          state.textContent += parseInfo.getText();
          break;
        default:
          break;
      }
      return true;
    }
  });

  return {
    feed: state.feed,
    alternateFeedUrls: state.alternateFeedUrls,
    redirectUrl: state.redirectUrl
  };
}

// ===== 事件处理 =====

function handleStartTag(parseInfo: xml.ParseInfo, state: ParseState): void {
  const name = parseInfo.getName().toLowerCase();
  const ns = parseInfo.getNamespace();
  state.textContent = '';
  // 属性已由 attributeValueCallbackFunction 填充到 currentAttributes

  // Feed 类型检测
  if (state.elementStack.length === 0) {
    if (name === 'feed' && ns.includes(NS_ATOM)) {
      state.feedType = FeedType.ATOM;
      state.inChannel = true;
    } else if (name === 'rss') {
      state.feedType = FeedType.RSS20;
    }
  }

  // RSS: channel 开始
  if (state.feedType === FeedType.RSS20 && name === 'channel') {
    state.inChannel = true;
  }

  // RSS: item 开始 / Atom: entry 开始
  if ((state.feedType === FeedType.RSS20 && name === 'item') ||
    (state.feedType === FeedType.ATOM && name === 'entry')) {
    state.inItem = true;
    state.currentItem = new FeedItem();
    state.currentItem.feedId = state.feed.id;
    state.currentMedia = null;
    state.itemDescriptionSet = false;
  }

  // RSS: channel > image
  if (state.feedType === FeedType.RSS20 && name === 'image' && state.isFeedLevel && !isNsElement(ns)) {
    state.inImage = true;
  }

  state.elementStack.push(name);
  // 属性处理已移到 tokenValueCallbackFunction 中延迟执行
}

function handleEndTag(parseInfo: xml.ParseInfo, state: ParseState): void {
  const name = parseInfo.getName().toLowerCase();
  const ns = parseInfo.getNamespace();
  const text = state.textContent.trim();

  // 分派到命名空间处理器
  if (isNsElement(ns)) {
    handleNamespaceEndTag(name, ns, text, state);
  } else if (state.feedType === FeedType.RSS20) {
    handleRss20EndTag(name, text, state);
  } else if (state.feedType === FeedType.ATOM) {
    handleAtomEndTag(name, text, state);
  }

  // Item / Entry 结束
  if ((state.feedType === FeedType.RSS20 && name === 'item') ||
    (state.feedType === FeedType.ATOM && name === 'entry')) {
    if (state.currentItem !== null) {
      if (state.currentMedia !== null) {
        state.currentItem.media = state.currentMedia;
      }
      state.feed.items.push(state.currentItem);
    }
    state.currentItem = null;
    state.currentMedia = null;
    state.inItem = false;
  }

  // RSS: channel > image 结束
  if (state.feedType === FeedType.RSS20 && name === 'image' && !isNsElement(ns)) {
    state.inImage = false;
  }

  if (state.elementStack.length > 0) {
    state.elementStack.pop();
  }
  state.textContent = '';
}

function isNsElement(ns: string): boolean {
  if (ns.length === 0) return false;
  return ns.includes(NS_ITUNES) || ns.includes(NS_PODCAST_INDEX) ||
    ns.includes(NS_CONTENT) || ns.includes(NS_DUBLIN_CORE) ||
    ns.includes(NS_MEDIA) || ns.includes(NS_SIMPLE_CHAPTERS);
}

// ===== 属性处理（使用 state.currentAttributes Map）=====

function getAttr(state: ParseState, name: string): string {
  return state.currentAttributes.get(name) ?? '';
}

function handleAttributes(name: string, ns: string, state: ParseState): void {
  const attrs = state.currentAttributes;
  if (attrs.size === 0) return;

  // RSS: enclosure
  if (state.feedType === FeedType.RSS20 && name === 'enclosure' && state.inItem) {
    const url = getAttr(state, 'url');
    const type = getAttr(state, 'type');
    const lengthStr = getAttr(state, 'length');
    const length = lengthStr.length > 0 ? (parseInt(lengthStr, 10) || 0) : 0;
    if (url.length > 0) {
      if (length > 0 && length < 16384 && !isMediaFile(type)) return;
      state.currentMedia = new FeedMedia(url, length, getMimeType(type, url));
    }
    return;
  }

  // Atom: link
  if (state.feedType === FeedType.ATOM && name === 'link') {
    const href = getAttr(state, 'href');
    const rel = (getAttr(state, 'rel') || 'alternate').toLowerCase();
    const type = getAttr(state, 'type');
    const title = getAttr(state, 'title');
    if (href.length === 0) return;
    if (state.inItem && state.currentItem !== null) {
      if (rel === 'enclosure') {
        state.currentMedia = new FeedMedia(href, 0, getMimeType(type, href));
      } else if (rel === 'alternate') {
        state.currentItem.link = href;
      }
    } else if (state.isFeedLevel) {
      if (rel === 'alternate') {
        if (type === 'application/rss+xml' || type === 'application/atom+xml') {
          state.alternateFeedUrls.set(href, title.length > 0 ? title : href);
        } else if (state.feed.link === null) {
          state.feed.link = href;
        }
      } else if (rel === 'next') {
        state.feed.paged = true;
        state.feed.nextPageLink = href;
      }
    }
    return;
  }

  // iTunes: image
  if (ns.includes(NS_ITUNES) && name === 'image') {
    const href = getAttr(state, 'href');
    if (href.length > 0) {
      if (state.inItem && state.currentItem !== null) {
        state.currentItem.imageUrl = href;
      } else if (state.isFeedLevel) {
        state.feed.imageUrl = href;
      }
    }
    return;
  }

  // PodcastIndex: funding
  if (ns.includes(NS_PODCAST_INDEX) && name === 'funding' && state.isFeedLevel) {
    const url = getAttr(state, 'url');
    if (url.length > 0) {
      state.feed.fundingList.push(new FeedFunding(url, ''));
    }
    return;
  }

  // PodcastIndex: chapters
  if (ns.includes(NS_PODCAST_INDEX) && name === 'chapters' && state.inItem && state.currentItem !== null) {
    const url = getAttr(state, 'url');
    if (url.length > 0) state.currentItem.podcastIndexChapterUrl = url;
    return;
  }

  // PodcastIndex: transcript
  if (ns.includes(NS_PODCAST_INDEX) && name === 'transcript' && state.inItem && state.currentItem !== null) {
    const url = getAttr(state, 'url');
    const type = getAttr(state, 'type');
    if (url.length > 0 && state.currentItem.podcastIndexTranscriptUrl === null) {
      state.currentItem.podcastIndexTranscriptUrl = url;
      state.currentItem.podcastIndexTranscriptType = type;
    }
    return;
  }

  // SimpleChapters: chapter
  if (ns.includes(NS_SIMPLE_CHAPTERS) && name === 'chapter' && state.inItem && state.currentItem !== null) {
    const start = getAttr(state, 'start');
    if (start.length > 0) {
      const startMs = parseDuration(start);
      const title = getAttr(state, 'title');
      const href = getAttr(state, 'href');
      const image = getAttr(state, 'image');
      const chapter = new Chapter(startMs, title.length > 0 ? title : null,
        href.length > 0 ? href : null, image.length > 0 ? image : null);
      state.currentItem.hasChapters = true;
    }
    return;
  }

  // Media RSS: content
  if (ns.includes(NS_MEDIA) && name === 'content' && state.inItem) {
    const url = getAttr(state, 'url');
    const type = getAttr(state, 'type');
    const medium = getAttr(state, 'medium').toLowerCase();
    if (url.length === 0) return;
    if (medium === 'image') return;
    if (medium !== 'audio' && medium !== 'video' && !isMediaFile(type)) return;
    if (state.currentMedia === null) {
      state.currentMedia = new FeedMedia(url, 0, getMimeType(type, url));
    }
    return;
  }

  // Media RSS: thumbnail
  if (ns.includes(NS_MEDIA) && name === 'thumbnail' && state.inItem && state.currentItem !== null) {
    const url = getAttr(state, 'url');
    if (url.length > 0 && state.currentItem.imageUrl === null) {
      state.currentItem.imageUrl = url;
    }
    return;
  }
}

// ===== RSS 2.0 元素处理 =====

function handleRss20EndTag(name: string, text: string, state: ParseState): void {
  if (text.length === 0) return;

  if (state.inItem && state.currentItem !== null) {
    // Item 级别
    switch (name) {
      case 'title':
        state.currentItem.title = htmlToPlainText(text);
        break;
      case 'link':
        state.currentItem.link = text;
        break;
      case 'description':
        if (!state.itemDescriptionSet) {
          state.currentItem.description = text; // 保留 HTML
        }
        break;
      case 'guid':
        state.currentItem.itemIdentifier = text;
        break;
      case 'pubdate':
        state.currentItem.pubDate = parseDate(text);
        break;
      default:
        break;
    }
  } else if (state.isFeedLevel) {
    // Feed 级别
    if (state.inImage) {
      // channel > image > url
      if (name === 'url' && state.feed.imageUrl === null) {
        state.feed.imageUrl = text;
      }
    } else {
      switch (name) {
        case 'title':
          state.feed.feedTitle = htmlToPlainText(text);
          break;
        case 'link':
          state.feed.link = text;
          break;
        case 'description':
          state.feed.description = htmlToPlainText(text);
          break;
        case 'language':
          state.feed.language = text.toLowerCase();
          break;
        default:
          break;
      }
    }
  }
}

// ===== Atom 元素处理 =====

function handleAtomEndTag(name: string, text: string, state: ParseState): void {
  if (text.length === 0) return;

  if (state.inItem && state.currentItem !== null) {
    // Entry 级别
    switch (name) {
      case 'title':
        state.currentItem.title = htmlToPlainText(text);
        break;
      case 'content':
        state.currentItem.description = text;
        state.itemDescriptionSet = true;
        break;
      case 'summary':
        if (!state.itemDescriptionSet) {
          state.currentItem.description = text;
        }
        break;
      case 'id':
        state.currentItem.itemIdentifier = text;
        break;
      case 'published':
      case 'updated':
        if (state.currentItem.pubDate === null) {
          state.currentItem.pubDate = parseDate(text);
        }
        break;
      default:
        break;
    }
  } else if (state.isFeedLevel) {
    // Feed 级别
    switch (name) {
      case 'title':
        state.feed.feedTitle = htmlToPlainText(text);
        break;
      case 'subtitle':
        state.feed.description = htmlToPlainText(text);
        break;
      case 'id':
        state.feed.feedIdentifier = text;
        break;
      case 'logo':
      case 'icon':
        if (state.feed.imageUrl === null) {
          state.feed.imageUrl = text;
        }
        break;
      case 'name':
        // feed > author > name
        if (state.elementStack.length >= 2 &&
          state.elementStack[state.elementStack.length - 2] === 'author') {
          state.feed.author = text;
        }
        break;
      default:
        break;
    }
  }
}

// ===== 命名空间元素处理 =====

function handleNamespaceEndTag(name: string, ns: string, text: string, state: ParseState): void {
  // iTunes
  if (ns.includes(NS_ITUNES)) {
    handleItunesEndTag(name, text, state);
    return;
  }

  // Content
  if (ns.includes(NS_CONTENT)) {
    if (name === 'encoded' && state.inItem && state.currentItem !== null) {
      state.currentItem.description = text; // content:encoded 覆盖 description
      state.itemDescriptionSet = true;
    }
    return;
  }

  // DublinCore
  if (ns.includes(NS_DUBLIN_CORE)) {
    if (name === 'date' && state.inItem && state.currentItem !== null) {
      state.currentItem.pubDate = parseDate(text);
    }
    return;
  }

  // Media RSS
  if (ns.includes(NS_MEDIA)) {
    if (name === 'description' && state.inItem && state.currentItem !== null) {
      if (!state.itemDescriptionSet) {
        state.currentItem.description = text;
      }
    }
    return;
  }

  // PodcastIndex: funding 文本内容
  if (ns.includes(NS_PODCAST_INDEX)) {
    if (name === 'funding' && state.isFeedLevel && text.length > 0) {
      const fundingList = state.feed.fundingList;
      if (fundingList.length > 0) {
        const last = fundingList[fundingList.length - 1];
        if (last.content.length === 0) {
          last.content = text;
        }
      }
    }
    return;
  }
}

function handleItunesEndTag(name: string, text: string, state: ParseState): void {
  if (text.length === 0) return;

  if (state.inItem && state.currentItem !== null) {
    switch (name) {
      case 'duration':
        if (state.currentMedia !== null) {
          state.currentMedia.duration = parseDuration(text);
        }
        break;
      case 'subtitle':
      case 'summary':
        if (!state.itemDescriptionSet && state.currentItem.description === null) {
          state.currentItem.description = text;
        }
        break;
      default:
        break;
    }
  } else if (state.isFeedLevel) {
    switch (name) {
      case 'author':
        state.feed.author = htmlToPlainText(text);
        break;
      case 'subtitle':
      case 'summary':
        if (state.feed.description === null) {
          state.feed.description = text;
        }
        break;
      case 'new-feed-url':
        if (text.startsWith('http://') || text.startsWith('https://')) {
          state.redirectUrl = text;
        }
        break;
      default:
        break;
    }
  }
}
