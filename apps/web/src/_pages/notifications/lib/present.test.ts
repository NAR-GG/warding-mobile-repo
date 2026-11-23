import test from 'node:test';
import assert from 'node:assert/strict';

import { toMemberNotification } from 'warding-api';

import { formatAbsolute, formatRelative, particleEuro, toView } from './present';

const NOW = new Date(2026, 10, 23, 17, 0);

function soloRank(data: Record<string, string>, at = new Date(2026, 10, 23, 16, 6)) {
  return toMemberNotification({
    id: 1,
    type: 'PLAYER_SOLO_RANK_STARTED',
    createdAt: at.toISOString(),
    data,
  });
}

/**
 * **문구는 네이티브 스크린샷과 글자까지 같아야 한다.**
 * 기대값은 실제 앱 화면에서 옮겨 적은 것이다(2026-11-23 마이구독 피드).
 */

test('솔랭 종료 — 승리·KDA·시간', () => {
  const v = toView(
    soloRank({
      eventType: 'END',
      playerName: 'Deft',
      championName: '이즈리얼',
      win: 'true',
      kda: '6/3/5',
      gameDurationSeconds: '1140',
    }),
    NOW,
  );
  assert.equal(v.title, 'Deft 선수가 솔랭을 끝냈어요');
  assert.equal(v.body, '이즈리얼로 승리 · 6/3/5 · 19분');
});

test('솔랭 종료 — 패배', () => {
  const v = toView(
    soloRank({
      eventType: 'END',
      playerName: 'Deft',
      championName: '자야',
      win: 'false',
      kda: '2/9/9',
      gameDurationSeconds: '1620',
    }),
    NOW,
  );
  assert.equal(v.body, '자야로 패배 · 2/9/9 · 27분');
});

test('받침에 따라 로·으로 가 갈린다', () => {
  // 하드코딩하면 "아칼리으로"·"자야로" 가 섞인다.
  assert.equal(particleEuro('자야'), '로'); // 받침 없음
  assert.equal(particleEuro('이즈리얼'), '로'); // ㄹ 받침
  assert.equal(particleEuro('아칼리'), '로');
  assert.equal(particleEuro('그레이브즈'), '로');
  assert.equal(particleEuro('갈리온'), '으로'); // ㄴ 받침
  assert.equal(particleEuro('Akali'), '으로'); // 한글 아님
  assert.equal(particleEuro(''), '으로');
});

test('결과를 못 읽은 종료는 경기 종료 로만 쓴다', () => {
  const v = toView(
    soloRank({ eventType: 'END', playerName: 'Deft', championName: '자야' }),
    NOW,
  );
  assert.equal(v.body, '자야 경기 종료');
});

test('1분 미만 경기는 시간을 생략한다', () => {
  // '0분' 은 정보가 아니라 오해를 만든다.
  const v = toView(
    soloRank({
      eventType: 'END',
      championName: '자야',
      win: 'true',
      kda: '1/0/0',
      gameDurationSeconds: '30',
    }),
    NOW,
  );
  assert.equal(v.body, '자야로 승리 · 1/0/0');
});

test('KDA 가 없으면 생략한다', () => {
  const v = toView(
    soloRank({
      eventType: 'END',
      championName: '자야',
      win: 'true',
      gameDurationSeconds: '600',
    }),
    NOW,
  );
  assert.equal(v.body, '자야로 승리 · 10분');
});

test('솔랭 시작', () => {
  const v = toView(
    soloRank({
      playerName: 'Deft',
      championName: '이즈리얼',
      queueType: '솔로 랭크',
    }),
    NOW,
  );
  assert.equal(v.title, 'Deft 선수가 솔랭을 시작했어요');
  assert.equal(v.body, '이즈리얼로 솔로 랭크 플레이 중');
});

test('솔랭은 헤드셋 아이콘이다', () => {
  assert.equal(toView(soloRank({}), NOW).icon, '/icons/headset.svg');
});

test('커뮤니티 아이콘은 44 가 아니라 줄여 그린다', () => {
  // 24 뷰박스를 꽉 채우는 그림이라 44 로 키우면 헤드셋보다 커 보인다.
  const like = toMemberNotification({ type: 'COMMUNITY_LIKE' });
  const comment = toMemberNotification({ type: 'COMMUNITY_COMMENT' });
  const setStart = toMemberNotification({ type: 'SET_START' });
  assert.equal(toView(like, NOW).iconSize, 22);
  assert.equal(toView(comment, NOW).iconSize, 26);
  assert.equal(toView(setStart, NOW).iconSize, 44);
});

test('커뮤니티는 서버 title/body 를 그대로 쓴다', () => {
  const n = toMemberNotification({
    type: 'COMMUNITY_COMMENT',
    title: '댓글이 달렸어요',
    body: '내용',
  });
  const v = toView(n, NOW);
  assert.equal(v.title, '댓글이 달렸어요');
  assert.equal(v.body, '내용');
});

test('절대 시각 포맷', () => {
  assert.equal(formatAbsolute(new Date(2026, 10, 23, 16, 6)), '2026-11-23 16:06');
  assert.equal(formatAbsolute(new Date(2026, 0, 5, 9, 7)), '2026-01-05 09:07');
});

test('상대 시각 경계', () => {
  const t = (minsAgo: number) =>
    formatRelative(new Date(NOW.getTime() - minsAgo * 60000), NOW);
  assert.equal(t(0), '방금 전');
  assert.equal(t(1), '1분 전');
  assert.equal(t(59), '59분 전');
  assert.equal(t(60), '1시간 전');
  assert.equal(t(60 * 23), '23시간 전');
  assert.equal(t(60 * 24), '1일 전');
});
