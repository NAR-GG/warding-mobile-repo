import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../model/team.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

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
    this.preferredTeam,
    this.teamSelected = false,
    this.onTeamTap,
  });

  /// 'yyyy.MM' 형식 월 라벨. 예: '2026.04'.
  final String monthLabel;

  /// 월 아래 요약 텍스트.
  final String summary;

  /// 월·달력 영역 탭 콜백. null 이면 비활성.
  final VoidCallback? onMonthTap;

  /// 필터 버튼 탭 콜백. null 이면 비활성.
  final VoidCallback? onFilterTap;

  /// 온보딩에서 고른 선호 팀. null 이면(건너뛰기 등) 팀 아이콘을 숨긴다.
  final Team? preferredTeam;

  /// 팀 아이콘 선택(2px 테두리) 상태.
  final bool teamSelected;

  /// 팀 아이콘 탭 콜백. null 이면 비활성.
  final VoidCallback? onTeamTap;

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
          // 오른쪽: 필터 버튼 + (온보딩에서 고른) 팀 아이콘
          GestureDetector(
            onTap: onFilterTap,
            child: _CircleSlot(
              scale: scale,
              child: SvgPicture.asset(
                'assets/icons/filter.svg',
                width: 24 * scale,
                height: 24 * scale,
              ),
            ),
          ),
          if (preferredTeam != null) ...[
            SizedBox(width: 8 * scale), // 필터 버튼 ↔ 팀 아이콘 간격 8
            GestureDetector(
              onTap: onTeamTap,
              child: _CircleSlot(
                scale: scale,
                bordered: teamSelected,
                child: CachedNetworkImage(
                  imageUrl: resolveImageUrl(preferredTeam!.imageUrl)!,
                  width: 25 * scale,
                  height: 25 * scale,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 150),
                  errorWidget: (_, _, _) => Icon(
                    Icons.shield_outlined,
                    size: 25 * scale,
                    color: AppColors.narText2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 헤더 오른쪽 끝의 44×44 원형 슬롯. 필터 버튼·팀 아이콘이 공유한다.
///
/// [bordered] 면 2px narBg 그라데이션 테두리를 두른다. 전체 크기는 44 로
/// 유지하고 안쪽 원을 40 으로 줄여, 선택/해제 시 레이아웃이 흔들리지 않는다.
class _CircleSlot extends StatelessWidget {
  const _CircleSlot({
    required this.scale,
    required this.child,
    this.bordered = false,
  });

  final double scale;
  final Widget child;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    if (!bordered) {
      return Container(
        width: 44 * scale,
        height: 44 * scale,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.narBgTertiary,
          shape: BoxShape.circle,
        ),
        child: child,
      );
    }
    return Container(
      width: 44 * scale,
      height: 44 * scale,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppColors.narBg, // 2px narBg 테두리
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 40 * scale, // 44 - 테두리 2px ×2
        height: 40 * scale,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.narBgTertiary,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}
