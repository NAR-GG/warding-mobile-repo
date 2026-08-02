import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import '../../config/secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../config/api_config.dart';
import '../../config/app_globals.dart';
import '../../l10n/app_strings.dart';
import '../../model/user_profile.dart';
import '../../screens/login/login_screen.dart';
import '../../util/sentry_logger.dart';
import '../device/device_repository.dart';

class AuthResult {
  const AuthResult({required this.jwt, required this.isOnboarded});

  final String jwt;
  final bool isOnboarded;
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

/// `PUT /api/auth/me` 가 409 를 반환할 때 — 다른 회원이 같은 닉네임 사용 중.
class NicknameConflictException implements Exception {
  const NicknameConflictException();

  @override
  String toString() => appStrings?.duplicateNickname ?? 'This nickname is already in use';
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _jwtKey = 'jwt';
  static const _refreshKey = 'refreshToken';

  final _storage = secureStorage;

  bool _googleInitialized = false;

  /// 카카오 SDK로 로그인 → 받은 access token을 백엔드로 전달 → 자체 JWT 저장.
  Future<AuthResult> signInWithKakao() async {
    final OAuthToken token;
    try {
      token = await _loginWithKakao();
    } on AuthCancelledException {
      rethrow;
    } catch (e) {
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'kakaoSdkLogin',
        reason: e.runtimeType.toString(),
        error: e,
      );
      rethrow;
    }
    return _exchangeWithBackend(ApiConfig.kakaoLoginUrl, token.accessToken);
  }

  /// 네이버 SDK로 로그인 → 받은 access token을 백엔드로 전달 → 자체 JWT 저장.
  Future<AuthResult> signInWithNaver() async {
    // SDK가 이전 로그인 세션을 캐싱해두면, 로그인 화면에서 다른 계정으로
    // 전환해도 logIn()이 새로 인증하지 않고 캐시된 토큰을 그대로 반환한다.
    // 매번 새 계정으로 제대로 인증되도록 시도 전에 기존 세션을 정리한다.
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {
      // 세션이 없어 로그아웃할 게 없어도 무시하고 로그인 진행.
    }

    final NaverLoginResult result;
    try {
      result = await FlutterNaverLogin.logIn();
    } catch (e) {
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'naverSdkLogin',
        reason: e.runtimeType.toString(),
        error: e,
      );
      rethrow;
    }
    debugPrint('[NAVER] status=${result.status} error=${result.errorMessage}');

    if (result.status != NaverLoginStatus.loggedIn) {
      // NaverLoginStatus에는 취소 전용 값이 없어 errorMessage로 취소를 구분한다.
      final message = result.errorMessage ?? '';
      if (message.toLowerCase().contains('cancel')) {
        throw const AuthCancelledException();
      }
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'naverSdkLogin',
        reason: 'status_${result.status.name}',
      );
      throw Exception('네이버 로그인 실패: $message');
    }

    // Android 앱-투-앱 인증은 logIn() 결과에 토큰이 비어 올 수 있어
    // SDK 저장소에서 한 번 더 조회한다.
    var token = result.accessToken;
    if (token == null || token.accessToken.isEmpty) {
      token = await FlutterNaverLogin.getCurrentAccessToken();
    }
    if (token.accessToken.isEmpty) {
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'naverSdkLogin',
        reason: 'empty_token',
      );
      throw Exception('네이버 로그인 응답에 access token이 없습니다');
    }

    return _exchangeWithBackend(ApiConfig.naverLoginUrl, token.accessToken);
  }

  /// 구글 SDK로 로그인 → 받은 idToken을 백엔드로 전달 → 자체 JWT 저장.
  Future<AuthResult> signInWithGoogle() async {
    // google_sign_in 7.x는 사용 전 한 번 initialize 해야 한다.
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: ApiConfig.googleServerClientId,
      );
      _googleInitialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'googleSdkLogin',
        reason: error.code.name,
        error: error,
      );
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'googleSdkLogin',
        reason: 'empty_idToken',
      );
      throw Exception('구글 로그인 응답에 idToken이 없습니다');
    }

    // 구글은 access token이 아닌 idToken을 백엔드가 검증한다.
    return _exchangeWithBackend(
      ApiConfig.googleLoginUrl,
      idToken,
      bodyKey: 'idToken',
    );
  }

  /// 애플 ID로 로그인 → 받은 identityToken을 백엔드로 전달 → 자체 JWT 저장.
  /// iOS 전용 (호출 측에서 Platform.isIOS 분기).
  Future<AuthResult> signInWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'appleSdkLogin',
        reason: error.code.name,
        error: error,
      );
      rethrow;
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'appleSdkLogin',
        reason: 'empty_identityToken',
      );
      throw Exception('애플 로그인 응답에 identityToken이 없습니다');
    }

    // 애플은 access token이 아닌 identityToken을 백엔드가 검증한다 (구글과 동일 방식).
    return _exchangeWithBackend(
      ApiConfig.appleLoginUrl,
      identityToken,
      bodyKey: 'idToken',
    );
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

  /// 소셜 토큰을 백엔드로 보내 자체 JWT를 교환하고 저장한다.
  /// 카카오·네이버는 access token, 구글·애플은 idToken을 보내므로 [bodyKey]로 구분한다.
  Future<AuthResult> _exchangeWithBackend(
    String loginUrl,
    String socialToken, {
    String bodyKey = 'accessToken',
  }) async {
    final response = await http.post(
      Uri.parse(loginUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({bodyKey: socialToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postLogin',
        reason: 'status_${response.statusCode}',
        extra: {
          'endpoint': loginUrl,
          'response': {'status': response.statusCode},
        },
      );
      throw Exception(
        '백엔드 로그인 실패 (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final jwt = (data['accessToken'] ?? data['jwt']) as String?;
    if (jwt == null) {
      SentryLogger.error(
        module: 'Logic',
        eventName: 'postLogin_noToken',
        reason: 'jwt_missing',
      );
      throw Exception('백엔드 응답에 토큰이 없습니다: ${response.body}');
    }
    final refreshToken =
        (data['refreshToken'] ?? data['refresh_token']) as String?;
    final isOnboarded = data['isOnboarded'] as bool? ?? false;

    await _storage.write(key: _jwtKey, value: jwt);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }

    // 로그인 성공 → Sentry에 사용자 ID 설정 + info 로그
    final memberId = data['memberId']?.toString();
    if (memberId != null) SentryLogger.setUser(memberId);
    SentryLogger.info(module: 'API', eventName: 'postLogin');

    return AuthResult(jwt: jwt, isOnboarded: isOnboarded);
  }

  Future<String?> get jwt => _storage.read(key: _jwtKey);

  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  /// 로그인 회원 정보를 조회한다 (`GET /api/auth/me`).
  /// 만료 시 [authorizedRequest] 가 토큰을 자동 갱신·재시도한다.
  Future<UserProfile> fetchMe() async {
    final response = await authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.meUrl),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('회원 정보 조회 실패 (${response.statusCode})');
    }
    return UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 로그인 회원의 닉네임(이름·태그)·응원 팀·프로필 이미지를 수정한다
  /// (`PUT /api/auth/me`). 닉네임이 다른 회원과 겹치면
  /// 409 → [NicknameConflictException].
  Future<UserProfile> updateProfile({
    required String name,
    required String tag,
    required int favoriteTeamId,
    String? profileImageUrl,
  }) async {
    final response = await authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.meUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'tag': tag,
          'favoriteTeamId': favoriteTeamId,
          'profileImageUrl': profileImageUrl,
        }),
      ),
    );
    if (response.statusCode == 409) {
      throw const NicknameConflictException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('프로필 수정 실패 (${response.statusCode})');
    }
    return UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 진행 중인 재발급 요청. 동시에 여러 API가 만료를 감지해도 1회만 호출한다.
  Future<String?>? _refreshing;

  /// Refresh Token으로 Access Token을 재발급해 저장한다.
  /// 성공하면 새 Access Token을, 실패(만료/없음)하면 null 을 반환한다.
  /// 동시 호출은 하나의 요청으로 합쳐 결과를 공유한다.
  Future<String?> refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = await refreshToken;
    if (refresh == null || refresh.isEmpty) {
      debugPrint('[Auth] refreshToken 없음 — 재발급 불가 (재로그인 필요)');
      return null;
    }
    try {
      debugPrint('[Auth] 재발급 요청 (query 방식)');
      // 백엔드 명세상 refreshToken 은 query 파라미터, body 는 없다.
      final response = await http.post(
        Uri.parse(ApiConfig.refreshUrl(refresh)),
        headers: const {'Content-Type': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[Auth] 토큰 재발급 실패 (${response.statusCode}): '
            '${response.body}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newJwt = (data['accessToken'] ?? data['jwt']) as String?;
      final newRefresh =
          (data['refreshToken'] ?? data['refresh_token']) as String?;
      if (newJwt != null) await _storage.write(key: _jwtKey, value: newJwt);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _storage.write(key: _refreshKey, value: newRefresh);
      }
      debugPrint('[Auth] 토큰 재발급 성공');
      return newJwt;
    } catch (e) {
      debugPrint('[Auth] 토큰 재발급 에러: $e');
      return null;
    }
  }

  /// 인증이 필요한 요청을 보낸다. 응답이 만료를 의미하면(401, 또는 로그인
  /// 페이지로 302 리다이렉트해 HTML 이 오면) Refresh Token으로 Access Token을
  /// 갱신한 뒤 1회 재시도한다.
  ///
  /// [send] 는 현재 Access Token을 받아 실제 HTTP 요청을 수행하는 콜백이다.
  Future<http.Response> authorizedRequest(
    Future<http.Response> Function(String accessToken) send,
  ) async {
    final token = await jwt;
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다 (토큰 없음)');
    }
    var response = await send(token);
    if (_isAuthExpired(response)) {
      debugPrint('[Auth] 인증 만료 감지 → 토큰 재발급 시도');
      final newToken = await refreshAccessToken();
      if (newToken != null) {
        response = await send(newToken);
      } else {
        // Refresh Token도 만료/무효화된 상태 — 더 이상 재시도해도 로그인
        // 상태를 복구할 수 없으므로 세션을 정리하고 로그인 화면으로 보낸다.
        await _forceLogout();
      }
    }
    return response;
  }

  /// 재발급까지 실패했을 때(리프레시 토큰도 만료) 로컬 세션을 정리하고
  /// 로그인 화면으로 되돌린다. 동시에 여러 API가 감지해도 1회만 수행한다.
  bool _forcingLogout = false;

  Future<void> _forceLogout() async {
    if (_forcingLogout) return;
    _forcingLogout = true;
    debugPrint('[Auth] 세션 만료 → 자동 로그아웃');
    try {
      await _storage.delete(key: _jwtKey);
      await _storage.delete(key: _refreshKey);
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      _forcingLogout = false;
    }
  }

  /// 응답이 '인증 만료'를 의미하는지. 백엔드가 만료 시 로그인 페이지(HTML)로
  /// 302 리다이렉트하므로 상태코드와 Content-Type 으로 함께 판별한다.
  bool _isAuthExpired(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 302) return true;
    final contentType = response.headers['content-type'] ?? '';
    return contentType.contains('text/html');
  }

  /// 회원 탈퇴 (`DELETE /api/auth/me`). 서버가 계정과 연관 데이터를 모두
  /// 삭제하므로, 성공하면 소셜 SDK 세션과 로컬 토큰만 정리한다
  /// (기기 비활성화는 서버 cascade 삭제에 이미 포함).
  Future<void> withdraw() async {
    final response = await authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.meUrl),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('회원 탈퇴 실패 (${response.statusCode}): ${response.body}');
    }
    await signOut(deactivateDevice: false);
  }

  Future<void> signOut({bool deactivateDevice = true}) async {
    // JWT 가 아직 살아있을 때 FCM 기기를 먼저 비활성화한다.
    if (deactivateDevice) {
      try {
        await DeviceRepository.instance.deactivateDevice();
      } catch (_) {
        // 기기 비활성화 실패가 로그아웃을 막지 않도록 무시한다.
      }
    }
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 세션이 이미 끊겼더라도 자체 토큰은 지움
    }
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {
      // 네이버 세션이 이미 끊겼더라도 자체 토큰은 지움
    }
    try {
      if (_googleInitialized) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // 구글 세션이 이미 끊겼더라도 자체 토큰은 지움
    }
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _refreshKey);
    SentryLogger.clearUser();
  }
}
