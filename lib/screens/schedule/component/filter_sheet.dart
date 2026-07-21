import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/app_select_box.dart';
import '../../../components/nar_filter_sheet.dart';
import '../../../components/labeled_field.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/schedule/filter_viewmodel.dart';

/// 경기 필터 바텀시트.
///
/// 리그는 멀티 선택(체크 아이콘 + 빨간 배경), 팀은 단일 선택.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, this.initialLeagues, this.initialTeamIds});

  /// 모달을 열 때 이미 적용 중이던 리그 코드 Set.
  final Set<String>? initialLeagues;

  /// 모달을 열 때 이미 적용 중이던 팀 ID Set.
  final Set<int>? initialTeamIds;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final FilterViewModel _viewModel = FilterViewModel(
    initialLeagues: widget.initialLeagues,
    initialTeamIds: widget.initialTeamIds,
  );

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
        return NarFilterSheet(
          title: '필터',
          onReset: _viewModel.reset,
          onApply: _viewModel.isApplyEnabled
              ? () => Navigator.of(context).pop(_viewModel.result)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: '리그',
                  scale: scale,
                  child: _MultiSelectField(
                    placeholder: '전체',
                    summary: _viewModel.selectedLeagueSummary,
                    options: _viewModel.leagueNames,
                    isSelectedByName: _viewModel.isLeagueSelectedByName,
                    isOpen: _viewModel.openDropdown == FilterDropdown.league,
                    onTapBox: () =>
                        _viewModel.toggleDropdown(FilterDropdown.league),
                    onToggle: _viewModel.toggleLeagueByName,
                    scale: scale,
                  ),
                ),
                SizedBox(height: 24 * scale),
                LabeledField(
                  label: '팀',
                  scale: scale,
                  child: _MultiSelectField(
                    placeholder: '전체',
                    summary: _viewModel.selectedTeamSummary,
                    options: _viewModel.teamNames,
                    isSelectedByName: _viewModel.isTeamSelectedByName,
                    isOpen: _viewModel.openDropdown == FilterDropdown.team,
                    onTapBox: () =>
                        _viewModel.toggleDropdown(FilterDropdown.team),
                    onToggle: _viewModel.toggleTeamByName,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 멀티 선택 드롭다운. 선택된 항목은 체크 아이콘 + 빨간 배경.
class _MultiSelectField extends StatelessWidget {
  const _MultiSelectField({
    required this.placeholder,
    required this.summary,
    required this.options,
    required this.isSelectedByName,
    required this.isOpen,
    required this.onTapBox,
    required this.onToggle,
    required this.scale,
  });

  final String placeholder;
  final String? summary;
  final List<String> options;
  final bool Function(String) isSelectedByName;
  final bool isOpen;
  final VoidCallback onTapBox;
  final ValueChanged<String> onToggle;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelectBox(
          text: summary ?? placeholder,
          scale: scale,
          onTap: onTapBox,
          trailing: SvgPicture.asset(
            'assets/icons/chevron-down.svg',
            width: 16 * scale,
            height: 16 * scale,
          ),
        ),
        if (isOpen) ...[
          SizedBox(height: 4 * scale),
          _MultiDropdownList(
            options: options,
            isSelected: isSelectedByName,
            onToggle: onToggle,
            scale: scale,
          ),
        ],
      ],
    );
  }
}

/// 멀티 선택 드롭다운 목록.
class _MultiDropdownList extends StatelessWidget {
  const _MultiDropdownList({
    required this.options,
    required this.isSelected,
    required this.onToggle,
    required this.scale,
  });

  final List<String> options;
  final bool Function(String) isSelected;
  final ValueChanged<String> onToggle;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const visibleItems = 4;
    final maxHeight = 45.0 * scale * visibleItems;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
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
                _MultiDropdownItem(
                  label: option,
                  isSelected: isSelected(option),
                  onTap: () => onToggle(option),
                  scale: scale,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 멀티 선택 항목. 선택 시 체크 아이콘 + 빨간 배경.
class _MultiDropdownItem extends StatelessWidget {
  const _MultiDropdownItem({
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
        color: isSelected ? AppColors.narRedOpacity25 : null,
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 8 * scale,
        ),
        child: Row(
          children: [
            if (isSelected) ...[
              SvgPicture.asset(
                'assets/icons/check.svg',
                width: 24 * scale,
                height: 24 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 4 * scale),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 16 * scale,
                  height: 22 / 16,
                  color: isSelected ? AppColors.narText : AppColors.narDark200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
