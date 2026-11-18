/**
 * 네이티브가 토큰을 넘기는 쿠키 이름.
 *
 * `server-only` 가 걸린 파일과 **분리해 둔다** — 상수만 쓰려는 클라이언트가
 * 그 파일을 당기면 빌드가 깨진다. Dart 쪽 `kAuthCookieName` 과 같은 값이다.
 */
export const AUTH_COOKIE = 'warding_jwt';
