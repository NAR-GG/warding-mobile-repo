class ApiConfig {
  ApiConfig._();

  static const String host = 'https://api.nar.kr';
  static const String apiBaseUrl = '$host/api';

  static const String kakaoNativeAppKey = '838b3def5acdd1dfbbe6b14e301ba05a';

  static String get kakaoLoginUrl => '$apiBaseUrl/auth/kakao';

  /// 온보딩용 LCK 팀 목록 조회 (인증 불필요).
  static String get onboardingTeamsUrl => '$apiBaseUrl/auth/onboarding/teams';
}
