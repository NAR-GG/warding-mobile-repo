import 'package:flutter/widgets.dart';

/// 앱 전역에서 BuildContext 없이 화면 전환을 하기 위한 Navigator 키.
///
/// FCM 알림을 탭했을 때처럼 위젯 트리 밖에서 네비게이션이 필요할 때 쓴다.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 마이구독 알림 피드를 다시 읽어야 할 때 올리는 카운터.
///
/// 피드는 화면 진입·앱 복귀 때만 서버에서 다시 읽는다. 그래서 앱이 떠 있는 채로
/// 푸시를 받으면(그 화면에 머물러 있으면 특히) 방금 온 알림이 목록에 없었다 —
/// 생명주기 이벤트도, 화면 재생성도 일어나지 않기 때문이다.
/// [FcmService] 가 포그라운드 수신 때 값을 올리고, 마이구독 화면이 듣고 다시 읽는다.
final ValueNotifier<int> feedRefreshTick = ValueNotifier<int>(0);
