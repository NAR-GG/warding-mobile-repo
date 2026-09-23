import 'package:flutter/material.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import '../../../model/standing.dart';
import 'home_pill_tabs.dart';
import 'home_section_header.dart';

/// 순위표 — 리그 칩 한 줄 + 리그 테이블. 목업의 세 형태(리그표/스위스/토너먼트)
/// 중 리그 테이블만 구현한다(스코프 결정 — [/api/standings]가 LCK만 제공).
///
/// spec "상태" 표: 데이터가 없는 리그(LPL·LEC·LCS, 월즈도 이번 스코프 밖)는
/// 점선 칩으로 두고 누를 수 없다. 로딩·에러는 그리지 않는다 — 아직 못 받았으면
/// 표 자리를 비운다. 1위 행은 따로 꾸미지 않는다(라이즈 그룹 1위가 전체 1위로
/// 읽히지 않게 — spec 결정).
class HomeStandingsSection extends StatelessWidget {
  const HomeStandingsSection({
    super.key,
    required this.viewModel,
    required this.scale,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// 리그 칩 키 — 테스트가 칩을 찾을 때 쓴다.
  static Key chipKey(String code) => ValueKey('homeLeagueChip-$code');

  /// 순위 숫자 [Text] 키.
  static Key rankKey(int rank) => ValueKey('homeStandingRank-$rank');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeStandingsTitle,
            scale: scale,
            subtitle:
                '2026 · ${viewModel.standings?.scopeLabel.isNotEmpty == true ? viewModel.standings!.scopeLabel : l.homeStandingsScopeLabel}',
          ),
        ),
        SizedBox(height: 10 * scale),
        HomePillTabs<String>(
          tabs: [
            for (final chip in viewModel.leagueChips)
              HomePillTab(
                value: chip.code,
                label: chip.label,
                enabled: chip.live,
                key: chipKey(chip.code),
              ),
          ],
          selected: viewModel.selectedLeague,
          onSelected: viewModel.selectLeague,
          scale: scale,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: _StandingsTable(viewModel: viewModel, scale: scale),
        ),
      ],
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.viewModel, required this.scale});

  final HomeViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 아직 못 받았으면 자리를 비운다(spec: 순위표 로딩·에러는 안 그림).
    final groups = viewModel.standings?.groups ?? const <StandingGroup>[];
    if (groups.isEmpty) return const SizedBox.shrink();

    // 첫 그룹(레전드)은 늘 펼쳐 두고, 나머지 그룹(라이즈 등)은 펼치기 뒤에 둔다.
    final main = groups.first;
    final rest = groups.skip(1).toList();
    final restCount = rest.fold<int>(0, (sum, g) => sum + g.rows.length);
    final expanded = viewModel.standingsExpanded;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        children: [
          _GroupHeader(
            label: main.name.isEmpty ? l.homeStandingsLegendGroup : main.name,
            hint: l.homeStandingsColumnHint,
            scale: scale,
          ),
          for (final (i, row) in main.rows.indexed)
            _StandingRow(
              row: row,
              isFirst: i == 0,
              scale: scale,
              // 라이즈 그룹은 그룹 안 순위라 숫자가 겹친다 — 키는 첫 그룹에만.
              rankKey: HomeStandingsSection.rankKey(row.rank),
            ),
          if (expanded)
            for (final group in rest) ...[
              _GroupHeader.sub(
                label: group.name.isEmpty
                    ? l.homeStandingsRiseGroup
                    : group.name,
                scale: scale,
              ),
              for (final (i, row) in group.rows.indexed)
                _StandingRow(row: row, isFirst: i == 0, scale: scale),
            ],
          if (restCount > 0)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: viewModel.toggleStandingsExpanded,
              child: Container(
                height: 40 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.narLine)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expanded
                          ? l.homeStandingsCollapse
                          : l.homeStandingsExpandMore(restCount),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13 * scale,
                        color: AppColors.narText2,
                      ),
                    ),
                    SizedBox(width: 4 * scale),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14 * scale,
                      color: AppColors.narText2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 그룹 헤더 — 기본(레전드 그룹): 하단 테두리 + 우측 컬럼 힌트.
/// [_GroupHeader.sub](라이즈 그룹): 상단 테두리로 앞 그룹과 구분, 힌트 없음.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.hint,
    required this.scale,
  }) : sub = false;

  const _GroupHeader.sub({required this.label, required this.scale})
    : hint = null,
      sub = true;

  final String label;
  final String? hint;
  final bool sub;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: (sub ? 30 : 34) * scale,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: BoxDecoration(
        border: sub
            ? Border(top: BorderSide(color: AppColors.narLine2))
            : Border(bottom: BorderSide(color: AppColors.narLine)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: (sub ? 12 : 13) * scale,
              color: sub ? AppColors.narGray400 : AppColors.narTextTertiary,
            ),
          ),
          const Spacer(),
          if (hint != null)
            Text(
              hint!,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 11 * scale,
                color: AppColors.narText2,
              ),
            ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.row,
    required this.scale,
    this.isFirst = false,
    this.rankKey,
  });

  final StandingRow row;
  final double scale;
  final Key? rankKey;

  /// 그룹의 첫 행이면 위 [_GroupHeader] 의 하단 테두리가 이미 구분선 역할을
  /// 하므로 자체 상단 테두리를 생략한다(겹선 방지).
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46 * scale,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : Border(top: BorderSide(color: AppColors.narLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22 * scale,
            child: Text(
              '${row.rank}',
              key: rankKey,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w600,
                fontSize: 13 * scale,
                color: AppColors.narTextTertiary,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          TeamCodeBadge(teamCode: row.teamCode, size: 26 * scale),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  row.teamCode,
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    color: AppColors.narTextTertiary,
                  ),
                ),
                Text(
                  row.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11 * scale,
                    color: AppColors.narText2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 54 * scale,
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 14 * scale,
                  color: AppColors.narTextTertiary,
                ),
                children: [
                  TextSpan(text: '${row.wins}'),
                  TextSpan(
                    text: '-',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.narDark200,
                    ),
                  ),
                  TextSpan(text: '${row.losses}'),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 44 * scale,
            child: Text(
              row.setDiff > 0 ? '+${row.setDiff}' : '${row.setDiff}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 12 * scale,
                color: row.setDiff > 0
                    ? AppColors.scoreWin
                    : AppColors.narText3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
