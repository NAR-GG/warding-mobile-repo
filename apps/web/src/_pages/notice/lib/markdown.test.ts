// 공지 마크다운 파서 회귀 테스트 — `tsx --test`.
//
// Flutter `notice_detail_screen.dart` 와 **같은 문법만** 지원해야 한다.
// 한쪽이 더/덜 지원하면 같은 공지가 앱과 웹에서 다르게 보인다.

import test from 'node:test';
import assert from 'node:assert/strict';

import { parseInline, parseNoticeMarkdown } from './markdown';

test('제목 3단계', () => {
  const b = parseNoticeMarkdown('# 하나\n## 둘\n### 셋');
  assert.deepEqual(
    b.map((x) => (x.kind === 'heading' ? x.level : x.kind)),
    [1, 2, 3],
  );
});

test('목록과 단락', () => {
  const b = parseNoticeMarkdown('- 항목\n평문');
  assert.equal(b[0]?.kind, 'listItem');
  assert.equal(b[1]?.kind, 'paragraph');
});

test('빈 줄은 블록이 되지 않는다', () => {
  assert.equal(parseNoticeMarkdown('a\n\n\nb').length, 2);
});

test('이미지와 너비 지정', () => {
  const [plain] = parseNoticeMarkdown('![설명](https://x/a.png)');
  assert.equal(plain?.kind, 'image');
  if (plain?.kind === 'image') {
    assert.equal(plain.url, 'https://x/a.png');
    assert.equal(plain.alt, '설명');
    assert.equal(plain.width, null);
  }

  const [sized] = parseNoticeMarkdown('![설명|240](https://x/a.png)');
  if (sized?.kind === 'image') {
    assert.equal(sized.width, 240);
    assert.equal(sized.alt, '설명');
  }
});

test('scroll: 이미지가 연달아 오면 한 스트립으로 묶인다', () => {
  const b = parseNoticeMarkdown(
    '![scroll:첫째|120](https://x/1.png)\n' +
      '![scroll:둘째](https://x/2.png)\n' +
      '평문',
  );
  assert.equal(b.length, 2);
  assert.equal(b[0]?.kind, 'strip');
  if (b[0]?.kind === 'strip') {
    assert.equal(b[0].items.length, 2);
    assert.equal(b[0].items[0]?.width, 120);
    assert.equal(b[0].items[0]?.label, '첫째');
    // 너비를 안 적으면 기본값
    assert.equal(b[0].items[1]?.width, 200);
  }
  assert.equal(b[1]?.kind, 'paragraph');
});

test('인라인 굵게', () => {
  const s = parseInline('앞 **굵게** 뒤');
  assert.deepEqual(s.map((x) => x.kind), ['text', 'bold', 'text']);
  assert.equal(s[1]?.text, '굵게');
});

test('인라인 링크', () => {
  const s = parseInline('→ [@warding_lol](https://x.com/a)');
  assert.equal(s[1]?.kind, 'link');
  if (s[1]?.kind === 'link') {
    assert.equal(s[1].text, '@warding_lol');
    assert.equal(s[1].url, 'https://x.com/a');
  }
});

test('굵게와 링크가 한 줄에 섞여도 순서를 지킨다', () => {
  const s = parseInline('**A** 중간 [B](u) 끝');
  assert.deepEqual(s.map((x) => x.kind), ['bold', 'text', 'link', 'text']);
});

test('인라인 문법이 없으면 통째로 텍스트', () => {
  assert.deepEqual(parseInline('그냥 글'), [{ kind: 'text', text: '그냥 글' }]);
  assert.deepEqual(parseInline(''), []);
});

test('백슬래시 이스케이프를 되돌린다', () => {
  const [b] = parseNoticeMarkdown('\\*별표\\*');
  if (b?.kind === 'paragraph') {
    assert.equal(b.spans.map((s) => s.text).join(''), '*별표*');
  }
});
