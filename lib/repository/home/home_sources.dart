import 'package:flutter/foundation.dart';

import '../../model/home_models.dart';

/// 솔로 랭크 상태 한 번의 조회 결과.
class SoloRankSnapshot {
  const SoloRankSnapshot({required this.live, required this.finished});

  final List<HomeLiveSoloPlayer> live;
  final List<HomeFinishedSoloPlayer> finished;
}

/// 구독 선수 솔랭 상태 소스. 솔랭 DTO(`gameStartTime`·챔피언·직전 결과)가
/// 백엔드에 생기면 구현체만 교체한다.
abstract class SoloRankSource {
  Future<SoloRankSnapshot> fetch();
}

/// 최근 평점 한줄평 소스. 한줄평이 달린 것만 반환한다는 계약.
abstract class ReviewSource {
  Future<List<HomeReviewItem>> fetchRecent();
}

/// 홈 뉴스 소스. 실제 `/api/community/news`는 LoL 필터가 붙기 전에는 홈에
/// 내보내면 안 되므로 목업 구현만 연결한다.
abstract class NewsSource {
  Future<List<HomeNewsArticle>> fetchTop();
}

/// 홈 목업 스위치. 켜져 있으면 솔랭·평점·뉴스의 기본 소스가 목업이고, 꺼져
/// 있으면 빈 소스다.
///
/// 기본값은 [kDebugMode] — 디버그·시뮬레이터에서는 목업을 보고, 릴리즈
/// (`shorebird release`) 빌드에서는 빈 소스가 나가 가짜 솔랭·실제 언론사 이름을 단
/// 가짜 뉴스·가짜 한줄평이 실사용자에게 보이지 않는다. 릴리즈 빌드에서 목업을
/// 보려면 `--dart-define=HOME_MOCKS=true`, 디버그에서 끄려면 `=false`.
const bool kHomeMocks = bool.fromEnvironment(
  'HOME_MOCKS',
  defaultValue: kDebugMode,
);

/// [HomeViewModel]·[MyPlayersViewModel] 의 기본 솔랭 소스. 테스트는 [mocks] 로
/// 게이트 결과를 확인한다.
SoloRankSource defaultSoloRankSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockSoloRankSource() : const EmptySoloRankSource();

/// [HomeViewModel] 의 기본 한줄평 소스.
ReviewSource defaultReviewSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockReviewSource() : const EmptyReviewSource();

/// [HomeViewModel] 의 기본 뉴스 소스.
NewsSource defaultNewsSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockNewsSource() : const EmptyNewsSource();

/// 빈 솔랭 소스 — 솔랭 백엔드가 없을 때 릴리즈 빌드의 기본값. 구독이 있으면
/// 홈 솔랭 카드는 "지금 솔랭 중인 선수 없음" 조용한 행이 되고, 내 선수 화면은
/// 모두 소식 없음으로 둔다.
class EmptySoloRankSource implements SoloRankSource {
  const EmptySoloRankSource();

  @override
  Future<SoloRankSnapshot> fetch() async =>
      const SoloRankSnapshot(live: [], finished: []);
}

/// 빈 한줄평 소스 — 홈 커뮤니티의 평점 한줄평 탭이 숨겨진다.
class EmptyReviewSource implements ReviewSource {
  const EmptyReviewSource();

  @override
  Future<List<HomeReviewItem>> fetchRecent() async => const [];
}

/// 빈 뉴스 소스 — 홈 콘텐츠의 뉴스 탭이 숨겨지고 쇼츠가 기본 탭이 된다.
class EmptyNewsSource implements NewsSource {
  const EmptyNewsSource();

  @override
  Future<List<HomeNewsArticle>> fetchTop() async => const [];
}

/// 목업 솔랭 소스. 솔랭 DTO가 생기기 전까지 [kHomeMocks] 가 켜진 빌드의 기본
/// 소스다.
class MockSoloRankSource implements SoloRankSource {
  const MockSoloRankSource();

  static const List<HomeLiveSoloPlayer> live = [
    HomeLiveSoloPlayer(
      name: 'Faker',
      teamCode: 'T1',
      champion: '아리',
      elapsedSeconds: 1452,
    ),
    HomeLiveSoloPlayer(
      name: 'Chovy',
      teamCode: 'GEN',
      champion: '신드라',
      elapsedSeconds: 698,
    ),
    HomeLiveSoloPlayer(
      name: 'Zeus',
      teamCode: 'HLE',
      champion: '그웬',
      elapsedSeconds: 422,
    ),
    HomeLiveSoloPlayer(
      name: 'Keria',
      teamCode: 'T1',
      champion: '레나타 글라스크',
      elapsedSeconds: 135,
    ),
  ];

  static const List<HomeFinishedSoloPlayer> finished = [
    HomeFinishedSoloPlayer(
      name: 'Oner',
      teamCode: 'T1',
      won: true,
      minutesAgo: 12,
      durationMinutes: 32,
    ),
    HomeFinishedSoloPlayer(
      name: 'Ruler',
      teamCode: 'HLE',
      won: false,
      minutesAgo: 40,
      durationMinutes: 28,
    ),
    HomeFinishedSoloPlayer(
      name: 'Canyon',
      teamCode: 'GEN',
      won: true,
      minutesAgo: 63,
      durationMinutes: 35,
    ),
    HomeFinishedSoloPlayer(
      name: 'Peyz',
      teamCode: 'KT',
      won: false,
      minutesAgo: 95,
      durationMinutes: 24,
    ),
    HomeFinishedSoloPlayer(
      name: 'Doran',
      teamCode: 'DK',
      won: true,
      minutesAgo: 118,
      durationMinutes: 31,
    ),
    HomeFinishedSoloPlayer(
      name: 'Gumayusi',
      teamCode: 'T1',
      won: false,
      minutesAgo: 140,
      durationMinutes: 27,
    ),
    HomeFinishedSoloPlayer(
      name: 'Kiin',
      teamCode: 'GEN',
      won: true,
      minutesAgo: 167,
      durationMinutes: 33,
    ),
    HomeFinishedSoloPlayer(
      name: 'Showmaker',
      teamCode: 'DK',
      won: true,
      minutesAgo: 190,
      durationMinutes: 29,
    ),
  ];

  @override
  Future<SoloRankSnapshot> fetch() async =>
      const SoloRankSnapshot(live: live, finished: finished);
}

/// 목업 한줄평 소스.
class MockReviewSource implements ReviewSource {
  const MockReviewSource();

  static const List<HomeReviewItem> reviews = [
    HomeReviewItem(
      playerName: 'Chovy',
      champion: '신드라',
      stars: 5,
      comment: '라인전부터 그냥 다른 경기 하던데',
      nickname: '젠지가족#4821',
      teamCode: 'GEN',
      minutesAgo: 12,
    ),
    HomeReviewItem(
      playerName: 'Faker',
      champion: '아리',
      stars: 4,
      comment: '한타 각 보는 건 여전히 세계 최고',
      nickname: 'ABLY#1127',
      teamCode: 'T1',
      minutesAgo: 35,
    ),
    HomeReviewItem(
      playerName: 'Zeus',
      champion: '그웬',
      stars: 5,
      comment: '탑 차이로 이긴 경기. 캐리력 미쳤다',
      nickname: '한화보험왕#0930',
      teamCode: 'HLE',
      minutesAgo: 68,
    ),
    HomeReviewItem(
      playerName: 'Ruler',
      champion: '징크스',
      stars: 2,
      comment: '포지셔닝이 오늘따라 아쉬웠음',
      nickname: '원딜은거들뿐#5985',
      teamCode: 'GEN',
      minutesAgo: 95,
    ),
    HomeReviewItem(
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
  Future<List<HomeReviewItem>> fetchRecent() async => reviews;
}

/// 목업 뉴스 소스.
class MockNewsSource implements NewsSource {
  const MockNewsSource();

  static const List<HomeNewsArticle> articles = [
    HomeNewsArticle(title: 'T1, 플레이오프 진출 확정', office: 'OSEN', minutesAgo: 40),
    HomeNewsArticle(title: '젠지, 정규시즌 1위 마감', office: '스포츠조선', minutesAgo: 120),
    HomeNewsArticle(
      title: '한화생명, 로스터 변경 발표',
      office: '인벤',
      minutesAgo: 200,
      hasThumbnail: false,
    ),
    HomeNewsArticle(
      title: 'LCK 2026 서머 일정 공개',
      office: '데일리e스포츠',
      minutesAgo: 340,
    ),
    HomeNewsArticle(title: 'kt, 신인 서포터 영입', office: '포모스', minutesAgo: 600),
  ];

  @override
  Future<List<HomeNewsArticle>> fetchTop() async => articles;
}
