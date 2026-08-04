/// 실시간 경기 Live Activity 의 진행 상태.
///
/// iOS 쪽 `MatchLivePhase` 와 [wireValue] 문자열이 일치해야 한다.
enum LiveMatchPhase {
  /// 세트 진행 중 — LIVE 배지가 깜빡인다.
  playing('playing'),

  /// 세트 종료 (다음 세트 대기).
  setEnded('setEnded'),

  /// 경기 전체 종료.
  matchEnded('matchEnded');

  const LiveMatchPhase(this.wireValue);

  /// 네이티브로 넘기는 문자열 값.
  final String wireValue;
}

/// Live Activity 를 시작할 때 한 번만 넘기는 정적 정보.
///
/// 팀 로고는 확장에서 네트워크를 못 쓰므로, 앱이 미리 내려받은
/// PNG 바이트를 base64 로 넘겨 App Group 에 캐싱시킨다.
class LiveMatchActivityConfig {
  const LiveMatchActivityConfig({
    required this.matchId,
    required this.teamAName,
    required this.teamACode,
    required this.teamBName,
    required this.teamBCode,
    this.leagueName = '',
    this.teamALogoBase64,
    this.teamBLogoBase64,
    this.favoriteTeamCode,
  });

  final String matchId;

  /// 왼쪽 팀.
  final String teamAName;
  final String teamACode;

  /// 오른쪽 팀.
  final String teamBName;
  final String teamBCode;

  /// 상단 좌측에 표시할 리그명 (예: 'LCK').
  final String leagueName;

  /// 팀 로고 PNG 의 base64. 없으면 로고 없이 박스만 표시된다.
  final String? teamALogoBase64;
  final String? teamBLogoBase64;

  /// 사용자가 응원하는 팀 코드. 세트 종료 화면에서 해당 팀 로고에 하트를 붙인다.
  final String? favoriteTeamCode;

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'teamAName': teamAName,
        'teamACode': teamACode,
        'teamBName': teamBName,
        'teamBCode': teamBCode,
        'leagueName': leagueName,
        'teamALogoBase64': teamALogoBase64,
        'teamBLogoBase64': teamBLogoBase64,
        'favoriteTeamCode': favoriteTeamCode,
      };
}

/// Live Activity 의 갱신 가능한 상태값.
class LiveMatchActivityState {
  const LiveMatchActivityState({
    required this.phase,
    required this.setNumber,
    required this.scoreA,
    required this.scoreB,
    this.statusLabel = '',
    this.winnerTeamCode,
  });

  final LiveMatchPhase phase;

  /// 현재 세트 번호 (1부터).
  final int setNumber;

  /// 왼쪽/오른쪽 팀의 세트 스코어.
  final int scoreA;
  final int scoreB;

  /// 시각 대신 보여줄 보조 라벨 (예: '다음 세트 준비 중').
  final String statusLabel;

  /// 경기 종료 시 승리 팀 코드.
  final String? winnerTeamCode;

  Map<String, dynamic> toMap() => {
        'phase': phase.wireValue,
        'setNumber': setNumber,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'statusLabel': statusLabel,
        'winnerTeamCode': winnerTeamCode,
      };

  LiveMatchActivityState copyWith({
    LiveMatchPhase? phase,
    int? setNumber,
    int? scoreA,
    int? scoreB,
    String? statusLabel,
    String? winnerTeamCode,
  }) {
    return LiveMatchActivityState(
      phase: phase ?? this.phase,
      setNumber: setNumber ?? this.setNumber,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      statusLabel: statusLabel ?? this.statusLabel,
      winnerTeamCode: winnerTeamCode ?? this.winnerTeamCode,
    );
  }
}
