import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_filter_sheet.dart';
import '../../../components/nar_select_dropdown_field.dart';
import '../../../components/labeled_field.dart';
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
                  child: NarSelectDropdownField(
                    placeholder: l.all,
                    summary: _viewModel.selectedLeagueSummary,
                    options: _viewModel.leagueOptions.toSelectOptions(),
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
                  child: NarSelectDropdownField(
                    placeholder: l.all,
                    summary: _viewModel.selectedTeamSummary,
                    options: _viewModel.teamOptions.toSelectOptions(),
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
