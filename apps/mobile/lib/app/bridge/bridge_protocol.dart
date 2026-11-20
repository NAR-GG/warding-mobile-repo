/// 웹 ↔ 네이티브 브리지 규약.
///
/// **웹 쪽 `apps/web/src/shared/bridge/protocol.ts` 와 짝을 이룬다.** 코드
/// 생성이 없으므로 둘이 어긋나면 런타임에야 드러난다 — 한쪽을 고치면 반드시
/// 다른 쪽도 본다.
///
/// | 단계 | 방향 | 용도 |
/// |---|---|---|
/// | A | 웹 → 네이티브 | 단방향 통지 (높이·준비완료·화면이동·뒤로가기) |
/// | B | 네이티브 → 웹 | 브로드캐스트 (환경·인증 변경) |
/// | C | 웹 ↔ 네이티브 | 요청·응답 (사진 뷰어·공유) |
library;

import 'package:flutter/material.dart';

import 'package:warding/core/util/api_client.dart' as api show appVersion;

/// 웹뷰에 등록하는 JS 채널 이름.
const String kBridgeChannel = 'WardingBridge';

/// 네이티브가 Stage B 를 뿌릴 때 쓰는 DOM 이벤트 접두사.
const String kBridgeEventPrefix = 'warding:';

/// 네이티브가 웹에 토큰을 넘기는 쿠키 이름.
///
/// URL 쿼리로 넘기면 접근 로그·리퍼러에 남고, 로드 후 JS 로 주입하면 SSR
/// 시점에 토큰이 없어 로그인 상태가 한 박자 늦게 채워진다. 쿠키면 **첫
/// 요청부터 서버가 토큰을 들고** API 를 부를 수 있다.
const String kAuthCookieName = 'warding_jwt';

/// Stage A 메시지 종류. 웹이 보내는 쪽이다.
enum BridgeNotify {
  height,
  ready,
  navigate,
  back;

  static BridgeNotify? parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// Stage C 요청 종류. 웹이 결과를 기다린다.
enum BridgeCall {
  openPhotoViewer,
  share;

  static BridgeCall? parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// 이 앱이 처리할 수 있는 브리지 메시지 이름.
///
/// **웹은 배포 즉시 전원에게 가지만 앱은 스토어 심사와 사용자 업데이트를
/// 기다린다.** 웹이 새 메시지를 쓰기 시작하면 구버전 앱은 그걸 모르는데,
/// 지금까지는 Stage A 가 그걸 **조용히 삼켰다** — 버튼이 안 먹는데 아무
/// 단서가 없었다.
///
/// 그래서 **능력 목록을 네이티브가 선언하고 웹이 묻는다.** 조사한 네 사례
/// (Hotwire Native · 토스 · 당근 metabridge · Capacitor)가 모두 같은 모양이고,
/// **메서드명에 `v2` 를 붙이는 곳은 한 곳도 없었다.** 판정 단위는 메서드다.
///
/// **기본값은 웹 폴백이다**(Hotwire 의 핵심 규칙). 웹은 네이티브가 지원할
/// 때만 브리지를 쓰고, 아니면 자기 구현으로 그린다 — 그래야 구버전 앱이
/// 자동으로 안전하다. `share` 가 이미 그렇게 동작한다.
///
/// **메시지를 추가하면 여기도 반드시 추가한다.** 안 하면 웹이 "미지원" 으로
/// 보고 폴백을 그린다 — 조용히 깨지는 것보다 낫지만 기능은 안 나간다.
const List<String> kBridgeCapabilities = [
  // Stage A
  'height',
  'ready',
  'navigate',
  'back',
  // Stage C
  'openPhotoViewer',
  // `share` 는 **아직 네이티브에 없다.** 선언하지 않으므로 웹이 자체 공유
  // (Web Share API 등)로 떨어진다 — 구현되면 여기에 추가한다.
];

/// 네이티브가 웹에 알려 주는 환경.
///
/// 토큰 자체는 쿠키로 가고 여기엔 담지 않는다 — JS 로 읽히는 자리에 토큰을
/// 두 벌 두지 않는다.
class BridgeEnv {
  const BridgeEnv({
    required this.signedIn,
    required this.reduceMotion,
    required this.safeAreaTop,
    required this.safeAreaBottom,
    this.appVersion,
    this.supports = kBridgeCapabilities,
  });

  final bool signedIn;
  final bool reduceMotion;
  final double safeAreaTop;
  final double safeAreaBottom;

  /// 앱 버전(`1.0.42+92`). 웹이 분기에 쓰기보다 **로그·문의 대응**에 쓴다 —
  /// 기능 판정은 [supports] 로 한다(버전 비교는 `1.0.9` vs `1.1.0` 처럼
  /// 자릿수를 독립 비교하다 틀리는 사고가 흔하다).
  final String? appVersion;

  /// 이 앱이 처리할 수 있는 메시지 이름.
  final List<String> supports;

  Map<String, Object?> toJson() => {
        'signedIn': signedIn,
        'reduceMotion': reduceMotion,
        'safeAreaTop': safeAreaTop,
        'safeAreaBottom': safeAreaBottom,
        'supports': supports,
        if (appVersion != null) 'appVersion': appVersion,
      };

  /// 지금 환경을 모은다.
  ///
  /// **조립을 한 곳에 둔다** — 웹뷰 화면이 둘(push 용 `WebViewScreen`,
  /// 탭용 워밍업)이라 각자 만들면 한쪽만 필드를 빠뜨린다. 실제로 능력
  /// 목록을 넣을 때 탭 경로가 빠져 있었다.
  ///
  /// [context] 가 없으면 세이프 에어리어를 0 으로 둔다 — 워밍업처럼 화면에
  /// 붙기 전에 부르는 경로가 있다.
  static BridgeEnv current({
    required bool signedIn,
    BuildContext? context,
  }) {
    final media = context == null ? null : MediaQuery.maybeOf(context);
    return BridgeEnv(
      signedIn: signedIn,
      reduceMotion: media?.disableAnimations ?? false,
      safeAreaTop: media?.padding.top ?? 0,
      safeAreaBottom: media?.padding.bottom ?? 0,
      appVersion: api.appVersion,
    );
  }
}
