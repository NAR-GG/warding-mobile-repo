class ApiConfig {
  ApiConfig._();

  static const String host = 'https://api.nar.kr';
  static const String apiBaseUrl = '$host/api';

  static const String kakaoNativeAppKey = '838b3def5acdd1dfbbe6b14e301ba05a';

  /// 카카오 access token을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용).
  static String get kakaoLoginUrl => '$apiBaseUrl/auth/mobile/kakao';

  /// 온보딩용 리그 목록 조회 (인증 불필요).
  static String get onboardingLeaguesUrl =>
      '$apiBaseUrl/auth/onboarding/leagues';

  /// 온보딩용 LCK 팀 목록 조회 (인증 불필요).
  static String get onboardingTeamsUrl => '$apiBaseUrl/auth/onboarding/teams';

  /// 온보딩용 선수 목록 조회 (인증 불필요).
  /// [teamId] 를 주면 해당 팀 선수만 조회한다.
  static String onboardingPlayersUrl({required int year, int? teamId}) {
    final query = StringBuffer('year=$year');
    if (teamId != null) query.write('&teamId=$teamId');
    return '$apiBaseUrl/auth/onboarding/players?$query';
  }

  /// 온보딩 완료 — 로그인 사용자의 선호 리그·팀·선수 서버 저장 (인증 필요).
  static String get onboardingUrl => '$apiBaseUrl/auth/onboarding';

  /// 월별 경기 존재 날짜 조회 (달력 마킹용, 인증 불필요).
  /// [month] 형식은 'yyyy-MM' (예: '2026-04').
  static String scheduleCalendarUrl(String month) =>
      '$apiBaseUrl/schedule/calendar?month=$month';

  /// 특정 날짜의 경기 목록 조회 (인증 불필요).
  /// [date] 형식은 'yyyy-MM-dd' (예: '2026-04-01').
  static String scheduleByDateUrl(String date) =>
      '$apiBaseUrl/schedule?date=$date';
}
