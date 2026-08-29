import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../styles/app_colors.dart';

/// 목록 화면 상단의 누적 건수 바 (padding 10/20, 높이 45, narDark600 배경).
///
/// [label] + 'N건'(narBg 그라데이션 텍스트). 내 리뷰/평점·내 게시물·내가
/// 남긴 댓글 등 날짜별 목록 화면이 공유해서 쓴다.
class CumulativeCountBar extends StatelessWidget {
  const CumulativeCountBar({
    super.key,
    required this.label,
    required this.count,
    this.scale = 1,
  });

  final String label;
  final int count;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 45 * scale,
      color: AppColors.narDark600,
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              height: 25 / 14,
              color: AppColors.narText,
            ),
          ),
          SizedBox(width: 8 * scale),
          ShaderMask(
            shaderCallback: (bounds) => AppColors.narBg.createShader(bounds),
            child: Text(
              l.countUnit(count),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 25 / 14,
                color: AppColors.narText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
