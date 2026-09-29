import 'package:flutter/material.dart';

import '../../../components/nar_live_dot.dart';
import '../../../components/team_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/schedule_match.dart';
import '../../../styles/app_colors.dart';
import '../../../util/match_detail_router.dart';
import '../../../util/match_status.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import 'home_section_header.dart';

/// 오늘 경기 — 가로 스트립. LIVE 경기가 앞으로 온다.
///
/// 일정 탭으로 가는 길은 헤더의 "일정 전체" 링크 하나뿐이다([onSeeSchedule]).
/// 예전엔 스트립 마지막에도 같은 링크의 카드가 있었는데, 헤더 바로 아래라
/// 같은 화면에 "일정 전체"가 두 번 보여 뺐다. 경기가 없으면 섹션 전체를
/// 그리지 않는다 — 헤더만 남는 빈 자리를 피한다.
class HomeTodayMatchesSection extends StatelessWidget {
  const HomeTodayMatchesSection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onSeeSchedule,
  });

  final HomeViewModel viewModel;
  final double scale;
  final VoidCallback? onSeeSchedule;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final matches = viewModel.todayMatchesSorted;
    if (matches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeTodayMatchesTitle,
            scale: scale,
            subtitle: _todayLabel(DateTime.now()),
            trailingLabel: l.homeSeeAllSchedule,
            onTapTrailing: onSeeSchedule,
          ),
        ),
        SizedBox(height: 10 * scale),
        SizedBox(
          height: 110 * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // 스트립은 화면 끝까지 밀리게 두고 양끝만 20 여백.
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            itemCount: matches.length,
            separatorBuilder: (_, _) => SizedBox(width: 10 * scale),
            itemBuilder: (context, i) =>
                _MatchCard(match: matches[i], scale: scale),
          ),
        ),
      ],
    );
  }
}

/// 헤더 부제 — 시안(`mockup.html`)의 `sh('오늘의 경기', ..., '9월 12일')`처럼
/// 앞자리 0 없이 "M월 d일"로 쓴다.
String _todayLabel(DateTime now) => '${now.month}월 ${now.day}일';

/// 오늘 경기 카드 한 장 — 시안(`mockup.html`)의 `.mc`.
///
/// 폭 172, 안쪽 여백 위 10·좌우 12·아래 12, 테두리 1을 더해 높이 110이다.
/// LIVE 카드는 어두운 배경에 일반 카드와 같은 옅은 테두리(narLine)를 두르고,
/// 왼쪽만 3px 강조선(liveSideBorder)으로 덧대 눈에 띄게 한다.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.scale});

  final ScheduleMatch match;
  final double scale;

  // 서버 표기가 흔들려(inProgress/in_progress/LIVE …) 공용 판정을 쓴다.
  bool get _live => isLiveMatchStatus(match.matchStatus);
  bool get _done => match.matchStatus == 'completed';

  /// 경기 상세로 이동한다. 딥링크(라이브 위젯·푸시)와 같은 창구를 써야
  /// 이미 열려 있는 같은 경기 상세를 재사용한다(직접 push 하면 중복 스택).
  void _openDetail(BuildContext context) {
    MatchDetailRouter.open(
      matchId: match.matchId,
      match: match,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12 * scale);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(context),
      // LIVE 카드는 테두리 색이 왼쪽(강조)과 나머지 3면(옅은 선)으로 다른데,
      // BoxDecoration.border는 borderRadius와 함께 쓸 때 색이 균일해야 한다
      // ("A borderRadius can only be given on borders with uniform colors").
      // 그래서 균일한 옅은 테두리를 바탕 Container에 두고, 왼쪽 강조선은
      // Stack으로 그 위에 따로 얹는다. ClipRRect로 Stack 전체를 카드와 같은
      // radius로 한 번 더 잘라야, 사각형인 강조선이 카드 모서리 둥근 구간에서
      // 바깥으로 삐져나오지 않고 곡선을 따라 자연스럽게 잘린다.
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Container(
              width: 172 * scale,
              padding: EdgeInsets.fromLTRB(
                12 * scale,
                10 * scale,
                12 * scale,
                12 * scale,
              ),
              decoration: BoxDecoration(
                color: _live ? AppColors.narDark600 : AppColors.narBgTertiary,
                borderRadius: radius,
                border: Border.all(color: AppColors.narLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(
                        live: _live,
                        done: _done,
                        time: match.scheduledTime,
                        scale: scale,
                      ),
                      SizedBox(width: 6 * scale),
                      Expanded(
                        child: Text(
                          '${match.leagueInfo} · ${match.matchTitle.split(' | ').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontWeight: FontWeight.w600,
                            fontSize: 13 * scale,
                            color: AppColors.narText2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10 * scale),
                  _TeamRow(
                    team: match.teamA,
                    other: match.teamB,
                    done: _done,
                    scale: scale,
                  ),
                  SizedBox(height: 6 * scale),
                  _TeamRow(
                    team: match.teamB,
                    other: match.teamA,
                    done: _done,
                    scale: scale,
                  ),
                ],
              ),
            ),
            if (_live)
              Positioned(
                left: 1 * scale,
                top: 1 * scale,
                bottom: 1 * scale,
                width: 3 * scale,
                child: ColoredBox(color: AppColors.liveSideBorder),
              ),
          ],
        ),
      ),
    );
  }
}

/// 상태 배지 — 시안의 `.badge`. 높이 22·둥근 8, 예정은 시각, 종료는 "종료",
/// LIVE 는 붉은 테두리에 깜박이는 점이 앞선다.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.live,
    required this.done,
    required this.time,
    required this.scale,
  });

  final bool live;
  final bool done;
  final String time;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final label = live
        ? 'LIVE'
        : done
        ? l.homeMatchStatusDone
        : time;
    return Container(
      height: 22 * scale,
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: live ? AppColors.liveBadgeBg : AppColors.narBgTertiary,
        border: Border.all(
          color: live ? AppColors.narRed500 : AppColors.narLine2,
        ),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            NarLiveDot(size: 5, scale: scale),
            SizedBox(width: 5 * scale),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: live ? FontWeight.w500 : FontWeight.w600,
              fontSize: 12 * scale,
              height: 1,
              color: live
                  ? AppColors.liveAccent
                  : done
                  ? AppColors.narText2
                  : AppColors.narTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 한 줄 — 로고 24 · 코드 14 · 점수 16. 끝난 경기에서 진 팀은 코드와 로고를
/// 흐리게(로고 투명도 .55), 이긴 팀 점수는 빨강으로 그린다.
class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    required this.other,
    required this.done,
    required this.scale,
  });

  final MatchTeam team;
  final MatchTeam other;
  final bool done;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final win = done && team.score > other.score;
    final lose = done && !win;
    return Row(
      children: [
        Opacity(
          opacity: lose ? 0.55 : 1,
          child: TeamLogo(
            teamCode: team.teamCode,
            imageUrl: team.teamImageUrl,
            size: 24 * scale,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            team.teamCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              color: lose ? AppColors.narDark200 : AppColors.narTextTertiary,
            ),
          ),
        ),
        Text(
          '${team.score}',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
            fontSize: 16 * scale,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: win ? AppColors.scoreWin : AppColors.narDark200,
          ),
        ),
      ],
    );
  }
}
