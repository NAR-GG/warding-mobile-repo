import 'package:flutter/material.dart';

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

  static const _boxMainTitle =
      "'Warding'에서 보내는 이벤트 및 알림을 받아보시겠습니까?";
  static const _boxSubTitle =
      '수신 동의 시 이벤트, 경기/팀/선수 등 다양한 정보에 대한 알림을 받아보실 수 있습니다.';
  static const _doneMainTitle = '준비 완료!';
  static const _doneSubTitle = '응원하는 팀과 선수의 경기,\n이제 놓치지 말고 즐겨보세요.';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: viewModel.notificationDone
          ? _buildDoneMessage()
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 45 * scale),
              child: NotificationPermissionBox(
                scale: scale,
                mainTitle: _boxMainTitle,
                subTitle: _boxSubTitle,
                onDeny: viewModel.markNotificationDone,
                onAllow: viewModel.requestNotificationPermission,
              ),
            ),
    );
  }

  /// 알림 권한 단계 완료 후 가운데에 표시되는 메시지.
  Widget _buildDoneMessage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _doneMainTitle,
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
          _doneSubTitle,
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
