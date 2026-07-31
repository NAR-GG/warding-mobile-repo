/// 경기(matchId)의 세트별 게임 한 건.
///
/// `GET /api/mobile/matches/{matchId}/games` 응답 항목에 대응한다.
/// 세트 순서([gameOrder]) → [gameId] 해석에 쓴다.
/// 세트(게임)의 진행 상태.
/// "LIVE": 진행 중, "ENDED": 종료(데이터 있음), "SCHEDULED": 예정(데이터 없음).
class MatchGameStatus {
  static const String live = 'LIVE';
  static const String ended = 'ENDED';
  static const String scheduled = 'SCHEDULED';
}

class MatchGame {
  const MatchGame({
    required this.gameId,
    required this.gameOrder,
    this.status = MatchGameStatus.scheduled,
    this.vodUrl,
    this.winnerTeamCode,
  });

  final String gameId;

  /// 세트 순서 (1부터 시작).
  final int gameOrder;

  /// 세트 진행 상태 ("LIVE" | "ENDED" | "SCHEDULED"). 미지정 시 "SCHEDULED".
  final String status;

  /// 세트 다시보기 VOD URL. 없으면 null.
  final String? vodUrl;

  /// 세트를 이긴 팀의 teamCode. 세트가 끝나기 전엔 null.
  final String? winnerTeamCode;

  bool get isLive => status == MatchGameStatus.live;
  bool get isEnded => status == MatchGameStatus.ended;

  factory MatchGame.fromJson(Map<String, dynamic> json) {
    // gameId 는 문자열 또는 정수로 내려올 수 있어 둘 다 받는다.
    final rawId = json['gameId'];
    final gameId = rawId == null ? '' : rawId.toString();
    final order = json['gameOrder'] as int? ??
        json['setNumber'] as int? ??
        json['order'] as int? ??
        0;
    final rawStatus = json['status'];
    final status = rawStatus == null
        ? MatchGameStatus.scheduled
        : rawStatus.toString().toUpperCase();
    return MatchGame(
      gameId: gameId,
      gameOrder: order,
      status: status,
      vodUrl: json['vodUrl'] as String?,
      winnerTeamCode: json['winnerTeamCode'] as String?,
    );
  }
}
