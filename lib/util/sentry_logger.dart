import 'dart:io';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry 커스텀 이벤트 로깅 유틸.
///
/// 블로그 가이드(https://techblog.lycorp.co.jp/ko/outage-monitoring-for-app-success)의
/// 로그 레벨 설계를 따른다.
///
/// - **info**: 데이터 변경 행위 성공 (로그인, 구매 등). 실시간 알림 대상 아님.
/// - **warning**: 외부 시스템 연동 실패 (API 실패 등). 실시간 알림 대상.
/// - **error**: 방어 코드로도 통제 불가한 내부 로직 오류. 즉시 알림.
/// - **fatal**: 앱 크래시 (Sentry 자동 수집).
///
/// 네트워크 에러(SocketException, timeout 등)는 전송하지 않는다.
class SentryLogger {
  SentryLogger._();

  /// 네트워크 관련 에러인지 판별. 사용자 측 일시적 네트워크 상태 이상은
  /// 앱/서버 결함이 아니므로 Sentry 로 전송하지 않는다.
  static bool _isNetworkError(Object? error) {
    if (error == null) return false;
    if (error is SocketException) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection timed out') ||
        msg.contains('network is unreachable') ||
        msg.contains('no internet') ||
        msg.contains('timed out');
  }

  /// extra 데이터를 Contexts 로 변환한다 (extra deprecated 대응).
  static Contexts? _toContexts(Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) return null;
    final contexts = Contexts();
    contexts['custom'] = extra;
    return contexts;
  }

  /// **info** — 데이터 변경 행위 성공 시 기록.
  ///
  /// 실시간 모니터링 대상 아님. 에러 발생 후 사용자 행동 추적에 활용.
  /// 예: 로그인 성공, 회원가입 성공, 구독 변경 등.
  static Future<void> info({
    required String module,
    required String eventName,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureEvent(
      SentryEvent(
        level: SentryLevel.info,
        message: SentryMessage('[$module] [$eventName] success'),
        tags: {
          'module': module,
          'eventName': eventName,
        },
        contexts: _toContexts(extra) ?? Contexts(),
      ),
    );
  }

  /// **warning** — 외부 시스템 연동 실패 시 기록.
  ///
  /// 네트워크 에러는 전송하지 않는다. 실시간 알림 대상.
  /// 예: API 호출 실패, 푸시 알림 유실, 리모트 설정 연동 실패 등.
  static Future<void> warning({
    required String module,
    required String eventName,
    String? reason,
    Map<String, dynamic>? extra,
    Object? error,
  }) async {
    // 네트워크 에러는 전송하지 않음
    if (_isNetworkError(error)) return;

    await Sentry.captureEvent(
      SentryEvent(
        level: SentryLevel.warning,
        message: SentryMessage('[$module] [$eventName] failed'),
        tags: {
          'module': module,
          'eventName': eventName,
          'reason': ?reason,
        },
        contexts: _toContexts(extra) ?? Contexts(),
      ),
    );
  }

  /// **error** — 방어 코드로 통제 불가한 내부 로직 오류 시 기록.
  ///
  /// 즉시 알림 대상. null 객체, 파싱 오류, 도달 불가 분기 진입 등.
  static Future<void> error({
    required String module,
    required String eventName,
    String? reason,
    Map<String, dynamic>? extra,
    Object? throwable,
    dynamic stackTrace,
  }) async {
    await Sentry.captureEvent(
      SentryEvent(
        level: SentryLevel.error,
        message: SentryMessage('[$module] [$eventName] failed'),
        tags: {
          'module': module,
          'eventName': eventName,
          'reason': ?reason,
        },
        contexts: _toContexts(extra) ?? Contexts(),
        throwable: throwable,
      ),
      stackTrace: stackTrace,
    );
  }

  /// 사용자 ID 설정 — 로그인 성공 후 호출.
  static void setUser(String userId) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: userId));
    });
  }

  /// 사용자 정보 초기화 — 로그아웃 시 호출.
  static void clearUser() {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// 사용자 동작 이벤트 기록 — 에러 발생 직전 행동 맥락 복원용.
  ///
  /// 핵심 행동(구독 변경, 알림 설정 등)만 남기고 과도한 기록은 피한다.
  static void trackTap(String label) {
    Sentry.addBreadcrumb(
      Breadcrumb(message: 'tap: $label', category: 'ui'),
    );
  }
}
