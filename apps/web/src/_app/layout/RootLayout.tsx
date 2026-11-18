import '../styles/globals.css';

/**
 * 루트 레이아웃 본체. `app/layout.tsx` 가 이것을 re-export 한다.
 *
 * 전역 CSS import 가 여기 있는 이유: 토큰 → 컴포넌트 스타일 → 리셋 순서가
 * 한 파일(`globals.css`)에 고정돼 있고, 그 파일이 `_app` 레이어에 속한다.
 */
export function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
