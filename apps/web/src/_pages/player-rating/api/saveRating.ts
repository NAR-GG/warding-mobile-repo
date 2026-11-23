'use server';

import { revalidatePath } from 'next/cache';
import { deleteMyRating, saveMyRating } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

/**
 * 내 평가 작성·수정.
 *
 * **신규와 수정을 구분하지 않는다** — 서버가 PUT 하나로 받는다(Dart 와 같다).
 *
 * **별점은 반올림한 정수로 보낸다.** UI 는 0.5 단위지만 저장은 정수다
 * (3.5 → 4). Dart 도 `result.rating.round()` 로 같은 처리를 한다 — 여기서
 * 반올림하지 않으면 두 플랫폼이 같은 입력에 다른 값을 저장한다.
 */
export async function saveRating(
  gameId: string,
  participantId: number,
  rating: number,
  comment: string,
): Promise<boolean> {
  const token = await readAuthToken();
  if (token === null) return false;

  const result = await saveMyRating(
    { gameId, participantId, rating: Math.round(rating), comment },
    { token },
  );
  if (!result.ok) return false;

  revalidatePath(`/rating/${gameId}/${participantId}`);
  revalidatePath('/my-review');
  return true;
}

/** 내 평가 삭제. 상세에서 지우면 내 평점 목록도 바뀐다. */
export async function deleteRating(
  gameId: string,
  participantId: number,
): Promise<boolean> {
  const token = await readAuthToken();
  if (token === null) return false;

  const result = await deleteMyRating({ gameId, participantId }, { token });
  if (!result.ok) return false;

  revalidatePath(`/rating/${gameId}/${participantId}`);
  revalidatePath('/my-review');
  return true;
}
