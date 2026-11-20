import type { PostSummary } from '../community/types';

/**
 * 마이페이지 "내 활동" — 내가 쓴 글·내가 쓴 댓글·스크랩.
 *
 * **널 판단은 Dart `community_my_activity.dart` 를 그대로 따른다.** 같은
 * 응답에서 두 플랫폼이 다른 화면을 그리면 안 되고, OpenAPI 스펙의
 * `required` 는 실전과 어긋난 적이 있어 믿지 않는다.
 *
 * 셋 다 **커서 페이지네이션**이고 커서의 의미가 각각 다르다 — 글은 글 id,
 * 댓글은 댓글 id, 스크랩은 scrapId 다. 그래서 타입을 하나로 합치지 않는다.
 */

/** 내가 쓴 글 한 페이지. 항목은 커뮤니티 목록과 같은 타입이다. */
export type MyPostPage = {
  posts: PostSummary[];
  /** 다음 페이지 커서(글 id). null 이면 마지막이다. */
  nextCursor: number | null;
};

/**
 * 내가 쓴 댓글 한 건.
 *
 * 원글이 삭제되면 목록에서 빠지므로 [postId] 는 항상 유효한 이동 대상이다
 * (Dart 주석과 같은 전제다).
 */
export type MyComment = {
  id: number;
  postId: number;
  postTitle: string;
  body: string;
  likeCount: number;
  createdAt: Date | null;
  /** 원글이 속한 게시판. null 이면 전체 게시판이다. */
  boardTeamId: number | null;
  /** 게시판 팀 코드(`GEN` 등). 팀 목록 조회 없이 배지를 그리라고 서버가 준다. */
  boardTeamCode: string | null;
};

export type MyCommentPage = {
  comments: MyComment[];
  /** 다음 페이지 커서(댓글 id). */
  nextCursor: number | null;
};

/** 스크랩 한 건. 커서가 글 id 가 아니라 `scrapId` 라 감싸는 타입이 있다. */
export type ScrapItem = {
  scrapId: number;
  post: PostSummary;
};

export type ScrapPage = {
  items: ScrapItem[];
  /** 다음 페이지 커서(scrapId). */
  nextCursor: number | null;
};
