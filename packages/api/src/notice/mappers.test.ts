// 공지 매퍼 회귀 테스트 — `tsx --test` 로 돈다.
//
// fixture 는 실제 서버 응답(`GET /api/notices?page=0&size=3`)에서 제목·본문만
// 치환한 것이다. 타입 체크는 런타임 응답을 보지 않으므로 이쪽이 실제 형식을
// 지킨다.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

import { toNotice, toNoticePage } from './mappers';

const here = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(
  readFileSync(join(here, 'fixtures', 'notice-page.json'), 'utf8'),
);
const bySlugFixture = JSON.parse(
  readFileSync(join(here, 'fixtures', 'notice-by-slug.json'), 'utf8'),
);

test('실제 목록 응답을 옮긴다', () => {
  const page = toNoticePage(fixture);
  assert.ok(page.notices.length > 0);
  assert.equal(typeof page.last, 'boolean');
  assert.equal(typeof page.totalElements, 'number');

  const n = page.notices[0]!;
  assert.equal(typeof n.id, 'number');
  assert.equal(typeof n.title, 'string');
  assert.equal(typeof n.content, 'string');
  assert.equal(typeof n.pinned, 'boolean');
});

test('본문이 목록에 함께 온다 (상세 API 가 필요 없는 근거)', () => {
  const page = toNoticePage(fixture);
  assert.ok(page.notices.every((n) => n.content.length > 0));
});

test('actionUrl 공백은 null 로 본다', () => {
  assert.equal(toNotice({ actionUrl: '   ' }).actionUrl, null);
  assert.equal(toNotice({ actionUrl: '' }).actionUrl, null);
  assert.equal(toNotice({ actionUrl: null }).actionUrl, null);
  // 앞뒤 공백은 다듬는다
  assert.equal(toNotice({ actionUrl: ' /x ' }).actionUrl, '/x');
});

test('필드가 비어도 터지지 않는다', () => {
  const n = toNotice({});
  assert.equal(n.id, 0);
  assert.equal(n.title, '');
  assert.equal(n.content, '');
  assert.equal(n.pinned, false);
  assert.equal(n.publishedAt, null);
  assert.equal(n.actionUrl, null);
});

test('last 를 모르면 true 로 본다 (무한 요청 방지)', () => {
  // false 로 떨어지면 "더 있다" 로 보고 계속 요청하게 된다
  assert.equal(toNoticePage({}).last, true);
  assert.equal(toNoticePage({ last: false }).last, false);
});

test('목록이 배열이 아니면 빈 목록', () => {
  assert.deepEqual(toNoticePage({ content: 'nope' }).notices, []);
  assert.deepEqual(toNoticePage({}).notices, []);
});

test('객체가 아니면 던진다', () => {
  assert.throws(() => toNoticePage(null), TypeError);
  assert.throws(() => toNoticePage([]), TypeError);
});

// ── by-slug 응답 (광고 안내) ──────────────────────────────
//
// 목록과 **다른 경로**(`/notices/by-slug/{slug}`)인데 응답은 공지 한 건
// 그대로다. 페이지 래퍼가 없다는 것이 이 테스트의 요점이다 — 목록 매퍼를
// 잘못 쓰면 빈 화면이 나오고 타입 체크는 통과한다.

test('by-slug 는 페이지 래퍼 없이 공지 한 건이다', () => {
  const n = toNotice(bySlugFixture);
  assert.equal(typeof n.id, 'number');
  assert.ok(n.title.length > 0);
  assert.ok(n.content.length > 0);
  assert.equal(n.pinned, false);
  assert.ok(n.publishedAt instanceof Date);
});

test('광고 안내는 actionUrl 을 들고 온다 (하단 신청 버튼의 근거)', () => {
  // 이 값이 null 이면 버튼이 사라진다 — 화면의 주 행동이 없어진다.
  const n = toNotice(bySlugFixture);
  assert.ok(n.actionUrl?.startsWith('https://'));
});
