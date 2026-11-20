/**
 * 블록 본문 편집 로직 — Flutter `post_write_screen.dart` 의 블록 조작을 옮긴 것.
 *
 * UI 에서 떼어 순수 함수로 둔다. 불변식이 깨지면 화면이 조용히 이상해지는
 * 종류라(사진 위에 글을 못 쓰게 되는 등) 테스트로 못박아야 한다.
 *
 * 서버 계약(`community_post_block.dart`)은 블록 배열의 JSON 문자열이다:
 * ```json
 * [{"type":"text","text":"...","style":"body|heading"},
 *  {"type":"image","url":"..."}]
 * ```
 * 지금 만드는 것은 text·image 둘이다. link·embed 는 작성 쪽에 아직 없다
 * (상세 렌더러는 이미 그린다).
 */

/** 편집 중 블록. `id` 는 React key 와 포커스 추적에만 쓰고 서버로 안 나간다. */
export type EditorBlock =
  | { id: string; type: 'text'; text: string; heading: boolean }
  | { id: string; type: 'image'; url: string };

let seq = 0;
/** 블록 id. 내용이 같아도 구분돼야 해서 순번을 쓴다. */
export const nextId = (): string => `b${(seq += 1)}`;

export const textBlock = (text = '', heading = false): EditorBlock => ({
  id: nextId(),
  type: 'text',
  text,
  heading,
});

export const imageBlock = (url: string): EditorBlock => ({
  id: nextId(),
  type: 'image',
  url,
});

/**
 * **맨 위와 맨 아래는 항상 텍스트 블록이어야 한다.**
 *
 * 이미지가 첫 블록이 되면 그 위에 커서를 둘 자리가 없어 "사진 위에 첫 줄
 * 쓰기" 가 불가능해진다 — Dart 주석이 1.0.23 사용자 피드백으로 적어 둔
 * 실제 사고다. 삽입·이동·삭제 뒤마다 부른다.
 */
export function ensureTextEdges(blocks: EditorBlock[]): EditorBlock[] {
  const next = [...blocks];
  if (next.length === 0 || next[0]!.type !== 'text') {
    next.unshift(textBlock());
  }
  if (next[next.length - 1]!.type !== 'text') {
    next.push(textBlock());
  }
  return next;
}

/**
 * 커서 위치에서 텍스트 블록을 쪼개고 그 사이에 미디어를 끼운다.
 *
 * `focusedId` 가 없으면 맨 끝에 붙인다. 끼운 뒤에는 **항상 이어서 쓸 텍스트
 * 블록**이 따라온다 — 사진 아래에 글을 못 쓰면 안 된다.
 *
 * **커서 주변 빈 줄은 걷어낸다.** "글 쓰고 엔터 → 사진" 이 이미지 위아래
 * 공백 줄로 남으면 안 된다(블록 간격이 이미 여백을 준다).
 */
export function insertMedia(
  blocks: EditorBlock[],
  media: EditorBlock[],
  focusedId: string | null,
  cursor: number,
): { blocks: EditorBlock[]; focusId: string | null } {
  if (media.length === 0) return { blocks, focusId: null };

  const index = focusedId === null ? -1 : blocks.findIndex((b) => b.id === focusedId);
  const focused = index >= 0 ? blocks[index] : undefined;

  // 포커스가 없을 때 — 끝의 빈 텍스트 블록 앞에 끼워 커서 자리를 보존한다.
  if (focused === undefined || focused.type !== 'text') {
    const last = blocks[blocks.length - 1];
    if (last !== undefined && last.type === 'text' && last.text.trim() === '') {
      const next = [...blocks.slice(0, -1), ...media, last];
      return { blocks: ensureTextEdges(next), focusId: last.id };
    }
    const tail = textBlock();
    return { blocks: ensureTextEdges([...blocks, ...media, tail]), focusId: tail.id };
  }

  const before = focused.text.slice(0, cursor).trimEnd();
  const after = focused.text.slice(cursor).trimStart();
  const tail = textBlock(after);

  const next = [
    ...blocks.slice(0, index),
    { ...focused, text: before },
    ...media,
    tail,
    ...blocks.slice(index + 1),
  ];

  return { blocks: ensureTextEdges(next), focusId: tail.id };
}

/** 블록 하나 제거. 불변식을 다시 맞춘다. */
export function removeBlock(blocks: EditorBlock[], id: string): EditorBlock[] {
  return ensureTextEdges(blocks.filter((b) => b.id !== id));
}

/**
 * 블록을 위/아래로 한 칸 옮긴다.
 *
 * 경계를 벗어나면 그대로 둔다. 이동 뒤에도 불변식을 맞추는데, 그 과정에서
 * 텍스트 블록이 새로 생길 수 있다(이미지를 맨 위로 올린 경우).
 */
export function moveBlock(
  blocks: EditorBlock[],
  id: string,
  direction: -1 | 1,
): EditorBlock[] {
  const i = blocks.findIndex((b) => b.id === id);
  if (i < 0) return blocks;

  const j = i + direction;
  if (j < 0 || j >= blocks.length) return blocks;

  const next = [...blocks];
  [next[i], next[j]] = [next[j]!, next[i]!];
  return ensureTextEdges(next);
}

/** 텍스트 블록 내용 갱신. */
export function updateText(
  blocks: EditorBlock[],
  id: string,
  text: string,
): EditorBlock[] {
  return blocks.map((b) => (b.id === id && b.type === 'text' ? { ...b, text } : b));
}

/** 텍스트 블록의 제목 스타일 토글. */
export function toggleHeading(blocks: EditorBlock[], id: string): EditorBlock[] {
  return blocks.map((b) =>
    b.id === id && b.type === 'text' ? { ...b, heading: !b.heading } : b,
  );
}

/**
 * 서버로 보낼 JSON 문자열.
 *
 * **빈 텍스트 블록은 뺀다** — 불변식 때문에 앞뒤로 생긴 빈 블록이 그대로
 * 나가면 상세 화면에 빈 줄이 생긴다. 서버 기본 `style` 이 'body' 라
 * 제목이 아닐 때는 아예 싣지 않는다(Dart `toJson` 과 같다).
 */
export function toBodyJson(blocks: EditorBlock[]): string {
  /** 서버로 나가는 블록. 필드가 블록 종류마다 달라 느슨하게 둔다. */
  type ServerBlock = Record<string, string>;

  const payload = blocks.flatMap((b): ServerBlock[] => {
    if (b.type === 'image') return [{ type: 'image', url: b.url }];
    const text = b.text.trim();
    if (text === '') return [];
    return [b.heading ? { type: 'text', text, style: 'heading' } : { type: 'text', text }];
  });
  return JSON.stringify(payload);
}

/** 블록에 들어 있는 이미지 URL. 글 작성의 `imageUrls` 로 보낸다. */
export function imageUrlsOf(blocks: EditorBlock[]): string[] {
  return blocks.flatMap((b) => (b.type === 'image' ? [b.url] : []));
}

/** 내용이 있는가 — 등록 버튼 활성 판단. 사진만 있어도 글이 된다. */
export function hasContent(blocks: EditorBlock[]): boolean {
  return blocks.some((b) => (b.type === 'image' ? true : b.text.trim() !== ''));
}
