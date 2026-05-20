import 'package:flutter/material.dart';

import '../component/onboarding_title.dart';

/// 선호 선수 선택 단계 (View).
class PlayerStep extends StatelessWidget {
  const PlayerStep({super.key, this.scale = 1.0});

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 48 * scale),
        OnboardingTitle(
          mainTitle: '응원하는 선수를 선택해주세요',
          subTitle: 'LCK 국내 팀 기준입니다. (중복 가능)',
          scale: scale,
        ),
        // TODO: 선수 선택 그리드
      ],
    );
  }
}
