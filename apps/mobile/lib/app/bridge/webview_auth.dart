import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/app/bridge/bridge_protocol.dart';

/// 웹뷰에 인증 토큰을 쿠키로 심는다.
///
/// **URL 쿼리나 JS 주입 대신 쿠키를 쓰는 이유:**
/// - URL 쿼리는 접근 로그·리퍼러에 토큰이 남는다.
/// - 로드 후 JS 주입은 SSR 시점에 토큰이 없어, 좋아요·스크랩 상태가 한 박자
///   늦게 채워지며 깜빡인다.
///
/// 쿠키면 **첫 요청부터 Next 서버가 토큰을 들고** API 를 부를 수 있어 로그인
/// 상태까지 SSR 로 그려진다.
///
/// **한계를 적어 둔다.** `webview_flutter` 의 쿠키 API 에는 `httpOnly` 플래그가
/// 없어 JS 로 읽힌다. 웹뷰가 우리 페이지만 띄우므로 외부 스크립트가 끼어들
/// 자리는 없지만, **서드파티 스크립트를 넣게 되면 이 전제가 깨진다.**
class WebViewAuth {
  WebViewAuth({WebViewCookieManager? cookies})
      : _cookies = cookies ?? WebViewCookieManager();

  final WebViewCookieManager _cookies;

  /// 마지막으로 심은 값. 같은 값이면 다시 심지 않는다.
  ///
  /// **`setCookie` 가 생각보다 비싸다 — 실측 314ms**(플랫폼 채널 왕복,
  /// 2026-11-20 iOS 시뮬레이터). 화면을 열 때마다 심으면 그 시간이 매번
  /// 로드를 막는다. 쿠키는 도메인 단위라 한 번 심으면 모든 웹뷰 화면에
  /// 걸리므로, 값이 그대로면 건너뛴다.
  ///
  /// `static` 인 이유: 화면마다 `WebViewAuth` 인스턴스가 새로 생기는데,
  /// 쿠키 저장소는 앱 전체에 하나뿐이다.
  ///
  /// **키에 토큰 값이 들어 있어** 로그인·로그아웃·재발급으로 값이 바뀌면
  /// 저절로 다시 심는다 — 따로 무효화를 부를 필요가 없다.
  static String? _lastApplied;

  /// 토큰을 심는다. `token` 이 null 이면 비로그인 상태로 둔다.
  ///
  /// [webHost] 는 웹이 떠 있는 오리진(`https://nar.kr` 등)이고, 쿠키 도메인은
  /// 거기서 뽑는다 — API 서버가 아니라 **웹 서버**에 가야 Next 가 읽는다.
  Future<void> apply({required String webHost, required String? token}) async {
    final host = Uri.tryParse(webHost)?.host;
    if (host == null || host.isEmpty) {
      debugPrint('[WebViewAuth] webHost 를 해석하지 못했다: $webHost');
      return;
    }

    // 비로그인이면 빈 값을 심어 이전 토큰을 덮는다. 쿠키 삭제 API 가 전체
    // 삭제(clearCookies)뿐이라, 다른 쿠키까지 날리지 않으려면 이 편이 낫다.
    final value = token ?? '';

    // 같은 값이면 건너뛴다 — 심는 데 314ms 가 든다(위 주석).
    final key = '$host|$value';
    if (_lastApplied == key) return;

    await _cookies.setCookie(
      WebViewCookie(
        name: kAuthCookieName,
        value: value,
        domain: host,
      ),
    );
    _lastApplied = key;
  }

  /// 로그아웃 등으로 모든 쿠키를 지운다.
  Future<void> clear() async {
    // 캐시를 먼저 비운다 — 안 그러면 다음 `apply` 가 "이미 심었다" 로 보고
    // 건너뛰어, 지워진 쿠키가 되살아나지 않는다.
    _lastApplied = null;
    await _cookies.clearCookies();
  }
}
