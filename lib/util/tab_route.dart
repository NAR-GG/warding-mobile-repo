import 'package:flutter/material.dart';
import 'analytics_events.dart';

/// 하단 네비 탭 전환용 무애니메이션 라우트.
///
/// 탭 사이를 [Navigator.pushReplacement] 로 오갈 때 슬라이드 전환이
/// 끼면 탭처럼 느껴지지 않으므로 전환 시간을 0 으로 둔다.
///
/// [page] 에 `location_page` 값([AnalyticsPage])을 주면 `page_view` 가
/// 자동으로 찍힌다([AnalyticsRouteObserver]). 생략하면 그 탭의 `page_view`
/// 가 누락되므로 탭 전환에서는 항상 넘긴다.
Route<void> tabRoute(Widget page, {String? name}) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  settings: name == null ? null : RouteSettings(name: name),
);
