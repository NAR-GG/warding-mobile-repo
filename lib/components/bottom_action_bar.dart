import 'package:flutter/material.dart';

import '../styles/app_colors.dart';
import 'common_button.dart';

/// 화면 하단에 떠 있는 주 행동 버튼. 본문 스크롤 위에 [Stack] 으로 얹고, 버튼 뒤로
/// 배경색이 위로 옅어지는 막을 깔아 본문이 버튼 밑으로 흐려지며 가려지게 한다.
/// 광고 안내·응원 광고 신청처럼 하단 버튼이 있는 화면이 같은 모양을 쓰도록 모았다.
///
/// 버튼 자체는 앱 공용 [CommonButton] 을 그대로 쓴다 — 응원 광고 신청은 경기리스트
/// 설정의 '완료' 와 같은 [CommonButtonVariant.light], 광고 안내는 경기 일정 필터
/// 시트의 '조회' 와 같은 [CommonButtonVariant.primary] 다. 이 바가 하는 일은
/// 버튼을 하단에 고정하고 뒤에 막을 깔아 주는 것뿐이다.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.label,
    required this.onTap,
    required this.scale,
    this.variant = CommonButtonVariant.light,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;

  /// 버튼 종류. 기본은 솔리드 밝은 버튼([CommonButtonVariant.light]).
  final CommonButtonVariant variant;

  /// 버튼 높이 ([CommonButton] 의 전체 폭 버튼 높이와 같다).
  static const double buttonHeight = 50;

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
      child: CommonButton(
        label: label,
        variant: variant,
        scale: scale,
        onPressed: onTap,
      ),
    );
  }
}
