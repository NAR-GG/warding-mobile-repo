import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../model/schedule_match.dart';
import '../../../styles/app_colors.dart';
import '../../../util/match_title_l10n.dart';
import '../../../viewmodel/match_day/match_day_viewmodel.dart';
import '../../match_detail/match_detail_screen.dart';
import '../../match_list/component/match_card.dart';
import '../../match_list/component/match_card_skeleton.dart';
import '../../match_list/component/match_date_header.dart';

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
    required this.scale,
  });

  final DateTime date;
  final MatchDayViewModel viewModel;
  final bool spoilerPreventionEnabled;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (viewModel.isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 * scale),
        itemCount: 4,
        itemBuilder: (_, _) => MatchCardSkeleton(scale: scale),
      );
    }

    final matches = viewModel.matches;
    if (matches.isEmpty) {
      return _centerMessage(
        viewModel.error != null ? l.matchLoadFailed : l.noMatches,
        scale,
      );
    }

    // 첫 항목은 날짜 그룹 헤더(경기리스트와 동일), 이후 경기 카드.
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 24 * scale),
      itemCount: matches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return MatchDateHeader(
            label: _relativeLabel(date, l),
            dateText: _formatDate(date, l),
            scale: scale,
          );
        }
        final m = matches[index - 1];
        return MatchCard(
          key: ValueKey('match-${m.matchId}'),
          matchId: m.matchId,
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
              ? l.setInProgress(m.sets.length.clamp(1, 99))
              : null,
          leagueInfo: m.leagueInfo,
          spoilerPreventionEnabled: spoilerPreventionEnabled,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: m.matchId, match: m),
            ),
          ),
          scale: scale,
        );
      },
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

  /// matchStatus 값이 'live'/'in_progress'/'ongoing' 이면 라이브로 본다 (대소문자 무시).
  bool _isLive(String status) {
    final s = status.toLowerCase();
    return s == 'live' || s == 'in_progress' || s == 'ongoing';
  }

  /// 오늘/어제/내일 만 라벨, 그 외는 빈 문자열 (경기리스트와 동일).
  String _relativeLabel(DateTime date, AppLocalizations l) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return l.today;
    if (diff == -1) return l.yesterday;
    if (diff == 1) return l.tomorrow;
    return '';
  }

  String _formatDate(DateTime d, AppLocalizations l) => l.monthDay(d.month, d.day);

  String _localizeMatchTitle(BuildContext context, String title) =>
      localizeMatchTitle(title, AppLocalizations.of(context)!);
}
