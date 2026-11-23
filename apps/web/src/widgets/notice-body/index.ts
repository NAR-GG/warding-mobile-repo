// 공지 본문 렌더러 — 공지 상세·광고 안내가 함께 쓴다.
//
// **`shared` 가 아니라 여기 있는 이유**: 이 렌더러는 백오피스 공지 본문이
// 어떤 문법으로 오는지를 안다(`scroll:` 스트립·`|px` 너비). `shared` 는
// 도메인을 모르는 레이어다.
//
// **`packages/ui` 로 올리지 않은 이유**: Dart 원본이
// `features/notice/presentation/screens/notice_detail_screen.dart` 안이다.
// 기능 폴더 안의 위젯은 공용 자리에 두지 않는 규칙이 웹에서도 그대로다.
export { NoticeBody } from './ui/NoticeBody';
