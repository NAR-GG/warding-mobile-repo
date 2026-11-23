import test from 'node:test';
import assert from 'node:assert/strict';

import type { MyReviewItem } from 'warding-api';

import { groupByDate } from './groupByDate';

/** 날짜만 의미 있는 테스트라 나머지는 기본값으로 채운다. */
function item(ratingId: number, createdAt: Date | null): MyReviewItem {
  return {
    ratingId,
    gameId: 'g',
    participantId: 1,
    playerId: 1,
    playerName: '선수',
    playerImageUrl: '',
    teamSide: 'Blue',
    role: 'mid',
    championName: '챔피언',
    rating: 5,
    comment: null,
    createdAt,
    updatedAt: null,
    profileImageUrl: null,
    teamImageUrl: null,
    match: null,
  };
}

test('같은 날짜끼리 묶는다', () => {
  const g = groupByDate([
    item(1, new Date(2026, 10, 18, 9)),
    item(2, new Date(2026, 10, 18, 23)),
    item(3, new Date(2026, 10, 17)),
  ]);
  assert.deepEqual([...g.keys()], ['2026.11.18', '2026.11.17']);
  assert.equal(g.get('2026.11.18')!.length, 2);
});

test('삽입 순서(최신 우선)를 유지한다', () => {
  // 서버가 이미 최신순으로 준다 — 정렬을 다시 하면 그 순서를 덮는다.
  const g = groupByDate([
    item(1, new Date(2026, 10, 10)),
    item(2, new Date(2026, 10, 20)),
  ]);
  assert.deepEqual([...g.keys()], ['2026.11.10', '2026.11.20']);
});

test('월·일을 두 자리로 채운다', () => {
  // `2026.1.5` 가 되면 날짜 헤더가 들쭉날쭉해진다.
  const g = groupByDate([item(1, new Date(2026, 0, 5))]);
  assert.deepEqual([...g.keys()], ['2026.01.05']);
});

test('작성일이 없으면 - 로 묶는다', () => {
  // Dart `_dateKey` 와 같은 키다.
  const g = groupByDate([item(1, null)]);
  assert.deepEqual([...g.keys()], ['-']);
});

test('빈 목록은 빈 맵', () => {
  assert.equal(groupByDate([]).size, 0);
});
