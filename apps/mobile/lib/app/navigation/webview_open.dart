import 'package:flutter/material.dart';

import 'package:warding/app/bridge/webview_screen.dart';
import 'package:warding/app/navigation/webview_routes.dart';

/// 기능 화면에서 웹뷰 화면으로 가는 **창구**.
///
/// 기능이 `WebViewScreen` 을 직접 쓰면 `features/` → `app/bridge/` 를 알게
/// 된다. 경기 상세가 `match_detail_router.dart` 한 곳으로 모이는 것과 같은
/// 이유로, 웹뷰 진입도 `app/navigation/` 에 모은다 — 어느 화면이 웹으로
/// 갔는지는 [webviewRoutes] 가, 어떻게 여는지는 여기가 답한다.
///
/// 탭 화면은 여기를 쓰지 않는다. 워밍업한 컨트롤러를 재사용해야 해서
/// `WebViewTabScreen` 이 따로 있다(`tab_navigation.dart` 가 조립한다).
Future<void> openWebRoute(
  BuildContext context, {
  required WebRoute route,
  Map<String, String> params = const {},
  required String analyticsPage,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: analyticsPage),
      builder: (_) => WebViewScreen(route: route, params: params),
    ),
  );
}
