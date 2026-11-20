'use client';

import { useEffect, useRef } from 'react';

import { moveBlock, removeBlock, updateText, type EditorBlock } from '../lib/blocks';

/**
 * 블록 본문 편집기 — Flutter `post_write_screen.dart` 의 `_blockWidget`.
 *
 * **조작 버튼은 이미지 블록에만, 이미지 위에 떠 있다**(우상단 원형 3개).
 * 텍스트 블록에는 버튼이 없다 — 글을 쓰는 자리에 버튼이 붙으면 좁은 화면에서
 * 입력 폭을 먹고, 텍스트는 어차피 비우면 사라진다.
 *
 * **제목(heading) 토글 UI 는 네이티브에도 없다.** `heading` 필드는 드래프트
 * 복원과 서버 전송에만 쓰이고, 사용자가 켜는 방법이 아직 없다(서식 v1 이
 * 거기까지 가지 않았다). 웹도 같게 둔다 — 한쪽에만 있으면 같은 글이
 * 플랫폼마다 다르게 보인다.
 *
 * 조작은 전부 순수 함수(`lib/blocks.ts`)가 한다. 불변식이 깨지면 조용히
 * 이상해지는 종류라 로직을 떼어 테스트로 덮었다.
 */
export function BlockEditor({
  blocks,
  onChange,
  onFocusBlock,
  onCursor,
  focusId,
  showHint,
}: {
  blocks: EditorBlock[];
  onChange: (next: EditorBlock[]) => void;
  /** 어느 텍스트 블록에 커서가 있는지 — 사진을 여기에 끼운다. */
  onFocusBlock: (id: string | null) => void;
  onCursor: (position: number) => void;
  /** 삽입 직후 포커스를 옮길 블록. */
  focusId: string | null;
  /** 본문 안내 문구를 보일지. 내용이 하나라도 생기면 끈다. */
  showHint: boolean;
}) {
  const refs = useRef(new Map<string, HTMLTextAreaElement>());

  // 삽입 직후 이어서 쓸 블록으로 커서를 옮긴다. 안 그러면 사진을 넣은 뒤
  // 어디에 쓰는지 알 수 없다. 렌더 중에 DOM 을 건드리면 안 되므로 effect 에서
  // 한다.
  useEffect(() => {
    if (focusId === null) return;
    const el = refs.current.get(focusId);
    if (el === undefined || document.activeElement === el) return;
    el.focus();
    el.setSelectionRange(0, 0);
  }, [focusId]);

  return (
    <div className="blocks">
      {blocks.map((block, i) =>
        block.type === 'text' ? (
          <textarea
            key={block.id}
            ref={(el) => {
              if (el === null) refs.current.delete(block.id);
              else refs.current.set(block.id, el);
            }}
            className="blocks__text"
            value={block.text}
            // 안내 문구는 첫 블록이 비어 있을 때만. 내용이 하나라도 생기면
            // 걷는다 — 안 그러면 콘텐츠 사이에 떠 있는 문장처럼 보인다.
            placeholder={
              i === 0 && showHint
                ? '경기 이야기, 응원, 질문 무엇이든 좋아요.\n비방·도배는 신고 대상입니다.'
                : ''
            }
            // 블록이 하나뿐인 빈 화면에서만 4줄을 예약한다(Dart `minLines`).
            // 미디어를 끼운 뒤에도 유지하면 짧은 문단 밑에 빈 줄이 남는다.
            rows={blocks.length === 1 ? 4 : 1}
            autoCapitalize="off"
            autoCorrect="off"
            onFocus={() => onFocusBlock(block.id)}
            onChange={(e) => {
              onCursor(e.target.selectionStart);
              onChange(updateText(blocks, block.id, e.target.value));
            }}
            // 커서 위치는 선택이 바뀔 때마다 따라간다 — 입력 없이 탭만 해도
            // 그 자리에 사진이 들어가야 한다.
            onSelect={(e) => onCursor((e.target as HTMLTextAreaElement).selectionStart)}
          />
        ) : (
          <figure key={block.id} className="blocks__media">
            <img className="blocks__image" src={block.url} alt="" />

            {/* 버튼은 이미지 위 우상단에 겹친다(Dart `Stack` + `Positioned`). */}
            <div className="blocks__media-actions">
              <button
                type="button"
                className="blocks__media-action"
                onClick={() => onChange(moveBlock(blocks, block.id, -1))}
                disabled={i === 0}
                aria-label="위로"
              >
                <ChevronUp />
              </button>
              <button
                type="button"
                className="blocks__media-action"
                onClick={() => onChange(moveBlock(blocks, block.id, 1))}
                disabled={i === blocks.length - 1}
                aria-label="아래로"
              >
                <ChevronDown />
              </button>
              <button
                type="button"
                className="blocks__media-action"
                onClick={() => onChange(removeBlock(blocks, block.id))}
                aria-label="삭제"
              >
                <Close />
              </button>
            </div>
          </figure>
        ),
      )}
    </div>
  );
}

/* 아이콘은 인라인이다 — Dart 는 Material 아이콘을 쓰지만 웹은 자산 왕복을
 * 줄인다. 모양은 `keyboard_arrow_up/down`·`close` 와 같은 계열로 맞춘다. */

function ChevronUp() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M7 14l5-5 5 5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function ChevronDown() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M7 10l5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function Close() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}
