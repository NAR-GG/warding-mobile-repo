import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../config/api_config.dart';

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.isOnboarded,
  });

  final String accessToken;
  final String refreshToken;
  final bool isOnboarded;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';

  final _storage = const FlutterSecureStorage();

  /// Opens the provider's OAuth login page in a secure browser session and
  /// waits for the backend to redirect back to [ApiConfig.callbackUrl].
  ///
  /// [registrationId] must be one of: google, kakao, naver.
  Future<AuthResult> signInWithProvider(String registrationId) async {
    final result = await FlutterWebAuth2.authenticate(
      url: ApiConfig.oauthAuthorizationUrl(registrationId),
      callbackUrlScheme: ApiConfig.callbackScheme,
    );

    final uri = Uri.parse(result);
    final accessToken = uri.queryParameters['accessToken'];
    final refreshToken = uri.queryParameters['refreshToken'];

    if (accessToken == null || refreshToken == null) {
      throw Exception('콜백 응답에 토큰이 없습니다: $result');
    }

    final isOnboarded = uri.queryParameters['isOnboarded'] == 'true';

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);

    return AuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      isOnboarded: isOnboarded,
    );
  }

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
