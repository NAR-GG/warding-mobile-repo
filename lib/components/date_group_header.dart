import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 목록 화면의 일자 구분 헤더 (padding 10/20, narBgSecondary 배경).
///
/// 내 리뷰/평점·내 게시물·내가 남긴 댓글 등 날짜별로 그룹핑하는 목록 화면이
/// 공유해서 쓴다.
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({super.key, required this.date, this.scale = 1});

  final String date;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgSecondary,
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      child: Text(
        date,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w500,
          fontSize: 14 * scale,
          height: 17 / 14,
          color: AppColors.narText,
        ),
      ),
    );
  }
}
