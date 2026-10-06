import 'worlds_standings.dart';

/// 리그 순위표 조회 결과 (`GET /api/standings`).
class StandingsResult {
  const StandingsResult({
    required this.league,
    required this.supported,
    this.reason,
    required this.scopeLabel,
    required this.groups,
    this.bracket,
  });

  final String league;
  final bool supported;
  final String? reason;
  final String scopeLabel;
  final List<StandingGroup> groups;

  /// 토너먼트 대진(스위스 버킷 + 녹아웃 라운드). 서버가 `bracket` 을 줄 때만
  /// 채워진다 — 아직 안 주므로 지금은 항상 null 이다(warding-docs
  /// `features/home/spec.md` "요청: 토너먼트 대진 응답" 참고).
  final StandingsBracket? bracket;

  /// 리그 테이블이 아니라 대진으로 그려야 하는 응답인지 — **`bracket` 이
  /// 실려 왔는지로만 판단한다.**
  ///
  /// `reason` 으로 판단하지 않는다. 백엔드의 `BRACKET_ONLY` 는 포맷 신호가
  /// 아니라 `StandingsService.SCOPES`(현재 LCK·ASIAN_GAMES·DEMACIA_CUP)에
  /// 없는 리그에 주는 기본값이다 — 즉 "스위스·토너먼트라서"가 아니라
  /// "아직 등록 안 된 리그라서" 붙는다. 데이터의 존재 자체를 신호로 삼으면
  /// 백엔드가 reason 체계를 바꿔도 앱이 흔들리지 않는다.
  bool get hasBracket => bracket?.isNotEmpty == true;

  factory StandingsResult.fromJson(Map<String, dynamic> json) {
    final bracketJson = json['bracket'];
    return StandingsResult(
      league: json['league'] as String? ?? '',
      supported: json['supported'] as bool? ?? false,
      reason: json['reason'] as String?,
      scopeLabel: json['scopeLabel'] as String? ?? '',
      groups: (json['groups'] as List<dynamic>? ?? const [])
          .map((e) => StandingGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      bracket: bracketJson is Map<String, dynamic>
          ? StandingsBracket.fromJson(bracketJson)
          : null,
    );
  }
}

/// 순위표 그룹 한 덩이(예: '레전드 그룹').
class StandingGroup {
  const StandingGroup({required this.name, required this.rows});

  final String name;
  final List<StandingRow> rows;

  factory StandingGroup.fromJson(Map<String, dynamic> json) {
    return StandingGroup(
      name: json['name'] as String? ?? '',
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 순위표 한 행(팀 한 개).
class StandingRow {
  const StandingRow({
    required this.rank,
    required this.teamCode,
    required this.teamName,
    this.imageUrl,
    required this.wins,
    required this.losses,
    required this.setDiff,
  });

  final int rank;
  final String teamCode;
  final String teamName;
  final String? imageUrl;
  final int wins;
  final int losses;
  final int setDiff;

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    return StandingRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamCode: json['teamCode'] as String? ?? '',
      teamName: json['teamName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      setDiff: (json['setDiff'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `/api/standings` 응답의 `bracket` — 스위스 전적 버킷 + 녹아웃 라운드.
///
/// 월즈용으로 먼저 만든 [WorldsStandings] 와 같은 모양이라, 받은 뒤
/// [toWorldsStandings] 로 바꿔 **이미 구현된 대진 UI를 그대로 재사용**한다
/// (`_WorldsStandingsCard`). 월즈 전용 목업 모델과 서버 응답 모델을 하나로
/// 합치지 않은 건, 목업 쪽은 `kHomeMocks` 게이트 뒤에 남겨 둬야 하기 때문이다.
class StandingsBracket {
  const StandingsBracket({required this.swiss, required this.rounds});

  final List<StandingsBracketRow> swiss;
  final List<StandingsBracketRound> rounds;

  bool get isNotEmpty => swiss.isNotEmpty || rounds.isNotEmpty;

  factory StandingsBracket.fromJson(Map<String, dynamic> json) {
    return StandingsBracket(
      swiss: (json['swiss'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StandingsBracketRow.fromJson)
          .toList(),
      rounds: (json['rounds'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StandingsBracketRound.fromJson)
          .toList(),
    );
  }

  /// 대진 UI([WorldsStandings])가 쓰는 모양으로 변환한다.
  WorldsStandings toWorldsStandings() => WorldsStandings(
    bracket: [for (final r in swiss) r.toWorldsRow()],
    knockout: [for (final r in rounds) r.toWorldsRound()],
  );
}

/// 스위스 전적 버킷 한 줄("3-0" 으로 묶인 팀들).
class StandingsBracketRow {
  const StandingsBracketRow({
    required this.record,
    required this.teamCodes,
    required this.advanced,
  });

  final String record;
  final List<String> teamCodes;
  final bool advanced;

  factory StandingsBracketRow.fromJson(Map<String, dynamic> json) {
    return StandingsBracketRow(
      record: json['record'] as String? ?? '',
      teamCodes: [
        for (final c in (json['teamCodes'] as List<dynamic>? ?? const []))
          if (c is String) c,
      ],
      advanced: json['advanced'] as bool? ?? false,
    );
  }

  WorldsBracketRow toWorldsRow() => WorldsBracketRow(
    record: record,
    teamCodes: teamCodes,
    advanced: advanced,
  );
}

/// 녹아웃 한 라운드(8강·4강·결승).
class StandingsBracketRound {
  const StandingsBracketRound({required this.name, required this.matches});

  final String name;
  final List<StandingsBracketMatch> matches;

  factory StandingsBracketRound.fromJson(Map<String, dynamic> json) {
    return StandingsBracketRound(
      name: json['name'] as String? ?? '',
      matches: (json['matches'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StandingsBracketMatch.fromJson)
          .toList(),
    );
  }

  WorldsKnockoutRound toWorldsRound() => WorldsKnockoutRound(
    name: name,
    matches: [for (final m in matches) m.toWorldsMatch()],
  );
}

/// 녹아웃 매치 한 경기.
class StandingsBracketMatch {
  const StandingsBracketMatch({
    required this.teamA,
    required this.teamB,
    required this.status,
    this.matchId,
    this.scheduledTime,
    this.isFinal = false,
  });

  final StandingsBracketTeam teamA;
  final StandingsBracketTeam teamB;

  /// `done` / `live` / `upcoming`. 모르는 값은 `upcoming` 으로 본다.
  final String status;

  /// 대진 카드 → 경기 상세 이동용. 없으면 카드를 눌러도 아무 일도 안 한다.
  final String? matchId;

  /// ISO8601 경기 시각. 진행 중·예정 카드에 "16:00" 으로 보여준다.
  final DateTime? scheduledTime;

  final bool isFinal;

  factory StandingsBracketMatch.fromJson(Map<String, dynamic> json) {
    final raw = json['scheduledTime'] as String?;
    return StandingsBracketMatch(
      teamA: StandingsBracketTeam.fromJson(
        json['teamA'] as Map<String, dynamic>? ?? const {},
      ),
      teamB: StandingsBracketTeam.fromJson(
        json['teamB'] as Map<String, dynamic>? ?? const {},
      ),
      status: json['status'] as String? ?? 'upcoming',
      matchId: json['matchId']?.toString(),
      scheduledTime: raw == null ? null : DateTime.tryParse(raw),
      isFinal: json['isFinal'] as bool? ?? false,
    );
  }

  WorldsMatchStatus get _status => switch (status) {
    'done' => WorldsMatchStatus.done,
    'live' => WorldsMatchStatus.today,
    _ => WorldsMatchStatus.upcoming,
  };

  WorldsMatch toWorldsMatch() {
    final t = scheduledTime?.toLocal();
    return WorldsMatch(
      teamA: teamA.toWorldsTeam(),
      teamB: teamB.toWorldsTeam(),
      status: _status,
      // 진행 중 카드만 스코어 자리에 시각을 대신 보여준다(월즈 카드 규칙).
      todayTime: _status == WorldsMatchStatus.today && t != null
          ? '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}'
          : null,
      isFinal: isFinal,
    );
  }
}

/// 녹아웃 매치의 팀 한쪽. 아직 안 정해졌으면 [teamCode] 가 null(TBD).
class StandingsBracketTeam {
  const StandingsBracketTeam({
    this.teamCode,
    this.teamName,
    this.imageUrl,
    this.gameWins,
    this.won,
  });

  final String? teamCode;
  final String? teamName;

  /// 국가대표 국기처럼 팀 로고 사전에 없는 이미지. 사전에 코드가 없을 때만 쓴다.
  final String? imageUrl;

  final int? gameWins;
  final bool? won;

  factory StandingsBracketTeam.fromJson(Map<String, dynamic> json) {
    final code = json['teamCode'] as String?;
    return StandingsBracketTeam(
      teamCode: (code == null || code.isEmpty) ? null : code,
      teamName: json['teamName'] as String?,
      imageUrl: json['imageUrl'] as String?,
      gameWins: (json['gameWins'] as num?)?.toInt(),
      won: json['won'] as bool?,
    );
  }

  WorldsMatchTeam toWorldsTeam() => WorldsMatchTeam(
    teamCode: teamCode,
    teamName: teamName,
    imageUrl: imageUrl,
    gameWins: gameWins,
    won: won,
  );
}
