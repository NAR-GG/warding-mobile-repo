import '../../model/home_models.dart';
import 'home_api_sources.dart';

/// 솔로 랭크 상태 한 번의 조회 결과.
class SoloRankSnapshot {
  const SoloRankSnapshot({required this.live, required this.finished});

  final List<HomeLiveSoloPlayer> live;
  final List<HomeFinishedSoloPlayer> finished;
}

/// 구독 선수 솔랭 상태 소스.
abstract class SoloRankSource {
  Future<SoloRankSnapshot> fetch();
}

/// 응원 전송 결과 — 서버 기준 이 판 합계와 내가 보낸 수.
class CheerResult {
  const CheerResult({required this.total, required this.mine});

  final int total;
  final int mine;
}

/// 서버가 응원을 받지 않는다고 답했다(409 솔랭 중 아님 / 400 count 범위 밖).
/// 재시도해도 같은 결과라 호출부는 미결 응원을 버린다.
class CheerRejected implements Exception {
  const CheerRejected(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'CheerRejected($statusCode)';
}

/// 솔랭 응원 전송 소스. [count] 는 1..30 이다.
abstract class CheerSource {
  Future<CheerResult> send(int playerId, int count);
}

/// 최근 평점 한줄평 소스. 한줄평이 달린 것만 반환한다는 계약.
abstract class ReviewSource {
  Future<List<HomeReviewItem>> fetchRecent();
}

/// 홈 뉴스 소스.
abstract class NewsSource {
  Future<List<HomeNewsArticle>> fetchTop();
}

/// 홈 목업 스위치. 켜져 있으면 솔랭·평점·뉴스의 기본 소스가 목업이다. 꺼져 있으면
/// 셋 다 실제 API다.
///
/// 기본값은 꺼짐이다. 디버그에서 목업 화면을 보려면 `--dart-define=HOME_MOCKS=true`.
const bool kHomeMocks = bool.fromEnvironment('HOME_MOCKS');

/// [HomeViewModel]·[MyPlayersViewModel] 의 기본 솔랭 소스. 테스트는 [mocks] 로
/// 게이트 결과를 확인한다.
SoloRankSource defaultSoloRankSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockSoloRankSource() : ApiSoloRankSource();

/// [HomeViewModel] 의 기본 응원 전송 소스. 목업 모드에선 서버 없이 받아 준다.
CheerSource defaultCheerSource({bool mocks = kHomeMocks}) =>
    mocks ? MockCheerSource() : ApiCheerSource();

/// [HomeViewModel] 의 기본 한줄평 소스. 백엔드 nar-back-repo#542 배포 후
/// `GET /api/mobile/ratings/recent` 를 쓴다.
ReviewSource defaultReviewSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockReviewSource() : ApiReviewSource();

/// [HomeViewModel] 의 기본 뉴스 소스.
NewsSource defaultNewsSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockNewsSource() : ApiNewsSource();

/// 빈 솔랭 소스 — 솔랭 백엔드가 없을 때 릴리즈 빌드의 기본값. 구독이 있으면
/// 홈 솔랭 카드는 "지금 솔랭 중인 선수 없음" 조용한 행이 되고, 내 선수 화면은
/// 모두 소식 없음으로 둔다.
class EmptySoloRankSource implements SoloRankSource {
  const EmptySoloRankSource();

  @override
  Future<SoloRankSnapshot> fetch() async =>
      const SoloRankSnapshot(live: [], finished: []);
}

/// 빈 한줄평 소스 — 홈 평점 섹션이 통째로 숨겨진다.
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
      playerId: 1,
      cheerTotal: 1284,
    ),
    HomeLiveSoloPlayer(
      name: 'Chovy',
      teamCode: 'GEN',
      champion: '신드라',
      elapsedSeconds: 698,
      playerId: 2,
      cheerTotal: 432,
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
      cheerTotal: 871,
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
  Future<SoloRankSnapshot> fetch() async {
    // elapsedSeconds 는 고정값이라, 매 조회마다 "그만큼 전에 시작한" startedAt
    // 으로 다시 앵커링해 실기기 카운트업(기기 시계 기준)을 목업에서도 볼 수
    // 있게 한다. 다음 새로고침 때 같은 값으로 되돌아가는 건 목업 한계다.
    final now = DateTime.now();
    return SoloRankSnapshot(
      live: [
        for (final p in live)
          HomeLiveSoloPlayer(
            name: p.name,
            teamCode: p.teamCode,
            champion: p.champion,
            elapsedSeconds: p.elapsedSeconds,
            playerImageUrl: p.playerImageUrl,
            startedAt: now.subtract(Duration(seconds: p.elapsedSeconds)),
            playerId: p.playerId,
            cheerTotal: p.cheerTotal,
            cheerMine: p.cheerMine,
          ),
      ],
      finished: finished,
    );
  }
}

/// 목업 응원 소스 — 보낸 만큼 누적해 돌려준다.
class MockCheerSource implements CheerSource {
  MockCheerSource();

  final Map<int, int> _mine = {};

  @override
  Future<CheerResult> send(int playerId, int count) async {
    final mine = _mine.update(
      playerId,
      (v) => v + count,
      ifAbsent: () => count,
    );
    return CheerResult(total: 100 + mine, mine: mine);
  }
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
