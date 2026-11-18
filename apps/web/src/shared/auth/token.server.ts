import 'server-only';

import { cookies } from 'next/headers';

import { AUTH_COOKIE } from './cookie';

/**
 * 웹뷰가 심어 준 인증 토큰.
 *
 * **네이티브가 쿠키로 넘긴다.** 다른 방식과 비교해 이걸 택한 이유:
 * - URL 쿼리로 넘기면 토큰이 접근 로그·리퍼러에 남는다.
 * - 로드 후 JS 로 주입하면 SSR 시점에 토큰이 없어, 좋아요·스크랩 상태가
 *   한 박자 늦게 채워지며 깜빡인다.
 *
 * 쿠키면 **첫 요청부터 서버가 토큰을 들고** API 를 부를 수 있어 로그인 상태까지
 * SSR 로 그려진다.
 *
 * 한계: `webview_flutter` 의 쿠키 API 에는 `httpOnly` 플래그가 없어 JS 로 읽힌다.
 * 웹뷰가 우리 페이지만 띄우므로 외부 스크립트가 끼어들 자리는 없지만,
 * **서드파티 스크립트를 넣게 되면 이 전제가 깨진다**(→ spec Decisions).
 */
/** 토큰. 비로그인이거나 웹뷰 밖이면 null. */
export async function readAuthToken(): Promise<string | null> {
  const store = await cookies();
  const value = store.get(AUTH_COOKIE)?.value;
  return value && value.trim() !== '' ? value : null;
}
