/// 경기 일정/리스트 화면의 필터(리그·팀) 옵션.
///
/// `/api/mobile/schedules/filters` 응답에 대응한다.
/// 팀 목록은 요청한 [defaultLeague](또는 query 의 league) 소속만 내려온다.
class ScheduleFilterOptions {
  const ScheduleFilterOptions({
    required this.defaultLeague,
    required this.leagues,
    required this.teams,
  });

  /// 기본 선택 리그 코드. 예: 'LCK'.
  final String defaultLeague;

  /// 선택 가능한 리그 목록.
  final List<FilterLeague> leagues;

  /// 현재 리그의 팀 목록.
  final List<FilterTeam> teams;

  factory ScheduleFilterOptions.fromJson(Map<String, dynamic> json) {
    return ScheduleFilterOptions(
      defaultLeague: json['defaultLeague'] as String? ?? '',
      leagues: (json['leagues'] as List<dynamic>? ?? const [])
          .map((e) => FilterLeague.fromJson(e as Map<String, dynamic>))
          .toList(),
      teams: (json['teams'] as List<dynamic>? ?? const [])
          .map((e) => FilterTeam.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 필터의 리그 옵션 한 개.
class FilterLeague {
  const FilterLeague({required this.code, required this.name});

  /// 리그 코드. 예: 'LCK'. API 요청 파라미터로 쓴다.
  final String code;

  /// 화면에 보일 리그 이름.
  final String name;

  factory FilterLeague.fromJson(Map<String, dynamic> json) {
    return FilterLeague(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// 필터의 팀 옵션 한 개.
class FilterTeam {
  const FilterTeam({
    required this.teamId,
    required this.teamName,
    required this.teamCode,
    required this.teamImageUrl,
  });

  /// 팀 ID. API 요청(teamId 파라미터)으로 쓴다.
  final int teamId;
  final String teamName;
  final String teamCode;
  final String teamImageUrl;

  factory FilterTeam.fromJson(Map<String, dynamic> json) {
    return FilterTeam(
      teamId: json['teamId'] as int? ?? 0,
      teamName: json['teamName'] as String? ?? '',
      teamCode: json['teamCode'] as String? ?? '',
      teamImageUrl: json['teamImageUrl'] as String? ?? '',
    );
  }
}
