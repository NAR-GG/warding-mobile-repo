/// 경기 일정/리스트 화면의 필터(리그·팀) 옵션.
///
/// `/api/mobile/schedules/filters` 응답에 대응한다.
/// 팀 목록은 요청한 [defaultLeague](또는 query 의 league) 소속만 내려온다.
class ScheduleFilterOptions {
  const ScheduleFilterOptions({
    required this.defaultLeague,
    required this.leagues,
    required this.teams,
    this.seasonYears = const [],
  });

  /// 기본 선택 리그 코드. 예: 'LCK'.
  final String defaultLeague;

  /// 선택 가능한 리그 목록.
  final List<FilterLeague> leagues;

  /// 현재 리그의 팀 목록.
  final List<FilterTeam> teams;

  /// 서버가 리그 메타(`standings`·`alarm`·`iconUrl`)를 내려주는 버전인지.
  ///
  /// 구버전 서버는 이 필드가 아예 없다 — 그때는 "메타 없음"과 "칩 없음(null)"을
  /// 구분할 수 없으므로, 앱이 하드코딩 값으로 폴백해야 한다. `alarm` 은 서버가
  /// 항상 채우는 boolean 이라 이것으로 판별한다.
  bool get hasLeagueMeta => leagues.any((l) => l.alarm != null);

  /// 선택 가능한 시즌 **연도** 목록(오름차순, 중복 제거).
  ///
  /// 서버는 `seasons` 를 연도+스플릿 단위로 준다(`2026 Split 1/2/3`).
  /// 시즌 필터는 연도 단위라(`seasonYear` 파라미터·`fetchTree(year:)`)
  /// 연도만 뽑아 쓴다. 응답에 없으면 빈 목록 — 호출부가 폴백한다.
  final List<int> seasonYears;

  factory ScheduleFilterOptions.fromJson(Map<String, dynamic> json) {
    final years = <int>{
      for (final e in json['seasons'] as List<dynamic>? ?? const [])
        if (e is Map<String, dynamic> && e['year'] is num)
          (e['year'] as num).toInt(),
    }.toList()..sort();

    return ScheduleFilterOptions(
      defaultLeague: json['defaultLeague'] as String? ?? '',
      leagues: (json['leagues'] as List<dynamic>? ?? const [])
          .map((e) => FilterLeague.fromJson(e as Map<String, dynamic>))
          .toList(),
      teams: (json['teams'] as List<dynamic>? ?? const [])
          .map((e) => FilterTeam.fromJson(e as Map<String, dynamic>))
          .toList(),
      seasonYears: years,
    );
  }
}

/// 필터의 리그 옵션 한 개.
class FilterLeague {
  const FilterLeague({
    required this.code,
    required this.name,
    this.standings,
    this.alarm,
    this.iconUrl,
  });

  /// 리그 코드. 예: 'LCK'. API 요청 파라미터로 쓴다.
  final String code;

  /// 화면에 보일 리그 이름.
  final String name;

  /// 홈 순위표 칩. null=칩 없음 / false=점선 비활성 / true=선택 가능.
  final bool? standings;

  /// 경기 카드에 알림 벨을 띄우는 리그인지. null 이면 서버가 메타를 안 준 것
  /// (구버전 서버)이라 하드코딩 값으로 폴백한다.
  final bool? alarm;

  /// 리그 아이콘 PNG URL. null 이면 앱 번들 아이콘으로 폴백한다.
  final String? iconUrl;

  factory FilterLeague.fromJson(Map<String, dynamic> json) {
    final icon = json['iconUrl'] as String?;
    return FilterLeague(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      standings: json['standings'] as bool?,
      alarm: json['alarm'] as bool?,
      iconUrl: icon == null || icon.isEmpty ? null : icon,
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
