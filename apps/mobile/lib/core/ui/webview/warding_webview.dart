import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/core/theme/app_colors.dart';

/// 웹뷰 컨테이너 **하나**.
///
/// 기능별로 복제하지 않는다 — 그러면 URL 만 다른 거의 같은 파일이 수십 개가
/// 된다. URL 과 브리지 조립은 쓰는 쪽이 넘긴다.
///
/// `core/ui/` 에 있는 이유: 도메인을 모르고 화면을 띄우지도 않는다. 어떤 URL 을
/// 어느 화면에서 여는지는 `app/` 이 정한다.
class WardingWebView extends StatefulWidget {
  const WardingWebView({
    super.key,
    required this.initialUrl,
    this.onControllerCreated,
    this.onPageFinished,
  });

  final String initialUrl;

  /// 컨트롤러가 만들어진 직후. 브리지 채널은 **로드 시작 전에** 붙여야
  /// 첫 메시지를 놓치지 않는다.
  final void Function(WebViewController controller)? onControllerCreated;

  final VoidCallback? onPageFinished;

  @override
  State<WardingWebView> createState() => _WardingWebViewState();
}

class _WardingWebViewState extends State<WardingWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 로드 전 흰 플래시를 막는다. 네이티브 배경과 같은 토큰을 쓴다 —
      // 다크 테마라 이것이 체감 품질에 가장 크게 영향한다.
      ..setBackgroundColor(AppColors.narDark800)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => widget.onPageFinished?.call(),
        ),
      );

    // 채널 등록이 먼저다. 그 다음에 로드한다.
    widget.onControllerCreated?.call(_controller);
    _controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
