// 알림 매퍼 회귀 테스트 — `tsx --test` 로 돈다.

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  toMemberNotification,
  toNotificationPage,
  toNotificationType,
} from './mappers';
import {
  gameDurationSeconds,
  isCommunityType,
  isSoloRankEnd,
  postId,
  soloRankWin,
} from './types';

test('백엔드 enum 을 도메인 타입으로 옮긴다', () => {
  assert.equal(toNotificationType('SET_START'), 'setStart');
  assert.equal(toNotificationType('PLAYER_SOLO_RANK_STARTED'), 'playerSoloRank');
  assert.equal(toNotificationType('COMMUNITY_LIKE'), 'communityLike');
});

test('모르는 종류는 버리지 않고 unknown 으로 둔다', () => {
  // 서버가 새 알림을 추가했을 때 목록에서 사라지는 것보다, 기본 아이콘으로
  // 라도 보이는 편이 낫다.
  assert.equal(toNotificationType('SOMETHING_NEW'), 'unknown');
  assert.equal(toNotificationType(undefined), 'unknown');
});

test('data 값을 문자열로 눕힌다', () => {
  // 서버가 숫자·불린으로 싣는 키가 있다 — Dart 가 `v.toString()` 으로 받는다.
  const n = toMemberNotification({
    data: { postId: 42, win: true, kda: '6/3/5' },
  });
  assert.deepEqual(n.data, { postId: '42', win: 'true', kda: '6/3/5' });
});

test('data 의 null 값은 키째 빠진다', () => {
  const n = toMemberNotification({ data: { a: null, b: '1' } });
  assert.deepEqual(n.data, { b: '1' });
});

test('createdAt 이 깨져도 목록이 비지 않는다', () => {
  // epoch 으로 떨어뜨린다(Dart 와 같다) — 시각 하나가 이상한 편이,
  // 목록이 통째로 비는 것보다 낫다.
  const n = toMemberNotification({ createdAt: 'not-a-date' });
  assert.equal(n.createdAt.getTime(), 0);
});

test('읽음 여부를 모르면 안 읽은 것으로 본다', () => {
  // 잘못 true 면 안 읽은 알림이 조용히 평범해진다.
  assert.equal(toMemberNotification({}).read, false);
});

test('솔랭 종료는 eventType 으로 가른다', () => {
  // 시작·종료가 **같은 type** 이라 이것 말고 구분할 길이 없다.
  const end = toMemberNotification({ data: { eventType: 'END' } });
  const start = toMemberNotification({ data: {} });
  assert.equal(isSoloRankEnd(end), true);
  assert.equal(isSoloRankEnd(start), false);
});

test('승패는 결과를 못 읽으면 null 이다', () => {
  const no = toMemberNotification({ data: { eventType: 'END' } });
  assert.equal(soloRankWin(no), null);
  assert.equal(soloRankWin(toMemberNotification({ data: { win: 'true' } })), true);
  assert.equal(
    soloRankWin(toMemberNotification({ data: { win: 'false' } })),
    false,
  );
});

test('경기 길이·원글 id 는 숫자로 꺼낸다', () => {
  const n = toMemberNotification({
    data: { gameDurationSeconds: '1620', postId: '114' },
  });
  assert.equal(gameDurationSeconds(n), 1620);
  assert.equal(postId(n), 114);
  // 키가 없으면 null — 커뮤니티 알림이 아니면 탭해도 이동하지 않는다.
  assert.equal(postId(toMemberNotification({})), null);
});

test('커뮤니티 분류', () => {
  assert.equal(isCommunityType('communityComment'), true);
  assert.equal(isCommunityType('communityRestriction'), true);
  assert.equal(isCommunityType('playerSoloRank'), false);
  assert.equal(isCommunityType('setStart'), false);
});

test('페이지를 옮긴다', () => {
  const p = toNotificationPage({
    notifications: [{ id: 1, type: 'COMMUNITY_LIKE' }],
    unreadCount: 3,
    page: 0,
    size: 20,
    totalElements: 1,
    totalPages: 1,
  });
  assert.equal(p.notifications.length, 1);
  assert.equal(p.unreadCount, 3);
});

test('목록이 배열이 아니면 빈 목록', () => {
  assert.deepEqual(toNotificationPage({ notifications: 'nope' }).notifications, []);
});

test('페이지가 객체가 아니면 던진다', () => {
  assert.throws(() => toNotificationPage(null), TypeError);
});
