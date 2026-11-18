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
  });

  final bool signedIn;
  final bool reduceMotion;
  final double safeAreaTop;
  final double safeAreaBottom;

  Map<String, Object?> toJson() => {
        'signedIn': signedIn,
        'reduceMotion': reduceMotion,
        'safeAreaTop': safeAreaTop,
        'safeAreaBottom': safeAreaBottom,
      };
}
