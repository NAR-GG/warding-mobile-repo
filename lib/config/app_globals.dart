import 'package:flutter/widgets.dart';

/// 앱 전역에서 BuildContext 없이 화면 전환을 하기 위한 Navigator 키.
///
/// FCM 알림을 탭했을 때처럼 위젯 트리 밖에서 네비게이션이 필요할 때 쓴다.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
