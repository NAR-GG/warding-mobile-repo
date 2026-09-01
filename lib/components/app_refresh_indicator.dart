import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../styles/app_colors.dart';

/// 앱 공용 '당겨서 새로고침'.
///
/// [RefreshIndicator] 를 직접 쓰지 않고 이걸 쓴다. 기본값이 Material 파란색이라
/// 화면마다 색을 따로 지정해야 하는데, 실제로 어떤 화면은 지정하고 어떤 화면은
/// 빠뜨려서 같은 동작이 화면마다 다른 색으로 돌고 있었다.
///
/// 새로고침이 끝나면 기본으로 "반영 완료!" 스낵바를 짧게 띄운다 — 당겨서
/// 새로고침은 인디케이터가 순식간에 사라져서 실제로 반영이 됐는지 체감이
/// 안 된다는 피드백이 있었다. 스낵바가 필요 없는 화면([showCompleteSnackBar]
/// 를 false로)만 끈다.
///
/// 스크롤 물리도 함께 정한다. 목록이 짧아 스크롤이 생기지 않는 상태
/// (로딩 실패·빈 목록·경기 전 잠금 안내)에서도 당길 수 있어야 하는데, 그건
/// 자식 스크롤 뷰가 [AlwaysScrollableScrollPhysics] 여야 성립한다. 화면이 그걸
/// 잊으면 **정작 새로고침이 가장 필요한 순간에만** 동작하지 않으므로,
/// [physics] 를 기본값으로 노출해 자식에 그대로 넘겨 쓰게 한다.
///
/// ```dart
/// AppRefreshIndicator(
///   onRefresh: _viewModel.refresh,
///   child: ListView.builder(
///     physics: AppRefreshIndicator.physics,
///     ...
///   ),
/// )
/// ```
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.showCompleteSnackBar = true,
  });

  /// 당겼을 때 실행할 새로고침. 이 Future 가 끝나면 인디케이터가 사라지므로,
  /// 안에서 예외를 던지면 인디케이터가 멈춘 채로 남는다 — 호출부가 삼켜야 한다.
  final Future<void> Function() onRefresh;

  final Widget child;

  /// 새로고침이 성공적으로 끝나면 "반영 완료!" 스낵바를 띄울지. 화면을 나가는
  /// 전환(pull-to-refresh 로 화면이 곧 사라지는 경우 등)에서만 false 로 끈다.
  final bool showCompleteSnackBar;

  /// 자식 스크롤 뷰에 넘길 물리. 내용이 짧아도 당길 수 있게 한다.
  static const ScrollPhysics physics = AlwaysScrollableScrollPhysics();

  Future<void> _handleRefresh(BuildContext context) async {
    await onRefresh();
    if (!showCompleteSnackBar || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.refreshDone),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.narDark600,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context),
      color: AppColors.narText,
      backgroundColor: AppColors.narDark600,
      child: child,
    );
  }
}
