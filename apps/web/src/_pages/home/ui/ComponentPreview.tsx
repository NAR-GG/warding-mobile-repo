'use client';

import { BoardBadge, Button, DetailHeader } from 'warding-ui';

/**
 * `packages/ui` 가 토큰을 제대로 읽는지 확인하는 미리보기. 첫 전환 화면이
 * 생기면 지운다.
 *
 * **클라이언트 경계가 왜 여기인가.** 핸들러(`onBack`·`onClick`)를 만드는 쪽이
 * 클라이언트여야 한다 — 컴포넌트 파일에 `'use client'` 를 붙여도 서버
 * 컴포넌트가 함수를 넘기는 순간 `Event handlers cannot be passed to Client
 * Component props` 로 런타임에 터진다(빌드는 통과하므로 실행해 봐야 안다).
 *
 * 그래서 `warding-ui` 는 경계를 선언하지 않는다. 핸들러 없이 쓰는 컴포넌트
 * (`BoardBadge` 등)는 서버에서 그대로 렌더되는 편이 낫고, 상호작용이 필요한
 * 화면만 이렇게 자기 경계를 만든다.
 */
export function ComponentPreview() {
  const row = {
    display: 'flex',
    flexWrap: 'wrap' as const,
    gap: `calc(8 * var(--scale) * 1px)`,
    alignItems: 'center',
    marginTop: `calc(20 * var(--scale) * 1px)`,
  };

  return (
    <>
      <DetailHeader
        title="Warding Web"
        onBack={() => {
          // 웹뷰에서는 브리지로 네이티브에 위임한다. 아직 브리지가 없다.
        }}
      />

      <div style={row}>
        <BoardBadge boardTeamId={null} boardTeamCode={null} allLabel="전체" />
        <BoardBadge boardTeamId={1} boardTeamCode="T1" allLabel="전체" />
        <Button variant="type1">type1</Button>
        <Button variant="type2">type2</Button>
        <Button variant="subscribe">구독</Button>
        <Button variant="subscribed">구독중</Button>
      </div>

      <div style={{ marginTop: `calc(8 * var(--scale) * 1px)` }}>
        <Button variant="set1">set1 (부모 폭)</Button>
      </div>
      <div style={{ marginTop: `calc(8 * var(--scale) * 1px)` }}>
        <Button variant="set1Disabled">경기 종료</Button>
      </div>
    </>
  );
}
