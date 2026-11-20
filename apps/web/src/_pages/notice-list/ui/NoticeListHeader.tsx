'use client';

import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

/**
 * 공지 목록 헤더. 제목은 Dart `l.notice` 와 같은 "공지사항" 이다.
 *
 * 클라이언트 경계인 이유는 `onBack` 때문이다 — 서버 컴포넌트에서 핸들러를
 * 넘기면 런타임에 터진다. 경계를 호출부에 두는 규칙은 `NoticeHeader` 와
 * 같다.
 */
export function NoticeListHeader() {
  return <DetailHeader title="공지사항" onBack={goBack} />;
}
