import 'package:flutter/material.dart';

import 'package:warding/core/util/analytics_events.dart';
import 'package:warding/features/login/presentation/screens/login_screen.dart';
import 'package:warding/features/notification/presentation/screens/notification_screen.dart';

/// 웹이 요청하는 네이티브 화면 이동(Stage A `navigate`)의 **단일 출처**.
///
/// 웹은 화면 이름만 보내고(`requestNavigate('notification')`) 어느 위젯을
/// 띄울지는 네이티브가 정한다 — 웹이 Flutter 화면을 알 필요가 없다.
///
/// **이름을 추가하면 여기만 고친다.** `kBridgeCapabilities` 의 `navigate` 는
/// "이 메시지를 처리할 수 있다" 를 뜻하고, 어떤 대상을 아는지는 이 표가
/// 답한다. 모르는 이름은 [openNativeRoute] 가 false 를 돌려준다.
///
/// 웹 쪽 짝은 `requestNavigate` 호출부다. 코드 생성이 없으므로 이름이
/// 어긋나면 런타임에야 드러난다.
class NativeRoute {
  const NativeRoute({required this.analyticsPage, required this.builder});

  /// 화면 전환 계측에 쓰는 이름.
  final String analyticsPage;

  final WidgetBuilder builder;
}

/// 웹이 열 수 있는 네이티브 화면.
///
/// **표와 빌더를 한 자리에 둔다** — 둘로 나누면 이름만 추가하고 빌더를
/// 빠뜨려도 컴파일이 통과한다.
final Map<String, NativeRoute> kNativeRoutes = {
  // 커뮤니티 알림함. 벨은 웹이 그리고 화면은 네이티브가 연다 —
  // 커뮤니티 밖 저장소를 읽고 앱 생명주기·푸시 신호에 묶여 있다.
  'notification': NativeRoute(
    analyticsPage: AnalyticsPage.notification,
    builder: (_) => const NotificationScreen(),
  ),
  // 로그인. **웹에 로그인 화면이 없다** — 카카오·네이버 SDK 가 네이티브에
  // 있어서 웹으로 옮길 수 없다. 평점 작성처럼 로그인이 필요한 자리에서
  // 웹이 이 이름을 보낸다.
  //
  // 돌아오면 쿠키가 새로 심기므로(`webview_auth.dart`) 웹을 다시 로드해야
  // 로그인 상태가 반영된다 — 그 일은 `WebViewScreen` 이 복귀 시 한다.
  'login': NativeRoute(
    analyticsPage: AnalyticsPage.login,
    builder: (_) => const LoginScreen(),
  ),
};

/// 이름으로 네이티브 화면을 연다. 모르는 이름이면 false.
///
/// **열었는지를 돌려준다.** 전에는 `debugPrint` 만 하고 끝나서, 웹은 보냈다고
/// 믿고 사용자는 버튼이 안 먹는 이유를 몰랐다 — `navigate` 가 능력 목록에
/// 선언돼 있는데 구현이 비어 있었다(`share` 는 미선언이라 웹이 폴백을
/// 골랐는데, 이쪽은 정반대였다).
Future<bool> openNativeRoute(BuildContext context, String name) async {
  final route = kNativeRoutes[name];
  if (route == null) return false;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: route.analyticsPage),
      builder: route.builder,
    ),
  );
  return true;
}
