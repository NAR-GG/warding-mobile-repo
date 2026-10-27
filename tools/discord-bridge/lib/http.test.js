import { test } from 'node:test';
import assert from 'node:assert/strict';
import { respondThenRun } from './http.js';

// Discord 의 인터랙션 응답 제한은 3초다. 넘기면 같은 요청을 재시도하고, 재시도
// 마다 dispatch 가 한 번씩 더 나가 중복 제출이 됐다(2026-10-27). 그래서 "느린
// 작업이 있어도 응답은 즉시" 가 이 헬퍼의 계약이다.

/** res.end() 까지를 기록하는 가짜 ServerResponse. */
function fakeRes() {
  const r = {
    statusCode: 0,
    headers: {},
    body: undefined,
    endedAt: undefined,
    setHeader(k, v) {
      this.headers[k] = v;
    },
    end(payload) {
      this.body = payload;
      this.endedAt = process.hrtime.bigint();
    },
  };
  return r;
}

const interaction = { id: 'i-1', application_id: 'app-1', token: 'tok-1' };

test('respondThenRun: 작업이 느려도 즉시 응답한다', async () => {
  const res = fakeRes();
  const started = process.hrtime.bigint();

  // 실제 콜드 스타트 + GitHub 호출보다 느린 작업을 흉내 낸다.
  const task = respondThenRun(res, interaction, { ephemeral: true }, async () => {
    await new Promise((r) => setTimeout(r, 300));
    return '완료';
  });

  assert.ok(res.endedAt !== undefined, '작업을 기다리지 않고 이미 응답했어야 한다');
  const elapsedMs = Number(res.endedAt - started) / 1e6;
  assert.ok(elapsedMs < 50, `응답이 ${elapsedMs.toFixed(1)}ms 걸렸다 — 즉시여야 한다`);

  await task.catch(() => {}); // follow-up 은 네트워크가 없어 실패한다(아래 참고)
});

test('respondThenRun: 지연 응답(type 5)과 ephemeral flag 를 보낸다', async () => {
  const res = fakeRes();
  const task = respondThenRun(res, interaction, { ephemeral: true }, async () => '끝');
  const sent = JSON.parse(res.body);

  assert.equal(res.statusCode, 200);
  // type 5 = DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE. Discord 가 "..." 을 띄운다.
  assert.equal(sent.type, 5);
  // 64 = ephemeral. 여기서 정해야 follow-up 까지 같은 가시성이 유지된다.
  assert.equal(sent.data.flags, 64);

  await task.catch(() => {});
});

test('respondThenRun: ephemeral 을 끄면 flags 를 넣지 않는다', async () => {
  const res = fakeRes();
  const task = respondThenRun(res, interaction, { ephemeral: false }, async () => '끝');
  const sent = JSON.parse(res.body);
  assert.equal(sent.type, 5);
  assert.equal(sent.data.flags, undefined);
  await task.catch(() => {});
});

test('respondThenRun: 작업이 throw 해도 응답은 이미 나갔고 task 는 삼키지 않는다', async () => {
  const res = fakeRes();
  let ran = false;
  const task = respondThenRun(res, interaction, { ephemeral: true }, async () => {
    ran = true;
    throw new Error('dispatch 실패');
  });

  // 응답은 작업 성패와 무관하게 먼저 나간다.
  assert.equal(JSON.parse(res.body).type, 5);
  await task.catch(() => {});
  assert.ok(ran, '작업이 실제로 실행됐어야 한다');
});

test('respondThenRun: work 의 반환값이 follow-up 본문이 된다', async () => {
  // followUp 은 Discord API 를 때리므로 fetch 를 가로채 본문만 확인한다.
  const realFetch = globalThis.fetch;
  let seen;
  globalThis.fetch = async (url, opts) => {
    seen = { url: String(url), body: JSON.parse(opts.body), method: opts.method };
    return { ok: true, status: 200, text: async () => '' };
  };
  try {
    const res = fakeRes();
    await respondThenRun(res, interaction, { ephemeral: true }, async () => '✅ 제출했어요');

    assert.equal(seen.method, 'PATCH', '지연 응답 메시지를 고쳐 쓴다');
    assert.ok(
      seen.url.includes(`/webhooks/app-1/tok-1/messages/@original`),
      `원본 메시지를 가리켜야 한다: ${seen.url}`
    );
    assert.equal(seen.body.content, '✅ 제출했어요');
    assert.equal(seen.body.flags, 64);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('respondThenRun: 작업이 실패하면 오류 안내를 띄운다', async () => {
  const realFetch = globalThis.fetch;
  let seen;
  globalThis.fetch = async (_url, opts) => {
    seen = JSON.parse(opts.body);
    return { ok: true, status: 200, text: async () => '' };
  };
  try {
    const res = fakeRes();
    await respondThenRun(res, interaction, { ephemeral: true }, async () => {
      throw new Error('GitHub 500');
    });
    assert.match(seen.content, /오류/, '사용자에게 실패를 알려야 한다');
  } finally {
    globalThis.fetch = realFetch;
  }
});
