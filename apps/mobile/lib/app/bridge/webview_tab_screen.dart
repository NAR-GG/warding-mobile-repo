import 'package:flutter/material.dart';

import 'package:warding/app/bridge/webview_screen.dart';
import 'package:warding/app/navigation/tab_navigation.dart';
import 'package:warding/app/navigation/webview_routes.dart';
import 'package:warding/core/theme/app_colors.dart';
import 'package:warding/core/ui/app_bottom_nav.dart';

/// 하단 탭이 붙은 웹뷰 화면.
///
/// **탭 화면만 이것을 쓴다.** 상세·공지처럼 push 로 열리는 화면은
/// [WebViewScreen] 을 그대로 쓴다 — 거긴 탭이 없어야 한다.
///
/// 웹은 **본문만** 그리고 탭은 네이티브가 그린다. 웹뷰가 탭까지 그리면
/// 네이티브 탭과 두 겹이 되고, 탭 전환이 웹 라우팅이 되어 다른 탭(홈·일정)과
/// 섞이지 않는다.
///
/// 웹 본문이 탭에 가리지 않도록 **아래 여백을 웹에 알린다** — 네이티브 탭
/// 높이를 웹이 모르면 마지막 글이 탭 뒤에 숨는다.
class WebViewTabScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: Stack(
        children: [
          WebViewScreen(route: route, params: params),
          Positioned(
            left: 0,
            right: 0,
            // 네이티브 커뮤니티 화면과 같은 위치(`community_screen.dart`).
            bottom: 26,
            child: AppBottomNav(
              currentTab: tab,
              onTabSelected: (next) => handleNavTabSelected(context, tab, next),
            ),
          ),
        ],
      ),
    );
  }
}
