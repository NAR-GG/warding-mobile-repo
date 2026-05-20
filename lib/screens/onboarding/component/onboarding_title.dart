import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 온보딩 단계의 메인·서브 타이틀.
///
/// 왼쪽 정렬이며 메인 타이틀 아래에 서브 타이틀이 있으면 8 간격으로 표시된다.
class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle({
    super.key,
    required this.mainTitle,
    this.subTitle,
    this.scale = 1.0,
  });

  /// 메인 타이틀 (21px 기준).
  final String mainTitle;

  /// 서브 타이틀 (14px 기준). null 이면 표시하지 않는다.
  final String? subTitle;

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 20 * scale),
          child: Text(
            mainTitle,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 21 * scale,
              height: 14 / 21,
              letterSpacing: 0.21 * scale,
              color: AppColors.narText,
            ),
          ),
        ),
        if (subTitle != null) ...[
          SizedBox(height: 8 * scale),
          Padding(
            padding: EdgeInsets.only(left: 20 * scale),
            child: Text(
              subTitle!,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 1.0,
                letterSpacing: 0.21 * scale,
                color: AppColors.narText2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
