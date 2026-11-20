// 여러 화면이 쓰는 **도메인을 모르는** 컴포넌트.
//
// 도메인 타입(`PostSummary` 등)을 아는 것은 `widgets` 로 간다 — FSD 에서
// `shared` 는 어떤 도메인도 몰라야 하고, 그래야 화면이 늘어도 이 레이어가
// 비대해지지 않는다.
//
// 앱 공용 위젯(`packages/ui`)과도 다르다 — 거기는 Flutter `core/ui/` 의 짝이다.
export { WebLink } from './WebLink';
