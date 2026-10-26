import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 공용 진행 막대 — 둥근 트랙 위에 [value] 비율만큼 채운다.
///
/// 승률 막대·분포 막대처럼 "가로로 비율을 보이는" 자리에 쓴다.
/// `LinearProgressIndicator` 대신 [FractionallySizedBox] 로 그려서 앱의 다른
/// 막대들(평점 분포·팀 지표)과 같은 방식·같은 모서리를 쓴다.
class NarProgressBar extends StatelessWidget {
  const NarProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.scale,
    this.height = 4,
    this.trackColor = AppColors.narDark500,
  });

  /// 채움 비율 0~1. 범위를 벗어나면 잘라 쓴다.
  final double value;
  final Color color;

  /// 막대 높이(기본 4).
  final double height;
  final Color trackColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2 * scale);
    return Container(
      height: height * scale,
      decoration: BoxDecoration(color: trackColor, borderRadius: radius),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
      ),
    );
  }
}
