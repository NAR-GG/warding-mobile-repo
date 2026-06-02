import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 경기 리스트의 날짜 그룹 헤더. 예: "오늘   4월 14일"
class MatchDateHeader extends StatelessWidget {
  const MatchDateHeader({
    super.key,
    required this.label,
    required this.dateText,
    this.scale = 1,
  });

  /// 상대 라벨. 예: "오늘", "내일".
  final String label;

  /// 절대 날짜 텍스트. 예: "4월 14일".
  final String dateText;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      fontSize: 14 * scale,
      height: 22 / 14, // 155%
      color: AppColors.narTextTertiary,
    );
    return Container(
      height: 38 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 8 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: textStyle),
            SizedBox(width: 8 * scale),
            Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: const BoxDecoration(
                color: AppColors.narTextTertiary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8 * scale),
          ],
          Text(dateText, style: textStyle),
        ],
      ),
    );
  }
}
