import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../model/live_match_activity.dart';

/// 실시간 경기 카드 제어 서비스.
///
/// 네이티브 채널(`com.warding.app/live_activity`)로 각 플랫폼 구현을 호출한다.
/// - iOS: ActivityKit Live Activity
/// - Android: 커스텀 레이아웃을 붙인 진행 중(ongoing) 알림
///
/// 두 플랫폼이 같은 채널·메서드·페이로드를 쓰므로 호출부는 분기하지 않는다.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const MethodChannel _channel =
      MethodChannel('com.warding.app/live_activity');

  /// 현재 활성 액티비티가 붙어있는 경기 ID. 없으면 null.
  String? _activeMatchId;

  String? get activeMatchId => _activeMatchId;

  /// 실시간 카드를 지원하는 플랫폼인지(iOS·Android).
  bool get _supportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// 기기/설정에서 실시간 카드를 쓸 수 있는지.
  ///
  /// Android 는 알림 권한이 곧 표시 가능 여부다(13+ 는 런타임 권한).
  Future<bool> isSupported() async {
    if (!_supportedPlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] isSupported failed: ${e.message}');
      return false;
    }
  }

  /// Android 알림 권한을 확보한다. iOS 는 별도 권한이 없어 그대로 true.
  ///
  /// 이미 거부된 상태면 다시 묻지 않고 false 를 돌려준다(설정에서만 변경 가능).
  Future<bool> ensurePermission() async {
    if (!_supportedPlatform) return false;
    if (!Platform.isAndroid) return true;
    if (await isSupported()) return true;

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Live Activity 를 시작한다. 성공하면 true.
  ///
  /// 이미 다른 경기의 액티비티가 떠 있으면 네이티브에서 정리하고 새로 띄운다.
  Future<bool> start({
    required LiveMatchActivityConfig config,
    required LiveMatchActivityState state,
  }) async {
    if (!_supportedPlatform) return false;
    try {
      final args = <String, dynamic>{...config.toMap(), ...state.toMap()};
      final id = await _channel.invokeMethod<String>('start', args);
      if (id != null) {
        _activeMatchId = config.matchId;
        debugPrint('[LiveActivity] started: $id (${config.matchId})');
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] start failed: ${e.code} ${e.message}');
      return false;
    }
  }

  /// 활성 액티비티의 상태를 갱신한다.
  Future<bool> update(LiveMatchActivityState state) async {
    if (!_supportedPlatform || _activeMatchId == null) return false;
    try {
      return await _channel.invokeMethod<bool>('update', state.toMap()) ?? false;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] update failed: ${e.message}');
      return false;
    }
  }

  /// 최종 상태를 반영하고 액티비티를 종료한다.
  Future<bool> end(LiveMatchActivityState finalState) async {
    if (!_supportedPlatform) return false;
    try {
      final ok =
          await _channel.invokeMethod<bool>('end', finalState.toMap()) ?? false;
      _activeMatchId = null;
      return ok;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] end failed: ${e.message}');
      return false;
    }
  }

  /// 남아있는 모든 액티비티를 즉시 종료한다 (앱 시작 시 정리용).
  Future<void> endAll() async {
    if (!_supportedPlatform) return;
    try {
      await _channel.invokeMethod<bool>('endAll');
      _activeMatchId = null;
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
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return base64Encode(response.bodyBytes);
    } catch (e) {
      debugPrint('[LiveActivity] logo fetch failed ($url): $e');
      return null;
    }
  }
}
