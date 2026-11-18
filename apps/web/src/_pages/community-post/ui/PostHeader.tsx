'use client';

import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

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
      onBack={goBack}
    />
  );
}
