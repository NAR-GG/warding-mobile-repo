import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/app/bridge/bridge_protocol.dart';

/// 웹에서 온 메시지를 해석해 네이티브 동작으로 잇는다.
///
/// **화면을 띄우고 여러 기능의 구현을 알아야 하므로 `app/` 에 둔다** —
/// `app/` 의 판별 기준("기능 2개 이상의 화면이나 구현을 알아야 하나")에 맞는다.
///
/// 데이터 요청은 받지 않는다. 웹이 API 를 직접 부른다(→ spec "데이터는 웹이
/// 직접 받는다"). 브리지는 **네이티브만 할 수 있는 일**만 맡는다.
class BridgeHandler {
  BridgeHandler({
    required this.controller,
    required this.onHeight,
    required this.onReady,
    required this.onBack,
    required this.onNavigate,
    required this.openPhotoViewer,
    required this.share,
  });

  final WebViewController controller;

  /// 본문 높이 통지. 웹뷰를 네이티브 스크롤에 끼울 때 쓴다.
  final void Function(double height) onHeight;

  /// 첫 페인트 완료. 로딩 가림막을 걷는다.
  final void Function(DateTime at) onReady;

  /// 뒤로가기. 웹 히스토리가 아니라 네이티브 스택을 되돌린다.
  final VoidCallback onBack;

  /// 네이티브 화면 이동 요청.
  final void Function(String route) onNavigate;

  /// 사진 전체화면 뷰어 (Stage C).
  final Future<void> Function(List<String> urls, int index) openPhotoViewer;

  /// 시스템 공유 시트 (Stage C).
  final Future<void> Function(String url, String? title) share;

  /// 웹뷰에 채널을 등록한다.
  void attach() {
    controller.addJavaScriptChannel(
      kBridgeChannel,
      onMessageReceived: (message) => _handle(message.message),
    );
  }

  /// 채널을 뗀다.
  ///
  /// **컨트롤러를 재사용할 때 필요하다**(→ `WebViewWarmup`). 화면이 사라져도
  /// 컨트롤러가 살아 있으면 채널이 남고, 다음 화면이 `attach` 할 때 같은
  /// 이름으로 두 번 등록된다. 콜백이 죽은 화면을 붙들고 있어 메시지가
  /// 엉뚱한 곳으로 간다.
  void detach() => controller.removeJavaScriptChannel(kBridgeChannel);

  /// 테스트에서 채널을 거치지 않고 직접 넣는 통로.
  ///
  /// `attach()` 는 플랫폼 채널이라 단위 테스트에서 쓸 수 없다. 메시지 해석
  /// 로직만 떼어 검증하려면 이 입구가 필요하다.
  @visibleForTesting
  Future<void> handleForTest(String raw) => _handle(raw);

  Future<void> _handle(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      // 웹이 깨진 문자열을 보내도 앱을 죽이지 않는다.
      debugPrint('[Bridge] 파싱 실패: $e');
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    switch (decoded['stage']) {
      case 'a':
        await _handleNotify(decoded);
      case 'c':
        await _handleCall(decoded);
      default:
        debugPrint('[Bridge] 모르는 stage: ${decoded['stage']}');
    }
  }

  Future<void> _handleNotify(Map<String, dynamic> json) async {
    switch (BridgeNotify.parse(json['type'] as String?)) {
      case BridgeNotify.height:
        final h = (json['height'] as num?)?.toDouble();
        if (h != null && h > 0) onHeight(h);
      case BridgeNotify.ready:
        final at = (json['at'] as num?)?.toInt();
        onReady(
          at == null
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(at),
        );
      case BridgeNotify.back:
        onBack();
      case BridgeNotify.navigate:
        final route = json['route'] as String?;
        if (route != null && route.isNotEmpty) onNavigate(route);
      case null:
        // **조용히 삼키지 않는다.** 웹은 배포 즉시 전원에게 가지만 앱은
        // 업데이트를 기다리므로, 새 메시지를 모르는 구버전이 반드시 생긴다.
        // 여기서 로그만 찍고 끝내면 웹은 "보냈으니 됐다" 고 믿고 사용자는
        // 버튼이 안 먹는 이유를 모른다 — 웹에 되돌려 폴백을 고르게 한다.
        final type = json['type'] as String?;
        debugPrint('[Bridge] 모르는 notify: $type');
        await _push({'type': 'unsupported', 'name': type});
    }
  }

  Future<void> _handleCall(Map<String, dynamic> json) async {
    final id = json['id'] as String?;
    if (id == null) return;

    try {
      switch (BridgeCall.parse(json['method'] as String?)) {
        case BridgeCall.openPhotoViewer:
          final urls = (json['urls'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
          if (urls.isEmpty) throw ArgumentError('urls 가 비었다');
          await openPhotoViewer(urls, (json['index'] as num?)?.toInt() ?? 0);
          await _respond(id, ok: true);
        case BridgeCall.share:
          final url = json['url'] as String?;
          if (url == null || url.isEmpty) throw ArgumentError('url 이 없다');
          await share(url, json['title'] as String?);
          await _respond(id, ok: true);
        case null:
          throw ArgumentError('모르는 method: ${json['method']}');
      }
    } catch (e) {
      await _respond(id, ok: false, error: '$e');
    }
  }

  /// Stage C 응답. 웹의 `__wardingReceive` 로 되돌린다.
  Future<void> _respond(
    String id, {
    required bool ok,
    Object? value,
    String? error,
  }) =>
      _push({
        'id': id,
        'ok': ok,
        if (ok) 'value': value else 'error': error ?? '알 수 없는 오류',
      });

  /// Stage B 브로드캐스트 — 환경 변경.
  Future<void> broadcastEnv(BridgeEnv env) =>
      _push({'type': 'env', 'env': env.toJson()});

  /// Stage B 브로드캐스트 — 토큰이 갱신됐다.
  ///
  /// 쿠키는 이 호출 **전에** 다시 심어야 한다. 웹은 이 신호를 받고 서버
  /// 데이터를 다시 받기만 한다.
  Future<void> broadcastAuthChanged() => _push({'type': 'auth-changed'});

  Future<void> _push(Map<String, Object?> payload) async {
    // 웹 쪽 수신 함수가 아직 설치되지 않았을 수 있다(로드 중). 그때는
    // 조용히 넘어간다 — 던지면 호출부마다 try 를 달아야 한다.
    final json = jsonEncode(jsonEncode(payload));
    try {
      await controller.runJavaScript(
        'window.__wardingReceive && window.__wardingReceive($json)',
      );
    } catch (e) {
      debugPrint('[Bridge] push 실패: $e');
    }
  }
}
