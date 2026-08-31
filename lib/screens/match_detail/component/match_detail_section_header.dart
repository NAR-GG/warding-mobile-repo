import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 경기 상세 탭 콘텐츠 맨 위에 붙는 섹션 타이틀 바.
///
/// 왼쪽에 흰색 4px 강조선, 배경은 아래 콘텐츠와 같은 narBgContent.
class MatchDetailSectionHeader extends StatelessWidget {
  const MatchDetailSectionHeader({
    super.key,
    required this.label,
    this.scale = 1,
  });

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 42 * scale,
      padding: EdgeInsets.fromLTRB(
        8 * scale,
        10 * scale,
        10 * scale,
        10 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgContent,
        border: Border(
          left: BorderSide(color: AppColors.narText, width: 4 * scale),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              fontSize: 14 * scale,
              height: 1.55,
              color: AppColors.narText,
            ),
          ),
        ],
      ),
    );
  }
}
