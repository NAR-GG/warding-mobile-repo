import 'package:flutter/material.dart';

import '../../../components/dashed_border.dart';
import '../../../components/nar_live_dot.dart';
import '../../../components/team_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/schedule_match.dart';
import '../../../styles/app_colors.dart';
import '../../../util/match_status.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import 'home_section_header.dart';

/// 오늘 경기 — 가로 스트립. LIVE 경기가 앞으로 온다.
///
/// 마지막 카드("일정 전체")와 헤더 링크는 [onSeeSchedule] 로 일정 탭에 보낸다
/// (spec 사용자 흐름 4). 빈 상태·로딩·에러는 그리지 않는다 — 경기가 없으면
/// "일정 전체" 카드만 남는다.
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

  static const Key seeScheduleCardKey = ValueKey('homeSeeScheduleCard');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final matches = viewModel.todayMatchesSorted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeTodayMatchesTitle,
            scale: scale,
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
            itemCount: matches.length + 1,
            separatorBuilder: (_, _) => SizedBox(width: 10 * scale),
            itemBuilder: (context, i) {
              if (i == matches.length) {
                return _MoreCard(
                  key: seeScheduleCardKey,
                  label: l.homeSeeAllSchedule,
                  scale: scale,
                  onTap: onSeeSchedule,
                );
              }
              return _MatchCard(match: matches[i], scale: scale);
            },
          ),
        ),
      ],
    );
  }
}

/// 오늘 경기 카드 한 장 — 시안(`mockup.html`)의 `.mc`.
///
/// 폭 172, 안쪽 여백 위 10·좌우 12·아래 12, 테두리 1을 더해 높이 110이다.
/// LIVE 카드는 어두운 배경에 왼쪽 3px 강조선만 두른다.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.scale});

  final ScheduleMatch match;
  final double scale;

  // 서버 표기가 흔들려(inProgress/in_progress/LIVE …) 공용 판정을 쓴다.
  bool get _live => isLiveMatchStatus(match.matchStatus);
  bool get _done => match.matchStatus == 'completed';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172 * scale,
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        10 * scale,
        12 * scale,
        12 * scale,
      ),
      decoration: BoxDecoration(
        color: _live ? AppColors.narDark600 : AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: _live
            ? Border(
                left: BorderSide(
                  color: AppColors.liveSideBorder,
                  width: 3 * scale,
                ),
              )
            : Border.all(color: AppColors.narLine),
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
                    fontSize: 11 * scale,
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
    );
  }
}

/// 스트립 마지막 "일정 전체 →" 카드 — 목업 `.mc.more` 처럼 점선.
class _MoreCard extends StatelessWidget {
  const _MoreCard({
    super.key,
    required this.label,
    required this.scale,
    this.onTap,
  });

  final String label;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DashedBorder(
        radius: 12 * scale,
        child: Container(
          width: 172 * scale,
          alignment: Alignment.center,
          child: Text(
            '$label →',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13 * scale,
              color: AppColors.narText2,
            ),
          ),
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
              fontSize: 11 * scale,
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
