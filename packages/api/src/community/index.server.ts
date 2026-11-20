import {
  API_BASE_URL,
  getJson,
  postJson,
  type RequestOptions,
  type Result,
} from '../client';
import { isObject, boolOr, numOr, strOr } from '../json';
import { toCommentList, toPoll, toPostDetail, toPostList } from './mappers';
import type {
  CommentList,
  Poll,
  PostDetail,
  PostList,
  UploadSignature,
} from './types';

/**
 * 커뮤니티 글 상세.
 *
 * `GET /api/mobile/community/posts/{postId}` — Flutter `ApiConfig.communityPostUrl`
 * 과 같은 경로다.
 *
 * **비회원도 조회할 수 있다**(실측 2026-11-17, HTTP 200). SSR 이 성립하는
 * 근거가 이것이다 — 서버가 토큰 없이도 본문을 그릴 수 있다.
 *
 * 비회원이어도 `viewer` 는 객체로 온다(전부 false). 화면은 로그인 여부를
 * 따로 알고 버튼 노출을 정한다.
 */
export function fetchPostDetail(
  postId: number,
  options: RequestOptions = {},
): Promise<Result<PostDetail>> {
  return getJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}`,
    toPostDetail,
    options,
  );
}

/**
 * 커뮤니티 글 목록.
 *
 * `GET /api/mobile/community/posts` — **비회원 조회가 열려 있다**
 * (실측 2026-11-19, HTTP 200). 커서 기반이라 글이 추가돼도 목록이 밀리지 않는다.
 *
 * `boardTeamId` 를 주면 그 팀 게시판, 없으면 전체다.
 */
export function fetchPosts(
  {
    cursor,
    size = 20,
    boardTeamId,
  }: { cursor?: number; size?: number; boardTeamId?: number } = {},
  options: RequestOptions = {},
): Promise<Result<PostList>> {
  const q = new URLSearchParams({ size: String(size) });
  if (cursor !== undefined) q.set('cursor', String(cursor));
  if (boardTeamId !== undefined) q.set('boardTeamId', String(boardTeamId));

  return getJson(
    `${API_BASE_URL}/mobile/community/posts?${q}`,
    toPostList,
    options,
  );
}

/**
 * 글의 댓글 목록.
 *
 * `GET /api/mobile/community/posts/{postId}/comments` — **비회원 조회가 열려
 * 있다**(실측 2026-11-19, HTTP 200).
 *
 * **오래된 순이다**(글 목록과 반대). 대화가 위에서 아래로 읽히게 하려는 것이라
 * 웹도 받은 순서를 그대로 그린다.
 *
 * 기본 50건인 것도 Dart 와 같다 — 댓글은 글보다 짧아 한 번에 많이 받아도
 * 부담이 적고, 대화가 중간에 끊기면 읽기 어렵다. 서버 상한은 100 이다.
 */
export function fetchComments(
  postId: number,
  { cursor, size = 50 }: { cursor?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<CommentList>> {
  const q = new URLSearchParams({ size: String(size) });
  if (cursor !== undefined) q.set('cursor', String(cursor));

  return getJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/comments?${q}`,
    toCommentList,
    options,
  );
}

// ── 쓰기 ──────────────────────────────────────────────────
//
// **전부 로그인이 필요하다**(`token` 필수). 비회원이 부르면 401 이고,
// 호출부가 그걸 로그인 유도로 바꾼다.
//
// **낙관적 업데이트를 하지 않는다.** 서버가 토글 후 최종 상태와 개수를
// 돌려주므로 그 값으로 교체한다 — 연타해도 서버 값으로 수렴한다(Dart
// `community_detail_viewmodel.dart` 의 명시적 결정과 같다).

/** 추천 토글 결과. 서버가 최종 상태와 개수를 함께 준다. */
export type LikeResult = { liked: boolean; likeCount: number };

function toLikeResult(json: unknown): LikeResult {
  if (!isObject(json)) throw new TypeError('LikeResult: 객체가 아니다');
  return {
    liked: boolOr(json.liked, false),
    likeCount: numOr(json.likeCount, 0),
  };
}

/** 글 추천 토글. `POST /posts/{id}/like` */
export function togglePostLike(
  postId: number,
  options: RequestOptions = {},
): Promise<Result<LikeResult>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/like`,
    toLikeResult,
    options,
  );
}

/** 글 스크랩 토글. `POST /posts/{id}/scrap` — 토글 후 상태만 준다. */
export function togglePostScrap(
  postId: number,
  options: RequestOptions = {},
): Promise<Result<boolean>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/scrap`,
    (json) => {
      if (!isObject(json)) throw new TypeError('scrap: 객체가 아니다');
      return boolOr(json.scrapped, false);
    },
    options,
  );
}

/**
 * 이 글 알림 켬/끔 토글. `POST /posts/{id}/notification`
 *
 * 끄면 이 글의 댓글·답글 알림이 오지 않는다. 서버가 안 주면 **true** 로 본다 —
 * Dart 기본값과 같다(알림이 기본 켜짐이라 모르면 켜진 것으로 본다).
 */
export function togglePostNotification(
  postId: number,
  options: RequestOptions = {},
): Promise<Result<boolean>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/notification`,
    (json) => {
      if (!isObject(json)) throw new TypeError('notification: 객체가 아니다');
      return boolOr(json.enabled, true);
    },
    options,
  );
}

/** 댓글 추천 토글. `POST /comments/{id}/like` */
export function toggleCommentLike(
  commentId: number,
  options: RequestOptions = {},
): Promise<Result<LikeResult>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/comments/${commentId}/like`,
    toLikeResult,
    options,
  );
}

/**
 * 댓글 작성. `POST /posts/{id}/comments` — 만들어진 댓글 id 를 돌려준다.
 *
 * **`replyToCommentId` 만 넘긴다. `parentId` 는 서버가 정한다.** 답글을 1단으로
 * 접는 규칙(답글의 답글도 최상위에 붙는다)과 멘션 대상 계산이 서버 몫이라,
 * 앱이 트리를 직접 계산하면 두 구현이 어긋난다(Dart `createComment` 주석).
 */
export function createComment(
  postId: number,
  { body, replyToCommentId }: { body: string; replyToCommentId?: number },
  options: RequestOptions = {},
): Promise<Result<number>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/comments`,
    (json) => {
      if (!isObject(json)) throw new TypeError('createComment: 객체가 아니다');
      return numOr(json.id, 0);
    },
    {
      ...options,
      body:
        replyToCommentId === undefined
          ? { body }
          : { body, replyToCommentId },
    },
  );
}

/**
 * 투표. `POST /posts/{id}/poll/vote` — 투표 후 상태를 통째로 돌려준다.
 *
 * **단일 선택은 변경이 안 된다**(서버 계약). 복수 선택이면 아직 안 고른
 * 선택지만 추가로 고를 수 있다.
 */
export function votePoll(
  postId: number,
  optionId: number,
  options: RequestOptions = {},
): Promise<Result<Poll>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/poll/vote`,
    (json) => {
      if (!isObject(json)) throw new TypeError('votePoll: 객체가 아니다');
      return toPoll(json);
    },
    { ...options, body: { optionId } },
  );
}

/**
 * Cloudinary 업로드 서명.
 *
 * **백엔드는 서명만 발급하고 파일은 받지 않는다.** 바이너리는 브라우저가
 * Cloudinary 로 직접 올린다 — 스펙 설명이 *"앱은 업로드 후 받은 secure_url
 * 목록을 게시글 작성/수정의 imageUrls 로 보낸다"* 로 못박고 있고, Flutter 도
 * 같은 경로다(`community_image_repository.dart`).
 *
 * 그래서 웹도 **백엔드 변경 없이** 같은 경로를 쓴다. Cloudinary 가 임의
 * Origin 을 반사해 CORS 설정도 필요 없다(실측 2026-11-20: preflight 200,
 * `access-control-allow-origin` 에 요청 Origin 그대로).
 *
 * `api_secret` 은 응답에 없다 — 서명 생성은 서버 몫이다. 타입은 브라우저도
 * 쓰므로 `types.ts` 에 있다.
 */
function toUploadSignature(json: unknown): UploadSignature {
  if (!isObject(json)) throw new TypeError('UploadSignature: 객체가 아니다');
  return {
    uploadUrl: strOr(json.uploadUrl, ''),
    apiKey: strOr(json.apiKey, ''),
    timestamp: numOr(json.timestamp, 0),
    publicId: strOr(json.publicId, ''),
    overwrite: boolOr(json.overwrite, true),
    signature: strOr(json.signature, ''),
  };
}

/**
 * 커뮤니티 첨부 사진 업로드 서명.
 *
 * **이미지 1장당 1회 호출한다** — `publicId` 가 매번 새로 발급된다(프로필
 * 이미지와 다른 점이다. 거긴 회원별로 고정이라 덮어쓴다).
 */
export function fetchUploadSignature(
  options: RequestOptions = {},
): Promise<Result<UploadSignature>> {
  return postJson(
    `${API_BASE_URL}/auth/me/community-image/signature`,
    toUploadSignature,
    options,
  );
}

/**
 * 글 작성. `POST /mobile/community/posts` — 만들어진 글 id 를 돌려준다.
 *
 * **이미지는 URL 로 보낸다.** 바이너리는 이미 Cloudinary 에 올라가 있고
 * (→ [fetchUploadSignature]) 여기엔 `secure_url` 목록만 싣는다.
 *
 * `bodyFormat` 은 지금 'PLAIN' 만 쓴다 — 블록 에디터는 다음 단계다.
 * 'BLOCKS' 면 `body` 가 블록 JSON 문자열이어야 한다.
 *
 * `boardTeamId` 는 null 로 고정이다. 팀별 게시판이 네이티브 쪽에서 보류
 * 상태라(글 리젠 악순환 우려) 웹도 전체 게시판만 쓴다.
 */
export function createPost(
  {
    title,
    body,
    imageUrls = [],
    bodyFormat = 'PLAIN',
    boardTeamId = null,
  }: {
    title: string;
    body: string;
    imageUrls?: string[];
    bodyFormat?: string;
    boardTeamId?: number | null;
  },
  options: RequestOptions = {},
): Promise<Result<number>> {
  return postJson(
    `${API_BASE_URL}/mobile/community/posts`,
    (json) => {
      if (!isObject(json)) throw new TypeError('createPost: 객체가 아니다');
      return numOr(json.id, 0);
    },
    {
      ...options,
      body: { boardTeamId, title, body, bodyFormat, imageUrls },
    },
  );
}

/**
 * 커뮤니티 알림 미읽음 수.
 *
 * `GET /api/mobile/me/notifications?group=COMMUNITY&size=1` — 목록이 아니라
 * **개수만** 필요해서 `size=1` 로 부른다(Dart `community_screen.dart` 와 같다).
 *
 * **경기 알림은 세지 않는다** — `group=COMMUNITY` 로 거른다. 그쪽은 마이구독
 * 이 담당한다.
 *
 * 비로그인·실패는 0 으로 본다. 벨 배지는 장식이라 못 세었다고 화면을 막을
 * 이유가 없다.
 */
export function fetchCommunityUnreadCount(
  options: RequestOptions = {},
): Promise<Result<number>> {
  return getJson(
    `${API_BASE_URL}/mobile/me/notifications?group=COMMUNITY&page=0&size=1`,
    (json) => {
      if (!isObject(json)) throw new TypeError('unreadCount: 객체가 아니다');
      return numOr(json.unreadCount, 0);
    },
    options,
  );
}

/** 검색어 최소 길이. 이보다 짧으면 **서버가 400 을 준다**(실측 2026-11-19). */
export const SEARCH_MIN_LENGTH = 2;

/**
 * 커뮤니티 글 검색 — 제목·본문 키워드.
 *
 * `GET /api/mobile/community/posts/search` — 응답이 목록(`fetchPosts`)과
 * **같은 모양이다**(실측 2026-11-19: `posts`·`nextCursor`·`boardViewer`, 글
 * 필드 14개 동일). 그래서 `PostList` 타입과 매퍼를 그대로 쓴다.
 *
 * 비회원 조회가 열려 있다(HTTP 200).
 *
 * **짧은 검색어는 부르지 않는다.** 2자 미만이면 서버가 400 이라 호출 자체가
 * 낭비다 — 호출부가 [SEARCH_MIN_LENGTH] 로 거른다.
 */
export function searchPosts(
  {
    q,
    cursor,
    size = 20,
  }: { q: string; cursor?: number; size?: number },
  options: RequestOptions = {},
): Promise<Result<PostList>> {
  const params = new URLSearchParams({ q, size: String(size) });
  if (cursor !== undefined) params.set('cursor', String(cursor));

  return getJson(
    `${API_BASE_URL}/mobile/community/posts/search?${params}`,
    toPostList,
    options,
  );
}
