'use server';

import { revalidatePath } from 'next/cache';
import {
  createComment,
  togglePostLike,
  togglePostScrap,
  type LikeResult,
} from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

/**
 * 상세 화면의 쓰기 액션.
 *
 * **토큰은 서버가 쿠키에서 읽는다.** 클라이언트가 토큰을 들고 다니지 않으므로
 * 액션 인자에 넣지 않는다 — 넣으면 번들과 네트워크에 토큰이 노출된다.
 *
 * **낙관적 업데이트를 하지 않는다.** 서버가 토글 후 최종 상태를 돌려주므로
 * 호출부가 그 값으로 교체한다 — 연타해도 서버 값으로 수렴한다(Dart 의
 * 명시적 결정과 같다).
 *
 * 비로그인이면 아예 부르지 않고 `'unauthorized'` 를 돌려준다. 호출부가 그걸
 * 로그인 유도로 바꾼다 — 서버에 401 을 받으러 가는 왕복을 아낀다.
 */
export type ActionResult<T> =
  | { kind: 'ok'; value: T }
  | { kind: 'unauthorized' }
  | { kind: 'failed' };

export async function likeAction(postId: number): Promise<ActionResult<LikeResult>> {
  const token = await readAuthToken();
  if (token === null) return { kind: 'unauthorized' };

  const r = await togglePostLike(postId, { token });
  if (!r.ok) {
    return r.failure.kind === 'unauthorized'
      ? { kind: 'unauthorized' }
      : { kind: 'failed' };
  }
  return { kind: 'ok', value: r.value };
}

export async function scrapAction(postId: number): Promise<ActionResult<boolean>> {
  const token = await readAuthToken();
  if (token === null) return { kind: 'unauthorized' };

  const r = await togglePostScrap(postId, { token });
  if (!r.ok) {
    return r.failure.kind === 'unauthorized'
      ? { kind: 'unauthorized' }
      : { kind: 'failed' };
  }
  return { kind: 'ok', value: r.value };
}

/**
 * 댓글 작성.
 *
 * **성공하면 페이지를 다시 그린다**(`revalidatePath`). 새 댓글을 클라이언트가
 * 직접 끼워 넣지 않는 이유는, 서버가 멘션 대상과 답글 위치(`parentId`)를
 * 정하기 때문이다 — 앱이 추측해 그리면 새로고침했을 때 자리가 달라진다.
 *
 * 답글이면 `replyToCommentId` 를 넘긴다. 그 값으로 서버가 최상위 댓글을
 * 찾아 붙이고 `@닉네임` 도 채운다.
 */
export async function commentAction(
  postId: number,
  body: string,
  replyToCommentId?: number,
): Promise<ActionResult<number>> {
  const text = body.trim();
  // 빈 댓글은 보내지 않는다. 서버 왕복을 아끼고, 버튼도 비활성이라 정상
  // 경로로는 오지 않는다.
  if (text === '') return { kind: 'failed' };

  const token = await readAuthToken();
  if (token === null) return { kind: 'unauthorized' };

  const r = await createComment(
    postId,
    replyToCommentId === undefined
      ? { body: text }
      : { body: text, replyToCommentId },
    { token },
  );

  if (!r.ok) {
    return r.failure.kind === 'unauthorized'
      ? { kind: 'unauthorized' }
      : { kind: 'failed' };
  }

  revalidatePath(`/community/post/${postId}`);
  return { kind: 'ok', value: r.value };
}
