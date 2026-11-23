// 내 리뷰 카드 — 내 평점 목록이 쓴다.
//
// **`shared` 가 아니라 여기 있는 이유**: 이 카드는 `MyReviewItem` 을 안다.
// `shared` 는 도메인을 모르는 레이어다.
//
// **`packages/ui` 가 아닌 이유**: Dart 원본이
// `features/my_review/presentation/widgets/review_card.dart` 안이다 —
// 기능 폴더 안의 위젯은 공용 자리에 두지 않는다.
export { ReviewCard } from './ui/ReviewCard';
export { Avatar } from './ui/Avatar';
