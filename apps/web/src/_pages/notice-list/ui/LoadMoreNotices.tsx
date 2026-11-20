'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';

import { loadMoreNotices } from '../api/loadMoreNotices';

/**
 * 무한 스크롤 — 바닥 근처에 닿으면 다음 페이지를 당긴다.
 *
 * 커뮤니티 `LoadMore` 와 같은 구조다. 다른 것은 커서가 아니라 페이지
 * 번호라는 점뿐이고, 그 이유는 `loadMoreNotices` 주석에 있다.
 *
 * **공용으로 올리지 않았다.** 페이징 방식(커서 vs 페이지)·항목 타입·실패
 * 문구가 달라서, 하나로 합치면 제네릭과 분기가 본문보다 길어진다. 화면이
 * 더 쌓여 같은 모양이 3번째로 나오면 그때 올린다(`packages/ui` 기준과 같은
 * 판단이다).
 */
export function LoadMoreNotices({ page }: { page: number }) {
  const [pages, setPages] = useState<ReactNode[]>([]);
  const [next, setNext] = useState<number | null>(page);
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
    const result = await loadMoreNotices(cur);
    setPending(false);

    if (result === null) {
      setFailed(true);
      return;
    }
    setPages((prev) => [...prev, result.items]);
    setNext(result.nextPage);
  }

  useEffect(() => {
    const el = sentinel.current;
    if (el === null) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) void load();
      },
      // 바닥에 닿기 전에 미리 당긴다 — Dart 의 "남은 스크롤 200px" 과 같다.
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
            // 자동 재시도를 하지 않는 대신 다시 시도할 길을 준다 — 네트워크가
            // 끊긴 상태에서 센티넬이 계속 보이면 무한히 재요청하게 된다.
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
