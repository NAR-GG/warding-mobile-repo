import 'package:flutter/material.dart';

import '../component/onboarding_title.dart';

/// 선호 리그 선택 단계 (View).
class LeagueStep extends StatelessWidget {
  const LeagueStep({super.key, this.scale = 1.0});

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 48 * scale),
        OnboardingTitle(
          mainTitle: '즐겨 시청하는 리그는 무엇인가요?',
          scale: scale,
        ),
        // TODO: 리그 선택 그리드
      ],
    );
  }
}
