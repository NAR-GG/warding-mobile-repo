'use client';

import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

/** 광고 안내 헤더. 클라이언트 경계인 이유는 `NoticeHeader` 주석 참고. */
export function AdGuideHeader() {
  return <DetailHeader title="광고 안내" onBack={goBack} />;
}
