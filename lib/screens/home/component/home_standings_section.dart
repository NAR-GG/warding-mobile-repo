import 'package:flutter/material.dart';

import '../../../components/nar_chip_multi_select.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import '../../../model/standing.dart';
import '../../../model/worlds_standings.dart';
import 'home_section_header.dart';
import 'home_skeletons.dart';

/// 순위표 — 리그 칩 한 줄 + 선택한 리그에 맞는 몸통. LCK 등은 리그 테이블
/// ([_StandingsTable]), 월즈는 스위스 전적 버킷([_WorldsBracket])과 토너먼트
/// 대진([_WorldsKnockout])을 카드 하단 버튼으로 전환한다
/// (warding-docs `features/home/mockup.html` 시안).
///
/// spec "상태" 표: 데이터가 없는 리그(LPL·LEC·LCS)는 점선 칩으로 두고 누를
/// 수 없다. 로딩·에러는 그리지 않는다 — 아직 못 받았으면 표 자리를 비운다.
/// 리그 테이블의 각 그룹(레전드·라이즈 등) 1위 순위 숫자를 메인 보라색
/// (narChipActive)으로 강조한다(2026-09-29 결정) — 그룹별 1위라 여러 개가
/// 보일 수 있다.
class HomeStandingsSection extends StatelessWidget {
  const HomeStandingsSection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onSeeAllBracket,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// "전체 경기" — 오늘 경기 섹션의 "일정 전체"와 같은 패턴으로 경기 리스트
  /// 탭을 연다. 선택한 리그와 무관하게 항상 헤더에 노출한다.
  final VoidCallback? onSeeAllBracket;

  /// 순위 숫자 [Text] 키.
  static Key rankKey(int rank) => ValueKey('homeStandingRank-$rank');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isWorlds = viewModel.selectedLeague == 'WORLDS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeStandingsTitle,
            scale: scale,
            // StandingsResult에 시즌 연도 필드가 없어 기기 시계 연도로 대신한다
            // (하드코딩된 2026이 다음 시즌에도 안 바뀌는 문제 — 백엔드가 연도를
            // 내려주면 그걸로 교체한다).
            subtitle: isWorlds
                ? (viewModel.worldsView == WorldsStandingsView.swiss
                      ? l.homeStandingsWorldsSwissScope
                      : l.homeStandingsWorldsKnockoutScope)
                : '${DateTime.now().year} · ${viewModel.standings?.scopeLabel.isNotEmpty == true ? viewModel.standings!.scopeLabel : l.homeStandingsScopeLabel}',
            trailingLabel: l.homeStandingsSeeAllMatches,
            onTapTrailing: onSeeAllBracket,
          ),
        ),
        SizedBox(height: 2 * scale),
        // 데이터가 있는 리그(live)만 고를 수 있고 나머지는 점선 칩이다.
        NarChipMultiSelect.single(
          options: [for (final chip in viewModel.leagueChips) chip.code],
          selected: viewModel.selectedLeague,
          onSelected: viewModel.selectLeague,
          labelBuilder: (code) =>
              viewModel.leagueChips.firstWhere((c) => c.code == code).label,
          disabledOptions: {
            for (final chip in viewModel.leagueChips)
              if (!chip.live) chip.code,
          },
          horizontalPadding: 20,
          scale: scale,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: isWorlds
              ? _WorldsStandingsCard(viewModel: viewModel, scale: scale)
              : _StandingsTable(viewModel: viewModel, scale: scale),
        ),
      ],
    );
  }
}

/// 월즈 카드 — 스위스 전적 / 토너먼트 대진 중 [HomeViewModel.worldsView]가
/// 가리키는 쪽을 그리고, 하단 버튼으로 서로 전환한다.
class _WorldsStandingsCard extends StatelessWidget {
  const _WorldsStandingsCard({required this.viewModel, required this.scale});

  final HomeViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final data = viewModel.worldsStandings;
    if (data == null) return const SizedBox.shrink();

    final isSwiss = viewModel.worldsView == WorldsStandingsView.swiss;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        children: [
          _WorldsCardHeader(
            label: isSwiss
                ? l.homeStandingsWorldsSwissTitle
                : l.homeStandingsWorldsKnockoutTitle,
            hint: isSwiss
                ? l.homeStandingsWorldsSwissHint
                : l.homeStandingsWorldsKnockoutHint,
            scale: scale,
          ),
          if (isSwiss)
            _WorldsBracket(rows: data.bracket, scale: scale)
          else
            _WorldsKnockout(rounds: data.knockout, scale: scale),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: viewModel.toggleWorldsView,
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
                    isSwiss
                        ? l.homeStandingsWorldsShowKnockout
                        : l.homeStandingsWorldsShowSwiss,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14 * scale,
                      color: AppColors.narText2,
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16 * scale,
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

/// 월즈 카드 헤더 — 좌측 라벨("스위스 전적"/"토너먼트 대진") + 우측 힌트
/// ("3승 진출 · 3패 탈락"/"8강 → 결승"). [_GroupHeader]의 wlHint(폭 54 고정)는
/// 리그 테이블의 "승-패" 같은 짧은 라벨 전용이라 이 긴 문구엔 폭이 모자라
/// 거의 다 잘렸다 — 월즈 전용으로 폭 제한 없이 둔다.
class _WorldsCardHeader extends StatelessWidget {
  const _WorldsCardHeader({
    required this.label,
    required this.hint,
    required this.scale,
  });

  final String label;
  final String hint;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 34 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.narLine)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              hint,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 11 * scale,
                color: AppColors.narText2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스위스 스테이지 전적 버킷 — 같은 전적(3-0, 2-3 등)끼리 팀 로고를 묶어
/// 한 줄로 보여준다. 3승 진출·3패 탈락 확정 여부로 색을 달리한다.
class _WorldsBracket extends StatelessWidget {
  const _WorldsBracket({required this.rows, required this.scale});

  final List<WorldsBracketRow> rows;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (final (i, row) in rows.indexed)
          Container(
            constraints: BoxConstraints(minHeight: 46 * scale),
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 8 * scale,
            ),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: AppColors.narLine)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44 * scale,
                  child: Text(
                    row.record,
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15 * scale,
                      // mockup `.bk .tr.adv .rec{color:var(--score-win)}` —
                      // 진출 전적은 레드(승 스코어와 같은 색), 탈락은 흐린 회색.
                      // tabularFigures로 "3-0"/"3-1" 숫자 폭을 맞춘다.
                      color: row.advanced
                          ? AppColors.scoreWin
                          : AppColors.narDark200,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Wrap(
                    spacing: 6 * scale,
                    runSpacing: 6 * scale,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final code in row.teamCodes)
                        Opacity(
                          opacity: row.advanced ? 1 : 0.45,
                          child: TeamCodeBadge(
                            teamCode: code,
                            size: 26 * scale,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8 * scale),
                Text(
                  row.advanced
                      ? l.homeStandingsWorldsAdvanced
                      : l.homeStandingsWorldsEliminated,
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 11 * scale,
                    color: row.advanced
                        ? AppColors.narGreenWin
                        : AppColors.narDark200,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 토너먼트 대진 — 라운드(8강·4강·결승)를 가로로 늘어놓고, 다음 라운드
/// 매치는 이전 라운드 두 매치의 중간 높이에 둬서 표준 브래킷 모양을 만든다.
/// 라운드 사이는 [CustomPaint]로 L자 연결선을 긋는다(mockup.html `drawLinks()`
/// 참고 — DOM 위치 계산 대신 토너먼트 구조로 좌표를 고정값 계산한다).
/// 화면 폭에 안 맞으면 가로로 스크롤한다.
class _WorldsKnockout extends StatelessWidget {
  const _WorldsKnockout({required this.rounds, required this.scale});

  final List<WorldsKnockoutRound> rounds;
  final double scale;

  static const double _columnWidth = 168;
  static const double _columnGap = 28;
  // 모든 노드(오늘 경기 포함)를 같은 높이로 통일한다 — "오늘" 시각은 스코어
  // 자리에 대신 넣어서 별도 줄을 안 둔다(전엔 셋째 줄을 더 둬서 노드가 더
  // 높았고, 그만큼 라운드 간 간격 공식도 커져 브래킷 전체가 헐렁했다).
  // 팀 로우 2개(각 padding 12 + 텍스트 라인하이트 ~20) + 구분선 1 ≈ 64.
  static const double _nodeHeight = 68;
  static const double _roundHeaderHeight = 24;
  // 첫 라운드(8강) 매치 사이 간격 — 다음 라운드는 이 배수로 넓어진다.
  static const double _firstRoundGap = 12;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();
    final firstCount = rounds.first.matches.length;
    final totalHeight =
        _roundHeaderHeight * scale +
        firstCount * _nodeHeight * scale +
        (firstCount - 1) * _firstRoundGap * scale +
        16 * scale;
    final totalWidth =
        rounds.length * _columnWidth * scale +
        (rounds.length - 1) * _columnGap * scale;

    // 라운드 i, 매치 j 카드의 세로 중심선 — 표준 토너먼트 간격 공식(2^i 배).
    double centerY(int roundIndex, int matchIndex) {
      final spacing = _firstRoundGap * scale * (1 << roundIndex);
      final period = (_nodeHeight * scale) + spacing;
      final firstCenter = period / 2;
      return _roundHeaderHeight * scale + firstCenter + matchIndex * period;
    }

    return Padding(
      padding: EdgeInsets.all(12 * scale),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(totalWidth, totalHeight),
                painter: _BracketLinesPainter(
                  rounds: rounds,
                  columnWidth: _columnWidth * scale,
                  columnGap: _columnGap * scale,
                  centerY: centerY,
                  color: AppColors.narLine2,
                ),
              ),
              for (final (ri, round) in rounds.indexed)
                Positioned(
                  left: ri * (_columnWidth + _columnGap) * scale,
                  top: 0,
                  width: _columnWidth * scale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _roundHeaderHeight * scale,
                        child: Center(
                          child: Text(
                            round.name,
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 12 * scale,
                              color: AppColors.narText2,
                            ),
                          ),
                        ),
                      ),
                      for (final (mi, match) in round.matches.indexed)
                        Padding(
                          padding: EdgeInsets.only(
                            top:
                                centerY(ri, mi) -
                                _nodeHeight * scale / 2 -
                                (mi == 0
                                    ? _roundHeaderHeight * scale
                                    : centerY(ri, mi - 1) +
                                          _nodeHeight * scale / 2),
                          ),
                          child: SizedBox(
                            height: _nodeHeight * scale,
                            child: Center(
                              child: _WorldsMatchNode(
                                match: match,
                                scale: scale,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라운드 사이 L자 연결선. 매치 i(라운드 r)의 두 팀은 라운드 r+1의
/// `i~/2`번 매치로 모인다 — 표준 단일 엘리미네이션 구조라 이 인덱스 매핑만
/// 으로 연결선을 계산할 수 있다(mockup.html은 `fromMatchId`로 같은 일을 한다).
class _BracketLinesPainter extends CustomPainter {
  _BracketLinesPainter({
    required this.rounds,
    required this.columnWidth,
    required this.columnGap,
    required this.centerY,
    required this.color,
  });

  final List<WorldsKnockoutRound> rounds;
  final double columnWidth;
  final double columnGap;
  final double Function(int roundIndex, int matchIndex) centerY;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var ri = 0; ri < rounds.length - 1; ri++) {
      final fromCount = rounds[ri].matches.length;
      for (var mi = 0; mi < fromCount; mi++) {
        // x1 = 현재 라운드 컬럼의 우측 끝(컬럼 시작 + 폭), x2 = 다음 라운드
        // 컬럼의 좌측 끝. 이전엔 x1을 다음 컬럼의 "시작"으로 잘못 계산해
        // columnGap만큼 밀려 있었다(8강 첫 두 매치 연결선이 안 보이던 원인).
        final x1 = ri * (columnWidth + columnGap) + columnWidth;
        final y1 = centerY(ri, mi);
        final x2 = x1 + columnGap;
        final y2 = centerY(ri + 1, mi ~/ 2);
        final midX = (x1 + x2) / 2;
        final path = Path()
          ..moveTo(x1, y1)
          ..lineTo(midX, y1)
          ..lineTo(midX, y2)
          ..lineTo(x2, y2);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketLinesPainter oldDelegate) => false;
}

class _WorldsMatchNode extends StatelessWidget {
  const _WorldsMatchNode({required this.match, required this.scale});

  final WorldsMatch match;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isToday = match.status == WorldsMatchStatus.today;
    final l = AppLocalizations.of(context)!;

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.circular(10 * scale),
        border: isToday
            ? null
            : Border.all(
                color: match.isFinal ? Colors.transparent : AppColors.narLine2,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WorldsMatchTeamRow(
            team: match.teamA,
            scale: scale,
            todayTime: isToday ? match.todayTime : null,
          ),
          Container(height: 1, color: AppColors.narLine),
          _WorldsMatchTeamRow(team: match.teamB, scale: scale),
        ],
      ),
    );

    if (isToday) {
      // 오늘 경기 — 주황 테두리(mockup `.node.today`, 네 변 두께를 통일했다).
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(
            color: AppColors.liveSideBorder,
            width: 1.5 * scale,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: card,
      );
    }
    if (match.isFinal) {
      // 결승 — 브랜드 그라디언트 테두리(mockup `.node.final`).
      return Container(
        padding: EdgeInsets.all(1.5 * scale),
        decoration: BoxDecoration(
          gradient: AppColors.narBg,
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: Semantics(
          label: l.homeStandingsWorldsKnockoutTitle,
          child: card,
        ),
      );
    }
    return card;
  }
}

class _WorldsMatchTeamRow extends StatelessWidget {
  const _WorldsMatchTeamRow({
    required this.team,
    required this.scale,
    this.todayTime,
  });

  final WorldsMatchTeam team;
  final double scale;

  /// 아직 안 끝난 "오늘 경기"의 시각 — 세트 스코어 자리에 작게 대신 보여준다
  /// (노드를 다른 매치와 같은 높이로 유지하려고 별도 줄을 안 둔다).
  final String? todayTime;

  @override
  Widget build(BuildContext context) {
    final lost = team.won == false;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
      child: Row(
        children: [
          if (!team.isTbd) ...[
            TeamCodeBadge(teamCode: team.teamCode!, size: 20 * scale),
            SizedBox(width: 6 * scale),
          ],
          Expanded(
            child: Text(
              team.teamCode ?? 'TBD',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 13 * scale,
                color: lost ? AppColors.narDark200 : AppColors.narTextTertiary,
              ),
            ),
          ),
          if (todayTime != null)
            Text(
              todayTime!,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w600,
                fontSize: 11 * scale,
                color: AppColors.liveSideBorder,
              ),
            )
          else if (team.gameWins != null)
            Text(
              '${team.gameWins}',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w700,
                fontSize: 14 * scale,
                color: team.won == true
                    ? AppColors.narGreenWin
                    : AppColors.narDark200,
              ),
            ),
        ],
      ),
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
    if (groups.isEmpty) {
      return viewModel.standingsLoading
          ? HomeStandingsSkeleton(scale: scale)
          : const SizedBox.shrink();
    }

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
            wlHint: l.homeStandingsColumnWL,
            setDiffHint: l.homeStandingsColumnSetDiff,
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
                        fontSize: 14 * scale,
                        color: AppColors.narText2,
                      ),
                    ),
                    SizedBox(width: 4 * scale),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16 * scale,
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

/// 그룹 헤더 — 기본(레전드 그룹): 하단 테두리 + 우측 컬럼 힌트(W-L·득실칸).
/// [_GroupHeader.sub](라이즈 그룹): 상단 테두리로 앞 그룹과 구분, 힌트 없음.
///
/// 힌트 두 칸은 [_StandingRow]의 W-L 칸(54)·득실 칸(44)과 같은 폭으로 둬야
/// 아래 행과 위아래로 정확히 겹친다.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.wlHint,
    required this.setDiffHint,
    required this.scale,
  }) : sub = false;

  const _GroupHeader.sub({required this.label, required this.scale})
    : wlHint = null,
      setDiffHint = null,
      sub = true;

  final String label;
  final String? wlHint;
  final String? setDiffHint;
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
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
          const Spacer(),
          if (wlHint != null)
            SizedBox(
              width: 54 * scale,
              child: Text(
                wlHint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 11 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ),
          if (setDiffHint != null) ...[
            SizedBox(width: 4 * scale),
            SizedBox(
              width: 48 * scale,
              child: Text(
                setDiffHint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 11 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ),
          ],
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
    // 각 그룹(레전드·라이즈 등) 안에서 1위 숫자를 보라색으로 강조한다
    // (2026-09-29 결정). 그룹별로 rank가 1부터 다시 매겨지므로, 이 강조는
    // "전체 1위"가 아니라 "그 그룹의 1위"를 가리킨다.
    final isTopRank = row.rank == 1;
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
                fontWeight: FontWeight.w800,
                fontSize: 15 * scale,
                color: isTopRank
                    ? AppColors.narChipActive
                    : AppColors.narTextTertiary,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          // 커뮤니티 등 다른 홈 섹션과 같은 이미지 소스([TeamLogoDirectory])를
          // 쓰도록 이 응답의 imageUrl은 넘기지 않는다 — 두 소스가 서로 다른
          // 원본(여백·비율)을 내려줘 같은 배지 크기에서도 로고가 다르게 보였다.
          TeamCodeBadge(teamCode: row.teamCode, size: 28 * scale),
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
                    fontSize: 16 * scale,
                    color: AppColors.narTextTertiary,
                  ),
                ),
                Text(
                  row.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13 * scale,
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
                  fontSize: 16 * scale,
                  color: AppColors.narTextTertiary,
                ),
                children: [
                  TextSpan(text: '${row.wins}'),
                  TextSpan(
                    text: ' - ',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.narDark200,
                    ),
                  ),
                  TextSpan(text: '${row.losses}'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 4 * scale),
          SizedBox(
            width: 48 * scale,
            child: Text(
              row.setDiff > 0 ? '+${row.setDiff}' : '${row.setDiff}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 14 * scale,
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
