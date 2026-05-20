import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onSkip,
    this.skipLabel = '건너뛰기',
  });

  final String title;

  final VoidCallback onBack;

  final VoidCallback? onSkip;

  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8, left: 4),
        child: Stack(
          children: [
            // 가운데 타이틀
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  height: 22 / 18,
                  letterSpacing: 0,
                  color: AppColors.narText,
                ),
              ),
            ),
            // 왼쪽 뒤로가기
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SvgPicture.asset(
                    'assets/icons/chevron-left.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
            // 오른쪽 건너뛰기 버튼
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 85,
                height: 44,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.narText2,
                  ),
                  child: Text(
                    skipLabel,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 34 / 14,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
