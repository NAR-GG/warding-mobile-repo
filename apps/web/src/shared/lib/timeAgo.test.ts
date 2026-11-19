import assert from 'node:assert/strict';
import { test } from 'node:test';

import { timeAgo } from './timeAgo';

/**
 * 경계값 회귀 테스트.
 *
 * Dart `ratingTimeAgo` 와 **분기 경계가 같은지**를 지킨다. 같은 글이 목록(웹)과
 * 상세(네이티브)에서 다른 시각을 말하면 안 되는데, 타입 체크로는 잡히지 않는다.
 * Dart 쪽을 고치면 이 테스트의 기대값도 같이 본다.
 */

const now = new Date('2026-11-19T12:00:00Z');
const ago = (ms: number) => new Date(now.getTime() - ms);

const SEC = 1_000;
const MIN = 60 * SEC;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

test('null 이면 빈 문자열', () => {
  assert.equal(timeAgo(null, now), '');
});

test('1분 미만은 방금 전', () => {
  assert.equal(timeAgo(ago(0), now), '방금 전');
  assert.equal(timeAgo(ago(59 * SEC), now), '방금 전');
});

test('1분 ~ 59분은 분 단위', () => {
  assert.equal(timeAgo(ago(MIN), now), '1분 전');
  assert.equal(timeAgo(ago(59 * MIN), now), '59분 전');
});

test('1시간 ~ 23시간은 시간 단위', () => {
  assert.equal(timeAgo(ago(HOUR), now), '1시간 전');
  assert.equal(timeAgo(ago(23 * HOUR), now), '23시간 전');
});

test('1일 ~ 6일은 일 단위', () => {
  assert.equal(timeAgo(ago(DAY), now), '1일 전');
  assert.equal(timeAgo(ago(6 * DAY), now), '6일 전');
});

/* 날짜 표기는 **로컬 타임존** 기준이다 — Dart `DateTime.year/month/day` 도
 * 그렇고, 서버가 타임존 표기 없는 문자열(`2026-11-18T20:07:34.119`)을 주므로
 * 양쪽이 같은 날짜를 말한다. 그래서 기대값을 UTC 로 못박으면 기기 타임존에
 * 따라 하루가 밀린다(실측: TZ=Pacific/Honolulu 에서 깨졌다).
 *
 * 픽스처를 로컬 시각으로 만들어 그 흔들림을 없앤다. 검증 대상은 "경계를 넘으면
 * 날짜로 바뀌는가" 와 "0 을 채우는가" 지 타임존 변환이 아니다. */
const localNoon = (y: number, m: number, d: number) => new Date(y, m - 1, d, 12);

test('7일부터는 날짜 표기', () => {
  const base = localNoon(2026, 11, 19);
  assert.equal(timeAgo(localNoon(2026, 11, 12), base), '2026.11.12');
});

test('월·일이 한 자리면 0 을 채운다', () => {
  const base = localNoon(2026, 11, 19);
  assert.equal(timeAgo(localNoon(2026, 1, 5), base), '2026.01.05');
});

test('미래 시각은 방금 전으로 접는다', () => {
  // 서버·기기 시계가 어긋나면 음수가 나온다. "-0분 전" 같은 표기를 막는다.
  assert.equal(timeAgo(new Date(now.getTime() + HOUR), now), '방금 전');
});
