import { type Inline, parseNoticeMarkdown } from '../lib/markdown';

/** 인라인 조각을 그린다. 링크는 외부로 연다 — Flutter 도 외부 브라우저다. */
function Spans({ spans }: { spans: Inline[] }) {
  return (
    <>
      {spans.map((s, i) => {
        if (s.kind === 'bold') return <strong key={i}>{s.text}</strong>;
        if (s.kind === 'link') {
          return (
            <a key={i} className="notice__link" href={s.url} target="_blank" rel="noreferrer noopener">
              {s.text}
            </a>
          );
        }
        return <span key={i}>{s.text}</span>;
      })}
    </>
  );
}

/**
 * 공지 본문 렌더러 — Flutter `notice_detail_screen.dart` 의 웹 구현.
 *
 * 이미지 너비는 375 기준 원시값이라 `calc(n * var(--scale))` 로 쓴다.
 *
 * **`* 1px` 을 붙이면 안 된다.** `--scale` 이 이미 px 단위라
 * (`clamp(320px, 100vw, 430px) / 375`) 한 번 더 곱하면 px² 이 되어 선언이
 * 통째로 무효가 된다 — 콘솔도 조용하고, 이미지가 지정 폭을 무시한 원본
 * 크기로 그려진다. CLAUDE.md 의 `packages/ui` 함정 표에 같은 항목이 있다.
 */
export function NoticeBody({ content }: { content: string }) {
  const blocks = parseNoticeMarkdown(content);
  if (blocks.length === 0) return null;

  return (
    <div className="notice__body">
      {blocks.map((b, i) => {
        const key = `${b.kind}-${i}`;

        switch (b.kind) {
          case 'heading': {
            const Tag = (['h1', 'h2', 'h3'] as const)[b.level - 1] ?? 'h3';
            return (
              <Tag key={key} className={`notice__h${b.level}`}>
                {b.text}
              </Tag>
            );
          }
          case 'listItem':
            return (
              <p key={key} className="notice__li">
                <Spans spans={b.spans} />
              </p>
            );
          case 'image':
            return (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                key={key}
                src={b.url}
                alt={b.alt}
                className="notice__image"
                style={
                  b.width === null
                    ? undefined
                    : { width: `calc(${b.width} * var(--scale))` }
                }
              />
            );
          case 'strip':
            return (
              <div key={key} className="notice__strip">
                {b.items.map((it, j) => (
                  <figure
                    key={`${it.url}-${j}`}
                    className="notice__strip-item"
                    style={{ width: `calc(${it.width} * var(--scale))` }}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={it.url} alt={it.label} className="notice__strip-img" />
                    {it.label ? (
                      <figcaption className="notice__caption">{it.label}</figcaption>
                    ) : null}
                  </figure>
                ))}
              </div>
            );
          default:
            return (
              <p key={key} className="notice__p">
                <Spans spans={b.spans} />
              </p>
            );
        }
      })}
    </div>
  );
}
