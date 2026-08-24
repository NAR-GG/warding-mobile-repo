import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/app_select_box.dart';
import '../../../components/nar_filter_sheet.dart';
import '../../../components/labeled_field.dart';
import '../../../styles/app_colors.dart';
import '../../../util/league_icon.dart';
import '../../../viewmodel/schedule/filter_viewmodel.dart';

/// 경기 필터 바텀시트.
///
/// 헤더([초기화]·'필터'·[닫기]) 아래에 리그·팀 셀렉트 필드와 조회 버튼을
/// 둔다. 셀렉트 필드는 탭하면 아래로 체크박스 드롭다운이 펼쳐지며, 리그·팀
/// 모두 다중 선택이다(전체 해제 시 '전체'로 되돌아간다). 선택값이 모달을
/// 열 때(이전 값)와 달라져야 조회 버튼이 활성된다.
/// [showAppBottomSheet] 의 child 로 띄운다.
///
/// ViewModel 은 **밖에서 옵션 조회까지 끝낸 뒤** 넘겨준다. 예전에는 시트가
/// 직접 만들어 열자마자 조회했는데, 그 조회가 실패하면 리그·팀 목록이 빈 채로
/// 시트가 떠서 선택값이 있어도 '전체/전체'로 보였다(이름↔코드 매핑이 없어서).
/// 사용자가 그 화면에서 조회를 누르면 진짜 필터가 '전체'로 덮어써졌다.
/// 지금은 실패하면 호출부가 시트를 아예 띄우지 않는다.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.viewModel});

  /// 옵션 조회가 끝난 ViewModel. 소유권은 호출부에 있다(dispose 도 호출부가).
  final FilterViewModel viewModel;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  FilterViewModel get _viewModel => widget.viewModel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final l = AppLocalizations.of(context)!;
        return NarFilterSheet(
          title: l.filter,
          onReset: _viewModel.reset,
          // 선택값이 이전 값과 같으면 비활성(null), 바뀌면 활성.
          onApply: _viewModel.isApplyEnabled
              ? () => Navigator.of(context).pop(_viewModel.result)
              : null,
          // 셀렉트 박스 영역 — 좌우 24 들여쓰기.
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: l.league,
                  scale: scale,
                  child: _SelectField(
                    placeholder: l.all,
                    summary: _viewModel.selectedLeagueSummary,
                    options: _viewModel.leagueOptions,
                    isOpen: _viewModel.openDropdown == FilterDropdown.league,
                    onTapBox: () =>
                        _viewModel.toggleDropdown(FilterDropdown.league),
                    onToggle: _viewModel.toggleLeague,
                    leadingBuilder: leagueIconWidget,
                    scale: scale,
                  ),
                ),
                SizedBox(height: 24 * scale), // 리그 ↔ 팀 간격 24
                LabeledField(
                  label: l.team,
                  scale: scale,
                  child: _SelectField(
                    placeholder: l.all,
                    summary: _viewModel.selectedTeamSummary,
                    options: _viewModel.teamOptions,
                    isOpen: _viewModel.openDropdown == FilterDropdown.team,
                    onTapBox: () =>
                        _viewModel.toggleDropdown(FilterDropdown.team),
                    onToggle: _viewModel.toggleTeam,
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

/// 셀렉트 박스 + 펼침 체크박스 드롭다운 한 묶음.
///
/// 셀렉트 박스는 왼쪽에 선택 요약 텍스트, 오른쪽에 펼침 화살표를 둔다.
/// [isOpen] 이면 박스 아래 4 간격을 띄우고 [_DropdownList] 를 보여준다.
class _SelectField extends StatelessWidget {
  const _SelectField({
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

  /// 현재 선택 요약 텍스트(복수 선택 시 ', '로 이어붙임). null 이면 [placeholder] 표시.
  final String? summary;

  /// 드롭다운 항목 목록 — 선택 여부 포함, 선택된 항목이 앞에 정렬돼 있다.
  final List<FilterOption> options;

  /// 드롭다운 펼침 여부.
  final bool isOpen;

  /// 셀렉트 박스 탭 콜백.
  final VoidCallback onTapBox;

  /// 드롭다운 항목 이름 앞에 둘 아이콘. null 이거나 항목에 대해 null 을
  /// 돌려주면 아이콘 없이 텍스트만 표시한다(리그 필드에만 준다).
  final Widget? Function(String)? leadingBuilder;

  /// 체크박스 항목 탭 콜백(토글).
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

  final List<FilterOption> options;
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

  final FilterOption option;
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
            ? AppColors.narText // 선택 — #FFFFFF
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
