import {
  type Json,
  boolOr,
  date,
  isObject,
  list,
  num,
  numList,
  numOr,
  obj,
  str,
  strOr,
} from '../json';
import type {
  Author,
  PostBlock,
  Poll,
  PollOption,
  PostDetail,
  PostImage,
  PostList,
  PostSummary,
  PostViewer,
} from './types';

/**
 * 서버 응답 → 도메인 타입.
 *
 * 기본값은 Flutter 쪽 `fromJson`(`features/community/domain/*.dart`)과 같게
 * 맞춘다 — 같은 응답에서 두 플랫폼이 다른 화면을 그리면 안 된다.
 */

export function toAuthor(json: Json): Author {
  return {
    memberId: numOr(json.memberId, 0),
    nickname: strOr(json.nickname, ''),
    profileImageUrl: str(json.profileImageUrl),
    teamId: num(json.teamId),
    teamCode: str(json.teamCode),
    teamImageUrl: str(json.teamImageUrl),
  };
}

export function toPostImage(json: Json): PostImage {
  return {
    id: numOr(json.id, 0),
    url: strOr(json.url, ''),
  };
}

export function toPollOption(json: Json): PollOption {
  return {
    id: numOr(json.id, 0),
    label: strOr(json.label, ''),
    // 결과 비공개면 서버가 안 준다. 0 으로 메우면 "0표" 로 보이므로 null 을 유지한다.
    voteCount: num(json.voteCount),
  };
}

export function toPoll(json: Json): Poll {
  return {
    id: numOr(json.id, 0),
    question: strOr(json.question, ''),
    totalVotes: numOr(json.totalVotes, 0),
    resultsVisible: boolOr(json.resultsVisible, false),
    allowMultiple: boolOr(json.allowMultiple, false),
    closesAt: date(json.closesAt),
    closed: boolOr(json.closed, false),
    myOptionIds: numList(json.myOptionIds),
    options: list(json.options, toPollOption),
  };
}

/** 서버가 viewer 를 안 줬을 때의 기본값. Dart `_empty` 와 같다. */
const EMPTY_VIEWER: PostViewer = {
  liked: false,
  scrapped: false,
  mine: false,
  blockedAuthor: false,
  notificationEnabled: false,
};

export function toPostViewer(json: Json): PostViewer {
  return {
    liked: boolOr(json.liked, false),
    scrapped: boolOr(json.scrapped, false),
    mine: boolOr(json.mine, false),
    blockedAuthor: boolOr(json.blockedAuthor, false),
    notificationEnabled: boolOr(json.notificationEnabled, false),
  };
}

export function toPostDetail(json: unknown): PostDetail {
  // 여기서 던지면 `getJson` 이 parseFailure 로 바꾼다 — 응답이 객체가
  // 아니라는 것은 정상 경로가 아니다.
  if (!isObject(json)) throw new TypeError('PostDetail: 객체가 아니다');

  return {
    id: numOr(json.id, 0),
    boardTeamId: num(json.boardTeamId),
    boardTeamCode: str(json.boardTeamCode),
    title: strOr(json.title, ''),
    body: strOr(json.body, ''),
    bodyFormat: strOr(json.bodyFormat, 'PLAIN'),
    author: obj(json.author, toAuthor),
    viewCount: numOr(json.viewCount, 0),
    likeCount: numOr(json.likeCount, 0),
    commentCount: numOr(json.commentCount, 0),
    edited: boolOr(json.edited, false),
    createdAt: date(json.createdAt),
    // 서버가 안 주면 전부 false 로 메운다(Dart `CommunityPostViewer._empty`).
    // 실측상 비회원도 객체를 받지만, 구버전 응답을 대비해 기본값을 둔다.
    viewer: obj(json.viewer, toPostViewer) ?? EMPTY_VIEWER,
    images: list(json.images, toPostImage),
    poll: obj(json.poll, toPoll),
  };
}

/** 본문 블록 하나. */
export function toPostBlock(json: Json): PostBlock {
  return {
    type: strOr(json.type, ''),
    text: str(json.text),
    style: str(json.style),
    url: str(json.url),
    title: str(json.title),
    description: str(json.description),
    imageUrl: str(json.imageUrl),
    siteName: str(json.siteName),
    provider: str(json.provider),
  };
}

/**
 * 상세 `body`(블록 JSON 문자열) → 블록 목록.
 *
 * 파싱 실패는 빈 목록이다 — 렌더러가 평문 폴백으로 그리게 한다(Dart
 * `CommunityPostBlock.parseList` 와 같은 처리). 서버가 검증해 내려주므로
 * 실제로는 일어나지 않는다.
 */
export function parseBlocks(body: string): PostBlock[] {
  if (body.trim() === '') return [];
  try {
    const decoded: unknown = JSON.parse(body);
    return list(decoded, toPostBlock);
  } catch {
    return [];
  }
}

export function toPostSummary(json: Json): PostSummary {
  return {
    id: numOr(json.id, 0),
    boardTeamId: num(json.boardTeamId),
    boardTeamCode: str(json.boardTeamCode),
    title: strOr(json.title, ''),
    bodyPreview: strOr(json.bodyPreview, ''),
    author: obj(json.author, toAuthor),
    viewCount: numOr(json.viewCount, 0),
    likeCount: numOr(json.likeCount, 0),
    commentCount: numOr(json.commentCount, 0),
    edited: boolOr(json.edited, false),
    createdAt: date(json.createdAt),
    thumbnailUrl: str(json.thumbnailUrl),
    imageCount: numOr(json.imageCount, 0),
    hasPoll: boolOr(json.hasPoll, false),
  };
}

export function toPostList(json: unknown): PostList {
  if (!isObject(json)) throw new TypeError('PostList: 객체가 아니다');
  return {
    posts: list(json.posts, toPostSummary),
    nextCursor: num(json.nextCursor),
  };
}
