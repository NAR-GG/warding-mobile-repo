/** @type {import('next').NextConfig} */
const nextConfig = {
  // 웹뷰에서 쓰는 페이지라 이미지 최적화 라우트를 거치지 않는다 — 서버 왕복이
  // 한 번 더 생기고, 이미지는 이미 CDN 에 있다.
  images: { unoptimized: true },

  // `warding-ui` 는 빌드 산출물 없이 소스(.tsx)를 그대로 내보낸다. 번들러를
  // 패키지마다 두면 토큰 변경 → UI 빌드 → 웹 빌드로 단계가 늘고, 그 중간
  // 산출물을 캐시 앵커로 또 관리해야 한다(토큰 쪽에서 겪은 문제다).
  // Next 가 직접 컴파일하게 두는 편이 단계가 하나 적다.
  transpilePackages: ['warding-ui', 'warding-api'],
};
export default nextConfig;
