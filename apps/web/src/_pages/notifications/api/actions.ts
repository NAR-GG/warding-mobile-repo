'use server';

import { revalidatePath } from 'next/cache';
import {
  deleteNotification,
  markAllNotificationsRead,
  markNotificationRead,
} from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

/** 알림함이 다루는 묶음. 커뮤니티 알림만 본다(경기 알림은 마이구독). */
const GROUP = 'COMMUNITY';

/**
 * 전체 읽음.
 *
 * **성공 여부만 돌려준다** — 화면은 "실패했는지" 만 알면 된다.
 */
export async function markAllRead(): Promise<boolean> {
  const token = await readAuthToken();
  if (token === null) return false;

  const r = await markAllNotificationsRead({ group: GROUP }, { token });
  if (!r.ok) return false;
  revalidatePath('/notifications');
  return true;
}

/**
 * 단건 읽음.
 *
 * **탭할 때 부른다.** 실패해도 화면은 그대로 둔다 — 읽음 표시가 늦는 것은
 * 글을 못 여는 것보다 가볍다(Dart 도 `markRead` 결과를 보지 않는다).
 */
export async function markRead(id: number): Promise<void> {
  const token = await readAuthToken();
  if (token === null) return;
  await markNotificationRead(id, { token });
  revalidatePath('/notifications');
}

/** 단건 삭제. 실패하면 호출부가 항목을 되살린다. */
export async function removeNotification(id: number): Promise<boolean> {
  const token = await readAuthToken();
  if (token === null) return false;

  const r = await deleteNotification(id, { token });
  if (!r.ok) return false;
  revalidatePath('/notifications');
  return true;
}
