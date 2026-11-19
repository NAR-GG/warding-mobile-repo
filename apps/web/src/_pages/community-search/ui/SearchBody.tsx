'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';

import { goBack } from '@/shared/bridge';

import { searchAction, type SearchPage } from '../api/searchAction';

/** 서버가 400 을 주는 길이. `warding-api/server` 의 상수와 같은 값이다 —
 *  그쪽은 서버 전용 모듈이라 클라이언트에서 import 할 수 없다. */
const MIN_LENGTH = 2;

/** 입력마다 쏘지 않는다. 검색은 LIKE 스캔이라 한 글자마다 쏘면 서버 CPU 를
 *  태운다(Dart 주석과 같은 이유·같은 값). */
const DEBOUNCE_MS = 350;

type State =
  /** 아직 2자를 채우지 않았다. */
  | { kind: 'idle' }
  | { kind: 'loading' }
  | { kind: 'failed' }
  | { kind: 'done'; pages: ReactNode[]; ids: number[]; nextCursor: number | null };

/**
 * 커뮤니티 검색 — 제목·본문 키워드.
 *
 * **목록과 달리 전부 클라이언트다.** 결과가 입력에 따라 바뀌어 SSR 로 미리
 * 그릴 것이 없다. 대신 결과 카드는 Server Action 이 그려서 넘긴다
 * (→ `searchAction`) — 카드와 포맷터가 번들로 들어오지 않게 한다.
 *
 * 수치는 Dart `community_search_screen.dart` 와 맞춘다 — 입력 14, 안내 13.5,
 * 바 패딩 8/8/16/10.
 */
export function SearchBody() {
  const [query, setQuery] = useState('');
  const [state, setState] = useState<State>({ kind: 'idle' });
  const [pending, setPending] = useState(false);

  /** 마지막으로 보낸 요청. 늦게 온 응답이 최신 결과를 덮지 않게 한다. */
  const seq = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => () => {
    if (timer.current !== null) clearTimeout(timer.current);
  }, []);

  function onChange(value: string) {
    setQuery(value);
    if (timer.current !== null) clearTimeout(timer.current);

    const trimmed = value.trim();
    if (trimmed.length < MIN_LENGTH) {
      // 서버가 400 을 주는 길이다. 요청하지 않고 안내로 되돌린다.
      seq.current += 1;
      setState({ kind: 'idle' });
      return;
    }

    timer.current = setTimeout(() => void run(trimmed), DEBOUNCE_MS);
  }

  async function run(q: string) {
    const mine = (seq.current += 1);
    setState({ kind: 'loading' });

    const result = await searchAction(q);

    // 더 새로운 입력이 이미 나갔으면 이 응답은 버린다.
    if (mine !== seq.current) return;

    setState(
      result === null
        ? { kind: 'failed' }
        : { kind: 'done', pages: [result.items], ids: result.ids, nextCursor: result.nextCursor },
    );
  }

  async function loadMore() {
    if (state.kind !== 'done' || state.nextCursor === null || pending) return;

    const mine = seq.current;
    setPending(true);

    const result = await searchAction(query.trim(), state.nextCursor, state.ids);

    setPending(false);
    // 더 받는 사이 검색어가 바뀌었으면 버린다.
    if (mine !== seq.current || result === null) return;

    setState((prev) =>
      prev.kind !== 'done'
        ? prev
        : {
            kind: 'done',
            pages: [...prev.pages, result.items],
            ids: [...prev.ids, ...result.ids],
            nextCursor: result.nextCursor,
          },
    );
  }

  return (
    <>
      <div className="search-bar">
        <button
          type="button"
          className="search-bar__back"
          onClick={goBack}
          aria-label="뒤로"
        >
          <BackIcon />
        </button>

        <div className="search-bar__field">
          <SearchIcon />
          <input
            className="search-bar__input"
            type="search"
            value={query}
            onChange={(e) => onChange(e.target.value)}
            placeholder="제목·내용 검색"
            // 열자마자 입력할 수 있게 한다(Dart 의 autofocus).
            autoFocus
            // 웹뷰에서 자동 대문자·교정은 검색어를 망친다.
            autoCapitalize="off"
            autoCorrect="off"
            spellCheck={false}
            enterKeyHint="search"
          />
          {query === '' ? null : (
            <button
              type="button"
              className="search-bar__clear"
              onClick={() => onChange('')}
              aria-label="지우기"
            >
              <ClearIcon />
            </button>
          )}
        </div>
      </div>

      <SearchResults state={state} pending={pending} onLoadMore={loadMore} />
    </>
  );
}

function SearchResults({
  state,
  pending,
  onLoadMore,
}: {
  state: State;
  pending: boolean;
  onLoadMore: () => void;
}) {
  if (state.kind === 'idle') {
    return <p className="search-message">두 글자 이상 입력하면 검색해요</p>;
  }
  if (state.kind === 'loading') {
    return <p className="search-message">검색하는 중…</p>;
  }
  if (state.kind === 'failed') {
    return <p className="search-message">검색하지 못했어요. 잠시 후 다시 시도해 주세요.</p>;
  }
  if (state.ids.length === 0) {
    return <p className="search-message">검색 결과가 없어요</p>;
  }

  return (
    <ul className="post-list">
      {state.pages}
      {state.nextCursor === null ? null : (
        <li className="post-more">
          <button
            type="button"
            className="post-more__button"
            onClick={onLoadMore}
            disabled={pending}
          >
            {pending ? '불러오는 중…' : '더보기'}
          </button>
        </li>
      )}
    </ul>
  );
}

/* 아이콘은 인라인이다 — 검색 바는 화면 최상단이라 에셋 왕복이 첫 페인트에
 * 그대로 보인다(`DetailHeader` 와 같은 판단). */

function BackIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M15 19l-7-7 7-7"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg className="search-bar__icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="2" />
      <path d="M20 20l-3.5-3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function ClearIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M6 6l12 12M18 6L6 18"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}
