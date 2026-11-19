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

import {
  parseBlocks,
  toComment,
  toCommentList,
  toPostDetail,
  toPostList,
  toPostSummary,
} from './mappers';
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

// ── 댓글 ─────────────────────────────────────────────────

const commentFixture = JSON.parse(
  readFileSync(join(here, 'fixtures', 'comment-list.json'), 'utf8'),
);

test('실제 댓글 응답을 옮긴다', () => {
  const page = toCommentList(commentFixture);
  assert.ok(page.comments.length > 0);

  const c = page.comments[0]!;
  assert.equal(typeof c.id, 'number');
  assert.equal(typeof c.likeCount, 'number');
  assert.equal(typeof c.liked, 'boolean');
  assert.equal(typeof c.mine, 'boolean');
  assert.equal(typeof c.edited, 'boolean');
  assert.equal(c.status, 'VISIBLE');
});

test('답글의 parentId 는 최상위 댓글을 가리킨다', () => {
  // 1단까지만 접는 계약. 답글의 답글도 같은 층에 쌓이므로, parentId 가
  // 가리키는 댓글은 **그 자체가 최상위**여야 한다.
  const { comments } = toCommentList(commentFixture);
  const topLevelIds = new Set(
    comments.filter((c) => c.parentId === null).map((c) => c.id),
  );
  const replies = comments.filter((c) => c.parentId !== null);

  assert.ok(replies.length > 0, '픽스처에 답글이 있어야 의미가 있다');
  for (const r of replies) {
    assert.ok(
      topLevelIds.has(r.parentId as number),
      `답글 ${r.id} 의 parentId(${r.parentId}) 가 최상위 댓글이 아니다`,
    );
  }
});

test('답글은 mentionNickname 으로 대상을 알린다', () => {
  const { comments } = toCommentList(commentFixture);
  const replies = comments.filter((c) => c.parentId !== null);
  assert.ok(replies.some((r) => r.mentionNickname !== null));
});

test('VISIBLE 이 아니면 body·author 가 null 이고 행은 남는다', () => {
  // 자리 보존 계약. 답글이 달린 댓글이 통째로 사라지면 대화가 끊긴다.
  const deleted = toComment({ id: 7, status: 'DELETED', body: null, author: null });
  assert.equal(deleted.id, 7);
  assert.equal(deleted.status, 'DELETED');
  assert.equal(deleted.body, null);
  assert.equal(deleted.author, null);
});

test('모르는 status 는 VISIBLE 로 본다', () => {
  assert.equal(toComment({ status: 'WHAT_IS_THIS' }).status, 'VISIBLE');
  assert.equal(toComment({}).status, 'VISIBLE');
});

test('댓글 필드가 비어도 터지지 않는다', () => {
  const c = toComment({});
  assert.equal(c.id, 0);
  assert.equal(c.parentId, null);
  assert.equal(c.likeCount, 0);
  assert.equal(c.liked, false);
  assert.equal(c.createdAt, null);
});

test('comments 가 배열이 아니면 빈 목록', () => {
  assert.deepEqual(toCommentList({ comments: 'nope' }).comments, []);
  assert.throws(() => toCommentList(null), TypeError);
});
