/// 월별 캘린더에서 '경기가 있는 하루'를 나타낸다.
///
/// `/api/schedule/calendar` 응답의 `dates` 항목 하나에 대응한다.
/// 경기 수와 리그 목록만 제공하며, 개별 경기(대진 팀 등) 정보는 없다.
class MatchCalendarDay {
  const MatchCalendarDay({
    required this.date,
    required this.matchCount,
    required this.leagues,
  });

  /// 경기가 있는 날짜 (시각은 0시).
  final DateTime date;

  /// 그 날 경기 수.
  final int matchCount;

  /// 그 날 경기가 열리는 리그 목록 (예: ['LCK', 'LPL']).
  final List<String> leagues;

  factory MatchCalendarDay.fromJson(Map<String, dynamic> json) {
    return MatchCalendarDay(
      date: DateTime.parse(json['date'] as String),
      matchCount: json['matchCount'] as int,
      leagues: (json['leagues'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
