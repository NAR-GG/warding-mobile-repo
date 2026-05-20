class ApiConfig {
  ApiConfig._();

  static const String host = 'https://api.nar.kr';
  static const String apiBaseUrl = '$host/api';

  static const String kakaoNativeAppKey = '838b3def5acdd1dfbbe6b14e301ba05a';

  static String get kakaoLoginUrl => '$apiBaseUrl/auth/kakao';

  /// 온보딩용 LCK 팀 목록 조회 (인증 불필요).
  static String get onboardingTeamsUrl => '$apiBaseUrl/auth/onboarding/teams';

  /// 월별 경기 존재 날짜 조회 (달력 마킹용, 인증 불필요).
  /// [month] 형식은 'yyyy-MM' (예: '2026-04').
  static String scheduleCalendarUrl(String month) =>
      '$apiBaseUrl/schedule/calendar?month=$month';

  /// 특정 날짜의 경기 목록 조회 (인증 불필요).
  /// [date] 형식은 'yyyy-MM-dd' (예: '2026-04-01').
  static String scheduleByDateUrl(String date) =>
      '$apiBaseUrl/schedule?date=$date';
}
