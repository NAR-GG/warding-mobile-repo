import 'package:flutter/material.dart';

import '../../../components/labeled_field.dart';
import '../../../components/nar_filter_sheet.dart';
import '../../../components/nar_select_dropdown_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../../util/league_icon.dart';
import '../../../viewmodel/match_list/match_list_viewmodel.dart';

/// 경기 리스트 필터 시트 — 시즌·리그·팀·정렬.
///
/// 예전에는 경기리스트 화면 상단에 늘 펼쳐져 있던 줄들이다. 캘린더와 리스트를
/// 한 화면에 함께 두게 되면서 그만큼의 세로 공간을 상시로 내줄 수 없어, 헤더
/// 오른쪽 필터 버튼 뒤로 모았다.
///
/// 네 필드 모두 **경기 일정 필터 시트와 같은 드롭다운**
/// ([NarSelectDropdownField])을 쓴다 — 같은 버튼에서 열리는 같은 계열 시트라
/// 드롭다운이 두 종류로 보이면 안 된다. 시즌·리그·정렬은 단일 선택이라
/// 고르면 드롭다운이 닫히고, 팀만 다중 선택으로 열어 둔 채 토글한다.
///
/// [viewModel] 을 직접 받아 그 자리에서 반영한다 — 리스트가 이미 그 VM 을
/// 구독하고 있어서, 고르는 즉시 목록이 다시 조회된다. 시트는 "조회" 버튼으로
/// 닫히기만 하면 된다.
class ScheduleListFilterSheet extends StatefulWidget {
  const ScheduleListFilterSheet({super.key, required this.viewModel});

  final MatchListViewModel viewModel;

  @override
  State<ScheduleListFilterSheet> createState() =>
      _ScheduleListFilterSheetState();
}

/// 지금 펼쳐진 드롭다운. 한 번에 하나만 열린다.
enum _OpenField { none, season, league, team, sort }

class _ScheduleListFilterSheetState extends State<ScheduleListFilterSheet> {
  MatchListViewModel get _vm => widget.viewModel;

  _OpenField _open = _OpenField.none;

  void _toggle(_OpenField field) => setState(
    () => _open = _open == field ? _OpenField.none : field,
  );

  /// 단일 선택 필드는 고르면 닫는다 — 더 고를 게 없는데 열어 두면
  /// 아래 필드가 가려진 채 남는다.
  void _pickAndClose(_OpenField field, VoidCallback apply) {
    apply();
    setState(() => _open = _OpenField.none);
  }

  /// 단일 선택 목록 → 드롭다운 항목.
  List<NarSelectOption> _single(List<String> options, String? selected) => [
    for (final o in options)
      NarSelectOption(name: o, selected: o == selected),
  ];

  /// VM 의 '전체'(ALL) 센티널만 현지화 라벨로 바꾼다. 나머지 리그·팀 이름은
  /// 서버 값 그대로 보여준다.
  static String _leagueLabel(String value, String allLabel) =>
      value == MatchListViewModel.allLeagueLabel ? allLabel : value;

  static String _teamLabel(String value, String allLabel) =>
      value == MatchListViewModel.allTeamsLabel ? allLabel : value;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final leagueIsAll =
            _vm.selectedLeague == MatchListViewModel.allLeagueLabel;
        // 팀은 다중 선택이라 '전체'면 요약을 비워 placeholder('전체')가 뜨게 한다.
        final teamsSelected = _vm.selectedTeams
            .where((t) => t != MatchListViewModel.allTeamsLabel)
            .toList();

        return NarFilterSheet(
          title: l.filter,
          onReset: () {
            _vm.resetFilter();
            setState(() => _open = _OpenField.none);
          },
          onApply: () => Navigator.of(context).pop(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: l.season,
                  scale: scale,
                  child: NarSelectDropdownField(
                    placeholder: l.select,
                    summary: _vm.selectedSeason,
                    options: _single(_vm.seasons, _vm.selectedSeason),
                    isOpen: _open == _OpenField.season,
                    onTapBox: () => _toggle(_OpenField.season),
                    onToggle: (name) => _pickAndClose(
                      _OpenField.season,
                      () => _vm.selectSeason(name),
                    ),
                    scale: scale,
                  ),
                ),
                SizedBox(height: 24 * scale),
                LabeledField(
                  label: l.league,
                  scale: scale,
                  child: NarSelectDropdownField(
                    placeholder: _vm.loadingLeagues ? l.loading : l.all,
                    // '전체'는 기본값이라 요약 없이 placeholder 로 둔다
                    // (셀렉트 박스 테두리도 그때만 빠진다).
                    summary: leagueIsAll ? null : _vm.selectedLeague,
                    options: [
                      for (final league in _vm.leagues)
                        NarSelectOption(
                          name: _leagueLabel(league, l.all),
                          selected: league == _vm.selectedLeague,
                        ),
                    ],
                    isOpen: _open == _OpenField.league,
                    onTapBox: () => _toggle(_OpenField.league),
                    // 드롭다운은 라벨만 돌려주므로 원래 값으로 되짚어 넘긴다
                    // — 라벨이 언어마다 다르고('전체'/'All'), 그 문자열을
                    // 그대로 VM 에 넣으면 영어에서 리그 코드가 어긋난다.
                    onToggle: (label) => _pickAndClose(
                      _OpenField.league,
                      () => _vm.selectLeague(
                        _vm.leagues.firstWhere(
                          (v) => _leagueLabel(v, l.all) == label,
                          orElse: () => MatchListViewModel.allLeagueLabel,
                        ),
                      ),
                    ),
                    leadingBuilder: leagueIconWidget,
                    scale: scale,
                  ),
                ),
                // 리그 '전체'(ALL)는 팀 스코프가 없어 팀 목록이 '전체'뿐이므로
                // 팀 필드를 숨긴다.
                if (!leagueIsAll) ...[
                  SizedBox(height: 24 * scale),
                  LabeledField(
                    label: l.team,
                    scale: scale,
                    child: NarSelectDropdownField(
                      placeholder: l.all,
                      summary: teamsSelected.isEmpty
                          ? null
                          : teamsSelected.join(', '),
                      options: [
                        for (final t in _vm.teams)
                          NarSelectOption(
                            name: _teamLabel(t, l.all),
                            selected: _vm.selectedTeams.contains(t),
                          ),
                      ],
                      isOpen: _open == _OpenField.team,
                      onTapBox: () => _toggle(_OpenField.team),
                      // 팀은 다중 선택 — 고른 뒤에도 열어 둔다.
                      // VM 이 '전체' 규칙(전부 해제 시 전체로 복귀 등)을
                      // 들고 있으므로 토글 결과를 그대로 넘긴다.
                      onToggle: (label) {
                        final value = _vm.teams.firstWhere(
                          (v) => _teamLabel(v, l.all) == label,
                          orElse: () => MatchListViewModel.allTeamsLabel,
                        );
                        final next = {..._vm.selectedTeams};
                        if (!next.remove(value)) next.add(value);
                        _vm.updateSelectedTeams(next);
                      },
                      scale: scale,
                    ),
                  ),
                ],
                SizedBox(height: 24 * scale),
                LabeledField(
                  label: l.sort,
                  scale: scale,
                  child: NarSelectDropdownField(
                    placeholder: l.select,
                    summary: _vm.sortOrder,
                    options: _single(_vm.sortOrders, _vm.sortOrder),
                    isOpen: _open == _OpenField.sort,
                    onTapBox: () => _toggle(_OpenField.sort),
                    onToggle: (name) => _pickAndClose(
                      _OpenField.sort,
                      () => _vm.selectSortOrder(name),
                    ),
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
