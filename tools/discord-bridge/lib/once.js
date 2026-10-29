// Discord 재시도로 같은 동작이 두 번 나가는 것을 막는다.
//
// 왜 필요한가 — 2026-10-27 중복 제출
// ----------------------------------
// 사용자가 [심사 제출] 을 **한 번** 눌렀는데 제출 워크플로우가 두 번 돌았다.
// Vercel 로그에는 같은 엔드포인트로 POST 가 **네 번** 찍혀 있었다
// (00:56:53, 00:56:58, 00:57:03, 00:57:05 — 약 5초 간격).
//
// Discord 는 인터랙션 응답을 **3초** 안에 못 받으면 같은 요청을 재시도한다.
// 그런데 브리지는 응답하기 전에 GitHub dispatch 를 먼저 await 했다. 그래서
// 느린 호출 한 번이 "응답 없음 → 재시도 → 또 dispatch" 를 연쇄로 만들었다.
//
// 범인은 dispatch 자체가 아니다. GitHub API 는 ~25ms 로 답한다. 그날 그 함수는
// 19분간 유휴였고(배포 09:37, 첫 요청 09:56) **콜드 스타트**로 부팅·모듈 로드·
// Ed25519 검증을 하는 동안 3초를 넘겼다.
//
// 그래서 "빨리 응답하기"(lib/http.js 의 respondThenRun)만으로는 부족하다.
// 콜드 스타트는 우리 코드가 돌기 전에 예산을 먹으므로, 재시도가 와도 **두 번째
// 부터는 아무 일도 하지 않는** 장치가 필요하다. 이 모듈이 그 역할이다.
//
// 저장소는 Vercel 의 런타임 캐시(getCache)를 쓴다. 호출마다 프로세스가 달라질 수
// 있어 모듈 수준 Map 으로는 막을 수 없고, 이것 하나 때문에 KV·Redis 를 새로
// 붙이는 것은 과하다.

import { getCache } from '@vercel/functions';

// 재시도는 몇 초 안에 몰려 온다. 10분이면 넉넉하고, 그 뒤에 같은 키가 다시 올
// 일은 사실상 없다(인터랙션 id 는 매번 새로 발급된다).
const TTL_SECONDS = 600;

/**
 * `key` 에 대해 **이번이 처음인지** 돌려준다.
 *
 * 처음이면 표시를 남기고 `true`, 이미 처리된 키면 `false`.
 *
 * 캐시를 쓸 수 없으면(로컬 실행·런타임 변경 등) `true` 를 돌려준다 —
 * 중복 방지가 안 되는 쪽이, 캐시 장애로 **제출이 아예 막히는** 쪽보다 낫다.
 * 중복이 나가도 받는 쪽(submit-for-review.yml)이 ASC 상태로 한 번 더 걸러낸다.
 *
 * `cacheFor` 는 테스트에서 가짜 캐시를 넣기 위한 자리다. `node --test` 의
 * 모듈 mock 은 아직 실험 기능(--experimental-test-module-mocks)이라, 플래그
 * 없이 돌아가도록 주입 지점을 열어 둔다.
 */
export async function claimOnce(key, cacheFor = getCache) {
  try {
    const cache = await cacheFor();
    if (await cache.get(key)) return false;
    await cache.set(key, '1', { ttl: TTL_SECONDS });
    return true;
  } catch (err) {
    console.error('[discord-bridge] 중복 방지 캐시를 쓸 수 없다 — 그대로 진행한다', err);
    return true;
  }
}

/**
 * 인터랙션 하나를 가리키는 멱등성 키.
 *
 * `interaction.id` 를 쓴다. Discord 는 **재시도할 때 같은 id 로** 보내고,
 * 사용자가 버튼을 진짜 두 번 누르면 **다른 id** 가 온다. 그래서 재시도는
 * 막으면서 의도한 재제출은 막지 않는다 (버전을 키로 쓰면 "같은 버전을 일부러
 * 다시 제출" 하는 정당한 경우까지 막힌다).
 */
export function interactionKey(interaction, action) {
  return `discord:${action}:${interaction?.id ?? 'unknown'}`;
}
