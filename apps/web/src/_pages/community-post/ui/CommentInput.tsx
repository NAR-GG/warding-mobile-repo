'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { commentAction } from '../api/actions';

/**
 * 댓글 입력 바 — Flutter `post_detail_screen.dart` 의 `_inputBar`.
 *
 * **화면 하단에 고정한다.** 네이티브는 키보드가 올라오면 Scaffold 가 본문을
 * 줄여 바를 밀어 올리는데, 웹뷰에서는 `position: sticky` 로 같은 모양을 낸다.
 *
 * **등록 후 페이지를 다시 받는다**(`router.refresh()`). 새 댓글을 직접 끼워
 * 넣지 않는 이유는 서버가 멘션 대상과 답글 위치를 정하기 때문이다 — 앱이
 * 추측해 그리면 새로고침했을 때 자리가 달라진다.
 *
 * 답글 UI(대상 지정)는 아직 없다. 지금은 최상위 댓글만 쓴다.
 */
export function CommentInput({ postId }: { postId: number }) {
  const router = useRouter();
  const [text, setText] = useState('');
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const ready = text.trim() !== '' && !pending;

  async function onSubmit() {
    if (!ready) return;

    setPending(true);
    setNotice(null);

    const r = await commentAction(postId, text);
    setPending(false);

    if (r.kind === 'unauthorized') {
      setNotice('로그인이 필요합니다');
      return;
    }
    if (r.kind === 'failed') {
      setNotice('등록하지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }

    setText('');
    // 서버가 그린 목록을 다시 받는다 — 멘션·답글 위치가 서버 몫이다.
    router.refresh();
  }

  return (
    <div className="comment-input">
      {notice === null ? null : (
        <p className="comment-input__notice">{notice}</p>
      )}

      <div className="comment-input__row">
        <textarea
          className="comment-input__field"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="댓글을 입력하세요"
          rows={1}
          // 웹뷰에서 자동 대문자·교정은 한국어 입력을 망친다.
          autoCapitalize="off"
          autoCorrect="off"
        />
        <button
          type="button"
          className="comment-input__submit"
          onClick={onSubmit}
          disabled={!ready}
        >
          {pending ? '등록 중…' : '등록'}
        </button>
      </div>
    </div>
  );
}
