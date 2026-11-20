// 글 카드 — 목록·검색이 함께 쓴다.
//
// **`shared` 가 아니라 여기 있는 이유**: 이 카드는 `PostSummary` 를 안다.
// `shared` 는 도메인을 모르는 레이어라 도메인 타입이 들어가면 안 된다 —
// 화면이 늘수록 그 레이어가 모든 도메인을 알게 된다.
export { PostCard } from './ui/PostCard';
export { PostCardSkeleton, PostListSkeleton } from './ui/PostCardSkeleton';
// 상세 스켈레톤도 여기 둔다 — 같은 '글' 을 그리는 것이고, 슬라이스를
// 쪼갤 만큼 크지 않다(steiger 가 참조 없는 슬라이스로 잡는다).
export { PostDetailSkeleton } from './ui/PostDetailSkeleton';
