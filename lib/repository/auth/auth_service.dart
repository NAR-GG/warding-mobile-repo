import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import '../../config/secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../util/api_client.dart' as http;
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

/// [AuthService.refreshAccessToken] 의 결과. 실패를 두 갈래로 구분한다 —
/// 서버가 401 로 토큰 무효를 확정했을 때만 로그아웃 대상이고,
/// 일시 장애(타임아웃·네트워크·5xx·429)는 이번 요청만 실패시켜야 한다.
class RefreshResult {
  /// 재발급 성공 — [token] 은 새 Access Token.
  const RefreshResult.success(String this.token) : tokenInvalid = false;

  /// 리프레시 토큰 무효/만료를 서버가 401 로 확정 — 재로그인만이 답이다.
  const RefreshResult.invalid()
      : token = null,
        tokenInvalid = true;

  /// 일시 장애 — 토큰은 아직 살아 있을 수 있으므로 로그아웃하면 안 된다.
  const RefreshResult.transient()
      : token = null,
        tokenInvalid = false;

  final String? token;
  final bool tokenInvalid;
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

  /// [jwt] 인메모리 캐시. Keychain/Keystore 는 플랫폼 채널을 타는 I/O라, 인증
  /// 요청마다(그리고 경기 카드 하나당 한 번씩) 매번 새로 읽으면 그 비용이
  /// 그대로 쌓인다. 로그인·재발급·로그아웃 시점에만 갱신하면 되므로 캐싱해도
  /// 안전하다.
  String? _cachedJwt;
  bool _jwtCached = false;

  void _setCachedJwt(String? value) {
    _cachedJwt = value;
    _jwtCached = true;
    // 로그인·로그아웃·강제 로그아웃이 모두 이 지점을 지난다. 계정이 바뀌었는데
    // 이전 사용자의 프로필이 남아 있으면 안 되므로 여기서 함께 버린다.
    _invalidateMeCache();
  }

  /// 테스트 전용 — 인메모리 캐시를 지워 다음 [jwt] 읽기가 storage 를 다시 보게
  /// 한다. `AuthService.instance` 는 테스트 파일 전체가 공유하는 싱글턴이라,
  /// `FlutterSecureStorage.setMockInitialValues` 로 storage 를 직접 갈아끼우는
  /// 테스트라면 `setUp` 에서 같이 호출해야 캐시가 이전 테스트 값으로 남지 않는다.
  @visibleForTesting
  void resetJwtCacheForTesting() {
    _cachedJwt = null;
    _jwtCached = false;
  }

  /// 테스트 전용 — 진행 중인 재발급 요청을 잊는다.
  ///
  /// [refreshAccessToken] 은 동시 호출을 하나로 합치므로, 앞 테스트가 남긴
  /// future 가 그대로 살아 있으면 다음 테스트가 그 결과를 물려받는다.
  @visibleForTesting
  void resetRefreshForTesting() => _refreshing = null;

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

    // 접근성이 갈린 잔여 항목 때문에 write 가 -25299(duplicate)로 튕기면
    // 로그인은 성공했는데 토큰이 저장되지 않아 '로그인이 안 되는' 것처럼 보인다
    // (Sentry WARDING-APP-FLUTTER-12/10/W/V/11/R). 지우고 다시 쓴다.
    await writeWithDuplicateRecovery(key: _jwtKey, value: jwt);
    _setCachedJwt(jwt);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await writeWithDuplicateRecovery(key: _refreshKey, value: refreshToken);
    } else {
      // 응답에 리프레시 토큰이 없으면 이전 세션의 것을 반드시 지운다.
      //
      // 그냥 두면 새로 받은 access token 과 남의(또는 옛) refresh token 이
      // 짝이 안 맞는 채로 남는다. 계정을 바꿔 로그인한 경우가 특히 그런데,
      // 다음 재발급에서 서버가 그 토큰을 401 로 거절하면 방금 로그인한
      // 사용자가 곧바로 로그아웃된다 — 원인이 로그인 시점에 심긴 탓에
      // 재현도 추적도 어렵다.
      debugPrint('[Auth] 로그인 응답에 refreshToken 없음 — 이전 토큰 제거');
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'loginWithoutRefreshToken',
        reason: 'refresh_token_missing',
      );
      try {
        await _storage.delete(key: _refreshKey);
      } catch (e) {
        debugPrint('[Auth] 이전 refreshToken 삭제 실패: $e');
      }
    }

    // 로그인 성공 → Sentry에 사용자 ID 설정 + info 로그
    final memberId = data['memberId']?.toString();
    if (memberId != null) SentryLogger.setUser(memberId);
    SentryLogger.info(module: 'API', eventName: 'postLogin');

    return AuthResult(jwt: jwt, isOnboarded: isOnboarded);
  }

  /// 저장된 Access Token.
  ///
  /// 기기 잠금 등으로 Keychain 을 **읽지 못하면**
  /// [SecureStorageUnavailableException] 을 던진다 — null 로 접으면
  /// 호출부가 '비로그인'으로 오해해 로그인 화면으로 보내버린다
  /// (Sentry WARDING-APP-FLUTTER-C, 491명 로그아웃의 경로).
  Future<String?> get jwt async {
    if (_jwtCached) return _cachedJwt;
    final value = await readOrThrowIfUnavailable(_jwtKey);
    // null 은 캐싱하지 않는다 — 기기 잠금 중 Keychain 접근성 불일치 등으로
    // 진짜 로그인 상태인데도 일시적으로 null 이 읽히는 경우가 있었다(과거
    // -25308 오탐 로그아웃 사고, splash_screen.dart 참고). 캐싱해버리면 그
    // 한 번의 헛읽기가 앱 재시작 전까지 영구히 '로그아웃'으로 굳는다.
    // 로그인·재발급·명시적 로그아웃(_setCachedJwt 직접 호출)은 그 자체가
    // 신뢰할 수 있는 값이라 정상적으로 캐싱된다.
    if (value != null) _setCachedJwt(value);
    return value;
  }

  /// 저장된 Refresh Token. 잠금 등으로 읽지 못하면
  /// [SecureStorageUnavailableException] — [_doRefresh] 가 이를 일시 장애로
  /// 처리한다. null 로 접으면 '리프레시 토큰 없음'이 되어 강제 로그아웃된다.
  Future<String?> get refreshToken => readOrThrowIfUnavailable(_refreshKey);

  /// 회원 정보 캐시. 경기일정·마이페이지·평점상세·프로필수정이 각자 이걸
  /// 부르는데, 마이페이지 계열은 화면 셋(마이페이지·계정설정·회원탈퇴)이
  /// 각각 ViewModel 을 만들어서 오가기만 해도 같은 요청이 여러 번 나갔다.
  ///
  /// 프로필은 사용자가 직접 바꾸기 전엔 변하지 않으므로, 짧은 TTL 로 충분하다.
  (DateTime, UserProfile)? _meCache;
  Future<UserProfile>? _meInFlight;
  static const Duration _meCacheTtl = Duration(seconds: 60);

  /// 로그인 회원 정보를 조회한다 (`GET /api/auth/me`).
  /// 만료 시 [authorizedRequest] 가 토큰을 자동 갱신·재시도한다.
  ///
  /// 같은 요청이 이미 떠 있거나 방금 끝났으면([_meCacheTtl] 이내) 그 결과를
  /// 재사용한다. 프로필을 고치거나 로그아웃하면 [_invalidateMeCache] 로 버린다.
  Future<UserProfile> fetchMe() {
    final cached = _meCache;
    if (cached != null && DateTime.now().difference(cached.$1) < _meCacheTtl) {
      return Future.value(cached.$2);
    }
    final inFlight = _meInFlight;
    if (inFlight != null) return inFlight;

    final request = _fetchMe().then((me) {
      _meCache = (DateTime.now(), me);
      return me;
    });
    // 실패는 호출부가 각자 받는다. 여기서 한 번 더 받아 두지 않으면 대기 중인
    // 리스너가 없을 때 '처리되지 않은 예외'로 올라온다.
    unawaited(request.whenComplete(() {
      if (identical(_meInFlight, request)) _meInFlight = null;
    }).then<void>((_) {}, onError: (_) {}));
    _meInFlight = request;
    return request;
  }

  /// 캐시된 회원 정보를 버린다. 프로필 수정·로그아웃·탈퇴 후에 부른다.
  void _invalidateMeCache() {
    _meCache = null;
    _meInFlight = null;
  }

  Future<UserProfile> _fetchMe() async {
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
    final updated = UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    // 방금 바꾼 값으로 캐시를 갱신한다. 버리기만 하면 다음 화면이 다시 받아야
    // 하는데, 응답이 이미 최신 프로필이라 그럴 이유가 없다.
    _meCache = (DateTime.now(), updated);
    _meInFlight = null;
    return updated;
  }

  /// 진행 중인 재발급 요청. 동시에 여러 API가 만료를 감지해도 1회만 호출한다.
  Future<RefreshResult>? _refreshing;

  /// Refresh Token으로 Access Token을 재발급해 저장한다.
  /// 동시 호출은 하나의 요청으로 합쳐 결과를 공유한다.
  ///
  /// 실패는 두 갈래로 구분해 반환한다 — 서버가 401 로 토큰 무효를 확정한
  /// 경우([RefreshResult.tokenInvalid])와, 타임아웃·네트워크 오류·5xx·429 같은
  /// 일시 장애. 후자는 토큰이 죽었다는 증거가 아니므로 호출부가 로그아웃하면
  /// 안 된다. (2026-08-11 20:17 장애: 커넥션 풀 대기로 refresh 응답이 3~5.7초
  /// 걸리자 타임아웃을 전부 로그아웃 처리해 유저들이 튕겨나갔다.)
  Future<RefreshResult> refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<RefreshResult> _doRefresh() async {
    final String? refresh;
    try {
      refresh = await refreshToken;
    } on SecureStorageUnavailableException catch (e) {
      // 못 읽었을 뿐 — 토큰이 없다는 뜻이 아니다. 잠금(-25308)이든 다른
      // Keychain 오류든 마찬가지라, 여기서 로그아웃하면 멀쩡한 세션이 날아간다.
      debugPrint('[Auth] 리프레시 토큰 읽기 불가(일시 장애로 처리): $e');
      SentryLogger.warning(
        module: 'Auth',
        eventName: 'refreshTokenUnreadable',
        reason: e.cause.runtimeType.toString(),
        error: e,
      );
      return const RefreshResult.transient();
    }
    if (refresh == null || refresh.isEmpty) {
      debugPrint('[Auth] refreshToken 없음 — 재발급 불가 (재로그인 필요)');
      return const RefreshResult.invalid();
    }
    try {
      debugPrint('[Auth] 재발급 요청 (query 방식)');
      // 백엔드 명세상 refreshToken 은 query 파라미터, body 는 없다.
      final response = await http.post(
        Uri.parse(ApiConfig.refreshUrl(refresh)),
        headers: const {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 401) {
        // 서버가 리프레시 토큰 무효/만료를 확정한 유일한 경우.
        // (서버의 로테이션 유예 덕에 동시 재발급 경합은 둘 다 성공하므로,
        // 여기의 401 은 정말 죽은 토큰이다.)
        debugPrint('[Auth] 리프레시 토큰 무효 확정 (401): ${response.body}');
        return const RefreshResult.invalid();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // 5xx·429 등 서버 사정 — 토큰이 무효라는 증거가 아니다.
        debugPrint('[Auth] 토큰 재발급 일시 실패 (${response.statusCode}): '
            '${response.body}');
        return const RefreshResult.transient();
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newJwt = (data['accessToken'] ?? data['jwt']) as String?;
      final newRefresh =
          (data['refreshToken'] ?? data['refresh_token']) as String?;
      if (newJwt == null) {
        // 2xx 인데 토큰이 없다 — 서버 응답 이상. 무효 확정이 아니다.
        debugPrint('[Auth] 재발급 응답에 accessToken 없음: ${response.body}');
        return const RefreshResult.transient();
      }
      await writeWithDuplicateRecovery(key: _jwtKey, value: newJwt);
      _setCachedJwt(newJwt);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await writeWithDuplicateRecovery(key: _refreshKey, value: newRefresh);
      }
      debugPrint('[Auth] 토큰 재발급 성공');
      return RefreshResult.success(newJwt);
    } catch (e) {
      // 타임아웃·네트워크 예외 — 서버가 토큰 무효를 확정한 게 아니다.
      debugPrint('[Auth] 토큰 재발급 에러(일시 장애로 처리): $e');
      return const RefreshResult.transient();
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
    // 잠금으로 못 읽은 경우는 [SecureStorageUnavailableException] 이 그대로
    // 올라간다 — '토큰 없음'과 구분되어야 호출부가 로그아웃으로 오해하지 않는다.
    final token = await jwt;
    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요합니다 (토큰 없음)');
    }
    var response = await send(token);
    if (_isAuthExpired(response)) {
      debugPrint('[Auth] 인증 만료 감지 → 토큰 재발급 시도');
      final refreshed = await refreshAccessToken();
      final newToken = refreshed.token;
      if (newToken != null) {
        response = await send(newToken);
      } else if (refreshed.tokenInvalid) {
        // Refresh Token도 만료/무효화된 상태 — 더 이상 재시도해도 로그인
        // 상태를 복구할 수 없으므로 세션을 정리하고 로그인 화면으로 보낸다.
        await _forceLogout();
      } else {
        // 재발급이 일시 장애(타임아웃·네트워크·5xx 등)로 실패 — 토큰이
        // 죽었다는 증거가 아니므로 로그아웃하지 않고, 이번 요청만 만료
        // 응답 그대로 실패시킨다. 다음 요청에서 재발급을 다시 시도한다.
        debugPrint('[Auth] 재발급 일시 실패 — 이번 요청만 실패 (로그아웃 안 함)');
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
      _setCachedJwt(null);
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
    if (response.statusCode == 401) return true;
    // 302 + HTML 이면 로그인 페이지로 보내진 것 — 만료로 본다.
    //
    // content-type 만으로 판단하면 안 된다. 게이트웨이(nginx·ALB)가 502·503·504
    // 에러 페이지를 text/html 로 내려주기 때문에, 서버가 아플 때의 5xx 를
    // '인증 만료'로 오판해 불필요한 재발급·토큰 로테이션을 유발한다.
    if (response.statusCode == 302) {
      final contentType = response.headers['content-type'] ?? '';
      return contentType.contains('text/html') || contentType.isEmpty;
    }
    return false;
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
    _setCachedJwt(null);
    await _storage.delete(key: _refreshKey);
    SentryLogger.clearUser();
  }
}
