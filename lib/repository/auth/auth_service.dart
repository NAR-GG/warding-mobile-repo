import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../config/api_config.dart';

class AuthResult {
  const AuthResult({required this.jwt, required this.isOnboarded});

  final String jwt;
  final bool isOnboarded;
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _jwtKey = 'jwt';

  final _storage = const FlutterSecureStorage();

  /// 카카오 SDK로 로그인 → 받은 access token을 백엔드로 전달 → 자체 JWT 저장.
  Future<AuthResult> signInWithKakao() async {
    final OAuthToken token = await _loginWithKakao();
    return _exchangeWithBackend(token.accessToken);
  }

  Future<OAuthToken> _loginWithKakao() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } on PlatformException catch (error) {
        if (error.code == 'CANCELED') {
          throw const AuthCancelledException();
        }
        // 카카오톡에 연결된 카카오계정이 없는 등의 경우 → 계정 로그인으로 폴백
        return UserApi.instance.loginWithKakaoAccount();
      }
    }
    return UserApi.instance.loginWithKakaoAccount();
  }

  Future<AuthResult> _exchangeWithBackend(String kakaoAccessToken) async {
    final response = await http.post(
      Uri.parse(ApiConfig.kakaoLoginUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'accessToken': kakaoAccessToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '백엔드 로그인 실패 (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final jwt = (data['accessToken'] ?? data['jwt']) as String?;
    if (jwt == null) {
      throw Exception('백엔드 응답에 토큰이 없습니다: ${response.body}');
    }
    final isOnboarded = data['isOnboarded'] as bool? ?? false;

    await _storage.write(key: _jwtKey, value: jwt);
    return AuthResult(jwt: jwt, isOnboarded: isOnboarded);
  }

  Future<String?> get jwt => _storage.read(key: _jwtKey);

  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 세션이 이미 끊겼더라도 자체 토큰은 지움
    }
    await _storage.delete(key: _jwtKey);
  }
}
