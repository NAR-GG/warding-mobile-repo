import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 경기 리스트의 날짜 그룹 헤더. 예: "4월 14일  오늘 ──────"
class MatchDateHeader extends StatelessWidget {
  const MatchDateHeader({
    super.key,
    required this.isToday,
    required this.dateText,
    required this.todayLabel,
    this.scale = 1,
  });

  /// 오늘 날짜 그룹이면 [todayLabel] 배지를 함께 그린다. 그 외에는 생략.
  final bool isToday;

  /// 절대 날짜 텍스트. 예: "4월 14일".
  final String dateText;

  /// "오늘" 배지에 쓰는 라벨(로케일 문자열).
  final String todayLabel;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final dateStyle = TextStyle(
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
          Text(dateText, style: dateStyle),
          if (isToday) ...[
            SizedBox(width: 8 * scale),
            ShaderMask(
              shaderCallback: (bounds) => AppColors.narBg.createShader(bounds),
              child: Text(
                todayLabel,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 14 * scale,
                  height: 22 / 14,
                  // ShaderMask 가 덮어쓰므로 흰색이어야 그라데이션이 보인다.
                  color: AppColors.narText,
                ),
              ),
            ),
          ],
          SizedBox(width: 8 * scale),
          const Expanded(
            child: Divider(color: AppColors.narLine2, thickness: 1, height: 1),
          ),
        ],
      ),
    );
  }
}
