import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 입력 필드 (디자인 기준 폭 335, 높이 55).
///
/// 두 상태를 가진다:
/// - 기본 : 배경 [AppColors.narDark800] 10% + 테두리 [AppColors.narInputBorder](#424242).
/// - 에러 : 배경 [AppColors.narDark800] + 테두리 [AppColors.narTextRed](#FF6B6B),
///   아래 4 간격에 [errorText] 를 표시.
///
/// [errorText] 가 null 이 아니면 에러 상태로 렌더링한다(제어 컴포넌트).
class NarInput extends StatelessWidget {
  const NarInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.scale = 1,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// 필드 위 라벨. null 이면 라벨 없이 필드만 렌더링한다.
  final String? label;

  /// placeholder 문구.
  final String? hintText;

  /// 에러 메시지. null 이 아니면 에러 상태(빨간 테두리 + 메시지)가 된다.
  final String? errorText;

  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    // Body Normal — Pretendard 400 / 16 / line 145%.
    final textStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 16 * scale,
      height: 1.45,
      color: AppColors.narTextTertiary,
    );

    final field = Container(
      height: 55 * scale,
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      decoration: BoxDecoration(
        color:
            hasError
                ? AppColors.narDark800
                : AppColors.narDark800.withValues(alpha: 0.1),
        border: Border.all(
          color: hasError ? AppColors.narTextRed : AppColors.narInputBorder,
        ),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      // expands 로 필드 전체 높이를 채워, 박스 어디를 눌러도 포커스되게 한다.
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscureText,
        cursorColor: AppColors.narTextTertiary,
        style: textStyle,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: textStyle.copyWith(color: AppColors.narText2),
        ),
      ),
    );

    // 필드(+에러 메시지)를 묶은 콘텐츠.
    final content =
        hasError
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                field,
                SizedBox(height: 4 * scale),
                Text(
                  errorText!,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 12 * scale,
                    height: 1.45,
                    color: AppColors.narTextRed,
                  ),
                ),
              ],
            )
            : field;

    if (label == null) return content;

    // 라벨 + 8 간격 + 콘텐츠.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 16 * scale,
            height: 1.3,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 8 * scale),
        content,
      ],
    );
  }
}
