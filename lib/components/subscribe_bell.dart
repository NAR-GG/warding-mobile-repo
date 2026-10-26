import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 공용 선수 구독 벨 — 구독 중이면 보라 체크 벨, 아니면 회색 플러스 벨.
///
/// 선수 페이지 상단, 내 선수 월즈 줄, 홈 월즈 솔랭 카드가 같이 쓴다.
/// 접근성 라벨은 화면마다 문구가 달라 [semanticsLabel] 로 받는다.
class SubscribeBell extends StatelessWidget {
  const SubscribeBell({
    super.key,
    required this.subscribed,
    required this.semanticsLabel,
    required this.onTap,
    this.size = 36,
    this.iconSize = 20,
    this.scale = 1,
  });

  final bool subscribed;

  /// "{이름} 구독" / "{이름} 구독 해제" 처럼 화면별 문구.
  final String semanticsLabel;
  final VoidCallback onTap;

  /// 원 지름(기본 36). 홈 작은 카드처럼 좁은 자리는 32.
  final double size;

  /// 벨 아이콘 크기(기본 20).
  final double iconSize;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size * scale,
          height: size * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: subscribed ? AppColors.narChipBadgeBg : AppColors.narDark600,
          ),
          child: SvgPicture.asset(
            subscribed
                ? 'assets/icons/bell-check.svg'
                : 'assets/icons/bell-plus.svg',
            width: iconSize * scale,
            height: iconSize * scale,
            colorFilter: ColorFilter.mode(
              subscribed ? AppColors.narViolet3 : AppColors.narText2,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
