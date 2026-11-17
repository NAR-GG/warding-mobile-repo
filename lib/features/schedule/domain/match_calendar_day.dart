/// 월별 캘린더에서 '경기가 있는 하루'를 나타낸다.
///
/// `/api/mobile/schedules/calendar` 응답의 `dates` 항목 하나에 대응한다.
/// 그 날 경기 수와, 캘린더 칸 칩에 바로 쓸 가벼운 경기 목록([matches])을 담는다.
class MatchCalendarDay {
  const MatchCalendarDay({
    required this.date,
    required this.matchCount,
    required this.matches,
  });

  /// 경기가 있는 날짜 (시각은 0시).
  final DateTime date;

  /// 그 날 경기 수.
  final int matchCount;

  /// 캘린더 칸에 칩으로 표시할 경기 목록 (대진 코드·이름만 가진 경량 데이터).
  final List<CalendarMatchBrief> matches;

  factory MatchCalendarDay.fromJson(Map<String, dynamic> json) {
    return MatchCalendarDay(
      date: DateTime.parse(json['date'] as String),
      matchCount: json['matchCount'] as int? ?? 0,
      matches: (json['matches'] as List<dynamic>? ?? const [])
          .map((e) => CalendarMatchBrief.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 캘린더 칸 칩에 표시할 한 경기의 경량 정보.
///
/// 캘린더 마킹용이라 스코어·로고는 없고 대진 코드/이름만 담는다.
class CalendarMatchBrief {
  const CalendarMatchBrief({
    required this.matchId,
    required this.blueTeamCode,
    required this.redTeamCode,
    required this.blueTeamName,
    required this.redTeamName,
    required this.displayText,
  });

  final String matchId;

  /// 블루 팀(왼쪽) 코드. 예: 'T1'.
  final String blueTeamCode;

  /// 레드 팀(오른쪽) 코드. 예: 'GEN'.
  final String redTeamCode;

  final String blueTeamName;
  final String redTeamName;

  /// 서버가 만들어 주는 표시용 문구. 예: 'T1 vs GEN'.
  final String displayText;

  factory CalendarMatchBrief.fromJson(Map<String, dynamic> json) {
    return CalendarMatchBrief(
      matchId: json['matchId'] as String? ?? '',
      blueTeamCode: json['blueTeamCode'] as String? ?? '',
      redTeamCode: json['redTeamCode'] as String? ?? '',
      blueTeamName: json['blueTeamName'] as String? ?? '',
      redTeamName: json['redTeamName'] as String? ?? '',
      displayText: json['displayText'] as String? ?? '',
    );
  }
}
