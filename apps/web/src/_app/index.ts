// 앱 전역 설정의 공개 API. 라우트(`app/layout.tsx`)가 이것만 re-export 한다.
export { metadata, viewport } from './config/metadata';
export { RootLayout } from './ui/RootLayout';
