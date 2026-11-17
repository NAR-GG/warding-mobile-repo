/**
 * 실패 분류 — Flutter `core/error/failure.dart` + `core/data/failure_mapper.dart`
 * 의 웹 구현.
 *
 * 같은 이름·같은 분기를 쓴다. 화면이 "다시 로그인" 을 안내해야 하는 경우와
 * "잠시 후 다시" 를 안내하는 경우가 다르기 때문에 401·403 을 따로 가른다
 * (Dart 주석과 같은 이유다).
 */
export type FailureKind =
  | 'server'
  | 'network'
  | 'parse'
  | 'unauthorized'
  | 'noData';

export type Failure = {
  kind: FailureKind;
  /** 서버 실패일 때의 HTTP 상태 코드. 그 외에는 없다. */
  statusCode?: number;
  /** 원인. 로깅용이고 화면에 그대로 보이지 않는다. */
  cause?: unknown;
};

export const serverFailure = (statusCode?: number, cause?: unknown): Failure =>
  statusCode === undefined ? { kind: 'server', cause } : { kind: 'server', statusCode, cause };

export const networkFailure = (cause?: unknown): Failure => ({ kind: 'network', cause });
export const parseFailure = (cause?: unknown): Failure => ({ kind: 'parse', cause });
export const unauthorizedFailure = (cause?: unknown): Failure => ({ kind: 'unauthorized', cause });
export const noDataFailure = (cause?: unknown): Failure => ({ kind: 'noData', cause });

/**
 * 성공 아니면 실패. Flutter 가 `Either<Failure, T>`(fpdart)를 쓰는 것과 같은
 * 목적이다 — **실패 분기를 타입으로 강제한다.** 예외를 던지면 호출부가
 * `catch` 를 빠뜨려도 아무도 모른다.
 *
 * TS 에는 fpdart 가 없으므로 판별 유니온으로 같은 효과를 낸다.
 */
export type Result<T> = { ok: true; value: T } | { ok: false; failure: Failure };

export const ok = <T>(value: T): Result<T> => ({ ok: true, value });
export const err = <T = never>(failure: Failure): Result<T> => ({ ok: false, failure });

/** HTTP 상태 코드 → Failure. Dart `toFailure` 의 분기와 같다. */
export function failureFromStatus(statusCode: number, cause?: unknown): Failure {
  if (statusCode === 401 || statusCode === 403) return unauthorizedFailure(cause);
  return serverFailure(statusCode, cause);
}

/**
 * 예외 → Failure.
 *
 * `fetch` 는 네트워크 실패에서만 throw 하고 4xx·5xx 는 정상 반환하므로,
 * 여기 들어오는 것은 대개 네트워크·중단·파싱이다. 상태 코드 분기는
 * `failureFromStatus` 가 따로 맡는다.
 */
export function toFailure(e: unknown): Failure {
  if (e instanceof SyntaxError) return parseFailure(e);
  // AbortError 는 타임아웃·취소다. 둘 다 "연결 문제" 로 묶는 쪽이 화면 안내에
  // 맞는다 — 사용자에게는 구분이 의미 없다.
  if (e instanceof DOMException && e.name === 'AbortError') return networkFailure(e);
  if (e instanceof TypeError) return networkFailure(e);
  return serverFailure(undefined, e);
}
