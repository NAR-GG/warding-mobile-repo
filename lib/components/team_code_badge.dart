import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 팀 코드 원형 배지 — 실제 로고 이미지가 없는 자리(목데이터 등)에서
/// [teamCode] 텍스트만으로 팀을 표시한다.
class TeamCodeBadge extends StatelessWidget {
  const TeamCodeBadge({
    super.key,
    required this.teamCode,
    required this.size,
  });

  final String teamCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.narDark500,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: Text(
            teamCode.isEmpty ? '?' : teamCode,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: size * 0.4,
              color: AppColors.narText,
            ),
          ),
        ),
      ),
    );
  }
}
