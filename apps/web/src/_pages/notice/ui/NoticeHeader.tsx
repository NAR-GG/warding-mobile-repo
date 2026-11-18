'use client';

import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

/** 공지 헤더. 클라이언트 경계인 이유는 `PostHeader` 주석 참고. */
export function NoticeHeader({ title }: { title: string }) {
  return (
    <DetailHeader
      title={title}
      onBack={goBack}
    />
  );
}
