import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 공용 선택 칩 (Pill 모양, 높이 34).
/// 선택: 보라 반투명 배경 + 흰 글자, 미선택: 어두운 배경 + 회색 글자 + 테두리.
class NarChip extends StatelessWidget {
  const NarChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.scale = 1,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.narChipSelectedBg
              : AppColors.narBgTertiary,
          border: selected
              ? null
              : Border.all(color: AppColors.narLine2, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 14 * scale,
            height: 1,
            color: selected ? AppColors.narText : AppColors.narText2,
          ),
        ),
      ),
    );
  }
}
