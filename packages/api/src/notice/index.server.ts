import { API_BASE_URL, getJson, type RequestOptions, type Result } from '../client';
import { toNotice, toNoticePage } from './mappers';
import type { Notice, NoticePage } from './types';

/**
 * 공지 목록.
 *
 * `GET /api/notices?page&size` — Flutter `ApiConfig.noticesUrl` 과 같다.
 * **비회원 조회가 열려 있다**(실측 2026-11-18, HTTP 200).
 *
 * 응답이 본문(`content`)까지 주므로 상세를 따로 부르지 않는다.
 */
export function fetchNotices(
  { page = 0, size = 20 }: { page?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<NoticePage>> {
  return getJson(
    `${API_BASE_URL}/notices?page=${page}&size=${size}`,
    toNoticePage,
    options,
  );
}

/**
 * 홈 배너에 띄우는 공지. 없으면 빈 배열이다.
 *
 * `GET /api/notices/promoted` — 응답이 배열이라 `toNoticePage` 가 아니라
 * 항목 매퍼를 직접 쓴다.
 */
export function fetchPromotedNotices(
  options: RequestOptions = {},
): Promise<Result<Notice[]>> {
  return getJson(
    `${API_BASE_URL}/notices/promoted`,
    (json) => {
      if (!Array.isArray(json)) throw new TypeError('promoted: 배열이 아니다');
      return json.filter((x): x is Record<string, unknown> =>
        typeof x === 'object' && x !== null && !Array.isArray(x),
      ).map(toNotice);
    },
    options,
  );
}
