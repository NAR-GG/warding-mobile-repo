import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';
import 'app_select_box.dart';

/// 드롭다운 한 항목 — 표시 이름과 현재 선택 여부.
///
/// 경기 일정 필터(`FilterOption`)에서 쓰던 모양 그대로다. 여러 시트가 같은
/// 드롭다운을 쓰게 되면서 공용 컴포넌트 쪽으로 옮겼다.
class NarSelectOption {
  const NarSelectOption({required this.name, required this.selected});
  final String name;
  final bool selected;
}

/// 셀렉트 박스 + 펼침 체크박스 드롭다운 한 묶음.
///
/// 셀렉트 박스는 왼쪽에 선택 요약 텍스트, 오른쪽에 펼침 화살표를 둔다.
/// [isOpen] 이면 박스 아래 4 간격을 띄우고 체크박스 목록을 보여준다.
///
/// 원래 경기 일정 필터 시트(`filter_sheet.dart`)에만 있던 비공개 위젯이다.
/// 경기 리스트 필터(시즌·리그·팀·정렬)도 같은 모양을 써야 해서 공용으로
/// 끌어올렸다 — 같은 시트 계열에서 드롭다운이 두 종류로 보이면 안 된다.
///
/// 보통 [LabeledField] 로 감싸 라벨과 함께 쓴다.
class NarSelectDropdownField extends StatelessWidget {
  const NarSelectDropdownField({
    super.key,
    required this.placeholder,
    required this.summary,
    required this.options,
    required this.isOpen,
    required this.onTapBox,
    required this.onToggle,
    required this.scale,
    this.leadingBuilder,
  });

  /// 미선택('전체') 시 박스에 보일 기본 문구.
  final String placeholder;

  /// 현재 선택 요약 텍스트(복수 선택 시 ', '로 이어붙임).
  /// null 이면 [placeholder] 를 표시한다.
  final String? summary;

  /// 드롭다운 항목 목록 — 선택 여부 포함.
  final List<NarSelectOption> options;

  /// 드롭다운 펼침 여부.
  final bool isOpen;

  /// 셀렉트 박스 탭 콜백.
  final VoidCallback onTapBox;

  /// 체크박스 항목 탭 콜백(토글).
  final ValueChanged<String> onToggle;

  /// 드롭다운 항목 이름 앞에 둘 아이콘. null 이거나 항목에 대해 null 을
  /// 돌려주면 아이콘 없이 텍스트만 표시한다(리그 필드에만 준다).
  final Widget? Function(String)? leadingBuilder;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelectBox(
          text: summary ?? placeholder,
          selected: summary != null,
          scale: scale,
          onTap: onTapBox,
          trailing: SvgPicture.asset(
            'assets/icons/chevron-down.svg',
            width: 16 * scale,
            height: 16 * scale,
          ),
        ),
        if (isOpen) ...[
          SizedBox(height: 4 * scale), // 셀렉트 박스 ↔ 드롭다운 간격 4
          _DropdownList(
            options: options,
            onToggle: onToggle,
            scale: scale,
            leadingBuilder: leadingBuilder,
          ),
        ],
      ],
    );
  }
}

/// 체크박스 드롭다운 항목 목록 — 라운드 10, 배경은 셀렉트 박스와 동일.
class _DropdownList extends StatelessWidget {
  const _DropdownList({
    required this.options,
    required this.onToggle,
    required this.scale,
    this.leadingBuilder,
  });

  final List<NarSelectOption> options;
  final ValueChanged<String> onToggle;
  final double scale;
  final Widget? Function(String)? leadingBuilder;

  @override
  Widget build(BuildContext context) {
    // 항목 한 칸 높이 ≈ 위아래 패딩 11.5×2 + 줄높이 22 = 45.
    // 약 5칸까지만 보이고 그보다 많으면 안에서 세로 스크롤한다.
    const visibleItems = 5;
    final maxHeight = 45.0 * scale * visibleItems;

    return Container(
      // 항목 배경이 라운드 모서리 밖으로 새지 않게 클리핑.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgLast, // 셀렉트 박스와 같은 #25262B
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                _DropdownItem(
                  option: option,
                  onTap: () => onToggle(option.name),
                  scale: scale,
                  leading: leadingBuilder?.call(option.name),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 체크박스 드롭다운 항목 한 칸 — 좌우 16·위아래 11.5 패딩.
///
/// 선택된 항목은 빨강 배경([AppColors.narRedOpacity25]) + 체크 아이콘 + 흰 글자,
/// 미선택 항목은 흐린 글자만 표시한다.
class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
    required this.option,
    required this.onTap,
    required this.scale,
    this.leading,
  });

  final NarSelectOption option;
  final VoidCallback onTap;
  final double scale;

  /// 항목 이름 앞에 둘 아이콘 위젯. null 이면 텍스트만(체크박스 자리는 그대로 유지).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isSelected = option.selected;
    final text = Text(
      option.name,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
        fontSize: 16 * scale,
        height: 22 / 16, // line-height 22px / font-size 16px
        letterSpacing: 0,
        color: isSelected
            ? AppColors
                  .narText // 선택 — #FFFFFF
            : AppColors.narText3, // 미선택 — #C1C2C5
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected ? AppColors.narRedOpacity25 : null, // #FA525240
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 11.5 * scale,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(
                width: 22 * scale,
                height: 22 * scale,
                // 옆 텍스트와 같은 색을 따라가게 — 선택 여부에 따라 함께 바뀐다.
                // 다색 로고를 그대로 두면 텍스트와 안 어울리고, 원본이 배경과
                // 비슷한 색이면(LCS) 안 보이는 문제도 있었다.
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    isSelected ? AppColors.narText : AppColors.narText3,
                    BlendMode.srcIn,
                  ),
                  child: leading,
                ),
              ),
              SizedBox(width: 6 * scale),
            ],
            if (isSelected) ...[
              SvgPicture.asset(
                'assets/icons/check.svg',
                width: 16 * scale,
                height: 16 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 4 * scale),
            ],
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}
