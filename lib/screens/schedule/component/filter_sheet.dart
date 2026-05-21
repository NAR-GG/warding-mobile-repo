import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/app_select_box.dart';
import '../../../components/common_button.dart';
import '../../../components/labeled_field.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/schedule/filter_viewmodel.dart';

/// 경기 필터 바텀시트.
///
/// 헤더([초기화]·'필터'·[닫기]) 아래에 리그·팀 셀렉트 필드와 조회 버튼을
/// 둔다. 셀렉트 필드는 탭하면 아래로 드롭다운이 펼쳐진다. 선택값이 모달을
/// 열 때(이전 값)와 달라져야 조회 버튼이 활성된다.
/// 자체 [FilterViewModel] 을 소유하며 [showAppBottomSheet] 의 child 로 띄운다.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final FilterViewModel _viewModel = FilterViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterHeader(
              scale: scale,
              onReset: _viewModel.reset,
              onClose: () => Navigator.of(context).pop(),
            ),
            // 셀렉트 박스 영역 — 좌우 24 들여쓰기.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabeledField(
                    label: '리그',
                    scale: scale,
                    child: _SelectField(
                      placeholder: '전체',
                      selected: _viewModel.selectedLeague,
                      options: FilterViewModel.leagues,
                      isOpen:
                          _viewModel.openDropdown == FilterDropdown.league,
                      onTapBox: () =>
                          _viewModel.toggleDropdown(FilterDropdown.league),
                      onSelect: _viewModel.selectLeague,
                      scale: scale,
                    ),
                  ),
                  SizedBox(height: 24 * scale), // 리그 ↔ 팀 간격 24
                  LabeledField(
                    label: '팀',
                    scale: scale,
                    child: _SelectField(
                      placeholder: '전체',
                      selected: _viewModel.selectedTeam,
                      options: FilterViewModel.teams,
                      isOpen:
                          _viewModel.openDropdown == FilterDropdown.team,
                      onTapBox: () =>
                          _viewModel.toggleDropdown(FilterDropdown.team),
                      onSelect: _viewModel.selectTeam,
                      scale: scale,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * scale), // 팀 ↔ 조회 버튼 간격 24
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child:CommonButton(
              label: '조회하기',
              scale: scale,
              // 선택값이 이전 값과 같으면 비활성(null), 바뀌면 활성.
              onPressed: _viewModel.isApplyEnabled
                  ? () => Navigator.of(context).pop()
                  : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 필터 시트 헤더 — 위아래 24 간격, [초기화] · '필터' · [닫기].
///
/// 초기화·닫기 아이콘이 양옆 44×44 로 같은 크기라, space-between 만으로도
/// 가운데 '필터' 텍스트가 정확히 중앙에 온다.
class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.scale,
    required this.onClose,
    this.onReset,
  });

  final double scale;
  final VoidCallback onClose;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24 * scale), // 위아래 24
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconButton(
            icon: 'assets/icons/reset.svg',
            scale: scale,
            onTap: onReset,
          ),
          Text(
            '필터',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
              fontSize: 16 * scale,
              height: 1.5, // line-height 150%
              letterSpacing: 0,
              color: AppColors.narTextGnbDefault, // #CED4DA
            ),
          ),
          _IconButton(
            icon: 'assets/icons/close.svg',
            scale: scale,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

/// 헤더의 44×44 아이콘 버튼.
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.scale, this.onTap});

  final String icon;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SvgPicture.asset(icon, width: 44 * scale, height: 44 * scale),
    );
  }
}

/// 셀렉트 박스 + 펼침 드롭다운 한 묶음.
///
/// 셀렉트 박스는 왼쪽에 텍스트, 오른쪽에 펼침 화살표를 둔다.
/// [isOpen] 이면 박스 아래 4 간격을 띄우고 [_DropdownList] 를 보여준다.
class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.placeholder,
    required this.selected,
    required this.options,
    required this.isOpen,
    required this.onTapBox,
    required this.onSelect,
    required this.scale,
  });

  /// 미선택 시 박스에 보일 기본 문구.
  final String placeholder;

  /// 현재 선택값. null 이면 [placeholder] 표시.
  final String? selected;

  /// 드롭다운 항목 목록.
  final List<String> options;

  /// 드롭다운 펼침 여부.
  final bool isOpen;

  /// 셀렉트 박스 탭 콜백.
  final VoidCallback onTapBox;

  /// 항목 선택 콜백.
  final ValueChanged<String> onSelect;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelectBox(
          text: selected ?? placeholder,
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
            selected: selected,
            onSelect: onSelect,
            scale: scale,
          ),
        ],
      ],
    );
  }
}

/// 드롭다운 항목 목록 — 라운드 10, 배경은 셀렉트 박스와 동일.
class _DropdownList extends StatelessWidget {
  const _DropdownList({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.scale,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 항목 배경이 라운드 모서리 밖으로 새지 않게 클리핑.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgLast, // 셀렉트 박스와 같은 #25262B
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _DropdownItem(
              label: option,
              isSelected: option == selected,
              onTap: () => onSelect(option),
              scale: scale,
            ),
        ],
      ),
    );
  }
}

/// 드롭다운 항목 한 칸 — 좌우 16·위아래 11.5 패딩.
///
/// 선택된 항목은 빨강 배경([AppColors.narRedOpacity25]) + 어두운 글자,
/// 미선택 항목은 흐린 글자만 표시한다.
class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected ? AppColors.narRedOpacity25 : null, // #FA525240
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 11.5 * scale,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 16 * scale,
            height: 22 / 16, // line-height 22px / font-size 16px
            letterSpacing: 0,
            color: isSelected
                ? AppColors.narButton1Text // 선택 — #101113
                : AppColors.narDark200, // 미선택 — #909296
          ),
        ),
      ),
    );
  }
}
