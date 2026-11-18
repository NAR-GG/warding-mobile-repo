import type { Metadata, Viewport } from 'next';

import colors from 'warding-design-tokens/build/colors.json';

/**
 * 앱 전역 메타데이터·뷰포트.
 *
 * 루트 레이아웃이 이것을 re-export 한다 — `app/` 은 Next 가 경로로 해석하는
 * 파일만 두고, 설정 자체는 `_app` 레이어가 갖는다.
 */
export const metadata: Metadata = {
  title: 'Warding',
  // 웹뷰 안에서 쓰는 페이지라 검색 노출 대상이 아니다. SSR 은 SEO 가 아니라
  // 첫 페인트 속도를 위한 것이다(→ spec Decisions).
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  // 웹뷰 안에서 확대가 되면 네이티브 화면과 이질감이 생긴다.
  maximumScale: 1,
  userScalable: false,
  // `<meta name="theme-color">` 는 CSS 변수를 쓸 수 없는 자리다. 색을 손으로
  // 적으면 토큰이 바뀔 때 조용히 갈리므로 생성된 값에서 끌어온다.
  themeColor: colors.narDark800,
};
