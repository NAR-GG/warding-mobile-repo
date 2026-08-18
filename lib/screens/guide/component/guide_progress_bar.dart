import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 가이드 캐러셀 진행 표시.
///
/// 현재 페이지는 49×9 흰색 pill, 나머지는 9×9 회색 점. 시안 gap 12.
class GuideProgressBar extends StatelessWidget {
  const GuideProgressBar({
    super.key,
    required this.count,
    required this.current,
    required this.scale,
  });

  final int count;

  /// 0-based 현재 페이지.
  final int current;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: 12 * scale),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: (i == current ? 49 : 9) * scale,
            height: 9 * scale,
            decoration: BoxDecoration(
              color: i == current ? AppColors.narText : AppColors.narDark300,
              // 활성은 pill, 나머지는 원.
              borderRadius: BorderRadius.circular(9 * scale),
            ),
          ),
        ],
      ],
    );
  }
}
