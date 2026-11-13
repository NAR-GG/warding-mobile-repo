import 'package:warding/core/config/home_mocks.dart';
import 'package:warding/domain/player_subscription.dart';
import 'package:warding/features/solo_rank/data/api_solo_rank_sources.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_models.dart';

// 솔로 랭크·월즈 솔랭·응원 데이터 소스.
//
// 원래 `features/home/data/home_sources.dart` 에 뉴스·평점 소스와 함께
// 있었는데, 솔랭은 홈 전용이 아니라 `player`·`my_players` 도 쓰는 것이
// 드러나 솔랭 기능으로 올렸다. 백엔드가 아직 없어 목업·빈 소스를
// `kHomeMocks` 로 가르는 구조는 그대로다.
class SoloRankSnapshot {
  const SoloRankSnapshot({required this.live, required this.finished});

  final List<LiveSoloPlayer> live;
  final List<FinishedSoloPlayer> finished;
}

/// 구독 선수 솔랭 상태 소스.
abstract class SoloRankSource {
  Future<SoloRankSnapshot> fetch();
}

/// 월즈 솔랭 한 번의 조회 결과 — 명단(구독 여부 포함)과 그 선수들의 솔랭 상태.
class WorldsSoloSnapshot {
  const WorldsSoloSnapshot({
    required this.players,
    required this.solo,
    this.today = const {},
  });

  static const WorldsSoloSnapshot empty = WorldsSoloSnapshot(
    players: [],
    solo: SoloRankSnapshot(live: [], finished: []),
  );

  /// 월즈 부트캠프 계정이 등록된 선수 전체. 비면 월즈 솔랭을 통째로 숨긴다 —
  /// 대회가 끝나 서버가 보조 계정을 끄면 앱 배포 없이 사라진다.
  final List<PlayerSubscription> players;
  final SoloRankSnapshot solo;

  /// 선수별 오늘 전적(playerId → 전적). 서버가 최근 24시간으로 센다. 옛 서버면 비어 있다.
  final Map<int, WorldsTodayRecord> today;
}

/// 월즈 선수 한 명의 오늘 전적. [games] 는 지금 하는 판을 포함한다.
class WorldsTodayRecord {
  const WorldsTodayRecord({
    required this.games,
    required this.wins,
    required this.losses,
  });

  final int games;
  final int wins;
  final int losses;
}

/// 월즈 솔랭 소스.
abstract class WorldsSoloSource {
  Future<WorldsSoloSnapshot> fetch();
}

/// [HomeViewModel]·월즈 솔랭 화면의 기본 소스.
WorldsSoloSource defaultWorldsSoloSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockWorldsSoloSource() : ApiWorldsSoloSource();

/// 빈 월즈 솔랭 소스 — 월즈 솔랭이 화면에 나오지 않는다.
class EmptyWorldsSoloSource implements WorldsSoloSource {
  const EmptyWorldsSoloSource();

  @override
  Future<WorldsSoloSnapshot> fetch() async => WorldsSoloSnapshot.empty;
}

/// 목업 월즈 솔랭 소스. [kHomeMocks] 가 켜진 빌드의 기본 소스다.
class MockWorldsSoloSource implements WorldsSoloSource {
  const MockWorldsSoloSource();

  static PlayerSubscription _player(
    int id,
    String name,
    String team,
    String role,
  ) => PlayerSubscription(
    playerId: id,
    playerName: name,
    playerImageUrl: '',
    role: role,
    teamId: 0,
    teamCode: team,
    teamName: team,
    teamImageUrl: '',
    subscribed: false,
    startEnabled: true,
    endEnabled: false,
  );

  @override
  Future<WorldsSoloSnapshot> fetch() async => WorldsSoloSnapshot(
    players: [
      _player(101, 'Canyon', 'GEN', 'JUNGLE'),
      _player(102, 'ShowMaker', 'DK', 'MID'),
      _player(103, 'Kanavi', 'HLE', 'JUNGLE'),
      _player(104, 'Doran', 'T1', 'TOP'),
    ],
    solo: const SoloRankSnapshot(
      live: [
        LiveSoloPlayer(
          name: 'Canyon',
          teamCode: 'GEN',
          champion: '키아나',
          elapsedSeconds: 725,
          playerId: 101,
          platform: 'NA1',
        ),
        LiveSoloPlayer(
          name: 'ShowMaker',
          teamCode: 'DK',
          champion: '아지르',
          elapsedSeconds: 1868,
          playerId: 102,
          platform: 'NA1',
        ),
      ],
      finished: [
        FinishedSoloPlayer(
          name: 'Kanavi',
          teamCode: 'HLE',
          won: true,
          minutesAgo: 23,
          durationMinutes: 29,
          playerId: 103,
        ),
      ],
    ),
  );
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
SoloRankSource defaultSoloRankSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockSoloRankSource() : ApiSoloRankSource();

/// [HomeViewModel] 의 기본 응원 전송 소스. 목업 모드에선 서버 없이 받아 준다.
CheerSource defaultCheerSource({bool mocks = kHomeMocks}) =>
    mocks ? MockCheerSource() : ApiCheerSource();

/// [HomeViewModel] 의 기본 한줄평 소스. 백엔드 nar-back-repo#542 배포 후
/// `GET /api/mobile/ratings/recent` 를 쓴다.
class EmptySoloRankSource implements SoloRankSource {
  const EmptySoloRankSource();

  @override
  Future<SoloRankSnapshot> fetch() async =>
      const SoloRankSnapshot(live: [], finished: []);
}

/// 빈 한줄평 소스 — 홈 평점 섹션이 통째로 숨겨진다.
class MockSoloRankSource implements SoloRankSource {
  const MockSoloRankSource();

  static const List<LiveSoloPlayer> live = [
    LiveSoloPlayer(
      name: 'Faker',
      teamCode: 'T1',
      champion: '아리',
      elapsedSeconds: 1452,
      playerId: 1,
      cheerTotal: 1284,
    ),
    LiveSoloPlayer(
      name: 'Chovy',
      teamCode: 'GEN',
      champion: '신드라',
      elapsedSeconds: 698,
      playerId: 2,
      cheerTotal: 432,
    ),
    LiveSoloPlayer(
      name: 'Zeus',
      teamCode: 'HLE',
      champion: '그웬',
      elapsedSeconds: 422,
    ),
    LiveSoloPlayer(
      name: 'Keria',
      teamCode: 'T1',
      champion: '레나타 글라스크',
      elapsedSeconds: 135,
    ),
  ];

  static const List<FinishedSoloPlayer> finished = [
    FinishedSoloPlayer(
      name: 'Oner',
      teamCode: 'T1',
      won: true,
      minutesAgo: 12,
      durationMinutes: 32,
      cheerTotal: 871,
      playerId: 11,
    ),
    FinishedSoloPlayer(
      name: 'Ruler',
      teamCode: 'HLE',
      won: false,
      minutesAgo: 40,
      durationMinutes: 28,
      playerId: 12,
    ),
    FinishedSoloPlayer(
      name: 'Canyon',
      teamCode: 'GEN',
      won: true,
      minutesAgo: 63,
      durationMinutes: 35,
    ),
    FinishedSoloPlayer(
      name: 'Peyz',
      teamCode: 'KT',
      won: false,
      minutesAgo: 95,
      durationMinutes: 24,
    ),
    FinishedSoloPlayer(
      name: 'Doran',
      teamCode: 'DK',
      won: true,
      minutesAgo: 118,
      durationMinutes: 31,
    ),
    FinishedSoloPlayer(
      name: 'Gumayusi',
      teamCode: 'T1',
      won: false,
      minutesAgo: 140,
      durationMinutes: 27,
    ),
    FinishedSoloPlayer(
      name: 'Kiin',
      teamCode: 'GEN',
      won: true,
      minutesAgo: 167,
      durationMinutes: 33,
    ),
    FinishedSoloPlayer(
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
          LiveSoloPlayer(
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
