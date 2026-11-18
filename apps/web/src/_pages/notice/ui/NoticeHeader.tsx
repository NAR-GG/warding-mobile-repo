'use client';

import { DetailHeader } from 'warding-ui';

/** 공지 헤더. 클라이언트 경계인 이유는 `PostHeader` 주석 참고. */
export function NoticeHeader({ title }: { title: string }) {
  return (
    <DetailHeader
      title={title}
      onBack={() => {
        // 웹뷰에서는 브리지로 네이티브에 위임해야 한다(Stage A 미구현).
        if (typeof window !== 'undefined') window.history.back();
      }}
    />
  );
}
