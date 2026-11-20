import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/app/bridge/bridge_protocol.dart';
import 'package:warding/app/bridge/webview_auth.dart';
import 'package:warding/app/navigation/webview_routes.dart';
import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/theme/app_colors.dart';
import 'package:warding/features/auth/data/auth_service.dart';

/// 탭 웹뷰를 **미리 만들어 두고 재사용한다.**
///
/// 왜 필요한가 — 탭을 누를 때마다 웹뷰를 새로 만들면 1.5초가 걸린다
/// (실측 2026-11-20, iOS 시뮬레이터):
///
/// | 구간 | 시간 |
/// |---|---|
/// | 쿠키 심기 | 330ms |
/// | WKWebView 생성 | ~400ms |
/// | HTML 수신 | **13ms** |
/// | JS 하이드레이션 | ~800ms |
///
/// **서버는 13ms 다.** 나머지가 전부 네이티브·브라우저 초기화라, 아무리
/// 웹을 가볍게 해도 매번 새로 만드는 한 줄어들지 않는다. 클라이언트
/// 컴포넌트를 하나라도 쓰면 React 런타임(800KB)이 딸려오고, 그 파싱·실행이
/// 하이드레이션 시간의 대부분이다 — 우리 화면 코드는 3KB 뿐이다.
///
/// 그래서 **앱이 뜰 때 한 번 만들어 로드해 두고**, 탭 전환에서는 그 컨트롤러를
/// 그대로 보여 준다.
///
/// **한계를 적어 둔다.**
/// - 웹뷰 하나가 계속 메모리에 상주한다. 탭 화면은 어차피 앱 수명 내내
///   살아 있는 것이라 받아들인다.
/// - 상세·검색·글쓰기처럼 push 로 열리는 화면은 여전히 새로 만든다. 그쪽은
///   사용자가 "뭔가 열린다" 를 기대하는 전환이라 체감이 다르다.
/// - 데이터가 낡을 수 있다 — 탭에 들어올 때 [refresh] 로 다시 받는다.
class WebViewWarmup {
  WebViewWarmup._();

  static final WebViewWarmup instance = WebViewWarmup._();

  WebViewController? _controller;

  /// 첫 로드가 끝났는가. 가림막을 걷는 기준이다.
  bool _loaded = false;
  bool get loaded => _loaded;

  /// 로드가 실패했는가.
  ///
  /// **이걸 안 보면 스켈레톤이 영원히 떠 있는다.** 네트워크가 끊기거나
  /// 서버가 죽으면 `onPageFinished` 가 오지 않아 [loaded] 가 false 로
  /// 남는데, 화면은 "곧 뜨겠지" 하며 계속 기다린다.
  bool _failed = false;
  bool get failed => _failed;

  /// 준비된 컨트롤러. 아직 데우지 않았으면 null.
  WebViewController? get controller => _controller;

  /// 컨트롤러가 만들어졌을 때 호출된다 — 브리지를 붙이는 쪽이 받는다.
  void Function(WebViewController controller)? onControllerCreated;

  /// 로드 상태가 바뀌었다(성공·실패). 화면이 붙어 있으면 다시 그린다.
  VoidCallback? onLoaded;

  /// 앱이 뜬 뒤 **한 번** 부른다. 두 번째부터는 아무 일도 하지 않는다.
  ///
  /// 실패해도 조용히 넘어간다 — 워밍업은 최적화지 필수 경로가 아니다.
  /// 안 되면 탭에서 평소대로 새로 만든다.
  Future<void> warm() async {
    if (_controller != null) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.narDark800);

    _controller = controller;

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          _loaded = true;
          _failed = false;
          onLoaded?.call();
          // 능력 목록을 알린다 — 이게 없으면 웹이 `isSupported()` 에서
          // 전부 false 를 받아 브리지를 아예 안 쓴다.
          unawaited(_broadcastEnv());
        },
        onWebResourceError: (error) {
          // **메인 문서가 실패했을 때만 막는다.** 이미지 하나가 404 라고
          // 화면을 에러로 덮으면 안 된다 — 글은 멀쩡히 읽힌다.
          if (error.isForMainFrame != true) return;

          debugPrint('[Warmup] 로드 실패: ${error.errorCode} ${error.description}');
          _failed = true;
          onLoaded?.call();
        },
      ),
    );

    onControllerCreated?.call(controller);

    // 쿠키를 먼저 심는다 — 토큰 없이 로드되면 SSR 이 비로그인 화면을 그린다.
    final token = await AuthService.instance.jwt;
    await WebViewAuth().apply(webHost: ApiConfig.webViewHost, token: token);

    await controller.loadRequest(
      Uri.parse(communityListRoute.url()),
    );
  }

  /// 환경(능력 목록·로그인 여부)을 웹에 알린다.
  ///
  /// **컨트롤러로 직접 보낸다.** 로드가 끝나는 시점에 탭 화면이 아직 안
  /// 붙어 있을 수 있어서(워밍업은 백그라운드다) 브리지 핸들러를 기다리면
  /// 능력 목록을 영영 못 받는 경우가 생긴다.
  Future<void> _broadcastEnv() async {
    final c = _controller;
    if (c == null) return;

    final env = BridgeEnv.current(
      signedIn: await AuthService.instance.jwt != null,
    );
    final payload = jsonEncode(jsonEncode({'type': 'env', 'env': env.toJson()}));
    try {
      await c.runJavaScript(
        'window.__wardingReceive && window.__wardingReceive($payload)',
      );
    } catch (e) {
      // 웹 수신기가 아직 없으면 조용히 넘어간다 — 화면이 붙을 때 다시 보낸다.
      debugPrint('[Warmup] env 전달 실패: $e');
    }
  }

  /// 실패한 로드를 다시 시도한다.
  ///
  /// 사용자가 "다시 시도" 를 눌렀을 때 쓴다. 성공하면 `onPageFinished` 가
  /// [_failed] 를 내린다.
  Future<void> retry() async {
    final c = _controller;
    if (c == null) return;

    _failed = false;
    onLoaded?.call();
    await c.loadRequest(Uri.parse(communityListRoute.url()));
  }

  /// 탭에 다시 들어왔을 때 데이터를 새로 받는다.
  ///
  /// 살려 두는 대가로 내용이 낡는다 — 글이 올라왔는데 안 보이면 안 된다.
  Future<void> refresh() async {
    final c = _controller;
    if (c == null) return;
    await c.reload();
  }
}
