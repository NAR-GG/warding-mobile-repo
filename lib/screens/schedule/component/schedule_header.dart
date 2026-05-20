import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 경기 일정 페이지 상단 헤더.
///
/// - 왼쪽: 'yyyy.MM' 월 + 달력·펼침 아이콘, 그 아래 요약 텍스트.
/// - 오른쪽: 필터 버튼(44 원형).
///
/// 시안 폭 375 기준으로 내부에서 [MediaQuery] 폭에 맞춰 스케일한다.
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.monthLabel,
    this.summary = '월간 경기 일정 요약',
    this.onMonthTap,
    this.onFilterTap,
  });

  /// 'yyyy.MM' 형식 월 라벨. 예: '2026.04'.
  final String monthLabel;

  /// 월 아래 요약 텍스트.
  final String summary;

  /// 월·달력 영역 탭 콜백. null 이면 비활성.
  final VoidCallback? onMonthTap;

  /// 필터 버튼 탭 콜백. null 이면 비활성.
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Row(
        children: [
          // 왼쪽: 월 + 요약
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onMonthTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthLabel,
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w700,
                          fontSize: 22 * scale,
                          height: 1.4, // 140%
                          letterSpacing: 0,
                          color: AppColors.narText,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      SvgPicture.asset(
                        'assets/icons/nar_calendar.svg',
                        width: 22 * scale,
                        height: 22 * scale,
                      ),
                      SizedBox(width: 4 * scale),
                      SvgPicture.asset(
                        'assets/icons/chevron-down.svg',
                        width: 16 * scale,
                        height: 16 * scale,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  summary,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    fontSize: 16 * scale,
                    height: 1.55, // 155%
                    letterSpacing: 0,
                    color: AppColors.narTextGnbDefault,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          // 오른쪽: 필터 버튼
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 44 * scale,
              height: 44 * scale,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.narBgTertiary,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/filter.svg',
                width: 24 * scale,
                height: 24 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
