'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';

import { loadMorePosts } from '../api/loadMorePosts';

/**
 * 무한 스크롤 — 바닥 근처에 닿으면 다음 페이지를 당긴다.
 *
 * Dart 목록(`_BoardList`)과 같은 조작감이다. 거긴 바닥 200px 전에 당기는데,
 * 여기서는 `IntersectionObserver` 의 `rootMargin` 으로 같은 효과를 낸다 —
 * 스크롤 이벤트를 직접 듣는 것보다 싸고, 메인 스레드를 덜 막는다.
 *
 * **받아온 항목은 서버가 그린 JSX 를 그대로 쌓는다.** 데이터를 받아 여기서
 * 그리면 카드와 포맷터가 클라이언트 번들로 따라 들어온다(→ `loadMorePosts`).
 *
 * **실패는 조용히 둔다.** 보고 있는 목록을 에러로 덮지 않는다(Dart `loadMore`
 * 와 같은 판단). 다만 자동 재시도는 하지 않는다 — 네트워크가 끊긴 상태에서
 * 센티넬이 계속 보이면 무한히 재요청하게 된다. 버튼을 보여 사용자가 고르게
 * 한다.
 */
export function LoadMore({ cursor }: { cursor: number }) {
  const [pages, setPages] = useState<ReactNode[]>([]);
  const [next, setNext] = useState<number | null>(cursor);
  const [pending, setPending] = useState(false);
  const [failed, setFailed] = useState(false);

  const sentinel = useRef<HTMLLIElement>(null);

  /** 최신 상태를 옵저버 콜백에서 읽기 위한 통로. 의존성 배열에 상태를 넣으면
   *  매번 옵저버를 다시 만들게 된다. */
  const state = useRef({ next, pending, failed });
  state.current = { next, pending, failed };

  async function load() {
    const { next: cur, pending: busy, failed: err } = state.current;
    if (cur === null || busy || err) return;

    setPending(true);
    const result = await loadMorePosts(cur);
    setPending(false);

    if (result === null) {
      setFailed(true);
      return;
    }
    setPages((prev) => [...prev, result.items]);
    setNext(result.nextCursor);
  }

  useEffect(() => {
    const el = sentinel.current;
    if (el === null) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) void load();
      },
      // 바닥에 닿기 전에 미리 당긴다 — Dart 의 "남은 스크롤 200px" 과 같은
      // 의도다. 사용자가 끝을 보기 전에 다음 장이 붙는다.
      { rootMargin: '200px' },
    );

    observer.observe(el);
    return () => observer.disconnect();
    // 센티넬은 한 번 만들어지면 그대로다. 상태는 ref 로 읽는다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      {pages}

      {next === null ? null : (
        <li className="post-more" ref={sentinel}>
          {failed ? (
            // 자동 재시도를 하지 않는 대신 다시 시도할 길을 준다.
            <button
              type="button"
              className="post-more__button"
              onClick={() => {
                setFailed(false);
                void load();
              }}
            >
              다시 시도
            </button>
          ) : (
            <span className="post-more__loading">불러오는 중…</span>
          )}
        </li>
      )}
    </>
  );
}
