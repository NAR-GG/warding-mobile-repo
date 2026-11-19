'use client';

import { useState, type ReactNode } from 'react';

import { loadMorePosts } from '../api/loadMorePosts';

/**
 * 더보기 버튼 — 이 화면의 **유일한 클라이언트 컴포넌트다.**
 *
 * 받아온 항목은 서버가 그린 JSX 그대로 쌓는다. 데이터를 받아 여기서 그리면
 * `PostListItem` 과 포맷터가 클라이언트 번들로 따라 들어온다(→ `loadMorePosts`).
 *
 * **자동 로드(IntersectionObserver)를 쓰지 않는다.** Dart 목록은 바닥 200px
 * 전에 자동으로 당기지만, 그러려면 목록 전체가 클라이언트 상태여야 해서 첫
 * 페인트 이득이 줄어든다. 조작감 차이는 받아들이고 번들을 지키는 쪽을 택했다.
 *
 * **실패는 조용히 되돌린다.** 서버가 null 을 주면 버튼만 되살려 다시 누를 수
 * 있게 한다 — 보고 있는 목록을 에러로 덮지 않는 Dart `loadMore` 와 같다.
 */
export function LoadMore({ cursor }: { cursor: number }) {
  const [pages, setPages] = useState<ReactNode[]>([]);
  const [next, setNext] = useState<number | null>(cursor);
  const [pending, setPending] = useState(false);
  const [failed, setFailed] = useState(false);

  async function onClick() {
    if (next === null || pending) return;

    setPending(true);
    setFailed(false);

    const result = await loadMorePosts(next);

    if (result === null) {
      setFailed(true);
      setPending(false);
      return;
    }

    setPages((prev) => [...prev, result.items]);
    setNext(result.nextCursor);
    setPending(false);
  }

  return (
    <>
      {pages}

      {next === null ? null : (
        <li className="post-more">
          <button
            type="button"
            className="post-more__button"
            onClick={onClick}
            disabled={pending}
          >
            {pending ? '불러오는 중…' : failed ? '다시 시도' : '더보기'}
          </button>
        </li>
      )}
    </>
  );
}
