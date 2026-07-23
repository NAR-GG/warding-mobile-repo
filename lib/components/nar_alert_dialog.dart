import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../styles/app_colors.dart';
import 'nar_button.dart';

/// 공용 확인/취소 알럿 다이얼로그를 띄운다.
///
/// '확인'(밝은 버튼) 시 true, '취소'(어두운 버튼)·바깥 탭 시 false/null 을 반환한다.
Future<bool?> showNarConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder:
        (ctx) => NarAlertDialog(
          title: title,
          message: message,
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          onCancel: () => Navigator.of(ctx).pop(false),
          onConfirm: () => Navigator.of(ctx).pop(true),
        ),
  );
}

/// 공용 알럿 다이얼로그.
///
/// narDark600 카드(285·radius16, padding 24)에 타이틀·설명과
/// 버튼 2개(취소 [NarButtonVariant.type2] / 확인 [NarButtonVariant.type1])를 담는다.
/// [showNarConfirmDialog] 로 띄우는 걸 권장한다.
class NarAlertDialog extends StatelessWidget {
  const NarAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelLabel,
    this.confirmLabel,
    this.onCancel,
    this.onConfirm,
  });

  /// 메인 타이틀(18px 기준).
  final String title;

  /// 설명 문구(12px 기준).
  final String message;

  /// null 이면 l10n 기본값([AppLocalizations.defaultCancel])을 사용한다.
  final String? cancelLabel;

  /// null 이면 l10n 기본값([AppLocalizations.defaultConfirm])을 사용한다.
  final String? confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24 * scale),
      child: Container(
        width: 285 * scale,
        padding: EdgeInsets.all(24 * scale),
        decoration: BoxDecoration(
          color: AppColors.narDark600,
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 18 * scale,
                height: 1.45,
                letterSpacing: 0.21 * scale,
                color: AppColors.narText,
              ),
            ),
            SizedBox(height: 8 * scale),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 12 * scale,
                height: 1.45,
                letterSpacing: 0.21 * scale,
                color: AppColors.narTextTertiary,
              ),
            ),
            SizedBox(height: 16 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NarButton(
                  label: cancelLabel ?? l.defaultCancel,
                  variant: NarButtonVariant.type2,
                  onPressed: onCancel,
                  scale: scale,
                ),
                NarButton(
                  label: confirmLabel ?? l.defaultConfirm,
                  variant: NarButtonVariant.type1,
                  onPressed: onConfirm,
                  scale: scale,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
