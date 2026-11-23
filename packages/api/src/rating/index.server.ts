import {
  API_BASE_URL,
  deleteJson,
  getJson,
  putJson,
  type RequestOptions,
  type Result,
} from '../client';
import { toMyRating, toMyReviewPage, toPlayerRatingDetail } from './mappers';
import type { MyRating, MyReviewPage, PlayerRatingDetail } from './types';

/**
 * 선수 평점 상세 + 리뷰 목록.
 *
 * `GET /api/mobile/live/games/{gameId}/participants/{participantId}/ratings`
 * — Flutter `ApiConfig.playerRatingUrl` 과 같다.
 *
 * **비회원 조회가 열려 있다**(실측 2026-11-23, HTTP 200). 다만 로그인 상태면
 * `myRating` 과 `reviews[].mine` 이 채워지므로 **토큰이 있으면 캐시하지
 * 않는다** — 공유 캐시에 담으면 남의 "내 평점" 이 보인다.
 */
export function fetchPlayerRatingDetail(
  {
    gameId,
    participantId,
    page = 0,
    size = 20,
  }: { gameId: string; participantId: number; page?: number; size?: number },
  options: RequestOptions = {},
): Promise<Result<PlayerRatingDetail>> {
  return getJson(
    `${API_BASE_URL}/mobile/live/games/${encodeURIComponent(gameId)}` +
      `/participants/${participantId}/ratings?page=${page}&size=${size}`,
    toPlayerRatingDetail,
    options,
  );
}

/**
 * 내가 작성한 평가 목록.
 *
 * `GET /api/mobile/me/ratings` — **인증 필수다**(실측 2026-11-23, 무인증 401).
 * 사용자마다 다른 목록이라 호출부가 `cache: 'no-store'` 를 준다.
 */
export function fetchMyRatings(
  { page = 0, size = 20 }: { page?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<MyReviewPage>> {
  return getJson(
    `${API_BASE_URL}/mobile/me/ratings?page=${page}&size=${size}`,
    toMyReviewPage,
    options,
  );
}

/**
 * 내 평가 작성·수정.
 *
 * `PUT .../my-rating` — **신규와 수정을 구분하지 않는다**(Dart 와 같다).
 *
 * **별점은 정수로 보낸다.** UI 는 0.5 단위지만 저장은 반올림한 정수다
 * (3.5 → 4). 호출부가 반올림해서 넘긴다 — 서버 저장값과 어긋나지 않게
 * 하려는 것이고, Dart 쪽도 `result.rating.round()` 로 같은 처리를 한다.
 */
export function saveMyRating(
  {
    gameId,
    participantId,
    rating,
    comment,
  }: {
    gameId: string;
    participantId: number;
    rating: number;
    comment?: string;
  },
  options: RequestOptions = {},
): Promise<Result<MyRating>> {
  return putJson(
    `${API_BASE_URL}/mobile/live/games/${encodeURIComponent(gameId)}` +
      `/participants/${participantId}/my-rating`,
    (json) => toMyRating(json as Record<string, unknown>),
    {
      ...options,
      body: {
        rating,
        // 빈 코멘트는 보내지 않는다 — 서버가 null 로 저장하는 것과 같게 둔다.
        ...(comment && comment.length > 0 ? { comment } : {}),
      },
    },
  );
}

/**
 * 내 평가 삭제.
 *
 * `DELETE .../my-rating` — 본문 없는 204 가 정상이고 `deleteJson` 이 그것을
 * 성공으로 돌려준다.
 */
export function deleteMyRating(
  { gameId, participantId }: { gameId: string; participantId: number },
  options: RequestOptions = {},
): Promise<Result<void>> {
  return deleteJson(
    `${API_BASE_URL}/mobile/live/games/${encodeURIComponent(gameId)}` +
      `/participants/${participantId}/my-rating`,
    options,
  );
}
