'use client';

import { useState } from 'react';

import { likeAction, scrapAction } from '../api/actions';

/**
 * 추천·댓글·스크랩 행 — Flutter `post_detail_screen.dart` 의 `_actions`.
 *
 * **폭 3등분으로 꽉 채운다.** 칩으로 왼쪽에 몰면 본문과 댓글 사이 경계가
 * 흐려지는데, 균등 분할하면 그 자체가 구분선 역할을 한다(Dart 주석).
 *
 * **낙관적 업데이트를 하지 않는다.** 누르면 서버 응답을 기다렸다 그 값으로
 * 바꾼다 — 연타해도 서버 값으로 수렴한다. Dart 가 의도적으로 그렇게 해 둔
 * 것이라 롤백 로직이 아예 없다.
 *
 * 비로그인은 액션이 `'unauthorized'` 를 돌려주고, 지금은 안내만 띄운다 —
 * 네이티브 로그인 화면을 여는 브리지 메시지가 아직 없다(Stage A 의
 * `navigate` 가 미구현이다).
 */
export function PostActions({
  postId,
  liked: initialLiked,
  likeCount: initialCount,
  scrapped: initialScrapped,
  commentCount,
}: {
  postId: number;
  liked: boolean;
  likeCount: number;
  scrapped: boolean;
  commentCount: number;
}) {
  const [liked, setLiked] = useState(initialLiked);
  const [likeCount, setLikeCount] = useState(initialCount);
  const [scrapped, setScrapped] = useState(initialScrapped);
  const [pending, setPending] = useState<'like' | 'scrap' | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function onLike() {
    if (pending !== null) return;
    setPending('like');
    setNotice(null);

    const r = await likeAction(postId);
    setPending(null);

    if (r.kind === 'unauthorized') {
      setNotice('로그인이 필요합니다');
      return;
    }
    if (r.kind === 'failed') {
      setNotice('잠시 후 다시 시도해 주세요');
      return;
    }
    // 서버가 돌려준 최종 상태로 교체한다.
    setLiked(r.value.liked);
    setLikeCount(r.value.likeCount);
  }

  async function onScrap() {
    if (pending !== null) return;
    setPending('scrap');
    setNotice(null);

    const r = await scrapAction(postId);
    setPending(null);

    if (r.kind === 'unauthorized') {
      setNotice('로그인이 필요합니다');
      return;
    }
    if (r.kind === 'failed') {
      setNotice('잠시 후 다시 시도해 주세요');
      return;
    }
    setScrapped(r.value);
  }

  return (
    <>
      <div className="post-actions">
        <button
          type="button"
          className={liked ? 'post-actions__cell is-active' : 'post-actions__cell'}
          onClick={onLike}
          disabled={pending !== null}
        >
          <ThumbUpIcon filled={liked} />
          {/* 0 이면 숫자를 떼고 라벨만 — Dart 와 같다. */}
          {likeCount === 0 ? '추천' : `추천 ${likeCount}`}
        </button>

        {/* 댓글 칸은 지금 표시 전용이다. Dart 는 입력창으로 포커스를 옮기는데,
            웹에는 아직 입력창이 없다(다음 단계). */}
        <span className="post-actions__cell">
          <CommentIcon />
          댓글 {commentCount}
        </span>

        <button
          type="button"
          className={scrapped ? 'post-actions__cell is-active' : 'post-actions__cell'}
          onClick={onScrap}
          disabled={pending !== null}
        >
          <BookmarkIcon filled={scrapped} />
          스크랩
        </button>
      </div>

      {notice === null ? null : <p className="post-actions__notice">{notice}</p>}
    </>
  );
}

/* 아이콘은 인라인이다 — Dart 는 svg 에셋을 쓰지만 웹은 자산 왕복을 줄인다. */

function ThumbUpIcon({ filled }: { filled: boolean }) {
  return (
    <svg viewBox="0 0 24 24" fill={filled ? 'currentColor' : 'none'} aria-hidden="true">
      <path
        d="M7 22h11a2 2 0 0 0 2-1.6l1.3-7A2 2 0 0 0 19.3 11H14l.8-4a2 2 0 0 0-2-2.4l-.4 1.2L8.5 11M7 22H4a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h3m0 11V11"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function CommentIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.9 8.9 0 0 1-3.9-.9L3 21l1.9-5.1A8.4 8.4 0 0 1 12 3.1a8.4 8.4 0 0 1 9 8.4Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function BookmarkIcon({ filled }: { filled: boolean }) {
  return (
    <svg viewBox="0 0 24 24" fill={filled ? 'currentColor' : 'none'} aria-hidden="true">
      <path
        d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
