import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// nar_button 디자인 토큰 버튼 종류.
enum NarButtonVariant {
  /// nar_button_1 — 밝은 배경, 테두리 없음.
  type1,

  /// nar_button_2 — 어두운 배경 + 테두리.
  type2,
}

/// 앱 공용 소형 버튼 (디자인 110.5×34).
class NarButton extends StatelessWidget {
  const NarButton({
    super.key,
    required this.label,
    required this.variant,
    this.onPressed,
    this.scale = 1.0,
  });

  /// 버튼 라벨.
  final String label;

  /// 버튼 종류 (nar_button_1 / nar_button_2).
  final NarButtonVariant variant;

  /// 탭 콜백.
  final VoidCallback? onPressed;

  /// 디자인 시안(110.5×34) 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isType1 = variant == NarButtonVariant.type1;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 110.5 * scale,
        height: 34 * scale,
        padding: EdgeInsets.symmetric(horizontal: 10 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isType1 ? AppColors.narButton1Bg : AppColors.narButton2Bg,
          borderRadius: BorderRadius.circular(8 * scale),
          border: isType1
              ? null
              : Border.all(
                  color: AppColors.narButton2Line,
                  width: 1.5 * scale,
                ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Open Sans',
            fontWeight: FontWeight.w400,
            fontSize: 14 * scale,
            letterSpacing: 0,
            color: isType1
                ? AppColors.narButton1Text
                : AppColors.narButton2Text,
          ),
        ),
      ),
    );
  }
}
