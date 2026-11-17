/** @type {import('next').NextConfig} */
const nextConfig = {
  // 웹뷰에서 쓰는 페이지라 이미지 최적화 라우트를 거치지 않는다 — 서버 왕복이
  // 한 번 더 생기고, 이미지는 이미 CDN 에 있다.
  images: { unoptimized: true },
};
export default nextConfig;
