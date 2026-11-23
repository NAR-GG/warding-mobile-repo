import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:warding/core/theme/app_colors.dart';
import 'package:warding/core/ui/webview/external_link.dart';

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
    required this.webHost,
    this.onControllerCreated,
    this.onPageFinished,
  });

  final String initialUrl;

  /// 우리 웹의 주소(스킴 포함). 이 호스트 밖으로 나가는 링크는 바깥
  /// 브라우저로 보낸다 — `core/ui/` 는 설정을 모르므로 쓰는 쪽이 넘긴다.
  final String webHost;

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
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    // 웹 콘솔을 네이티브 로그로 뺀다. 웹뷰 안에서 무슨 일이 나는지 볼
    // 방법이 이것뿐이다 — Safari 개발자도구를 붙이지 않으면 에러도 조용히
    // 묻힌다. 디버그 빌드에서만 찍는다.
    if (kDebugMode) {
      _controller.setOnConsoleMessage(
        (msg) => debugPrint('[web] ${msg.level.name}: ${msg.message}'),
      );
    }

    _enableAndroidFileSelector();

    // 채널 등록이 먼저다. 그 다음에 로드한다.
    widget.onControllerCreated?.call(_controller);
    _controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  /// 외부 링크를 **바깥 브라우저로** 보낸다.
  ///
  /// 규칙 자체는 [shouldOpenInWebView] 에 있다(테스트가 그걸 본다). 여기서는
  /// 거절한 주소를 실제로 여는 것까지 한다 — 막기만 하고 열지 않으면
  /// 사용자에겐 "버튼이 안 먹는" 것과 같다.
  ///
  /// **여는 데 실패해도 웹뷰 안에서 열지 않는다.** 되돌아갈 길이 없는 화면에
  /// 가두는 것이 아무 일도 안 일어나는 것보다 나쁘다.
  Future<NavigationDecision> _onNavigationRequest(NavigationRequest request) async {
    if (shouldOpenInWebView(request.url, webHost: widget.webHost)) {
      return NavigationDecision.navigate;
    }

    try {
      await launchUrl(
        Uri.parse(request.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[WebView] 외부 링크를 열지 못했다: ${request.url} ($e)');
    }
    return NavigationDecision.prevent;
  }

  /// `<input type="file">` 을 Android 에서 살린다.
  ///
  /// **iOS 는 필요 없다** — WKWebView 가 파일 선택 패널을 자체 처리한다.
  /// Android 는 이 콜백을 등록하지 않으면 입력을 눌러도 **아무 반응이 없다**
  /// (`setOnShowFileSelector` 는 `webview_flutter_android` 에만 있는 API 다).
  ///
  /// 리사이즈는 **웹이 한다**(canvas). 여기서 `maxWidth` 를 주면 웹의 리사이즈와
  /// 두 번 줄어들어 Android 만 화질이 나빠진다 — 원본 경로를 그대로 넘긴다.
  void _enableAndroidFileSelector() {
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) return;

    platform.setOnShowFileSelector((params) async {
      final picker = ImagePicker();
      // 웹이 `multiple` 을 주는지에 맞춘다. 한 장만 받는 입력에 여러 장을
      // 돌려주면 웹이 첫 장만 쓰고 나머지는 조용히 버려진다.
      if (params.mode == FileSelectorMode.openMultiple) {
        final files = await picker.pickMultiImage();
        return files.map((f) => Uri.file(f.path).toString()).toList();
      }
      final file = await picker.pickImage(source: ImageSource.gallery);
      return file == null ? <String>[] : [Uri.file(file.path).toString()];
    });
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
