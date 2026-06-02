import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 공용 작은 배지 (높이 24, 둥근 8).
/// 다크 배경 + 회색 테두리 + 흰 텍스트. 시간/태그 등 짧은 라벨에 쓴다.
class NarBadge extends StatelessWidget {
  const NarBadge({super.key, required this.label, this.scale = 1});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24 * scale,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        border: Border.all(color: AppColors.narLine2, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w600,
          fontSize: 12 * scale,
          height: 1,
          color: AppColors.narTextTertiary,
        ),
      ),
    );
  }
}

/// 진영 표시 뱃지 종류.
enum BadgeSide { blue, red }

/// 진영 표시 뱃지 (59×24). 투명 배경 + 컬러 보더 + 컬러 텍스트.
/// BLUE: 인디고 톤(indigo/3 보더 + indigo/8 텍스트).
/// RED: 빨강 톤(red/3 보더 + red/8 텍스트).
class NarBadgeSide extends StatelessWidget {
  const NarBadgeSide({super.key, required this.side, this.scale = 1});

  final BadgeSide side;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isBlue = side == BadgeSide.blue;
    return Container(
      width: 59 * scale,
      height: 24 * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: isBlue ? AppColors.sideBlueBorder : AppColors.sideRedBorder,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isBlue ? 'BLUE' : 'RED',
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w500,
          fontSize: 12 * scale,
          height: 1,
          color: isBlue ? AppColors.sideBlueText : AppColors.sideRedText,
        ),
      ),
    );
  }
}

/// LIVE 라이트 뱃지 (높이 24). 빨간 점 + 'LIVE' 텍스트.
/// 옅은 빨강 배경 + 빨강 보더 + 빨강 텍스트의 라이트 톤. 시안 'nar_badge_LIVE'.
/// 시간 뱃지([NarBadge])와 동일한 높이라 자리 교체 가능.
class NarBadgeLive extends StatelessWidget {
  const NarBadgeLive({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24 * scale,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.liveBadgeLightBg,
        border: Border.all(color: AppColors.liveBadgeLightBorder, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6 * scale,
            height: 6 * scale,
            decoration: const BoxDecoration(
              color: AppColors.liveAccent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6 * scale),
          Text(
            'LIVE',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              fontSize: 12 * scale,
              height: 1,
              color: AppColors.liveAccent,
            ),
          ),
        ],
      ),
    );
  }
}
