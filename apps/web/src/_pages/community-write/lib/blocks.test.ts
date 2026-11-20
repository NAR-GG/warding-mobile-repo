import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  ensureTextEdges,
  hasContent,
  imageBlock,
  imageUrlsOf,
  insertMedia,
  moveBlock,
  removeBlock,
  textBlock,
  toBodyJson,
  toggleHeading,
  type EditorBlock,
} from './blocks';

/**
 * 블록 편집 회귀 테스트.
 *
 * **불변식이 깨지면 화면이 조용히 이상해진다** — 이미지가 첫 블록이 되면 그
 * 위에 커서를 둘 자리가 없어 "사진 위에 첫 줄 쓰기" 가 막힌다(Dart 가
 * 1.0.23 사용자 피드백으로 적어 둔 실제 사고다). 눈으로는 "왜 안 써지지"
 * 로만 보이므로 테스트로 막는다.
 */

const types = (bs: EditorBlock[]) => bs.map((b) => b.type).join(',');

test('빈 배열이면 텍스트 블록 하나가 생긴다', () => {
  assert.equal(types(ensureTextEdges([])), 'text');
});

test('맨 위가 이미지면 앞에 텍스트를 끼운다', () => {
  const r = ensureTextEdges([imageBlock('u'), textBlock('뒤')]);
  assert.equal(types(r), 'text,image,text');
});

test('맨 아래가 이미지면 뒤에 텍스트를 붙인다', () => {
  const r = ensureTextEdges([textBlock('앞'), imageBlock('u')]);
  assert.equal(types(r), 'text,image,text');
});

test('이미지 하나뿐이면 위아래로 감싼다', () => {
  assert.equal(types(ensureTextEdges([imageBlock('u')])), 'text,image,text');
});

test('커서 위치에서 쪼개 끼운다', () => {
  const t = textBlock('앞부분뒷부분');
  const { blocks } = insertMedia([t], [imageBlock('u')], t.id, 3);

  assert.equal(types(blocks), 'text,image,text');
  assert.equal((blocks[0] as { text: string }).text, '앞부분');
  assert.equal((blocks[2] as { text: string }).text, '뒷부분');
});

test('커서 주변 빈 줄을 걷어낸다', () => {
  // "글 쓰고 엔터 → 사진" 이 이미지 위아래 공백 줄로 남으면 안 된다.
  const t = textBlock('앞\n\n   \n뒤');
  const { blocks } = insertMedia([t], [imageBlock('u')], t.id, 4);

  assert.equal((blocks[0] as { text: string }).text, '앞');
  assert.equal((blocks[2] as { text: string }).text, '뒤');
});

test('끼운 뒤 이어서 쓸 텍스트 블록에 포커스가 간다', () => {
  const t = textBlock('내용');
  const { blocks, focusId } = insertMedia([t], [imageBlock('u')], t.id, 2);
  assert.equal(focusId, blocks[2]!.id);
});

test('포커스가 없으면 끝의 빈 텍스트 블록 앞에 끼운다', () => {
  const head = textBlock('내용');
  const tail = textBlock('');
  const { blocks } = insertMedia([head, tail], [imageBlock('u')], null, 0);

  assert.equal(types(blocks), 'text,image,text');
  // 빈 블록이 새로 생기지 않고 기존 것이 뒤에 남아야 한다.
  assert.equal(blocks[2]!.id, tail.id);
});

test('포커스가 없고 끝이 비어 있지 않으면 뒤에 붙이고 텍스트를 만든다', () => {
  const head = textBlock('내용');
  const { blocks } = insertMedia([head], [imageBlock('u')], null, 0);
  assert.equal(types(blocks), 'text,image,text');
});

test('여러 장을 한 번에 끼운다', () => {
  const t = textBlock('내용');
  const { blocks } = insertMedia(
    [t],
    [imageBlock('a'), imageBlock('b')],
    t.id,
    2,
  );
  assert.equal(types(blocks), 'text,image,image,text');
});

test('블록을 지워도 불변식이 유지된다', () => {
  const head = textBlock('앞');
  const img = imageBlock('u');
  const tail = textBlock('뒤');

  // 앞 텍스트를 지우면 이미지가 첫 블록이 되므로 새 텍스트가 생겨야 한다.
  const r = removeBlock([head, img, tail], head.id);
  assert.equal(types(r), 'text,image,text');
});

test('이미지를 맨 위로 올리면 그 위에 텍스트가 생긴다', () => {
  const head = textBlock('앞');
  const img = imageBlock('u');
  const tail = textBlock('뒤');

  const r = moveBlock([head, img, tail], img.id, -1);
  assert.equal(types(r), 'text,image,text,text');
});

test('경계를 벗어나는 이동은 무시한다', () => {
  const a = textBlock('a');
  const b = textBlock('b');
  assert.deepEqual(moveBlock([a, b], a.id, -1), [a, b]);
  assert.deepEqual(moveBlock([a, b], b.id, 1), [a, b]);
});

test('제목 토글', () => {
  const t = textBlock('제목');
  const r = toggleHeading([t], t.id);
  assert.equal((r[0] as { heading: boolean }).heading, true);
});

test('서버 JSON 에서 빈 텍스트 블록은 빠진다', () => {
  // 불변식 때문에 생긴 앞뒤 빈 블록이 그대로 나가면 상세에 빈 줄이 생긴다.
  const blocks = [textBlock(''), imageBlock('u'), textBlock('  ')];
  assert.deepEqual(JSON.parse(toBodyJson(blocks)), [{ type: 'image', url: 'u' }]);
});

test('제목이 아니면 style 을 싣지 않는다', () => {
  // 서버 기본값이 body 라 생략한다(Dart toJson 과 같다).
  assert.deepEqual(JSON.parse(toBodyJson([textBlock('본문')])), [
    { type: 'text', text: '본문' },
  ]);
  assert.deepEqual(JSON.parse(toBodyJson([textBlock('제목', true)])), [
    { type: 'text', text: '제목', style: 'heading' },
  ]);
});

test('이미지 URL 을 순서대로 모은다', () => {
  const blocks = [textBlock('a'), imageBlock('u1'), textBlock('b'), imageBlock('u2')];
  assert.deepEqual(imageUrlsOf(blocks), ['u1', 'u2']);
});

test('사진만 있어도 내용이 있는 것으로 본다', () => {
  assert.equal(hasContent([textBlock(''), imageBlock('u')]), true);
  assert.equal(hasContent([textBlock('  ')]), false);
  assert.equal(hasContent([textBlock('글')]), true);
});
