import 'package:flutter/material.dart';

/// 하단 네비 탭 전환용 무애니메이션 라우트.
///
/// 탭 사이를 [Navigator.pushReplacement] 로 오갈 때 슬라이드 전환이
/// 끼면 탭처럼 느껴지지 않으므로 전환 시간을 0 으로 둔다.
Route<void> tabRoute(Widget page) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
);
