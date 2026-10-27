import { test } from 'node:test';
import assert from 'node:assert/strict';
import { claimOnce, interactionKey } from './once.js';

// ── 멱등성 키 ──────────────────────────────────────────────────────────────
//
// Discord 는 **재시도할 때 같은 interaction.id** 로 보내고, 사용자가 버튼을 진짜
// 두 번 누르면 **다른 id** 를 준다. 키를 id 로 잡아야 재시도만 막고 의도한
// 재제출은 통과한다.

test('interactionKey: 같은 인터랙션은 같은 키', () => {
  const a = interactionKey({ id: '12345' }, 'rel_confirm');
  const b = interactionKey({ id: '12345' }, 'rel_confirm');
  assert.equal(a, b);
});

test('interactionKey: 다른 인터랙션은 다른 키 (의도한 재제출을 막지 않는다)', () => {
  const first = interactionKey({ id: '111' }, 'rel_confirm');
  const second = interactionKey({ id: '222' }, 'rel_confirm');
  assert.notEqual(first, second);
});

test('interactionKey: action 이 다르면 키도 다르다', () => {
  // 같은 인터랙션에서 버튼 경로와 모달 경로가 섞이지 않게 한다.
  const button = interactionKey({ id: '999' }, 'rel_confirm');
  const modal = interactionKey({ id: '999' }, 'rel_notes_modal');
  assert.notEqual(button, modal);
});

test('interactionKey: id 가 없어도 터지지 않는다', () => {
  assert.equal(typeof interactionKey(undefined, 'x'), 'string');
  assert.equal(typeof interactionKey({}, 'x'), 'string');
});

// ── claimOnce ─────────────────────────────────────────────────────────────
//
// 실제 Vercel 런타임 캐시는 테스트에서 못 쓰므로 가짜 캐시를 주입한다.

/** TTL 까지 기억하는 가짜 캐시. */
function fakeCache() {
  const store = new Map();
  return {
    calls: store,
    accessor: async () => ({
      get: async (k) => store.get(k),
      set: async (k, v, opts) => void store.set(k, { v, opts }),
    }),
  };
}

test('claimOnce: 처음은 true, 같은 키 재호출은 false', async () => {
  const { accessor } = fakeCache();
  assert.equal(await claimOnce('k1', accessor), true, '처음이면 통과');
  assert.equal(await claimOnce('k1', accessor), false, '두 번째는 막힌다');
  assert.equal(await claimOnce('k2', accessor), true, '다른 키는 통과');
});

test('claimOnce: 재시도 4연타 중 한 번만 통과한다 (2026-10-27 재현)', async () => {
  // 그날 Vercel 로그에 같은 POST 가 네 번 찍혔다. 전부 같은 interaction.id 다.
  const { accessor } = fakeCache();
  const key = interactionKey({ id: 'same-interaction' }, 'rel_confirm');
  const results = [];
  for (let i = 0; i < 4; i++) results.push(await claimOnce(key, accessor));
  assert.deepEqual(results, [true, false, false, false]);
});

test('claimOnce: TTL 을 함께 저장한다', async () => {
  const { calls, accessor } = fakeCache();
  await claimOnce('ttl-check', accessor);
  const entry = calls.get('ttl-check');
  assert.equal(typeof entry.opts?.ttl, 'number', 'ttl 이 있어야 캐시가 영구 점유되지 않는다');
  assert.ok(entry.opts.ttl > 0);
});

test('claimOnce: 캐시를 쓸 수 없으면 통과시킨다 (제출이 막히는 쪽이 더 나쁘다)', async () => {
  const broken = async () => {
    throw new Error('캐시 없음');
  };
  assert.equal(await claimOnce('whatever', broken), true);
  assert.equal(await claimOnce('whatever', broken), true, '계속 통과 — 중복은 받는 쪽이 걸러낸다');
});
