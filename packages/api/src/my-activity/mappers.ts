import { toPostSummary } from '../community/mappers';
import { date, isObject, list, num, numOr, obj, str, strOr } from '../json';
import type {
  MyComment,
  MyCommentPage,
  MyPostPage,
  ScrapItem,
  ScrapPage,
} from './types';

/**
 * 내가 쓴 글 페이지.
 *
 * 항목 매퍼를 커뮤니티와 공유한다 — Dart 도 같은 `CommunityRemotePost.fromJson`
 * 을 쓴다. 서버가 한쪽만 바꾸면 두 화면이 같이 깨지는 편이, 한쪽만 조용히
 * 틀어지는 것보다 낫다.
 */
export function toMyPostPage(json: unknown): MyPostPage {
  if (!isObject(json)) throw new TypeError('MyPostPage: 객체가 아니다');
  return {
    posts: list(json.posts, toPostSummary),
    nextCursor: num(json.nextCursor),
  };
}

export function toMyComment(json: unknown): MyComment {
  if (!isObject(json)) throw new TypeError('MyComment: 객체가 아니다');
  return {
    id: numOr(json.id, 0),
    postId: numOr(json.postId, 0),
    postTitle: strOr(json.postTitle, ''),
    body: strOr(json.body, ''),
    likeCount: numOr(json.likeCount, 0),
    createdAt: date(json.createdAt),
    boardTeamId: num(json.boardTeamId),
    // 커뮤니티 매퍼와 같은 처리다(`str`) — Dart 도 `as String?` 이다.
    boardTeamCode: str(json.boardTeamCode),
  };
}

export function toMyCommentPage(json: unknown): MyCommentPage {
  if (!isObject(json)) throw new TypeError('MyCommentPage: 객체가 아니다');
  return {
    comments: list(json.comments, toMyComment),
    nextCursor: num(json.nextCursor),
  };
}

/**
 * 스크랩 한 건.
 *
 * **`post` 가 없으면 던진다.** Dart 는 `json['post'] as Map` 으로 캐스팅해
 * 같은 자리에서 예외가 난다 — 스크랩인데 글이 없는 응답은 그릴 방법이
 * 없으므로, 조용히 빈 글로 만들지 않고 파싱 실패로 보고한다
 * (`Failure.parse` 로 분류된다).
 */
export function toScrapItem(json: unknown): ScrapItem {
  if (!isObject(json)) throw new TypeError('ScrapItem: 객체가 아니다');
  const post = obj(json.post, toPostSummary);
  if (post === null) throw new TypeError('ScrapItem: post 가 없다');
  return {
    scrapId: numOr(json.scrapId, 0),
    post,
  };
}

export function toScrapPage(json: unknown): ScrapPage {
  if (!isObject(json)) throw new TypeError('ScrapPage: 객체가 아니다');
  return {
    items: list(json.items, toScrapItem),
    nextCursor: num(json.nextCursor),
  };
}
