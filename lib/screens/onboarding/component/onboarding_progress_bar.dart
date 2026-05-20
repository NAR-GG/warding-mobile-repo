import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 온보딩 진행도 바.
///
/// 진행된 구간은 점·선이 하나로 이어진 [AppColors.narBg] 그라데이션 막대로,
/// 진행되지 않은 단계는 [AppColors.narDark300] 점으로 표시된다.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  /// 전체 온보딩 단계 수.
  final int totalSteps;

  /// 현재 진행 중인 단계 (0-based).
  final int currentStep;

  /// 점 지름 / 막대 두께.
  static const double _dotSize = 6;

  @override
  Widget build(BuildContext context) {
    final clampedStep = currentStep.clamp(0, totalSteps - 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: _dotSize,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // 점 사이 간격 (양 끝 점 포함 균등 배치)
            final gap = totalSteps > 1
                ? (width - _dotSize) / (totalSteps - 1)
                : 0.0;
            // 진행 막대 = 점0 ~ 점(currentStep + 1) 을 잇는 길이.
            // 첫 페이지(currentStep 0)는 첫 점 ~ 두 번째 점까지 이어진다.
            final progressWidth = (clampedStep + 1) * gap + _dotSize;

            return Stack(
              children: [
                // 진행되지 않은 단계 점들
                for (var i = clampedStep + 2; i < totalSteps; i++)
                  Positioned(
                    left: i * gap,
                    child: Container(
                      width: _dotSize,
                      height: _dotSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.narDark300,
                      ),
                    ),
                  ),
                // 진행 막대 (점·선이 하나로 이어진 그라데이션)
                Positioned(
                  left: 0,
                  child: Container(
                    width: progressWidth,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      gradient: AppColors.narBg,
                      borderRadius: BorderRadius.circular(_dotSize / 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
