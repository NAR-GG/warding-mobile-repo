import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../model/schedule_match.dart';
import '../../../components/app_refresh_indicator.dart';
import '../../../styles/app_colors.dart';
import '../../../util/match_detail_router.dart';
import '../../../util/match_status.dart';
import '../../../util/match_title_l10n.dart';
import '../../../viewmodel/match_day/match_day_viewmodel.dart';
import '../../match_list/component/match_card.dart';
import '../../match_list/component/match_card_skeleton.dart';
import '../../match_list/component/match_date_header.dart';
import '../../match_list/component/match_league_header.dart';

/// 특정 날짜 하나의 경기 리스트 본문(날짜 헤더 + 카드 리스트 + 로딩/빈 상태).
///
/// [MatchDayScreen]의 스와이프 페이지 하나하나가 이 위젯을 렌더링한다.
/// 렌더링만 담당하고 상태·로직은 [viewModel]([MatchDayViewModel])이 갖는다.
class MatchDayView extends StatelessWidget {
  const MatchDayView({
    super.key,
    required this.date,
    required this.viewModel,
    required this.spoilerPreventionEnabled,
    required this.revealedMatchIds,
    required this.onSpoilerReveal,
    required this.scale,
  });

  final DateTime date;
  final MatchDayViewModel viewModel;
  final bool spoilerPreventionEnabled;

  /// 사용자가 스코어를 공개한 경기 ID. 카드가 파괴·재생성돼도 공개 상태가
  /// 유지되도록 화면이 들고 내려준다.
  final Set<String> revealedMatchIds;

  /// 스포방지 오버레이를 탭했을 때. 인자는 그 경기 ID.
  final ValueChanged<String> onSpoilerReveal;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // 로딩 중에는 당기지 않는다 — 이미 받고 있는데 또 걸 이유가 없다.
    if (viewModel.isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 * scale),
        itemCount: 4,
        // 첫 장은 실제 카드와 같이 위 구분선을 끈다(날짜 헤더 아래 첫 카드 규칙).
        itemBuilder: (_, index) =>
            MatchCardSkeleton(scale: scale, showTopBorder: index != 0),
      );
    }

    return AppRefreshIndicator(
      onRefresh: viewModel.load,
      child: _buildList(context, l),
    );
  }

  /// 경기 목록. 결과가 없으면 안내 문구만 두되, 그 상태에서도 당길 수 있게
  /// 스크롤 뷰 안에 담는다 — 조회 실패로 비어 있을 때가 새로고침이 가장
  /// 필요한 순간이다.
  Widget _buildList(BuildContext context, AppLocalizations l) {
    final matches = viewModel.matches;
    if (matches.isEmpty) {
      // 경기가 없는 날도 날짜 헤더는 그대로 보여주고, 그 아래에 안내 문구만 둔다.
      return ListView(
        physics: AppRefreshIndicator.physics,
        children: [
          _dateHeader(l),
          SizedBox(height: 120 * scale),
          _centerMessage(
            viewModel.error != null ? l.matchLoadFailed : l.noMatches,
            scale,
          ),
        ],
      );
    }

    // 첫 항목은 날짜 그룹 헤더(경기리스트와 동일), 이후 리그 헤더(필요하면)+경기 카드.
    final items = _buildItems(context, matches, l);
    return ListView.builder(
      physics: AppRefreshIndicator.physics,
      padding: EdgeInsets.only(bottom: 24 * scale),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// 날짜 그룹 헤더 + 바로 아래 리그 헤더/카드와의 갭.
  Widget _dateHeader(AppLocalizations l) => Padding(
    padding: EdgeInsets.only(bottom: 8 * scale),
    child: MatchDateHeader(
      isToday: _isToday(date),
      dateText: _formatDate(date, l),
      todayLabel: l.today,
      scale: scale,
    ),
  );

  /// 날짜 헤더 + (필요하면 리그 헤더로 묶인) 경기 카드들을 미리 만들어 둔다.
  ///
  /// [viewModel.leagues] 가 리그를 하나로 특정하지 않았으면(전체·다중 선택)
  /// 여러 리그 경기가 섞여 오므로, 리그별로 묶어(첫 등장 순서 유지) 그 앞에
  /// 리그 헤더([MatchLeagueHeader])를 낀다 — 경기리스트 탭과 동일한 규칙.
  List<Widget> _buildItems(
    BuildContext context,
    List<ScheduleMatch> matches,
    AppLocalizations l,
  ) {
    final leagues = viewModel.leagues;
    final groupByLeague =
        leagues.isEmpty || leagues.length > 1 || leagues.single == 'ALL';

    final items = <Widget>[_dateHeader(l)];

    if (!groupByLeague) {
      for (var i = 0; i < matches.length; i++) {
        items.add(_buildCard(context, matches[i], showTopBorder: i > 0, l: l));
      }
      return items;
    }

    final byLeague = <String, List<ScheduleMatch>>{};
    for (final m in matches) {
      (byLeague[m.leagueInfo] ??= []).add(m);
    }
    for (final entry in byLeague.entries) {
      items.add(MatchLeagueHeader(leagueName: entry.key, scale: scale));
      for (var i = 0; i < entry.value.length; i++) {
        items.add(
          _buildCard(context, entry.value[i], showTopBorder: i > 0, l: l),
        );
      }
    }
    return items;
  }

  /// 경기 카드 한 장. [showTopBorder] 는 자기 그룹(날짜/리그 헤더) 안 첫 카드면 false.
  Widget _buildCard(
    BuildContext context,
    ScheduleMatch m, {
    required bool showTopBorder,
    required AppLocalizations l,
  }) {
    return MatchCard(
      key: ValueKey('match-${m.matchId}'),
      matchId: m.matchId,
      showTopBorder: showTopBorder,
      time: m.scheduledTime,
      label: _localizeMatchTitle(context, m.matchTitle),
      homeName: _shortName(m.teamA),
      awayName: _shortName(m.teamB),
      homeLogoUrl: m.teamA.teamImageUrl,
      awayLogoUrl: m.teamB.teamImageUrl,
      homeCode: m.teamA.teamCode,
      awayCode: m.teamB.teamCode,
      homeScore: m.teamA.score,
      awayScore: m.teamB.score,
      isLive: _isLive(m.matchStatus),
      liveSetLabel: _isLive(m.matchStatus)
          ? l.setInProgress(
              liveSetNumber(
                homeScore: m.teamA.score,
                awayScore: m.teamB.score,
                setsPlayed: m.sets.length,
              ),
            )
          : null,
      leagueInfo: m.leagueInfo,
      spoilerPreventionEnabled: spoilerPreventionEnabled,
      spoilerRevealed: revealedMatchIds.contains(m.matchId),
      onSpoilerReveal: () => onSpoilerReveal(m.matchId),
      // 딥링크(라이브 위젯·푸시)와 같은 창구를 쓴다 — 직접 push 하면 그쪽에서
      // 열린 상세를 못 찾아 같은 경기가 두 장 쌓인다.
      onTap: () => MatchDetailRouter.open(
        matchId: m.matchId,
        match: m,
        context: context,
      ),
      scale: scale,
    );
  }

  Widget _centerMessage(String text, double scale) => Center(
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14 * scale,
        color: AppColors.narText2,
      ),
    ),
  );

  String _shortName(MatchTeam team) =>
      team.teamCode.isNotEmpty ? team.teamCode : team.teamName;

  /// 라이브 판정은 표기 흔들림(`inProgress` 등)을 흡수하는 공용 유틸에 맡긴다.
  bool _isLive(String status) => isLiveMatchStatus(status);

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d == today;
  }

  String _formatDate(DateTime d, AppLocalizations l) =>
      l.yearMonthDay(d.year, d.month, d.day);

  String _localizeMatchTitle(BuildContext context, String title) =>
      localizeMatchTitle(title, AppLocalizations.of(context)!);
}
