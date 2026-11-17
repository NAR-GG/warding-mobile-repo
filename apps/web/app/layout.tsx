import type { Metadata, Viewport } from 'next';
import './globals.css';

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
  themeColor: '#141517',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
