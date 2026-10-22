import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'analytics_events.dart';

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
      await _registerAppVersion();
    } catch (e) {
      debugPrint('[Analytics] 초기화 실패: $e');
    }
  }

  /// `app_version` 을 super property 로 등록한다 — 이후 **모든 이벤트**에
  /// 자동으로 붙는다(기기에 저장되고 전송 시 합쳐지므로 이벤트가 늘지 않는다.
  /// Mixpanel 과금은 이벤트 수 기준이라 비용도 그대로다).
  ///
  /// 왜 필요한가: 이게 없으면 **어느 버전이 그 숫자를 만들었는지 알 수 없다.**
  /// 실제로 2026-10-20 DAU 알림에서 화면·퍼널이 전부 0 으로 나왔는데, 원인이
  /// "집계 버그" 인지 "계측이 안 들어간 구버전이 대부분" 인지 데이터로 가를
  /// 방법이 없어 원시 이벤트를 직접 까 봐야 했다(계측 미도달이 맞았다).
  ///
  /// 소급 적용이 안 된다 — 이벤트는 보낸 시점의 프로퍼티로 영구 저장된다.
  /// 그래서 지금 심지 않으면 과거 데이터는 영영 버전을 모른다.
  ///
  /// `api_client.dart` 의 `X-App-Version` 과 같은 `version+build` 형식을 쓴다.
  /// 서버 로그와 Mixpanel 을 같은 키로 맞춰 봐야 하므로 형식이 갈리면 안 된다.
  static Future<void> _registerAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
      await _applyAppVersion();
    } catch (e) {
      // 버전을 못 읽어도 트래킹 자체는 계속한다 — 버전 없는 이벤트가
      // 이벤트 누락보다 낫다.
      debugPrint('[Analytics] app_version super property 등록 실패: $e');
    }
  }

  /// 읽어 둔 버전. [reset] 뒤 다시 등록할 때 쓴다 — `PackageInfo` 플랫폼
  /// 채널을 또 타지 않아도 되므로 reset 직후 바로 재등록할 수 있다.
  static String? _appVersion;

  static Future<void> _applyAppVersion() async {
    final v = _appVersion;
    if (v == null) return;
    await _mixpanel?.registerSuperProperties({AnalyticsProp.appVersion: v});
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
  ///
  /// `reset()` 은 **super property 도 함께 지운다**(플러그인 문서: "Clear
  /// super properties and generates a new random distinctId"). 다시 등록하지
  /// 않으면 로그아웃·탈퇴 이후의 모든 이벤트가 `app_version` 을 잃는다 —
  /// 그러면 버전별 집계에서 로그아웃한 사용자만 조용히 빠져 숫자가 틀어진다.
  ///
  /// 둘 다 MethodChannel 호출이라 **순서를 보장하려면 await 해야 한다.**
  /// 재등록이 reset 을 앞지르면 방금 심은 버전이 그대로 지워진다. 호출부는
  /// 기존처럼 기다리지 않아도 되게 `void` 를 유지하고, 순서만 내부에서 잡는다.
  static void reset() {
    final mp = _mixpanel;
    if (mp == null) return;
    () async {
      try {
        await mp.reset();
        await _applyAppVersion();
      } catch (e) {
        debugPrint('[Analytics] reset 실패: $e');
      }
    }();
  }

  static void track(String event, [Map<String, dynamic>? properties]) {
    try {
      _mixpanel?.track(event, properties: properties);
    } catch (e) {
      debugPrint('[Analytics] track 실패: $e');
    }
  }
}
