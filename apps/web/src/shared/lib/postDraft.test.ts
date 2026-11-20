import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';

import { DRAFT_MAX_AGE_DAYS, clearDraft, loadDraft, saveDraft } from './postDraft';

/**
 * 임시저장 회귀 테스트.
 *
 * **7일 경계는 화면에 적힌 약속이다**("최대 7일간 보관돼요"). 코드가 그보다
 * 오래 들고 있거나 일찍 버리면 문구가 거짓이 되므로 경계를 못박는다.
 *
 * Node 에는 localStorage 가 없어 최소 구현을 깔아 둔다 — 실제 브라우저 동작을
 * 검증하는 것이 아니라 **보존 기간·깨진 값 처리**를 보는 테스트다.
 */

const store = new Map<string, string>();

(globalThis as { localStorage?: unknown }).localStorage = {
  getItem: (k: string) => store.get(k) ?? null,
  setItem: (k: string, v: string) => void store.set(k, v),
  removeItem: (k: string) => void store.delete(k),
};

const KEY = 'warding:community:draft';
const DAY = 86_400_000;

beforeEach(() => store.clear());

test('저장한 것을 그대로 읽는다', () => {
  saveDraft({ title: '제목', body: '본문', imageUrls: ['https://x/1.jpg'] });

  const d = loadDraft();
  assert.equal(d?.title, '제목');
  assert.equal(d?.body, '본문');
  assert.deepEqual(d?.imageUrls, ['https://x/1.jpg']);
  assert.equal(typeof d?.savedAt, 'number');
});

test('없으면 null', () => {
  assert.equal(loadDraft(), null);
});

test('7일 직전은 남는다', () => {
  const almost = Date.now() - (DRAFT_MAX_AGE_DAYS * DAY - 60_000);
  store.set(KEY, JSON.stringify({ title: 'a', body: 'b', imageUrls: [], savedAt: almost }));
  assert.equal(loadDraft()?.title, 'a');
});

test('7일을 넘기면 버린다', () => {
  const old = Date.now() - (DRAFT_MAX_AGE_DAYS * DAY + 60_000);
  store.set(KEY, JSON.stringify({ title: 'a', body: 'b', imageUrls: [], savedAt: old }));

  assert.equal(loadDraft(), null);
  // 읽으면서 지운다 — 다음에 또 만나지 않게.
  assert.equal(store.has(KEY), false);
});

test('깨진 JSON 은 지우고 없는 것으로 본다', () => {
  store.set(KEY, '{이건 JSON 이 아니다');
  assert.equal(loadDraft(), null);
  assert.equal(store.has(KEY), false);
});

test('savedAt 이 없으면 읽지 않는다', () => {
  // 보존 기간을 판단할 수 없는 값이다.
  store.set(KEY, JSON.stringify({ title: 'a', body: 'b', imageUrls: [] }));
  assert.equal(loadDraft(), null);
});

test('imageUrls 에 문자열이 아닌 것이 섞이면 걸러낸다', () => {
  store.set(
    KEY,
    JSON.stringify({ title: 'a', body: 'b', imageUrls: ['ok', 3, null], savedAt: Date.now() }),
  );
  assert.deepEqual(loadDraft()?.imageUrls, ['ok']);
});

test('clearDraft 로 지운다', () => {
  saveDraft({ title: 'a', body: 'b', imageUrls: [] });
  clearDraft();
  assert.equal(loadDraft(), null);
});
