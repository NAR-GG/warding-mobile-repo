import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../util/api_client.dart' as http;

import 'live_activity_push_token_repository.dart';

/// 실시간 경기 카드 제어 서비스.
///
/// 네이티브 채널(`com.warding.app/live_activity`)로 iOS(ActivityKit Live
/// Activity) 구현을 호출한다. 세트 스코어는 서버가 APNs 로 카드를 직접
/// 갱신하고, 앱은 카드가 발급한 푸시 토큰을 받아 등록만 한다(`pushToken`
/// 콜백 — [_handleNativeCall] 참고).
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const MethodChannel _channel =
      MethodChannel('com.warding.app/live_activity');

  /// [_handleNativeCall] 등록 여부. 실제로 지원 플랫폼에서 채널을 처음 쓸
  /// 때 등록한다 — 생성자에서 바로 등록하면 위젯 바인딩 없는 순수 단위
  /// 테스트에서 `LiveActivityService.instance` 에 닿기만 해도 죽는다.
  bool _handlerRegistered = false;

  void _ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// 실시간 카드 킬스위치.
  ///
  /// false 면 [_supportedPlatform] 이 항상 false 라 카드 표시·push-to-start
  /// 토큰 등록·로고 프리페치 경로가 전부 즉시 빠져나간다. 내부 테스트를 위해
  /// true 로 켠 상태 — 문제가 생기면 false 로 되돌리는 shorebird patch 한 번으로
  /// 다시 끌 수 있다.
  ///
  /// ponytail: 서버 푸시 갱신이 안정화되면 이 상수를 지운다.
  static final bool _enabled = true;

  /// 실시간 카드를 지원하는 플랫폼인지. Android 는 서버 푸시 갱신 없이
  /// 백그라운드 상태를 따라가지 못해 제외했다(iOS 만 지원).
  bool get _supportedPlatform => _enabled && !kIsWeb && Platform.isIOS;

  /// 기기/설정에서 실시간 카드를 쓸 수 있는지.
  Future<bool> isSupported() async {
    if (!_supportedPlatform) return false;
    _ensureHandlerRegistered();
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] isSupported failed: ${e.message}');
      return false;
    }
  }

  /// 네이티브(iOS)에서 오는 콜백을 처리한다.
  ///
  /// - `pushToken` : 카드가 발급한 APNs 푸시 토큰. 서버에 등록해야 세트
  ///   시작·종료 시 서버가 이 카드를 직접 갱신할 수 있다.
  /// - `pushToStartToken` : 앱 단위 토큰. 카드가 없어도 발급되고, 이게 있어야
  ///   서버가 앱이 안 떠 있는 상태에서 카드를 새로 만들 수 있다.
  Future<void> _handleNativeCall(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>?;
    final pushToken = args?['pushToken'] as String?;
    if (pushToken == null) return;

    switch (call.method) {
      case 'pushToken':
        final matchId = args?['matchId'] as String?;
        if (matchId == null) return;
        await LiveActivityPushTokenRepository.instance.register(
          matchId: matchId,
          pushToken: pushToken,
        );
      case 'pushToStartToken':
        await LiveActivityPushTokenRepository.instance
            .registerStartToken(pushToken);
    }
  }

  /// push-to-start 토큰 관찰을 시작한다.
  ///
  /// 앱 시작 시 한 번 부르면 되고, 네이티브가 중복 관찰을 막는다.
  /// iOS 17.2 미만이면 false — 그 기기는 포그라운드 폴백만 쓴다.
  Future<bool> observePushToStartToken() async {
    if (!_supportedPlatform) return false;
    _ensureHandlerRegistered();
    try {
      return await _channel.invokeMethod<bool>('observePushToStartToken') ??
          false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] push-to-start 관찰 실패: ${e.message}');
      return false;
    }
  }

  /// [fileName] 로고가 [url] 로 받아둔 그대로 캐싱돼 있는지.
  ///
  /// 파일 존재와 원본 URL 을 함께 본다 — 파일만 보면 팀이 로고를 바꿔도
  /// 옛 이미지를 계속 쓰게 된다. URL 기록은 파일과 같은 App Group 에 둔다.
  Future<bool> hasLogo(String fileName, {String? url}) async {
    if (!_supportedPlatform) return false;
    _ensureHandlerRegistered();
    try {
      return await _channel.invokeMethod<bool>(
            'hasLogo',
            {'fileName': fileName, 'url': url},
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] hasLogo 실패: ${e.message}');
      return false;
    }
  }

  /// base64 로고를 App Group 에 [fileName] 으로 캐싱한다.
  ///
  /// 서버가 만든 카드는 앱이 안 떠 있을 때 렌더되므로, 그 전에 미리
  /// 저장돼 있어야 로고가 보인다. [url] 을 주면 다음 [hasLogo] 가
  /// 리브랜딩을 알아채도록 원본 주소를 함께 기록한다.
  Future<bool> cacheLogo(String base64, String fileName, {String? url}) async {
    if (!_supportedPlatform) return false;
    _ensureHandlerRegistered();
    try {
      return await _channel.invokeMethod<bool>(
            'cacheLogo',
            {'base64': base64, 'fileName': fileName, 'url': url},
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] cacheLogo 실패: ${e.message}');
      return false;
    }
  }

  /// 남아있는 모든 액티비티를 즉시 종료한다 (고착 카드 정리용).
  ///
  /// 카드의 시작·갱신·정상 종료는 서버가 APNs 로 처리한다. 앱에는 서버가
  /// 못 닫는(토큰 미등록) 카드를 치우는 이 경로만 남겼다.
  Future<void> endAll() async {
    if (!_supportedPlatform) return;
    try {
      await _channel.invokeMethod<bool>('endAll');
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] endAll failed: ${e.message}');
    }
  }

  /// 팀 로고 URL 을 내려받아 base64 PNG 로 변환한다.
  ///
  /// Live Activity 확장은 네트워크를 못 쓰므로 앱이 미리 받아 넘겨야 한다.
  /// 실패하면 null (위젯은 로고 없이 렌더링된다).
  Future<String?> fetchLogoBase64(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse(url),
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return base64Encode(response.bodyBytes);
    } catch (e) {
      debugPrint('[LiveActivity] logo fetch failed ($url): $e');
      return null;
    }
  }
}
