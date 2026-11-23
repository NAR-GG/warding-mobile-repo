/**
 * 평점 도메인 타입.
 *
 * Flutter `features/player_rating/domain/game_rating.dart` 와
 * `features/my_review/domain/entities/my_review_item.dart` 의 널 판단을
 * 복제한다. **스펙의 `required` 를 그대로 믿지 않는다** — Dart 가 실전
 * 응답 기준으로 정해 둔 것을 따르고, 어긋나면 매퍼 테스트가 잡는다.
 */

/** 별점 분포 한 칸. 5점부터 1점까지 다섯 개가 온다. */
export type RatingDistribution = {
  rating: number;
  count: number;
  percentage: number;
};

/** 평점 상세의 선수 정보(KDA 포함). */
export type RatingPlayerDetail = {
  participantId: number;
  playerId: number;
  playerName: string;
  playerImageUrl: string;
  teamSide: string;
  role: string;
  championName: string;
  kills: number;
  deaths: number;
  assists: number;
};

/** 내 평가. 상세 응답의 `myRating` 과 PUT 응답이 같은 모양이다. */
export type MyRating = {
  ratingId: number;
  rating: number;
  comment: string | null;
};

/** 다른 사용자의 리뷰 한 건. */
export type Review = {
  ratingId: number;
  nickname: string;
  /** 작성자 프로필 이미지. 없으면 placeholder 를 그린다. */
  profileImageUrl: string | null;
  /** 작성자 응원팀 로고(구독 뱃지용). 없으면 placeholder. */
  teamImageUrl: string | null;
  rating: number;
  comment: string | null;
  /** 내가 쓴 리뷰인가. 비로그인이면 전부 false 다. */
  mine: boolean;
  createdAt: Date | null;
  updatedAt: Date | null;
};

/**
 * 선수 평점 상세 + 리뷰 목록.
 *
 * **비회원 조회가 열려 있다**(실측 2026-11-23, HTTP 200). 로그인했을 때만
 * `myRating` 과 `reviews[].mine` 이 채워진다.
 */
export type PlayerRatingDetail = {
  gameId: string;
  /** 평점 작성 가능 여부(세트 종료 후 true). */
  rateable: boolean;
  player: RatingPlayerDetail;
  averageRating: number;
  ratingCount: number;
  distribution: RatingDistribution[];
  myRating: MyRating | null;
  reviews: Review[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
};

/** 평가 대상 세트가 속한 매치. 매핑이 없으면 null 이다. */
export type RatedMatch = {
  matchId: string;
  gameOrder: number;
  leagueName: string;
  matchTitle: string;
  blueTeamCode: string;
  redTeamCode: string;
  matchDate: Date | null;
};

/** 내가 작성한 평가 한 건. */
export type MyReviewItem = {
  ratingId: number;
  gameId: string;
  participantId: number;
  playerId: number;
  playerName: string;
  playerImageUrl: string;
  teamSide: string;
  role: string;
  championName: string;
  rating: number;
  comment: string | null;
  createdAt: Date | null;
  updatedAt: Date | null;
  /** 작성자(나) 프로필 이미지. 없으면 placeholder. */
  profileImageUrl: string | null;
  /** 작성자(나) 응원팀 로고. 없으면 placeholder. */
  teamImageUrl: string | null;
  match: RatedMatch | null;
};

/** 내 평가 목록 한 페이지. */
export type MyReviewPage = {
  ratings: MyReviewItem[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
};

/** 다음 페이지가 있는가. Dart `MyReviewPage.hasMore` 와 같은 판정이다. */
export const hasMore = (p: { page: number; totalPages: number }): boolean =>
  p.page + 1 < p.totalPages;
