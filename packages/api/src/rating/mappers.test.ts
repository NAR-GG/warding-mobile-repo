// 평점 매퍼 회귀 테스트 — `tsx --test` 로 돈다.
//
// fixture 는 실제 서버 응답에서 닉네임·한줄평만 치환한 것이다. 타입 체크는
// 런타임 응답을 보지 않으므로 이쪽이 실제 형식을 지킨다.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  toMyRating,
  toMyReviewPage,
  toPlayerRatingDetail,
  toReview,
} from './mappers';
import { hasMore } from './types';

const here = dirname(fileURLToPath(import.meta.url));
const read = (name: string) =>
  JSON.parse(readFileSync(join(here, 'fixtures', name), 'utf8'));

const detailFixture = read('player-rating-detail.json');
const myRatingsFixture = read('my-ratings.json');

// ── 선수 평점 상세 ────────────────────────────────────────

test('실제 상세 응답을 옮긴다', () => {
  const d = toPlayerRatingDetail(detailFixture);
  assert.equal(typeof d.gameId, 'string');
  assert.equal(typeof d.rateable, 'boolean');
  assert.ok(d.player.playerName.length > 0);
  assert.equal(typeof d.averageRating, 'number');
  assert.ok(d.reviews.length > 0);
});

test('분포는 5칸이 온다 (5점~1점)', () => {
  // 화면이 다섯 줄 막대를 그린다 — 칸이 모자라면 레이아웃이 어긋난다.
  const d = toPlayerRatingDetail(detailFixture);
  assert.equal(d.distribution.length, 5);
  assert.deepEqual(
    d.distribution.map((x) => x.rating),
    [5, 4, 3, 2, 1],
  );
});

test('비로그인이면 myRating 이 null 이다', () => {
  // fixture 는 토큰 없이 받은 응답이다. null 을 객체로 잘못 보면 화면이
  // "내가 이미 평가함" 으로 그려진다.
  const d = toPlayerRatingDetail(detailFixture);
  assert.equal(d.myRating, null);
});

test('mine 이 없으면 false 로 본다', () => {
  // 잘못 true 면 남의 리뷰에 삭제 버튼이 붙는다.
  assert.equal(toReview({}).mine, false);
  assert.equal(toReview({ mine: true }).mine, true);
});

test('rateable 을 모르면 작성 불가로 본다', () => {
  // 버튼을 잘못 띄워 서버가 거절하는 것보다 안 띄우는 쪽이 조용하다.
  assert.equal(toPlayerRatingDetail({}).rateable, false);
});

test('상세가 객체가 아니면 던진다', () => {
  assert.throws(() => toPlayerRatingDetail(null), TypeError);
  assert.throws(() => toPlayerRatingDetail([]), TypeError);
});

test('myRating 의 빈 코멘트는 null 이다', () => {
  assert.equal(toMyRating({ ratingId: 1, rating: 4 }).comment, null);
  assert.equal(toMyRating({ comment: '좋다' }).comment, '좋다');
});

// ── 내 평점 목록 ──────────────────────────────────────────

test('실제 내 평점 목록을 옮긴다', () => {
  const p = toMyReviewPage(myRatingsFixture);
  assert.ok(p.ratings.length > 0);
  const r = p.ratings[0]!;
  assert.equal(typeof r.ratingId, 'number');
  assert.equal(typeof r.gameId, 'string');
  assert.equal(typeof r.participantId, 'number');
  assert.ok(r.playerName.length > 0);
});

test('match 가 함께 온다 (리그·팀 줄의 근거)', () => {
  // match 가 null 이면 화면이 리그·팀 줄을 통째로 비운다.
  const p = toMyReviewPage(myRatingsFixture);
  const r = p.ratings[0]!;
  assert.notEqual(r.match, null);
  assert.ok(r.match!.leagueName.length > 0);
  assert.equal(typeof r.match!.gameOrder, 'number');
});

test('match 가 없으면 null 이다', () => {
  assert.equal(toMyReviewPage({ ratings: [{}] }).ratings[0]!.match, null);
});

test('목록이 배열이 아니면 빈 목록', () => {
  assert.deepEqual(toMyReviewPage({ ratings: 'nope' }).ratings, []);
  assert.deepEqual(toMyReviewPage({}).ratings, []);
});

test('목록이 객체가 아니면 던진다', () => {
  assert.throws(() => toMyReviewPage(null), TypeError);
});

test('hasMore 는 page+1 < totalPages', () => {
  assert.equal(hasMore({ page: 0, totalPages: 1 }), false);
  assert.equal(hasMore({ page: 0, totalPages: 2 }), true);
  assert.equal(hasMore({ page: 1, totalPages: 2 }), false);
});
