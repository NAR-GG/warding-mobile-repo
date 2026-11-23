'use client';

import Link from 'next/link';
import type { ReactNode } from 'react';

import { pushWebDepth } from '@/shared/bridge';

/**
 * 웹 내부 이동 링크.
 *
 * **`<a>` 가 아니라 Next `<Link>` 다.** 전체 문서 로드를 하면 브라우저가 새
 * 문서를 받는 동안 **이전 화면을 그대로 두기 때문에** `loading.tsx` 가
 * 뜨지 않는다 — 스켈레톤이 있어도 보이지 않는다. 클라이언트 라우팅이면
 * 즉시 스켈레톤이 뜨고 React 런타임도 다시 받지 않는다.
 *
 * 처음엔 번들을 아끼려 `<a>` 를 썼는데, 웹뷰를 미리 데워 두면서
 * (→ `app/bridge/webview_warmup.dart`) React 가 이미 로드돼 있어 그 이유가
 * 사라졌다.
 *
 * **깊이를 기록한다** — 그래야 상세에서 뒤로가기를 눌렀을 때 네이티브가
 * 아니라 웹 히스토리를 되돌린다. 탭 화면은 네이티브 스택이 비어 있어서
 * 네이티브에 맡기면 아무 일도 안 일어난다.
 */
export function WebLink({
  href,
  className,
  children,
  'aria-label': ariaLabel,
}: {
  href: string;
  className?: string;
  children: ReactNode;
  /** 아이콘만 있는 링크(알림 벨 등)는 라벨이 있어야 읽힌다. */
  'aria-label'?: string;
}) {
  return (
    <Link
      className={className}
      href={href}
      onClick={pushWebDepth}
      aria-label={ariaLabel}
    >
      {children}
    </Link>
  );
}
