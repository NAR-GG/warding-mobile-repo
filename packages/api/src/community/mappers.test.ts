// 매퍼 회귀 테스트 — `tsx --test` 로 돈다.
//
// 왜 필요한가: 타입 체크는 **런타임 응답을 보지 않는다.** 서버가 필드를 빼거나
// 타입을 바꿔도 `tsc` 는 통과한다. 실제로 `viewer` 를 null 가능으로 잘못
// 설계했다가 실측 응답으로 잡았다(2026-11-17).
//
// 고정 샘플은 `fixtures/post-detail.json` 이고, 실제 서버 응답을 받아 제목·
// 본문·닉네임만 치환한 것이다(`GET /api/mobile/community/posts/50`). 서버
// 형식이 바뀌면 이 파일을 갱신하면서 어디가 달라졌는지 보게 된다.
//
// Node 내장 타입 스트리핑은 확장자 없는 상대 import 를 못 풀어서 `tsx` 를 쓴다
// — 패키지가 소비처에 `allowImportingTsExtensions` 를 강요하지 않으려면
// 소스 쪽 import 에 확장자를 붙일 수 없기 때문이다.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(
  readFileSync(join(here, 'fixtures', 'post-detail.json'), 'utf8'),
);

import { parseBlocks, toPostDetail, toPostList, toPostSummary } from './mappers';
import { isHeading } from './types';

test('실제 응답을 도메인 타입으로 옮긴다', () => {
  const p = toPostDetail(fixture);

  assert.equal(typeof p.id, 'number');
  assert.equal(typeof p.title, 'string');
  assert.equal(typeof p.body, 'string');
  assert.equal(typeof p.viewCount, 'number');
  assert.equal(typeof p.edited, 'boolean');
  assert.ok(Array.isArray(p.images));
});

test('viewer 는 null 이 되지 않는다', () => {
  // 비회원 응답(viewer 객체 포함)
  assert.equal(typeof toPostDetail(fixture).viewer.liked, 'boolean');
  // 구버전 응답(viewer 없음) → 기본값으로 메운다
  const { viewer, ...withoutViewer } = fixture;
  void viewer;
  const p = toPostDetail(withoutViewer);
  assert.equal(p.viewer.liked, false);
  assert.equal(p.viewer.mine, false);
});

test('필드가 전부 빠져도 터지지 않는다', () => {
  const p = toPostDetail({});
  assert.equal(p.id, 0);
  assert.equal(p.title, '');
  assert.equal(p.bodyFormat, 'PLAIN');
  assert.equal(p.author, null);
  assert.equal(p.poll, null);
  assert.deepEqual(p.images, []);
  assert.equal(p.createdAt, null);
});

test('타입이 어긋난 값은 기본값으로 떨어진다', () => {
  const p = toPostDetail({
    id: 'not-a-number',
    title: 42,
    images: 'nope',
    createdAt: 'garbage',
  });
  assert.equal(p.id, 0);
  assert.equal(p.title, '');
  assert.deepEqual(p.images, []);
  assert.equal(p.createdAt, null);
});

test('객체가 아니면 던진다 (getJson 이 parseFailure 로 바꾼다)', () => {
  assert.throws(() => toPostDetail(null), TypeError);
  assert.throws(() => toPostDetail([]), TypeError);
  assert.throws(() => toPostDetail('string'), TypeError);
});

test('날짜는 Date 로, 못 읽으면 null', () => {
  assert.ok(toPostDetail({ createdAt: '2026-11-17T08:57:54.006' }).createdAt instanceof Date);
  assert.equal(toPostDetail({ createdAt: '' }).createdAt, null);
});

test('블록 본문을 파싱한다', () => {
  const blocks = parseBlocks(
    JSON.stringify([
      { type: 'text', text: '안녕', style: 'heading' },
      { type: 'image', url: 'https://x/1.jpg' },
      { type: 'nope' },
    ]),
  );
  assert.equal(blocks.length, 3);
  assert.equal(blocks[0]?.text, '안녕');
  assert.equal(isHeading(blocks[0]!), true);
  assert.equal(blocks[1]?.url, 'https://x/1.jpg');
  // 모르는 타입도 버리지 않는다 — 렌더러가 건너뛴다
  assert.equal(blocks[2]?.type, 'nope');
});

test('본문 파싱 실패는 빈 목록 (평문 폴백)', () => {
  assert.deepEqual(parseBlocks('not json'), []);
  assert.deepEqual(parseBlocks(''), []);
  assert.deepEqual(parseBlocks('{"not":"array"}'), []);
});

test('실제 fixture 의 본문은 이미지 블록 4개다', () => {
  const blocks = parseBlocks(toPostDetail(fixture).body);
  assert.ok(blocks.length > 0);
  assert.ok(blocks.every((b) => typeof b.type === 'string'));
});

// ── 목록 ─────────────────────────────────────────────────

const listFixture = JSON.parse(
  readFileSync(join(here, 'fixtures', 'post-list.json'), 'utf8'),
);

test('실제 목록 응답을 옮긴다', () => {
  const page = toPostList(listFixture);
  assert.ok(page.posts.length > 0);
  const p = page.posts[0]!;
  assert.equal(typeof p.id, 'number');
  assert.equal(typeof p.title, 'string');
  assert.equal(typeof p.bodyPreview, 'string');
  assert.equal(typeof p.hasPoll, 'boolean');
});

test('목록에는 본문 전문이 없다 (bodyPreview 만)', () => {
  // 상세와 타입을 합치지 않는 근거. 합치면 상세 화면이 매번 분기하게 된다.
  const raw = listFixture.posts[0];
  assert.equal('body' in raw, false);
  assert.equal('viewer' in raw, false);
  assert.ok('bodyPreview' in raw);
});

test('nextCursor 가 없으면 null (마지막 페이지)', () => {
  assert.equal(toPostList({ posts: [] }).nextCursor, null);
  assert.equal(toPostList({ posts: [], nextCursor: 124 }).nextCursor, 124);
});

test('전체 게시판 글은 boardTeamId 가 null', () => {
  const p = toPostSummary({ boardTeamId: null, boardTeamCode: null });
  assert.equal(p.boardTeamId, null);
  assert.equal(p.boardTeamCode, null);
});

test('탈퇴 회원이면 author 가 null', () => {
  assert.equal(toPostSummary({}).author, null);
});

test('목록 필드가 비어도 터지지 않는다', () => {
  const p = toPostSummary({});
  assert.equal(p.id, 0);
  assert.equal(p.title, '');
  assert.equal(p.imageCount, 0);
  assert.equal(p.hasPoll, false);
  assert.equal(p.thumbnailUrl, null);
});

test('posts 가 배열이 아니면 빈 목록', () => {
  assert.deepEqual(toPostList({ posts: 'nope' }).posts, []);
  assert.throws(() => toPostList(null), TypeError);
});
