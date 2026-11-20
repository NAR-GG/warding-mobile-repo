// 내 활동 매퍼 회귀 테스트 — `tsx --test` 로 돈다.
//
// **샘플이 실측 응답이 아니다.** `/api/mobile/me/community/*` 는 전부 인증
// 필수라 토큰 없이 받아올 수 없었다. 그래서 샘플은 Dart
// `community_my_activity.dart` 의 `fromJson` 이 읽는 필드를 그대로 옮겨
// 손으로 만든 것이고, 커뮤니티 글 부분만 실측 픽스처
// (`../community/fixtures/post-list.json`)를 끌어 쓴다.
//
// 그래서 이 테스트가 보장하는 것은 **"Dart 와 같은 필드를 같은 널 판단으로
// 읽는다"** 까지다. 서버가 Dart 쪽 가정과 다르게 내려주면 두 플랫폼이 함께
// 틀리고 이 테스트는 통과한다. 토큰을 쓸 수 있게 되면 실측 응답으로 샘플을
// 갈아 끼우는 것이 맞다.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  toMyComment,
  toMyCommentPage,
  toMyPostPage,
  toScrapItem,
  toScrapPage,
} from './mappers';

const here = dirname(fileURLToPath(import.meta.url));
const postList = JSON.parse(
  readFileSync(join(here, '..', 'community', 'fixtures', 'post-list.json'), 'utf8'),
);

/** 실측 커뮤니티 목록에서 글 하나를 꺼낸다 — 스크랩·내 글의 항목과 같은 모양이다. */
const samplePost = postList.posts[0];

test('내 글 페이지를 읽는다', () => {
  const page = toMyPostPage({ posts: [samplePost], nextCursor: 42 });

  assert.equal(page.posts.length, 1);
  assert.equal(typeof page.posts[0]!.id, 'number');
  assert.equal(page.nextCursor, 42);
});

test('마지막 페이지면 nextCursor 가 null 이다', () => {
  assert.equal(toMyPostPage({ posts: [], nextCursor: null }).nextCursor, null);
  // 키 자체가 없는 경우도 같게 본다(Dart 의 `as num?` 과 같다).
  assert.equal(toMyPostPage({ posts: [] }).nextCursor, null);
});

test('내 댓글을 읽는다', () => {
  const c = toMyComment({
    id: 7,
    postId: 114,
    postTitle: '제목',
    body: '댓글 본문',
    likeCount: 3,
    createdAt: '2026-11-18T12:00:00',
    boardTeamId: 2,
    boardTeamCode: 'GEN',
  });

  assert.equal(c.id, 7);
  assert.equal(c.postId, 114);
  assert.equal(c.boardTeamCode, 'GEN');
  assert.ok(c.createdAt instanceof Date);
});

test('전체 게시판 댓글은 게시판 팀이 null 이다', () => {
  const c = toMyComment({ id: 1, postId: 2, postTitle: '', body: '' });

  assert.equal(c.boardTeamId, null);
  assert.equal(c.boardTeamCode, null);
  // 날짜가 없으면 null 이다 — Dart `DateTime.tryParse` 와 같다.
  assert.equal(c.createdAt, null);
  assert.equal(c.likeCount, 0);
});

test('내 댓글 페이지를 읽는다', () => {
  const page = toMyCommentPage({
    comments: [{ id: 1, postId: 2, postTitle: 't', body: 'b' }],
    nextCursor: 1,
  });

  assert.equal(page.comments.length, 1);
  assert.equal(page.nextCursor, 1);
});

test('스크랩은 글을 감싸고 커서가 scrapId 다', () => {
  const item = toScrapItem({ scrapId: 99, post: samplePost });

  assert.equal(item.scrapId, 99);
  assert.equal(item.post.id, samplePost.id);
});

test('스크랩에 글이 없으면 던진다', () => {
  // 그릴 방법이 없는 응답이다. 조용히 빈 글로 만들면 목록에 유령 항목이
  // 남으므로 파싱 실패로 보고한다(Dart 도 캐스팅에서 터진다).
  assert.throws(() => toScrapItem({ scrapId: 1 }), TypeError);
});

test('스크랩 페이지를 읽는다', () => {
  const page = toScrapPage({
    items: [{ scrapId: 1, post: samplePost }],
    nextCursor: null,
  });

  assert.equal(page.items.length, 1);
  assert.equal(page.nextCursor, null);
});

test('객체가 아니면 던진다', () => {
  assert.throws(() => toMyPostPage(null), TypeError);
  assert.throws(() => toMyCommentPage([]), TypeError);
  assert.throws(() => toScrapPage('x'), TypeError);
});
