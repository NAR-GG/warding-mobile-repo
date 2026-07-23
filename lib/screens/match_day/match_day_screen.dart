import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../components/nar_detail_header.dart';
import '../../model/schedule_match.dart';
import '../../styles/app_colors.dart';
import '../../util/match_title_l10n.dart';
import '../../viewmodel/match_day/match_day_viewmodel.dart';
import '../match_detail/match_detail_screen.dart';
import '../match_list/component/match_card.dart';
import '../match_list/component/match_card_skeleton.dart';
import '../match_list/component/match_date_header.dart';

/// 경기 일정 캘린더에서 특정 날짜를 탭하면 열리는 '그 날의 경기 리스트' 화면.
///
/// 뒤로가기 상세 헤더([NarDetailHeader]) + 경기리스트 탭과 동일한 카드([MatchCard])로
/// 구성해 UI 를 일치시킨다. 데이터는 [MatchDayViewModel] 이 캘린더 필터(리그·팀)를
/// 그대로 넘겨 그 날짜의 경기만 조회한다.
class MatchDayScreen extends StatefulWidget {
  const MatchDayScreen({
    super.key,
    required this.date,
    this.leagues = const ['LCK'],
    this.teamIds,
  });

  final DateTime date;
  final List<String> leagues;
  final List<int>? teamIds;

  @override
  State<MatchDayScreen> createState() => _MatchDayScreenState();
}

class _MatchDayScreenState extends State<MatchDayScreen> {
  late final MatchDayViewModel _viewModel = MatchDayViewModel(
    date: widget.date,
    leagues: widget.leagues,
    teamIds: widget.teamIds,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(title: l.matchSchedule, scale: scale),
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => _buildBody(scale),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double scale) {
    final l = AppLocalizations.of(context)!;
    // 최초 로드 중 — 스켈레톤 카드로 채운다.
    if (_viewModel.isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 * scale),
        itemCount: 4,
        itemBuilder: (_, _) => MatchCardSkeleton(scale: scale),
      );
    }

    final matches = _viewModel.matches;
    if (matches.isEmpty) {
      return _centerMessage(
        _viewModel.error != null ? l.matchLoadFailed : l.noMatches,
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
            label: _relativeLabel(widget.date, l),
            dateText: _formatDate(widget.date, l),
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
          homeScore: m.teamA.score,
          awayScore: m.teamB.score,
          isLive: _isLive(m.matchStatus),
          liveSetLabel: _isLive(m.matchStatus)
              ? l.setInProgress(m.sets.length.clamp(1, 99))
              : null,
          leagueInfo: m.leagueInfo,
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
