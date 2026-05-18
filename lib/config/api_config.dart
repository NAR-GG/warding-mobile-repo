class ApiConfig {
  ApiConfig._();

  static const String host = 'https://api.nar.kr';
  static const String apiBaseUrl = '$host/api';

  static const String callbackScheme = 'warding';
  static const String callbackUrl = '$callbackScheme://login-callback';

  static String oauthAuthorizationUrl(String registrationId) =>
      '$host/oauth2/authorization/$registrationId';
}
