'use client';

import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

/** 선수 평점 헤더. 클라이언트 경계인 이유는 `NoticeHeader` 주석 참고. */
export function PlayerRatingHeader() {
  return <DetailHeader title="선수 평점" onBack={goBack} />;
}
