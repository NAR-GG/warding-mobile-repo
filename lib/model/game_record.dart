/// 종료 후 CSV 적재분 게임 기록. `GET /api/games/{recordGameId}/record` 응답.
///
/// 라이브 챔피언 픽 API(`match_champion_pick.dart`)에는 없는 와드 설치·파괴
/// 등 세부 스탯을 담는다. [MatchGame.recordGameId] 로 조회하며, 그 값이
/// null 이면(CSV 미적재) 이 API 자체를 부르지 않는다.
class GameRecord {
  const GameRecord({required this.players});

  final List<PlayerRecord> players;

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    return GameRecord(
      players: (json['players'] as List<dynamic>? ?? const [])
          .map((e) => PlayerRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// [side]("Blue"|"Red", 대소문자 무시) 팀 5명의 와드 설치·파괴 합산.
  (int placed, int killed) wardsForSide(String side) {
    var placed = 0;
    var killed = 0;
    for (final p in players) {
      if (p.side.toLowerCase() != side.toLowerCase()) continue;
      placed += p.wardsPlaced;
      killed += p.wardsKilled;
    }
    return (placed, killed);
  }
}

/// 선수 한 명의 기록(CSV 적재분). 지금은 와드 설치·파괴만 쓴다 — 필요해지면
/// damageToChampions 등 나머지 필드도 같은 방식으로 추가할 수 있다.
class PlayerRecord {
  const PlayerRecord({
    required this.side,
    this.wardsPlaced = 0,
    this.wardsKilled = 0,
  });

  /// "Blue" | "Red".
  final String side;
  final int wardsPlaced;
  final int wardsKilled;

  factory PlayerRecord.fromJson(Map<String, dynamic> json) {
    return PlayerRecord(
      side: json['side'] as String? ?? '',
      wardsPlaced: json['wardsPlaced'] as int? ?? 0,
      wardsKilled: json['wardsKilled'] as int? ?? 0,
    );
  }
}
