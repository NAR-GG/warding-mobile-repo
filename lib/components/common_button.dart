import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 공용 버튼 종류.
enum CommonButtonVariant {
  /// 기본 — 전체 폭 그라데이션 버튼.
  primary,

  /// 로그아웃 — 다크 배경(narBgTertiary) + logout 아이콘, 내용 폭 컴팩트 버튼.
  logout,

  /// 텍스트 — 배경 없는 컴팩트 텍스트 버튼 (예: 회원탈퇴).
  text,
}

/// 앱 공용 버튼.
///
/// [variant] 로 종류를 고른다.
/// - [CommonButtonVariant.primary] : 전체 폭 그라데이션. [onPressed] 가 null 이면
///   비활성(배경 반투명 다크 / 텍스트 [AppColors.narDark300]).
/// - [CommonButtonVariant.logout] : 다크 배경 + logout 아이콘, 내용 폭.
/// - [CommonButtonVariant.text] : 배경 없는 텍스트 버튼.
class CommonButton extends StatelessWidget {
  const CommonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CommonButtonVariant.primary,
    this.scale = 1.0,
  });

  /// 버튼 라벨.
  final String label;

  /// 탭 콜백. null 이면 비활성 상태가 된다(primary 기준).
  final VoidCallback? onPressed;

  /// 버튼 종류.
  final CommonButtonVariant variant;

  /// 디자인 시안 대비 스케일.
  final double scale;

  /// 비활성 상태 배경색 (#101113CC).
  static const Color _disabledBg = Color(0xCC101113);

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case CommonButtonVariant.logout:
        return _buildCompact(
          background: AppColors.narBgTertiary,
          textColor: AppColors.narText,
          icon: SvgPicture.asset(
            'assets/icons/logout.svg',
            width: 24 * scale,
            height: 24 * scale,
          ),
        );
      case CommonButtonVariant.text:
        return _buildCompact(textColor: AppColors.narTextTertiary);
      case CommonButtonVariant.primary:
        return _buildPrimary();
    }
  }

  /// 기본 — 전체 폭 그라데이션 버튼.
  Widget _buildPrimary() {
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

  /// 컴팩트 버튼(logout/text 공용) — 내용 폭, padding 5/20, radius 10.
  /// [background] 가 null 이면 배경 없음, [icon] 이 있으면 라벨 앞에 gap 4 로 배치.
  Widget _buildCompact({
    required Color textColor,
    Color? background,
    Widget? icon,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 35 * scale,
        padding: EdgeInsets.symmetric(
          horizontal: 20 * scale,
          vertical: 5 * scale,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[icon, SizedBox(width: 4 * scale)],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 25 / 14,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
