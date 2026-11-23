/**
 * 공지 본문 마크다운 → 블록 목록.
 *
 * Flutter `notice_detail_screen.dart` 의 `_buildContent`(124줄 수동 파서)와
 * **같은 문법만** 지원한다. 범용 마크다운 라이브러리를 쓰지 않는 이유:
 * 서버 에디터(tiptap-markdown)가 내는 형식이 제한적이고, 양쪽이 다른 문법을
 * 지원하면 같은 공지가 앱과 웹에서 다르게 보인다.
 *
 * 지원 문법 (Dart 와 동일):
 * - `# ` · `## ` · `### ` 제목
 * - `- ` 목록
 * - `![alt](url)` 이미지
 * - `![scroll:라벨|너비](url)` 연속 → 가로 스크롤 스트립
 * - 인라인 `**굵게**` 와 `[텍스트](url)` 링크
 * - 그 외는 본문 단락
 *
 * **이 파일은 `widgets/notice-body` 안에 있다.** 공지 상세와 광고 안내가
 * 같은 백오피스 공지 본문을 그려서 소비처가 둘이 됐다. `packages/ui` 가
 * 아닌 이유는 Dart 원본이 `features/notice/` 안이기 때문이다 — 기능 폴더
 * 안의 위젯은 공용 자리에 두지 않는다.
 */

/** 한 줄 안의 인라인 조각. Dart `_inlineText` 의 span 에 해당한다. */
export type Inline =
  | { kind: 'text'; text: string }
  | { kind: 'bold'; text: string }
  | { kind: 'link'; text: string; url: string };

export type NoticeBlock =
  | { kind: 'heading'; level: 1 | 2 | 3; text: string }
  | { kind: 'listItem'; spans: Inline[] }
  | { kind: 'paragraph'; spans: Inline[] }
  | { kind: 'image'; url: string; alt: string; width: number | null }
  | { kind: 'strip'; items: { url: string; label: string; width: number }[] };

const IMAGE = /^!\[([^\]]*)\]\((.+)\)$/;
/** 가로 스크롤 스트립임을 나타내는 alt 접두사. */
const STRIP_PREFIX = 'scroll:';
/** alt 끝의 `|240` → 표시 너비(375 기준). */
const WIDTH = /\|(\d+)$/;
const DEFAULT_STRIP_WIDTH = 200;

/** 인라인 문법. Dart `_inlinePattern` 과 같은 정규식이다. */
const INLINE = /\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)/g;

/**
 * 한 줄을 인라인 조각으로 쪼갠다.
 *
 * 링크는 Flutter 가 외부 브라우저로 여는데, 웹은 그냥 `<a>` 다 — 웹뷰
 * 안에서도 같은 결과(외부 전환)가 되도록 `target="_blank"` 를 쓴다.
 */
export function parseInline(text: string): Inline[] {
  if (!text.includes('**') && !text.includes('](')) {
    return text === '' ? [] : [{ kind: 'text', text }];
  }

  const spans: Inline[] = [];
  let cursor = 0;
  INLINE.lastIndex = 0;

  for (let m = INLINE.exec(text); m !== null; m = INLINE.exec(text)) {
    if (m.index > cursor) {
      spans.push({ kind: 'text', text: text.slice(cursor, m.index) });
    }
    if (m[1] !== undefined) {
      spans.push({ kind: 'bold', text: m[1] });
    } else if (m[2] !== undefined && m[3] !== undefined) {
      spans.push({ kind: 'link', text: m[2], url: m[3] });
    }
    cursor = m.index + m[0].length;
  }

  if (cursor < text.length) {
    spans.push({ kind: 'text', text: text.slice(cursor) });
  }
  return spans;
}

/** 에디터가 넣는 백슬래시 이스케이프를 되돌린다 (Dart 와 같은 문자 집합). */
const unescape = (s: string): string =>
  s.replace(/\\([\\`*_{}[\]()#+\-.!~<>])/g, '$1');

function stripItem(alt: string, url: string) {
  const label = alt.slice(STRIP_PREFIX.length);
  const m = WIDTH.exec(label);
  return {
    url,
    label: m ? label.slice(0, m.index) : label,
    width: m?.[1] ? Number(m[1]) : DEFAULT_STRIP_WIDTH,
  };
}

export function parseNoticeMarkdown(content: string): NoticeBlock[] {
  const blocks: NoticeBlock[] = [];
  const lines = content.split('\n');

  for (let i = 0; i < lines.length; i += 1) {
    const raw = lines[i] ?? '';
    const line = raw.trim();
    if (line === '') continue;

    const img = IMAGE.exec(line);

    // `scroll:` 이미지가 연달아 오면 하나의 가로 스트립으로 묶는다.
    //
    // **사이의 빈 줄은 건너뛴다** — Dart `_buildContent` 와 같다. 에디터가
    // 이미지 사이에 빈 줄을 넣기 때문에(실측: 광고 안내 본문이 그렇다),
    // 바로 다음 줄만 보면 3장이 각자 스트립 하나씩으로 쪼개져 세로로 쌓인다.
    // 빌드도 타입 체크도 통과하고 화면에서만 드러난다.
    if (img?.[1]?.startsWith(STRIP_PREFIX) && img[2]) {
      const items = [stripItem(img[1], img[2])];
      let j = i + 1;
      while (j < lines.length) {
        const next = (lines[j] ?? '').trim();
        // 빈 줄과 홀로 남은 `\`(에디터가 넣는 줄바꿈)는 묶음을 끊지 않는다.
        if (next === '' || next === '\\') {
          j += 1;
          continue;
        }
        const m = IMAGE.exec(next);
        if (!m?.[1]?.startsWith(STRIP_PREFIX) || !m[2]) break;
        items.push(stripItem(m[1], m[2]));
        i = j;
        j += 1;
      }
      blocks.push({ kind: 'strip', items });
      continue;
    }

    if (img?.[2]) {
      const alt = img[1] ?? '';
      const m = WIDTH.exec(alt);
      blocks.push({
        kind: 'image',
        url: img[2],
        alt: m ? alt.slice(0, m.index) : alt,
        width: m?.[1] ? Number(m[1]) : null,
      });
      continue;
    }

    if (line.startsWith('### ')) {
      blocks.push({ kind: 'heading', level: 3, text: unescape(line.slice(4)) });
    } else if (line.startsWith('## ')) {
      blocks.push({ kind: 'heading', level: 2, text: unescape(line.slice(3)) });
    } else if (line.startsWith('# ')) {
      blocks.push({ kind: 'heading', level: 1, text: unescape(line.slice(2)) });
    } else if (line.startsWith('- ')) {
      blocks.push({ kind: 'listItem', spans: parseInline(unescape(line.slice(2))) });
    } else {
      blocks.push({ kind: 'paragraph', spans: parseInline(unescape(line)) });
    }
  }

  return blocks;
}
