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
/// 팀 로고는 확장에서 네트워크를 못 쓰므로 앱이 App Group 에 미리
/// `<팀코드>.png` 로 캐싱해 두고([LiveActivityLogoPrefetcher]), 네이티브가
/// 그 파일을 찾아 attributes 에 담는다. 그래서 여기엔 이미지가 없다.
class LiveMatchActivityConfig {
  const LiveMatchActivityConfig({
    required this.matchId,
    required this.teamAName,
    required this.teamACode,
    required this.teamBName,
    required this.teamBCode,
    this.leagueName = '',
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

  /// 사용자가 응원하는 팀 코드. 세트 종료 화면에서 해당 팀 로고에 하트를 붙인다.
  final String? favoriteTeamCode;

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'teamAName': teamAName,
        'teamACode': teamACode,
        'teamBName': teamBName,
        'teamBCode': teamBCode,
        'leagueName': leagueName,
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
