import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/app/bridge/bridge_handler.dart';
import 'package:warding/app/bridge/bridge_protocol.dart';
import 'package:warding/app/bridge/webview_auth.dart';
import 'package:warding/app/navigation/webview_navigate.dart';
import 'package:warding/app/navigation/webview_routes.dart';
import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/theme/app_colors.dart';
import 'package:warding/core/ui/webview/warding_webview.dart';
import 'package:warding/features/auth/data/auth_service.dart';
import 'package:warding/features/community/presentation/widgets/community_photo_viewer.dart';

/// 웹으로 간 화면을 띄우는 네이티브 껍데기.
///
/// **이 화면 하나가 모든 웹뷰 화면을 맡는다.** 어느 URL 을 열지는
/// `app/navigation/webview_routes.dart` 가 정한다.
///
/// `app/` 에 있는 이유: 인증(`features/auth`)·사진 뷰어(`features/community`)·
/// 네비게이션을 전부 알아야 조립된다 — 기능 2개 이상의 구현을 아는 코드다.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.route,
    this.params = const {},
    this.title,
  });

  final WebRoute route;
  final Map<String, String> params;

  /// 네이티브 앱바 제목. null 이면 앱바를 그리지 않는다(웹이 헤더를 그린다).
  final String? title;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final _auth = WebViewAuth();
  BridgeHandler? _bridge;


  /// 첫 페인트 전까지 덮어 두는 가림막. 흰 플래시와 깜빡임을 막는다.
  bool _ready = false;

  /// 쿠키를 심기 전에는 로드를 시작하지 않는다 — 토큰 없이 로드되면 SSR 이
  /// 비로그인 화면을 그려 버리고, 그게 전환의 이점을 지운다.
  bool _authApplied = false;

  @override
  void initState() {
    super.initState();
    _applyAuth();
  }

  Future<void> _applyAuth() async {
    final token = await AuthService.instance.jwt;
    await _auth.apply(webHost: ApiConfig.webViewHost, token: token);
    if (mounted) setState(() => _authApplied = true);
  }

  void _onControllerCreated(WebViewController controller) {
    final bridge = BridgeHandler(
      controller: controller,
      onHeight: (h) {
        // 지금은 웹뷰가 화면을 꽉 채운다. 네이티브 스크롤 안에 끼울 때 쓴다.
        debugPrint('[Bridge] height=$h');
      },
      onReady: (at) {
        debugPrint('[Bridge] ready at $at');
        if (mounted) setState(() => _ready = true);
      },
      onBack: () {
        debugPrint('[Bridge] back');
        if (mounted) Navigator.of(context).maybePop();
      },
      onNavigate: (route) async {
        if (!mounted) return;
        final opened = await openNativeRoute(context, route);
        // 모르는 이름이면 로그를 남긴다 — 웹이 새 화면을 추가했는데
        // `kNativeRoutes` 에 안 넣은 경우다.
        if (!opened) debugPrint('[Bridge] 모르는 navigate 대상: $route');
      },
      openPhotoViewer: (urls, index) async {
        if (!mounted) return;
        CommunityPhotoViewer.open(context, urls: urls, initialIndex: index);
      },
      share: (url, title) async {
        // 공유 패키지가 아직 없다. 웹이 실패를 받아 자체 대체 동작을 고른다.
        throw UnimplementedError('공유는 아직 네이티브에 없다');
      },
    )..attach();
    _bridge = bridge;
  }

  Future<void> _onPageFinished() async {
    // **가림막을 여기서 걷는다.** 브리지 `ready` 를 기다리면 안 된다 — 그건
    // JS 가 전부 로드되고 하이드레이션이 끝나야 오는 신호라, 서버가 보낸
    // HTML 이 이미 그려졌는데도 화면을 덮고 있게 된다. SSR 로 얻은 이득을
    // 통째로 버리는 셈이다(실측으로 겪었다 — "화면이 엄청 느리다").
    if (mounted && !_ready) setState(() => _ready = true);

    // 웹이 `ready` 를 보내기 전에도 환경은 미리 넣어 둔다. 수신 함수가 아직
    // 없으면 `_push` 가 조용히 넘어간다.
    //
    // **토큰을 먼저 읽고 그다음에 context 를 쓴다.** 순서를 바꾸면 await
    // 뒤에 사라진 위젯의 context 를 건드리게 된다.
    final signedIn = await AuthService.instance.jwt != null;
    if (!mounted) return;

    await _bridge?.broadcastEnv(
      BridgeEnv.current(signedIn: signedIn, context: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      appBar: widget.title == null
          ? null
          : AppBar(
              backgroundColor: AppColors.narDark800,
              title: Text(widget.title!),
            ),
      body: !_authApplied
          // 쿠키를 심기 전에는 로드하지 않는다.
          ? const SizedBox.shrink()
          : SafeArea(
              // 웹이 자기 헤더를 그리므로 네이티브 앱바가 없다. 그대로 두면
              // 제목이 상태바에 가린다 — 상단만 띄운다.
              bottom: false,
              child: Stack(
                children: [
                  WardingWebView(
                    initialUrl: widget.route.url(params: widget.params),
                    onControllerCreated: _onControllerCreated,
                    onPageFinished: _onPageFinished,
                  ),
                  // 가림막은 **첫 HTML 이 그려지기 전**에만 덮는다
                  // (`onPageFinished` 에서 걷는다). 웹뷰 배경색이 이미
                  // 같은 토큰이라 흰 플래시는 그것만으로 막히지만, 직전
                  // 화면이 잠깐 비치는 것을 막으려고 남겨 둔다.
                  if (!_ready)
                    const ColoredBox(
                      color: AppColors.narDark800,
                      child: SizedBox.expand(),
                    ),
                ],
              ),
            ),
    );
  }
}
