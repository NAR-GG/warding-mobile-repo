import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../styles/app_colors.dart';
import '../../../viewmodel/onboarding/onboarding_viewmodel.dart';
import '../component/notification_permission_box.dart';

/// 알림 권한 단계 (View).
///
/// 미완료 시 안내 박스를, 완료 시 '준비 완료!' 메시지를 보여준다.
/// 권한 상태는 [OnboardingViewModel] 에서 가져온다.
class NotificationStep extends StatelessWidget {
  const NotificationStep({
    super.key,
    required this.viewModel,
    this.scale = 1.0,
  });

  final OnboardingViewModel viewModel;

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: viewModel.notificationDone
          ? _buildDoneMessage(context)
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 45 * scale),
              child: NotificationPermissionBox(
                scale: scale,
                mainTitle: l.notificationQuestion,
                subTitle: l.notificationConsentMessage,
                onDeny: viewModel.markNotificationDone,
                onAllow: viewModel.requestNotificationPermission,
              ),
            ),
    );
  }

  /// 알림 권한 단계 완료 후 가운데에 표시되는 메시지.
  Widget _buildDoneMessage(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.readyComplete,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 21 * scale,
            height: 14 / 21,
            letterSpacing: 0.21 * scale,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          l.enjoyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 16 * scale,
            height: 1.45,
            letterSpacing: 0.21 * scale,
            color: AppColors.narText,
          ),
        ),
      ],
    );
  }
}
