'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

import { installBridgeReceiver, notifyReady, onBroadcast } from '@/shared/bridge';

/**
 * 브리지 수신기를 설치하고 Stage B 를 앱 전역에서 처리한다.
 *
 * `_app` 레이어에 있는 이유: 어느 화면이든 네이티브 브로드캐스트를 받아야
 * 한다. 화면마다 설치하면 전환 중에 메시지를 놓친다.
 */
export function BridgeProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();

  useEffect(() => {
    const uninstall = installBridgeReceiver();

    // 첫 페인트 완료를 알린다 — 네이티브가 로딩 가림막을 걷는 신호다.
    notifyReady(Date.now());


    // 토큰이 갱신되면 쿠키는 네이티브가 이미 다시 심은 뒤다. 서버 데이터만
    // 다시 받으면 로그인 상태가 반영된다.
    const off = onBroadcast('auth-changed', () => router.refresh());

    return () => {
      off();
      uninstall();
    };
  }, [router]);

  return <>{children}</>;
}
