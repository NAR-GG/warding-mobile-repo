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
      _mixpanel = await Mixpanel.init(
        _token,
        trackAutomaticEvents: true,
        featureFlags: const FeatureFlagsConfig(
          // 로그인 전(익명 ID)에 평가하지 않는다. `identify()` 뒤에
          // [loadFlags] 를 직접 부른다 — 익명으로 평가한 변형과 로그인 후
          // 변형이 갈리면 같은 사용자가 세션 중에 다른 값을 본다.
          prefetchFlags: false,
          // 기본값 networkOnly 는 캐시를 안 써서, 네트워크가 느리거나 끊기면
          // fallback 이 나간다 — 앱을 켤 때마다 같은 사용자가 다른 값을 볼 수
          // 있다는 뜻이고, 실험 데이터가 오염된다. 저장된 변형을 먼저 주고
          // 네트워크는 뒤에서 갱신한다.
          variantLookupPolicy: VariantLookupPolicy.persistenceUntilNetworkSuccess(),
        ),
      );
      await _registerAppVersion();
      // 비회원도 실험 대상이다. 로그인하면 `identify` 뒤에 다시 부른다.
      await loadFlags();
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
  ///
  /// 식별 뒤 플래그를 다시 받는다. SDK 의 `identify()` 는 플래그를 자동으로
  /// 재평가하지 않아서, 이게 없으면 **익명 ID 로 배정된 변형이 그대로 남는다**
  /// — 회원 기준으로 타겟팅한 실험이 로그인한 사용자에게 안 걸린다.
  /// 호출부(2곳)가 기다리지 않아도 되게 순서만 내부에서 잡는다.
  static void identify(String memberId) {
    final mp = _mixpanel;
    if (mp == null) return;
    () async {
      try {
        await mp.identify(memberId);
        await loadFlags();
      } catch (e) {
        debugPrint('[Analytics] identify 실패: $e');
      }
    }();
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
  ///
  /// [tagExperiment] 로 붙인 `experiment_*` 는 **복원하지 않는다**(복원하면
  /// 안 된다). 새 익명 사용자는 변형을 다시 배정받으므로, 이전 사용자의
  /// 실험군을 물려주면 실험 데이터가 섞인다. 아래 [loadFlags] 뒤에 화면이
  /// 변형을 다시 읽고 [tagExperiment] 를 다시 부르는 것이 정상 흐름이다.
  static void reset() {
    final mp = _mixpanel;
    if (mp == null) return;
    () async {
      try {
        await mp.reset();
        await _applyAppVersion();
        // 새 익명 ID 기준으로 플래그를 다시 받는다. 안 하면 로그아웃한
        // 사용자가 **이전 회원 기준으로 배정된 변형**을 계속 본다.
        await loadFlags();
      } catch (e) {
        debugPrint('[Analytics] reset 실패: $e');
      }
    }();
  }

  // ───────────────────────── 피처 플래그 / A/B 실험 ─────────────────────────
  //
  // Mixpanel 실험을 쓴다(Firebase A/B 가 아니라). 이유:
  // - `mixpanel_flutter` 2.14.0 에 이미 들어 있어 새 의존성이 0개다. 네이티브
  //   변경이 없어 Shorebird 패치로도 나갈 수 있다.
  // - Firebase A/B 는 승패를 **GA4 지표로만** 판정한다. 이미 Mixpanel 에 P0
  //   26행을 심어 둔 상태에서 같은 이벤트를 GA4 에 또 보내야 한다.
  // - 사용자 식별이 [identify] 로 이미 서버 회원 ID 에 묶여 있다(Firebase 는
  //   FID 라 Mixpanel 과 키가 달라 결과 대조가 어렵다).
  //
  // Free 플랜 한도: 실험 무제한, **MEU(실험 참여 사용자) 1,000/월**, 활성
  // 플래그 10개. DAU 가 이미 1,000 을 넘으므로 **전체 사용자를 실험에 넣으면
  // 한도를 넘긴다** — 콘솔에서 타겟팅으로 모집단을 좁혀야 한다(특정 화면
  // 진입자 등). 넘으면 과금이 아니라 배정이 멈춘다.

  /// 플래그를 지금 사용자 기준으로 다시 받는다.
  ///
  /// [identify] 직후에 불러야 한다 — 익명 ID 로 평가된 변형이 로그인 후와
  /// 다를 수 있다. [init] 은 `prefetchFlags: false` 로 자동 조회를 끄고
  /// 비회원 상태에서 한 번만 부른다.
  static Future<void> loadFlags() async {
    try {
      await _mixpanel?.getFeatureFlags().loadFlags();
    } catch (e) {
      debugPrint('[Analytics] loadFlags 실패: $e');
    }
  }

  /// 플래그 값을 읽는다. 실패하면 [fallback] 을 준다.
  ///
  /// **[fallback] 은 반드시 "지금 운영 중인 값"** 을 넣는다. 0 이나 빈 문자열을
  /// 넣으면 네트워크가 느린 사용자·디버그 빌드·실험 종료 후에 깨진 화면이
  /// 나간다. 플래그가 없는 상태가 정상 동작이어야 한다.
  ///
  /// 타입이 어긋나면(콘솔에서 문자열로 설정한 플래그를 `int` 로 읽는 등)
  /// [fallback] 을 준다. SDK 의 `getVariantValue` 는 `dynamic` 을 돌려주므로
  /// 그대로 쓰면 잘못된 타입이 화면까지 흘러가 런타임에서 터진다.
  ///
  /// ```dart
  /// final price = await Analytics.flag('banner_price', 20000);
  /// ```
  ///
  /// 주의: **디버그 빌드에서는 트래킹이 꺼져 있어 항상 [fallback] 이 나온다.**
  /// 시뮬레이터에서 변형을 확인하려면 `--dart-define=MIXPANEL_DEBUG=true` 로
  /// 켠다([_enableInDebug]).
  static Future<T> flag<T>(String name, T fallback) async {
    final mp = _mixpanel;
    if (mp == null) return fallback;
    try {
      final value = await mp.getFeatureFlags().getVariantValue(name, fallback);
      if (value is T) return value;
      // 플랫폼 채널은 숫자를 JSON 으로 실어 와서, 콘솔에 `15000` 으로 넣은
      // 값이 `double` 을 기대하는 코드에 `int` 로 도착한다(반대도 있다).
      // 타입 불일치로 버리면 실험이 조용히 안 걸리므로 숫자만 변환해 준다.
      if (value is num) {
        if (T == double) return value.toDouble() as T;
        if (T == int) return value.toInt() as T;
      }
      debugPrint(
        '[Analytics] 플래그 $name 타입 불일치: ${value.runtimeType} ≠ $T — fallback 사용',
      );
      return fallback;
    } catch (e) {
      debugPrint('[Analytics] 플래그 $name 조회 실패: $e');
      return fallback;
    }
  }

  /// bool 플래그 전용. 기능을 켜고 끄는 스위치에 쓴다.
  static Future<bool> flagEnabled(String name, bool fallback) async {
    final mp = _mixpanel;
    if (mp == null) return fallback;
    try {
      return await mp.getFeatureFlags().isEnabled(name, fallback);
    } catch (e) {
      debugPrint('[Analytics] 플래그 $name 조회 실패: $e');
      return fallback;
    }
  }

  /// 배정된 변형을 `experiment_<name>` super property 로 등록해, 이후 **모든
  /// 이벤트**에 실험군을 실어 보낸다.
  ///
  /// 이게 있어야 **Mixpanel 퍼널·리텐션을 실험군별로 쪼개 볼 수 있다.**
  /// 실험 콘솔이 보여주는 지표 말고 다른 각도로 파고들 때 필요하다(예:
  /// "가격 변형 B 를 본 사용자의 온보딩 완료율").
  ///
  /// 실험이 아닌 플래그(단순 스위치)는 `experimentId` 가 없어 등록하지 않는다 —
  /// 쓸데없이 super property 가 쌓이면 모든 이벤트가 무거워진다.
  ///
  /// 변형을 읽은 뒤 한 번 부른다:
  /// ```dart
  /// final price = await Analytics.flag('banner_price', 20000);
  /// await Analytics.tagExperiment('banner_price');
  /// ```
  static Future<void> tagExperiment(String name) async {
    final mp = _mixpanel;
    if (mp == null) return;
    try {
      final variant = await mp.getFeatureFlags().getVariant(
        name,
        MixpanelFlagVariant(key: name, value: null),
      );
      // 실험에 묶이지 않은 플래그거나 fallback 이면 실험군이 아니다.
      if (variant.experimentId == null) return;
      await mp.registerSuperProperties({'experiment_$name': variant.key});
    } catch (e) {
      debugPrint('[Analytics] 실험 태깅 $name 실패: $e');
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
