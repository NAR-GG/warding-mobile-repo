import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseVersion, extractReleaseNotes } from './interactions.js';

// custom_id 는 우리가 만든 값이지만, Discord 를 거쳐 돌아오는 외부 입력이다.
// 그대로 워크플로우에 넘기면 안 되므로 형식을 먼저 막는다.
test('parseVersion: pubspec 형식만 통과시킨다', () => {
  assert.equal(parseVersion('1.0.33+81'), '1.0.33+81');
  assert.equal(parseVersion('10.20.30+400'), '10.20.30+400');
});

test('parseVersion: 형식이 어긋나면 null', () => {
  for (const bad of [
    '1.0.33', // 빌드 번호 없음
    '1.0.33+', // 빌드 번호 비어 있음
    'v1.0.33+81', // 접두사
    '1.0.33+81; rm -rf /', // 명령 주입 시도
    '',
    undefined,
    null,
  ]) {
    assert.equal(parseVersion(bad), null, `${JSON.stringify(bad)} 는 막혀야 한다`);
  }
});

test('extractReleaseNotes: 패치노트 embed 에서 본문을 꺼낸다', () => {
  const notes = '■ 광고 화면이 좋아졌어요!\n  - 팝업이 이미지를 꽉 채워요.';
  const message = {
    embeds: [
      { title: '🚀 스토어 업로드 완료 — 1.0.33+81', description: '✅ 검증 · ✅ e2e' },
      { title: '📝 패치노트 초안 (distribution/ 에 반영하세요)', description: notes },
    ],
  };
  assert.equal(extractReleaseNotes(message), notes);
});

test('extractReleaseNotes: 초안이 없으면(안내 문구뿐) null', () => {
  // user_facing=false 일 때 워크플로우가 넣는 안내 문구는 패치노트가 아니다.
  const message = {
    embeds: [
      { title: '🚀 스토어 업로드 완료', description: '✅' },
      {
        title: '📝 패치노트',
        description: '이번 릴리즈에는 사용자가 체감할 변경이 없어 보인다.',
      },
    ],
  };
  assert.equal(extractReleaseNotes(message), null);
});

test('extractReleaseNotes: embed 가 없어도 터지지 않는다', () => {
  assert.equal(extractReleaseNotes(undefined), null);
  assert.equal(extractReleaseNotes({}), null);
  assert.equal(extractReleaseNotes({ embeds: [] }), null);
});
