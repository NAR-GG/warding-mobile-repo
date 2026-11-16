/// 캘린더가 어느 요일부터 시작하는지 — 마이페이지 설정값.
enum CalendarWeekStart {
  monday,
  sunday;

  /// [DateTime.weekday] 기준 값 (월=1 ... 일=7).
  int get dateTimeWeekday =>
      this == CalendarWeekStart.monday ? DateTime.monday : DateTime.sunday;

  /// [firstOfMonth]가 속한 주에서, 이 설정 기준 주 시작일까지 거슬러 올라갈 일수.
  /// 월간 그리드의 앞쪽 빈 칸 수로 쓰인다.
  int leadingDays(DateTime firstOfMonth) =>
      (firstOfMonth.weekday - dateTimeWeekday + 7) % 7;

  /// [month]의 월간 그리드가 차지하는 주(행) 수 — 4~6.
  ///
  /// 앞쪽 빈 칸([leadingDays])과 그 달 일수를 합쳐 7로 올림한다. 스켈레톤과
  /// 실제 그리드가 같은 행 수를 그려야 로딩이 끝나는 순간 줄이 늘거나 줄지
  /// 않으므로, 계산은 반드시 이 한 곳만 쓴다.
  int weekCount(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return ((leadingDays(firstOfMonth) + daysInMonth) / 7).ceil();
  }

  /// [mondayFirstLabels](월~일 순서 7개)를 이 설정 기준 순서로 회전한다.
  List<String> orderedWeekdayLabels(List<String> mondayFirstLabels) {
    assert(mondayFirstLabels.length == 7);
    if (this == CalendarWeekStart.monday) return mondayFirstLabels;
    return [mondayFirstLabels.last, ...mondayFirstLabels.take(6)];
  }

  /// 저장/전송용 문자열 — 'monday' / 'sunday'.
  String get storageValue => name;

  /// [storageValue]의 역변환. 알 수 없는 값이면 monday로 폴백.
  static CalendarWeekStart fromStorageValue(String? value) {
    return CalendarWeekStart.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CalendarWeekStart.monday,
    );
  }
}
