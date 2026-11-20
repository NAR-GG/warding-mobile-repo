'use client';

import type { ReactNode } from 'react';

import { pushWebDepth } from '@/shared/bridge';

/**
 * 웹 내부 이동 링크.
 *
 * **깊이를 기록한다** — 그래야 상세에서 뒤로가기를 눌렀을 때 네이티브가
 * 아니라 웹 히스토리를 되돌린다. 탭 화면은 `pushReplacement` 로 열려
 * 네이티브 스택이 비어 있어서, 네이티브에 맡기면 아무 일도 안 일어난다.
 *
 * `<a>` 를 그대로 쓴다. Next `<Link>` 로 바꾸면 클라이언트 라우팅이 되어
 * 서버 렌더링 이점이 줄고, 지금은 화면마다 전체 로드가 더 단순하다.
 */
export function WebLink({
  href,
  className,
  children,
}: {
  href: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <a className={className} href={href} onClick={pushWebDepth}>
      {children}
    </a>
  );
}
