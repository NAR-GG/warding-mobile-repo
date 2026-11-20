'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

import { MY_ACTIVITY_TABS, TAB_LABELS } from '../model/tabs';

/**
 * "내 활동" 헤더 + 탭.
 *
 * 탭은 **링크**다. 라우트로 갈랐으니 클릭이 곧 이동이고, 각 탭이 자기
 * 데이터를 서버에서 받아 온다 — 클라이언트 상태로 들고 있을 것이 없다.
 *
 * **현재 탭을 경로에서 읽는다.** props 로 받지 않는 이유는 스켈레톤
 * (`loading.tsx`)이 라우트 params 를 받지 못해서다 — 그쪽에서도 탭이
 * 제대로 보이려면 헤더가 스스로 알아야 한다.
 *
 * 클라이언트 경계인 이유는 `onBack` 과 `usePathname` 둘 다다.
 */
export function MyActivityHeader() {
  const pathname = usePathname();

  return (
    <>
      <DetailHeader title="내 활동" onBack={goBack} />

      <nav className="activity-tabs">
        {MY_ACTIVITY_TABS.map((t) => {
          const on = pathname === `/my-activity/${t}`;
          return (
            <Link
              key={t}
              href={`/my-activity/${t}`}
              className={on ? 'activity-tab activity-tab--on' : 'activity-tab'}
              aria-current={on ? 'page' : undefined}
              // 같은 탭을 다시 눌러 되받아오지 않게 막는다.
              {...(on ? { 'aria-disabled': true, tabIndex: -1 } : {})}
            >
              {TAB_LABELS[t]}
            </Link>
          );
        })}
      </nav>
    </>
  );
}
