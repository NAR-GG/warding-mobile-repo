import {
  type Failure,
  type Result,
  err,
  failureFromStatus,
  noDataFailure,
  ok,
  parseFailure,
  toFailure,
} from './failure';

/** 운영 백엔드. Flutter `ApiConfig.host` 와 같은 값이다. */
export const API_HOST = 'https://api.nar.kr';
export const API_BASE_URL = `${API_HOST}/api`;

/**
 * 응답을 기다리는 최대 시간.
 *
 * Flutter `kDefaultApiTimeout` 과 같은 15초다 — 서버 정상 응답이 100ms 안팎이라
 * 15초를 넘겼다면 사실상 실패한 요청이라는 판단도 그대로 가져온다.
 */
export const DEFAULT_TIMEOUT_MS = 15_000;

export type RequestOptions = {
  /**
   * Bearer 토큰. **웹은 토큰을 스스로 갖지 않는다** — 네이티브 Keychain 에
   * 있는 것을 브리지로 받아 호출부가 넘긴다. 비회원 조회가 열린 엔드포인트는
   * 없이 부른다.
   */
  token?: string | null;
  timeoutMs?: number;
  /** SSR 에서 Next 의 fetch 캐시를 제어할 때 쓴다. */
  cache?: RequestCache;
  revalidate?: number | false;
  signal?: AbortSignal;
};

function headersFor(token?: string | null): HeadersInit {
  const h: Record<string, string> = { Accept: 'application/json' };
  if (token) h.Authorization = `Bearer ${token}`;
  return h;
}

/**
 * GET 요청 하나. 실패를 던지지 않고 [Result] 로 돌려준다.
 *
 * Flutter repository 가 `Either<Failure, T>` 를 돌려주는 것과 같은 계약이다 —
 * 호출부가 실패 분기를 빠뜨리면 타입에서 걸린다.
 *
 * `parse` 는 JSON 을 도메인 타입으로 옮기는 함수다. 서버 응답 형식이 화면으로
 * 새지 않도록 여기서 끊는다(Flutter 가 `fromJson` 을 repository 안에서만
 * 부르는 것과 같은 경계다).
 */
export async function getJson<T>(
  url: string,
  parse: (json: unknown) => T,
  options: RequestOptions = {},
): Promise<Result<T>> {
  const { token, timeoutMs = DEFAULT_TIMEOUT_MS, cache, revalidate, signal } = options;

  // 외부에서 준 signal 과 타임아웃을 함께 건다. 둘 중 먼저 끊기는 쪽이 이긴다.
  const timer = AbortSignal.timeout(timeoutMs);
  const abort = signal ? AbortSignal.any([signal, timer]) : timer;

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: headersFor(token),
      signal: abort,
      ...(cache ? { cache } : {}),
      ...(revalidate !== undefined ? { next: { revalidate } } : {}),
    });

    // 204·205 는 본문이 없다. 파싱하면 SyntaxError 가 나므로 먼저 가른다.
    if (res.status === 204 || res.status === 205) return err(noDataFailure());

    if (!res.ok) {
      // 서버가 에러 본문을 주면 cause 에 담는다 — 로그에서 원인을 보기 위해서다.
      const body = await res.text().catch(() => '');
      return err(failureFromStatus(res.status, body || undefined));
    }

    const text = await res.text();
    if (text.trim() === '') return err(noDataFailure());

    let json: unknown;
    try {
      json = JSON.parse(text);
    } catch (e) {
      return err(parseFailure(e));
    }

    // parse 안에서 터지는 것은 응답 형태가 예상과 다른 것이므로 parse 실패다.
    try {
      return ok(parse(json));
    } catch (e) {
      return err(parseFailure(e));
    }
  } catch (e) {
    return err(toFailure(e));
  }
}

export type { Failure, Result };
