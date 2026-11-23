import test from 'node:test';
import assert from 'node:assert/strict';

import { CHAMPION_KO_TO_EN, championSplashUrl, championToEn } from './champion';

/**
 * 챔피언명 매핑 회귀 테스트.
 *
 * **Dart `champion_name_map.dart` 의 복제라 수가 어긋나면 안 된다.** 신챔이
 * 나왔는데 한쪽만 갱신하면 그 챔피언의 스플래시 배경이 비어 보이는데,
 * 타입 체크로는 안 잡힌다.
 */

test('Dart 와 같은 항목 수다 (173)', () => {
  assert.equal(Object.keys(CHAMPION_KO_TO_EN).length, 173);
});

test('아포스트로피 챔피언이 빠지지 않았다', () => {
  // 옮길 때 실제로 8개를 놓쳤던 자리다 — Dart 가 값에 "..." 를 쓴다.
  assert.equal(championToEn('카이사'), "Kai'Sa");
  assert.equal(championToEn('렉사이'), "Rek'Sai");
  assert.equal(championToEn('코그모'), "Kog'Maw");
  assert.equal(championToEn('크산테'), "K'Sante");
});

test('모르는 이름은 원본 그대로', () => {
  assert.equal(championToEn('없는챔프'), '없는챔프');
});

test('스플래시 URL 을 만든다', () => {
  assert.equal(
    championSplashUrl('아칼리'),
    'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/Akali_0.jpg',
  );
});

test('파일명 예외를 따른다', () => {
  // 기본 규칙(공백·아포스트로피 제거)으로는 안 맞는 것들.
  const url = (ko: string) => championSplashUrl(ko)?.split('/').pop();
  assert.equal(url('카이사'), 'Kaisa_0.jpg');
  assert.equal(url('누누와 윌럼프'), 'Nunu_0.jpg');
  assert.equal(url('오공'), 'MonkeyKing_0.jpg');
  assert.equal(url('르블랑'), 'Leblanc_0.jpg');
  assert.equal(url('레나타 글라스크'), 'Renata_0.jpg');
});

test('공백이 든 이름은 공백을 뺀 키다', () => {
  const url = (ko: string) => championSplashUrl(ko)?.split('/').pop();
  assert.equal(url('리 신'), 'LeeSin_0.jpg');
  assert.equal(url('미스 포츈'), 'MissFortune_0.jpg');
});

test('빈 이름이면 null', () => {
  assert.equal(championSplashUrl(''), null);
});
