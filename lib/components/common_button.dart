import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 버튼.
///
/// [onPressed] 가 null 이면 비활성(disabled) 상태로 표시된다.
/// - 활성: 배경 [AppColors.narBg] 그라데이션 / 텍스트 흰색
/// - 비활성: 배경 반투명 다크 / 텍스트 [AppColors.narDark300]
class CommonButton extends StatelessWidget {
  const CommonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.scale = 1.0,
  });

  /// 버튼 라벨.
  final String label;

  /// 탭 콜백. null 이면 비활성 상태가 된다.
  final VoidCallback? onPressed;

  /// 디자인 시안 대비 스케일.
  final double scale;

  /// 비활성 상태 배경색 (#101113CC).
  static const Color _disabledBg = Color(0xCC101113);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 50 * scale,
        padding: EdgeInsets.symmetric(
          horizontal: 26 * scale,
          vertical: 1 * scale,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * scale),
          gradient: enabled ? AppColors.narBg : null,
          color: enabled ? null : _disabledBg,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 18 * scale,
            height: 48 / 18,
            letterSpacing: 0,
            color: enabled ? AppColors.naverText : AppColors.narDark300,
          ),
        ),
      ),
    );
  }
}
