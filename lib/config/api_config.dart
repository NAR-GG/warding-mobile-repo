class ApiConfig {
  ApiConfig._();

  static const String host = 'https://api.nar.kr';
  static const String apiBaseUrl = '$host/api';

  static const String kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';

  static String get kakaoLoginUrl => '$apiBaseUrl/auth/kakao';
}
