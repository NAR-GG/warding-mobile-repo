import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// nar_button 디자인 토큰 버튼 종류.
enum NarButtonVariant {
  /// nar_button_1 — 밝은 배경, 테두리 없음. 폭 고정(110.5).
  type1,

  /// nar_button_2 — 어두운 배경 + 테두리. 폭 고정(110.5).
  type2,

  /// nar_button_set1 — narDark300 배경, 테두리 없음, 부모 폭을 채움.
  set1,
}

/// 앱 공용 버튼.
/// [variant] 가 type1/type2 면 110.5×34 고정, set1 이면 부모 폭을 채우는 34 높이.
class NarButton extends StatelessWidget {
  const NarButton({
    super.key,
    required this.label,
    required this.variant,
    this.onPressed,
    this.scale = 1.0,
  });

  final String label;
  final NarButtonVariant variant;
  final VoidCallback? onPressed;
  final double scale;

  Color get _bgColor {
    switch (variant) {
      case NarButtonVariant.type1:
        return AppColors.narButton1Bg;
      case NarButtonVariant.type2:
        return AppColors.narButton2Bg;
      case NarButtonVariant.set1:
        return AppColors.narDark300;
    }
  }

  Color get _textColor {
    switch (variant) {
      case NarButtonVariant.type1:
        return AppColors.narButton1Text;
      case NarButtonVariant.type2:
        return AppColors.narButton2Text;
      case NarButtonVariant.set1:
        return AppColors.narText;
    }
  }

  BoxBorder? _border(double scale) => variant == NarButtonVariant.type2
      ? Border.all(color: AppColors.narButton2Line, width: 1.5 * scale)
      : null;

  /// type1/type2 는 시안 폭 고정, set1 은 부모를 채운다.
  double? _width(double scale) =>
      variant == NarButtonVariant.set1 ? double.infinity : 110.5 * scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: _width(scale),
        height: 34 * scale,
        padding: EdgeInsets.symmetric(horizontal: 10 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(8 * scale),
          border: _border(scale),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Open Sans',
            fontWeight: FontWeight.w400,
            fontSize: 14 * scale,
            letterSpacing: 0,
            color: _textColor,
          ),
        ),
      ),
    );
  }
}
