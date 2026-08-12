import 'package:flutter/material.dart';

import '../styles/app_colors.dart';
import 'nar_live_dot.dart';

/// 라이브 진행중 표시 배지. 빨간 점 + LIVE 텍스트, 둥근 8.
/// 시간 배지([NarBadge])와 동일한 높이(24)라 그대로 자리에 교체 가능.
/// 점은 [NarLiveDot] 이라 천천히 깜박인다.
class NarLiveBadge extends StatelessWidget {
  const NarLiveBadge({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24 * scale,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.liveBadgeBg,
        border: Border.all(color: AppColors.narRed500, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NarLiveDot(scale: scale),
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
