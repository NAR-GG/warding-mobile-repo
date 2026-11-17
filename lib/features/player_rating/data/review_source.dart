import 'package:warding/core/config/home_mocks.dart';
import 'package:warding/features/player_rating/data/api_review_source.dart';
import 'package:warding/features/player_rating/domain/review_item.dart';

// 평점 한줄평 요약 소스. 홈 평점 섹션이 쓴다.
//
// 목업은 `HOME_MOCKS=true` 빌드에서만 나간다 — 실 API 가 붙은 뒤에도 디버그·
// 시뮬레이터에서 UI 를 확인하려고 남겨 둔다.
abstract class ReviewSource {
  Future<List<ReviewItem>> fetchRecent();
}

/// 홈 뉴스 소스.
ReviewSource defaultReviewSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockReviewSource() : ApiReviewSource();

/// [HomeViewModel] 의 기본 뉴스 소스.
class MockReviewSource implements ReviewSource {
  const MockReviewSource();

  static const List<ReviewItem> reviews = [
    ReviewItem(
      playerName: 'Chovy',
      champion: '신드라',
      stars: 5,
      comment: '라인전부터 그냥 다른 경기 하던데',
      nickname: '젠지가족#4821',
      teamCode: 'GEN',
      minutesAgo: 12,
    ),
    ReviewItem(
      playerName: 'Faker',
      champion: '아리',
      stars: 4,
      comment: '한타 각 보는 건 여전히 세계 최고',
      nickname: 'ABLY#1127',
      teamCode: 'T1',
      minutesAgo: 35,
    ),
    ReviewItem(
      playerName: 'Zeus',
      champion: '그웬',
      stars: 5,
      comment: '탑 차이로 이긴 경기. 캐리력 미쳤다',
      nickname: '한화보험왕#0930',
      teamCode: 'HLE',
      minutesAgo: 68,
    ),
    ReviewItem(
      playerName: 'Ruler',
      champion: '징크스',
      stars: 2,
      comment: '포지셔닝이 오늘따라 아쉬웠음',
      nickname: '원딜은거들뿐#5985',
      teamCode: 'GEN',
      minutesAgo: 95,
    ),
    ReviewItem(
      playerName: 'Keria',
      champion: '레나타',
      stars: 3,
      comment: '이니시 좋았는데 뒤가 안 받쳐줬다',
      nickname: '서폿장인입니다#2210',
      teamCode: 'T1',
      minutesAgo: 140,
    ),
  ];

  @override
  Future<List<ReviewItem>> fetchRecent() async => reviews;
}

/// 목업 뉴스 소스.

/// 빈 평점 소스. 테스트가 "한줄평이 없는 상태"(섹션 숨김)를 만들 때 쓴다.
class EmptyReviewSource implements ReviewSource {
  const EmptyReviewSource();
  @override
  Future<List<ReviewItem>> fetchRecent() async => const [];
}
