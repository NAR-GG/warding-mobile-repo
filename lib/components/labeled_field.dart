import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 라벨 + 입력 위젯을 세로로 묶는 공용 래퍼.
///
/// 라벨을 위에 두고 4 간격을 띄운 뒤 [child] 를 둔다. [child] 는 가로로
/// 꽉 차게 늘어난다. 셀렉트 박스([AppSelectBox])·텍스트 인풋 등 어떤
/// 입력 위젯에도 재활용할 수 있다.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.scale = 1,
  });

  /// 위에 표시할 라벨 텍스트.
  final String label;

  /// 라벨 아래(4 간격)에 둘 입력 위젯.
  final Widget child;

  /// 비율 스케일. 디자인 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 16 * scale,
            height: 22 / 16, // line-height 22px / font-size 16px
            letterSpacing: 0,
            color: AppColors.narTextSecondary, // #FFFFFF
          ),
        ),
        SizedBox(height: 4 * scale), // 라벨 ↔ child 간격 4
        child,
      ],
    );
  }
}
