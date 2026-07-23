import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_button.dart';
import '../../../styles/app_colors.dart';

/// 알림 권한 단계의 안내 박스.
///
/// narDark600 배경의 둥근 박스 안에 메인·서브 타이틀과
/// '허용 안 함' / '허용' 버튼을 담는다.
class NotificationPermissionBox extends StatelessWidget {
  const NotificationPermissionBox({
    super.key,
    required this.mainTitle,
    required this.subTitle,
    this.onAllow,
    this.onDeny,
    this.scale = 1.0,
  });

  /// 박스 안 메인 타이틀 (18px 기준).
  final String mainTitle;

  /// 박스 안 서브 타이틀 (16px 기준).
  final String subTitle;

  /// '허용' 버튼 콜백.
  final VoidCallback? onAllow;

  /// '허용 안 함' 버튼 콜백.
  final VoidCallback? onDeny;

  /// 디자인 시안(285×227) 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      // 고정 높이를 두지 않고 내용에 맞춰 늘어나게 한다 — 안내 문구가
      // 줄바꿈으로 길어져도 세로 오버플로가 발생하지 않는다.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mainTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 18 * scale,
              height: 1.45,
              letterSpacing: 0.21 * scale,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            subTitle,
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
          SizedBox(height: 16 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NarButton(
                label: l.deny,
                variant: NarButtonVariant.type2,
                scale: scale,
                onPressed: onDeny,
              ),
              NarButton(
                label: l.allow,
                variant: NarButtonVariant.type1,
                scale: scale,
                onPressed: onAllow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
