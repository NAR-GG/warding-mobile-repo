'use client';

import { useEffect, useRef } from 'react';

import {
  moveBlock,
  removeBlock,
  toggleHeading,
  updateText,
  type EditorBlock,
} from '../lib/blocks';

/**
 * 블록 본문 편집기 — Flutter `post_write_screen.dart` 의 블록 UI.
 *
 * **텍스트 사이에 이미지를 끼우는 구조다.** 조작은 전부 순수 함수
 * (`lib/blocks.ts`)가 하고 여기서는 그리기와 포커스 추적만 한다 — 불변식이
 * 깨지면 조용히 이상해지는 종류라 로직을 떼어 테스트로 덮었다.
 *
 * 블록마다 ▲▼(이동) · ✕(삭제)가 붙고, 텍스트 블록에는 제목 토글이 더 붙는다.
 */
export function BlockEditor({
  blocks,
  onChange,
  onFocusBlock,
  onCursor,
  focusId,
}: {
  blocks: EditorBlock[];
  onChange: (next: EditorBlock[]) => void;
  /** 어느 텍스트 블록에 커서가 있는지 — 사진을 여기에 끼운다. */
  onFocusBlock: (id: string | null) => void;
  onCursor: (position: number) => void;
  /** 삽입 직후 포커스를 옮길 블록. */
  focusId: string | null;
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
      {blocks.map((block, i) => (
        <div key={block.id} className="blocks__row">
          {block.type === 'text' ? (
            <textarea
              ref={(el) => {
                if (el === null) refs.current.delete(block.id);
                else refs.current.set(block.id, el);
              }}
              className={
                block.heading ? 'blocks__text blocks__text--heading' : 'blocks__text'
              }
              value={block.text}
              // 안내 문구는 첫 블록에만. Dart 와 같은 문장이다.
              placeholder={
                i === 0
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
              // 커서 위치는 선택이 바뀔 때마다 따라간다 — 입력 없이 탭만
              // 해도 그 자리에 사진이 들어가야 한다.
              onSelect={(e) => onCursor((e.target as HTMLTextAreaElement).selectionStart)}
            />
          ) : (
            <img className="blocks__image" src={block.url} alt="" />
          )}

          <div className="blocks__tools">
            {block.type === 'text' ? (
              <button
                type="button"
                className={
                  block.heading
                    ? 'blocks__tool blocks__tool--on'
                    : 'blocks__tool'
                }
                onClick={() => onChange(toggleHeading(blocks, block.id))}
                aria-label="제목 스타일"
              >
                H
              </button>
            ) : null}

            <button
              type="button"
              className="blocks__tool"
              onClick={() => onChange(moveBlock(blocks, block.id, -1))}
              disabled={i === 0}
              aria-label="위로"
            >
              ▲
            </button>
            <button
              type="button"
              className="blocks__tool"
              onClick={() => onChange(moveBlock(blocks, block.id, 1))}
              disabled={i === blocks.length - 1}
              aria-label="아래로"
            >
              ▼
            </button>

            {/* 텍스트 블록이 하나뿐이면 지울 수 없다 — 지워도 불변식이
                되살리지만, 버튼이 아무 일도 안 하는 것처럼 보인다. */}
            <button
              type="button"
              className="blocks__tool"
              onClick={() => onChange(removeBlock(blocks, block.id))}
              disabled={blocks.length === 1}
              aria-label="삭제"
            >
              ✕
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
