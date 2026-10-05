import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// Mixpanel 이벤트 트래킹 래퍼.
///
/// 프로젝트 토큰은 클라이언트 공개용 값이라 Sentry DSN 처럼 기본값으로 박아 둔다
/// (릴리즈 명령에 `--dart-define` 을 빠뜨려도 트래킹이 꺼지지 않게). 다른 프로젝트
/// 토큰을 쓰려면 `--dart-define=MIXPANEL_TOKEN=...` 로 덮어쓴다.
///
/// 디버그 빌드에서는 켜지 않는다 — 개발 중 이벤트가 운영 데이터에 섞이지 않게.
/// 토큰이 비어 있거나 초기화 전이면 모든 호출이 조용히 무시되므로 호출부에서
/// 분기할 필요가 없다.
/// 트래킹 실패가 앱 동작을 막으면 안 되므로 예외는 전부 삼킨다.
class Analytics {
  Analytics._();

  static const String _token = String.fromEnvironment(
    'MIXPANEL_TOKEN',
    defaultValue: '7ed0b71e26432af6c7656c176f8cceef',
  );

  /// 시뮬레이터는 release 모드를 못 돌려서, 디버그에서 트래킹을 확인하려면
  /// `--dart-define=MIXPANEL_DEBUG=true` 로 켠다.
  static const bool _enableInDebug = bool.fromEnvironment('MIXPANEL_DEBUG');

  static Mixpanel? _mixpanel;

  static bool get enabled => _mixpanel != null;

  /// 앱 시작 시 한 번 부른다. 토큰이 없으면 아무것도 하지 않는다.
  static Future<void> init() async {
    if ((kDebugMode && !_enableInDebug) || _token.isEmpty) {
      debugPrint('[Analytics] 디버그 빌드이거나 MIXPANEL_TOKEN 없음 — 트래킹 비활성화');
      return;
    }
    try {
      _mixpanel = await Mixpanel.init(_token, trackAutomaticEvents: true);
    } catch (e) {
      debugPrint('[Analytics] 초기화 실패: $e');
    }
  }

  /// 로그인 성공 시 서버 회원 ID 로 사용자를 식별한다.
  static void identify(String memberId) {
    try {
      _mixpanel?.identify(memberId);
    } catch (e) {
      debugPrint('[Analytics] identify 실패: $e');
    }
  }

  /// 로그아웃 시 식별을 끊고 다음 사용자를 새 익명 ID 로 시작한다.
  static void reset() {
    try {
      _mixpanel?.reset();
    } catch (e) {
      debugPrint('[Analytics] reset 실패: $e');
    }
  }

  static void track(String event, [Map<String, dynamic>? properties]) {
    try {
      _mixpanel?.track(event, properties: properties);
    } catch (e) {
      debugPrint('[Analytics] track 실패: $e');
    }
  }
}
