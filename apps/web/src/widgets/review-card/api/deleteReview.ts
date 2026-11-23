'use server';

import { revalidatePath } from 'next/cache';
import { deleteMyRating } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

/**
 * 내 평가 한 건을 지운다.
 *
 * **성공 여부만 돌려준다.** 실패 종류는 `Failure` 로 이미 분류돼 있고,
 * 화면은 "실패했는지" 만 알면 된다 — Dart ViewModel 도 같은 계약이다.
 *
 * 지운 뒤 목록을 다시 그린다. 낙관적으로 DOM 에서 빼지 않는 이유는, 누적
 * 건수 막대(`totalElements`)가 같이 줄어야 해서다 — 항목만 지우면 숫자가
 * 남아 어긋난다.
 */
export async function deleteReview(
  gameId: string,
  participantId: number,
): Promise<boolean> {
  const token = await readAuthToken();
  if (token === null) return false;

  const result = await deleteMyRating({ gameId, participantId }, { token });
  if (!result.ok) return false;

  // 내 평점 목록과 그 평가가 달린 선수 평점 상세 둘 다 바뀐다.
  revalidatePath('/my-review');
  revalidatePath(`/rating/${gameId}/${participantId}`);
  return true;
}
