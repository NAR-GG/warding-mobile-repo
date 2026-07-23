import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 앱 공용 검색바 (`nar_search_bar`).
///
/// 높이 44, 좌측 13 패딩 + 우측 35×35 검색 아이콘 박스의 한 줄짜리 입력.
/// 부모 폭에 맞춰 늘어난다 (시안 기준 335 의 `align-self: stretch`).
class NarSearchBar extends StatelessWidget {
  const NarSearchBar({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onSearchTap,
    this.autofocus = false,
    this.scale = 1,
  });

  /// 텍스트 컨트롤러. 미제공 시 내부적으로 [TextField] 가 관리한다.
  final TextEditingController? controller;

  /// placeholder 문구. null 이면 l10n 기본값([AppLocalizations.searchHint])을 사용한다.
  final String? hint;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 우측 검색 아이콘 영역 탭 콜백. null 이면 아이콘은 단순 장식.
  final VoidCallback? onSearchTap;

  final bool autofocus;

  /// 비율 스케일. 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 44 * scale,
      padding: EdgeInsets.only(left: 13 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary, // #1A1B1E
        border: Border.all(color: AppColors.narLine, width: 1), // #343A40
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: AppColors.narRed500,
              cursorWidth: 1.5,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.55, // 155%
                color: AppColors.narTextSecondary, // #FFFFFF
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: hint ?? l.searchHint,
                hintStyle: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.55, // 155%
                  color: AppColors.narTextTertiarySub, // #A6A7AB
                ),
              ),
            ),
          ),
          // 우측 검색 아이콘 박스: 35×35, padding 10 → 안쪽 15×15 아이콘.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSearchTap,
            child: Container(
              width: 35 * scale,
              height: 35 * scale,
              padding: EdgeInsets.all(10 * scale),
              child: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 15 * scale,
                height: 15 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText3, // #C1C2C5
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
