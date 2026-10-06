/// 월즈(롤드컵) 순위표 — 스위스 스테이지 전적 버킷 + 토너먼트 대진.
///
/// 리그 테이블([StandingsResult])과 형식이 달라 별도 모델로 둔다. 백엔드가
/// 아직 월즈를 지원하지 않아(`StandingsRepository.fetchStandings` WORLDS 분기)
/// 지금은 목업([worldsStandingsMock])만 존재한다.
class WorldsStandings {
  const WorldsStandings({required this.bracket, required this.knockout});

  /// 스위스 스테이지 전적별 버킷(3-0 ~ 0-3), 진출/탈락 확정 순.
  final List<WorldsBracketRow> bracket;

  /// 토너먼트 대진 — 8강 → 4강 → 결승 순.
  final List<WorldsKnockoutRound> knockout;
}

/// 스위스 스테이지에서 같은 전적(예: "3-1")으로 묶인 팀들 한 줄.
class WorldsBracketRow {
  const WorldsBracketRow({
    required this.record,
    required this.teamCodes,
    required this.advanced,
  });

  /// "3-0", "2-3" 같은 승-패 표기.
  final String record;

  final List<String> teamCodes;

  /// 3승(진출) 또는 3패(탈락) 확정 여부.
  final bool advanced;
}

/// 토너먼트 한 라운드(8강/4강/결승) 한 묶음.
class WorldsKnockoutRound {
  const WorldsKnockoutRound({required this.name, required this.matches});

  final String name;
  final List<WorldsMatch> matches;
}

/// 토너먼트 매치 진행 상태 — mockup.html `state()` 참고(완료/오늘/예정).
enum WorldsMatchStatus { done, today, upcoming }

/// 토너먼트 매치 한 경기(두 팀). [isFinal]이면 카드 테두리를 브랜드 그라디언트로
/// 강조하고, [status]가 [WorldsMatchStatus.today]면 주황 테두리 + 경기 시각을
/// 보여준다(mockup.html `.node.today`/`.node.final`).
class WorldsMatch {
  const WorldsMatch({
    required this.teamA,
    required this.teamB,
    this.status = WorldsMatchStatus.done,
    this.todayTime,
    this.isFinal = false,
  });

  final WorldsMatchTeam teamA;
  final WorldsMatchTeam teamB;
  final WorldsMatchStatus status;

  /// "오늘 16:00" 처럼 보여줄 시각 문자열. [status]가 today일 때만 쓴다.
  final String? todayTime;

  /// 결승전인지 — 카드 테두리를 브랜드 그라디언트로 그린다.
  final bool isFinal;
}

/// 토너먼트 매치의 팀 한쪽 — 아직 확정 안 됐으면 [teamCode]가 null(TBD).
class WorldsMatchTeam {
  const WorldsMatchTeam({
    this.teamCode,
    this.teamName,
    this.imageUrl,
    this.gameWins,
    this.won,
  });

  final String? teamCode;
  final String? teamName;

  /// 응답이 준 로고 URL. 국가대표 국기처럼 팀 로고 사전(온보딩 팀 목록)에
  /// 없는 팀을 위해 쓴다 — 사전에 코드가 있으면 사전 값이 이긴다.
  final String? imageUrl;

  /// 이 매치에서 딴 세트 수. 경기 전이면 null.
  final int? gameWins;

  /// 이 매치의 승자인지. 경기 전이면 null.
  final bool? won;

  bool get isTbd => teamCode == null;
}
