import 'package:warding/features/subscription/domain/player_subscription.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_models.dart';

// 솔랭 조회 결과 모델. 소스가 돌려주고 규칙(solo_rank_rules)이 해석한다.
//
// `data/` 에 있었는데 규칙 파일이 이걸 참조해 domain → data 역방향이 됐다.
// 파싱 로직이 없는 순수 모델이라 domain 이 맞는 자리다.
class SoloRankSnapshot {
  const SoloRankSnapshot({required this.live, required this.finished});

  final List<LiveSoloPlayer> live;
  final List<FinishedSoloPlayer> finished;
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
