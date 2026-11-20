import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/app/bridge/bridge_handler.dart';
import 'package:warding/app/bridge/webview_screen.dart';
import 'package:warding/app/bridge/webview_warmup.dart';
import 'package:warding/app/navigation/tab_navigation.dart';
import 'package:warding/app/navigation/webview_routes.dart';
import 'package:warding/core/theme/app_colors.dart';
import 'package:warding/core/ui/app_bottom_nav.dart';
import 'package:warding/features/community/presentation/widgets/community_photo_viewer.dart';

/// 하단 탭이 붙은 웹뷰 화면.
///
/// **미리 데워 둔 웹뷰를 재사용한다**(→ [WebViewWarmup]). 탭마다 새로 만들면
/// WKWebView 생성·JS 하이드레이션으로 1.5초가 걸리는데, 그 비용을 앱 시작
/// 때 한 번만 치른다.
///
/// 워밍업이 아직 안 됐거나 실패했으면 **평소대로 새로 만든다**([WebViewScreen]).
/// 최적화가 없는 경로로 조용히 떨어질 뿐 화면이 안 뜨지는 않는다.
///
/// 웹은 **본문만** 그리고 탭은 네이티브가 그린다. 웹뷰가 탭까지 그리면
/// 네이티브 탭과 두 겹이 되고, 탭 전환이 웹 라우팅이 되어 다른 탭(홈·일정)
/// 으로 갈 수 없다.
class WebViewTabScreen extends StatefulWidget {
  const WebViewTabScreen({
    super.key,
    required this.route,
    required this.tab,
    this.params = const {},
  });

  final WebRoute route;

  /// 이 화면이 속한 탭. 하단 네비의 활성 표시에 쓴다.
  final AppNavTab tab;

  final Map<String, String> params;

  @override
  State<WebViewTabScreen> createState() => _WebViewTabScreenState();
}

class _WebViewTabScreenState extends State<WebViewTabScreen> {
  final _warmup = WebViewWarmup.instance;
  BridgeHandler? _bridge;

  @override
  void initState() {
    super.initState();

    final controller = _warmup.controller;
    if (controller == null) return;

    _attachBridge(controller);

    // **`reload()` 를 부르지 않는다.** 들어올 때마다 전체를 다시 받으면
    // 로드·하이드레이션을 또 치르게 되어 워밍업으로 아낀 것을 그대로
    // 반납한다(실측: 탭 전환마다 1.4~2.1초짜리 재로드가 돌았다).
    //
    // 내용이 낡는 문제는 **웹이 푼다** — 목록은 `revalidate: 15` 라 서버가
    // 15초마다 다시 받고, 글을 쓰거나 좋아요를 누르면 그 자리에서 갱신된다.
    // 그래도 부족하면 당겨서 새로고침(pull-to-refresh)을 웹에 붙이는 쪽이
    // 네이티브가 통째로 리로드하는 것보다 싸다.

    // 로드가 아직이면 끝났을 때 다시 그린다(가림막 제거).
    _warmup.onLoaded = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    // 컨트롤러는 워밍업이 들고 있으므로 버리지 않는다. 브리지만 뗀다 —
    // 다음 진입에서 새 화면이 다시 붙인다.
    _bridge?.detach();
    _warmup.onLoaded = null;
    super.dispose();
  }

  void _attachBridge(WebViewController controller) {
    _bridge = BridgeHandler(
      controller: controller,
      onHeight: (_) {},
      onReady: (_) {
        if (mounted) setState(() {});
      },
      // 탭 화면은 되돌아갈 네이티브 화면이 없다 — 웹이 자체 히스토리를
      // 먼저 쓰므로 여기 오는 것은 "웹에서도 되돌릴 곳이 없다" 는 뜻이다.
      onBack: () {},
      onNavigate: (route) {
        debugPrint('[Bridge] navigate 요청: $route (미구현)');
      },
      openPhotoViewer: (urls, index) async {
        if (!mounted) return;
        CommunityPhotoViewer.open(context, urls: urls, initialIndex: index);
      },
      share: (url, title) async {
        throw UnimplementedError('공유는 아직 네이티브에 없다');
      },
    )..attach();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _warmup.controller;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: Stack(
        children: [
          if (controller == null)
            // 워밍업 전이면 평소 경로로 만든다.
            WebViewScreen(route: widget.route, params: widget.params)
          else
            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  WebViewWidget(controller: controller),
                  if (!_warmup.loaded)
                    const ColoredBox(
                      color: AppColors.narDark800,
                      child: SizedBox.expand(),
                    ),
                ],
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            // 네이티브 커뮤니티 화면과 같은 위치(`community_screen.dart`).
            bottom: 26,
            child: AppBottomNav(
              currentTab: widget.tab,
              onTabSelected: (next) =>
                  handleNavTabSelected(context, widget.tab, next),
            ),
          ),
        ],
      ),
    );
  }
}
