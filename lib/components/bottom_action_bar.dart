import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 화면 하단에 떠 있는 주 행동 버튼. 본문 스크롤 위에 [Stack] 으로 얹고, 버튼 뒤로
/// 배경색이 위로 옅어지는 막을 깔아 본문이 버튼 밑으로 흐려지며 가려지게 한다.
/// 광고 안내·응원 광고 신청처럼 하단 버튼이 있는 화면이 같은 모양을 쓰도록 모았다 —
/// 색만 화면이 정한다([gradient] 가 있으면 그것을, 없으면 [color] 를 채운다).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.label,
    required this.onTap,
    required this.scale,
    this.gradient,
    this.color = AppColors.narButton1Bg,
    this.textColor = AppColors.narButton1Text,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;
  final Gradient? gradient;
  final Color color;
  final Color textColor;

  /// 버튼 높이.
  static const double buttonHeight = 52;

  /// 본문 스크롤 아래 여백(스케일 전). 막 위쪽 40 + 버튼 + 아래 24 — 마지막 줄이
  /// 버튼에 가려지지 않도록 스크롤 쪽이 이만큼 비워 둔다.
  static const double scrollInset = 40 + buttonHeight + 24;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        40 * scale,
        20 * scale,
        16 * scale,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: [0.62, 1],
          colors: [AppColors.narDark800, Color(0x00141517)],
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: buttonHeight * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 16 * scale,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
