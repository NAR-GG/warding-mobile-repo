/**
 * 커뮤니티 글 상세 도메인 타입.
 *
 * **OpenAPI 스펙의 `required` 를 그대로 믿지 않는다.** 스펙에는 이 응답의
 * required 가 하나도 없어서 전부 optional 로 읽히지만, Flutter 쪽 모델
 * (`features/community/domain/community_*.dart`)은 실전 기준으로 널 여부를
 * 정해 두었다. 두 구현이 어긋나면 같은 응답을 놓고 웹만 화면이 비는 일이
 * 생기므로, **Dart 의 판단을 복제한다.**
 *
 * 들어올 때(`*Dto`)는 전부 널 가능으로 받고, 매퍼가 기본값으로 메워
 * 아래 타입으로 바꾼다 — Dart `fromJson` 이 `?? 0`·`?? ''` 를 쓰는 것과 같다.
 */

export type Author = {
  memberId: number;
  nickname: string;
  profileImageUrl: string | null;
  teamId: number | null;
  teamCode: string | null;
  teamImageUrl: string | null;
};

export type PostImage = {
  id: number;
  url: string;
};

export type PollOption = {
  id: number;
  label: string;
  /** 결과 비공개 상태에서는 서버가 내려주지 않는다. */
  voteCount: number | null;
};

export type Poll = {
  id: number;
  question: string;
  totalVotes: number;
  resultsVisible: boolean;
  allowMultiple: boolean;
  closesAt: Date | null;
  closed: boolean;
  /** 내가 고른 선택지. 비회원·미투표면 빈 배열이다. */
  myOptionIds: number[];
  options: PollOption[];
};

/**
 * 내 상태.
 *
 * **null 이 되지 않는다.** 서버가 안 주면 전부 false 로 메운다 — Dart 가
 * `CommunityPostViewer._empty` 로 같은 처리를 한다. 비회원이라고 해서 화면이
 * 분기를 또 하지 않게 하려는 것이다(비회원은 어차피 전부 false 다).
 *
 * 실측: 비회원 토큰 없이 불러도 서버는 `viewer` 를 객체로 내려준다
 * (2026-11-17, `GET /api/mobile/community/posts/50`).
 */
export type PostViewer = {
  liked: boolean;
  scrapped: boolean;
  mine: boolean;
  blockedAuthor: boolean;
  notificationEnabled: boolean;
};

export type PostDetail = {
  id: number;
  /** 전체 게시판이면 null. 팀 게시판이면 팀 id 다. */
  boardTeamId: number | null;
  /** 구버전 응답에는 없을 수 있다 — 배지를 그리는 쪽이 null 을 처리한다. */
  boardTeamCode: string | null;
  title: string;
  body: string;
  /**
   * 본문 형식. 서버가 안 주면 'PLAIN' 으로 본다.
   * 실측값은 'BLOCKS' 다 — 본문이 블록 JSON 이라는 뜻이고, 렌더러가
   * `body` 를 그 형식으로 해석한다.
   */
  bodyFormat: string;
  /** 탈퇴·차단 등으로 작성자가 없을 수 있다. */
  author: Author | null;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  edited: boolean;
  createdAt: Date | null;
  viewer: PostViewer;
  images: PostImage[];
  poll: Poll | null;
};

/**
 * 본문 블록 (`bodyFormat === 'BLOCKS'`).
 *
 * Flutter `features/community/domain/community_post_block.dart` 와 같은 모양이다.
 * 타입은 'text' · 'image' · 'link' · 'embed' 네 가지고, 알 수 없는 타입은
 * 렌더러가 건너뛴다(서버가 새 타입을 추가해도 화면이 안 깨진다).
 */
export type PostBlock = {
  type: string;
  text: string | null;
  /** 'heading' 이면 제목 스타일. */
  style: string | null;
  url: string | null;
  title: string | null;
  description: string | null;
  imageUrl: string | null;
  siteName: string | null;
  provider: string | null;
};

export const isHeading = (b: PostBlock): boolean => b.style === 'heading';

/**
 * 목록 항목. 상세(`PostDetail`)와 **다른 타입이다.**
 *
 * 서버가 목록에는 `bodyPreview`(본문 일부)만 주고 `body`·`viewer`·`poll` 은
 * 주지 않는다. 한 타입으로 합치면 목록에서 없는 필드를 optional 로 열어야
 * 하고, 그러면 상세 화면이 "있을 수도 없을 수도" 를 매번 분기하게 된다.
 *
 * 널 판단은 Flutter `CommunityRemotePost` 를 복제한다.
 */
export type PostSummary = {
  id: number;
  /** null 이면 전체 게시판 글. */
  boardTeamId: number | null;
  /** 게시판 팀 코드(`GEN`·`HLE` 등). 전체 게시판이면 null. */
  boardTeamCode: string | null;
  title: string;
  /** 본문 일부. 목록에는 전문이 오지 않는다. */
  bodyPreview: string;
  /** 탈퇴 회원이면 null. */
  author: Author | null;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  edited: boolean;
  createdAt: Date | null;
  thumbnailUrl: string | null;
  imageCount: number;
  /** 투표가 붙어 있는가 — 목록 배지용. */
  hasPoll: boolean;
};

export type PostList = {
  posts: PostSummary[];
  /**
   * 다음 페이지 커서. null 이면 마지막이다.
   *
   * 페이지 번호가 아니라 **커서**다 — 글이 추가돼도 목록이 밀리지 않는다.
   */
  nextCursor: number | null;
};
