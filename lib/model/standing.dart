/// 리그 순위표 조회 결과 (`GET /api/standings`).
class StandingsResult {
  const StandingsResult({
    required this.league,
    required this.supported,
    this.reason,
    required this.scopeLabel,
    required this.groups,
  });

  final String league;
  final bool supported;
  final String? reason;
  final String scopeLabel;
  final List<StandingGroup> groups;

  factory StandingsResult.fromJson(Map<String, dynamic> json) {
    return StandingsResult(
      league: json['league'] as String? ?? '',
      supported: json['supported'] as bool? ?? false,
      reason: json['reason'] as String?,
      scopeLabel: json['scopeLabel'] as String? ?? '',
      groups: (json['groups'] as List<dynamic>? ?? const [])
          .map((e) => StandingGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
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
