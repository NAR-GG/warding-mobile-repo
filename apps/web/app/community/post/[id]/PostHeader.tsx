'use client';

import { DetailHeader } from 'warding-ui';

/**
 * 글 상세 헤더.
 *
 * 클라이언트 경계가 여기인 이유: `onBack` 핸들러를 만드는 쪽이 클라이언트여야
 * 한다. 서버 컴포넌트에서 함수를 넘기면 런타임에 터진다.
 */
export function PostHeader() {
  return (
    <DetailHeader
      title="게시글"
      onBack={() => {
        // 웹뷰 안에서는 브리지로 네이티브에 위임해야 한다 — `history.back()` 은
        // 웹 라우팅만 되돌리고 네이티브 스택은 그대로라 아무 일도 안 일어난
        // 것처럼 보인다. 브리지(Stage A)가 생기면 그쪽으로 바꾼다.
        if (typeof window !== 'undefined') window.history.back();
      }}
    />
  );
}
