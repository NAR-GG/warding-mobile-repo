import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/game_rating.dart';
import '../../model/schedule_match.dart';
import '../../util/rating_mapping.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/nar_badge.dart';
import '../../components/nar_button.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_dropdown.dart';
import '../../components/nar_tab_bar.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/match_detail/match_detail_viewmodel.dart';
import '../player_rating/player_rating_screen.dart';
import 'component/match_detail_champion_pick_section.dart';
import 'component/match_detail_live_event_section.dart';
import 'component/match_detail_player_rating_section.dart';
import 'component/match_detail_score_section.dart';
import 'component/match_detail_team_rating_section.dart';

/// 경기 상세 페이지. 경기 리스트에서 카드를 탭하면 진입한다.
class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    this.match,
    this.initialTabIndex = 0,
  });

  /// 상세를 볼 경기 ID. 탭(챔피언/이벤트) 로드의 기준.
  final String matchId;

  /// 헤더에 표시할 경기 정보. null 이면 헤더는 플레이스홀더로 렌더한다.
  final ScheduleMatch? match;

  /// 진입 시 선택할 탭 인덱스(0: 챔피언 픽, 1: 라이브 이벤트, 2: 선수 평점).
  final int initialTabIndex;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  static const List<String> _tabs = ['챔피언 픽', '라이브 이벤트', '선수 평점'];
  late int _tabIndex = widget.initialTabIndex;

  late final MatchDetailViewModel _viewModel =
      MatchDetailViewModel(matchId: widget.matchId);

  @override
  void initState() {
    super.initState();
    // 세트 라벨·목록은 뷰모델 상태에서 파생되므로(스코어/선수평점 탭은
    // ListenableBuilder 밖) 뷰모델 변경 시 화면을 다시 그린다.
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.load();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  /// 세트 번호 → '세트 N' 라벨.
  String _setLabelOf(int order) => '세트 $order';

  /// 현재 선택된 세트의 '세트 N' 라벨. (뷰모델의 currentSet 기준)
  String get _currentSet => _setLabelOf(_viewModel.currentSet);

  /// 드롭다운·선수평점 탭에 쓸 세트 라벨 목록.
  /// 로드된 게임 목록에서 만들고, 아직 비어있으면 현재 세트만 노출한다.
  List<String> get _sets {
    if (_viewModel.games.isEmpty) return [_currentSet];
    return _viewModel.games.map((g) => _setLabelOf(g.gameOrder)).toList();
  }

  /// '세트 N' 라벨 → 세트 번호(1부터).
  int _setNumber(String label) =>
      int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

  /// matchTitle('스테이지 | 팀A vs 팀B')에서 앞쪽 스테이지/라운드명만 추출한다.
  /// 예: '토너먼트 스테이지 | T1 vs GEN' → '토너먼트 스테이지'.
  String _stageOf(String matchTitle) {
    final idx = matchTitle.indexOf('|');
    return (idx >= 0 ? matchTitle.substring(0, idx) : matchTitle).trim();
  }

  /// 경기 날짜(date)를 'YY.MM.DD' 로 포맷한다. date 가 없으면 빈 문자열.
  String _formatMatchDate(ScheduleMatch m) {
    final d = m.date;
    if (d == null) return '';
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yy.$mm.$dd';
  }

  /// matchStatus 가 라이브를 의미하는지. 'LIVE'/'inProgress'/'진행' 등 포함이면 true.
  bool _isLiveStatus(String status) {
    final s = status.toLowerCase();
    return s.contains('live') ||
        s.contains('inprogress') ||
        s.contains('in_progress') ||
        s.contains('ongoing') ||
        status.contains('진행');
  }

  /// matchStatus 가 경기 종료를 의미하는지. 'completed'/'ended'/'종료' 등 포함이면 true.
  bool _isCompletedStatus(String status) {
    final s = status.toLowerCase();
    return s.contains('complet') ||
        s.contains('end') ||
        s.contains('done') ||
        s.contains('finish') ||
        status.contains('종료') ||
        status.contains('완료');
  }

  /// 라이브 경기의 스코어 아래 라벨. matchStatus 가 이미 'SET'/'진행' 형태면 그대로,
  /// 아니면 현재 선택된 세트로 'SET N 진행중' 라벨을 만든다.
  String _setLabel(String status) {
    if (status.contains('진행') || status.toUpperCase().contains('SET')) {
      return status;
    }
    return 'SET ${_setNumber(_currentSet)} 진행중';
  }

  /// '중계 보기' 탭. liveStreamUrl 을 외부 브라우저/앱으로 연다.
  Future<void> _openLiveStream() async {
    final url = widget.match?.liveStreamUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// 헤더의 세트 드롭다운 탭 시 호출. 세트 목록 바텀시트를 띄우고 선택값으로 갱신.
  /// 세트 목록은 로드된 games 에서 만든다. (LIVE 세트엔 마커 표시)
  Future<void> _showSetSheet() async {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    // games 가 있으면 그걸로, 없으면 현재 세트만 노출.
    final games = _viewModel.games;
    final orders = games.isEmpty
        ? [_viewModel.currentSet]
        : games.map((g) => g.gameOrder).toList();
    final liveOrders = games.where((g) => g.isLive).map((g) => g.gameOrder).toSet();
    final selected = await showAppBottomSheet<int>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final order in orders)
            InkWell(
              onTap: () => Navigator.of(context).pop(order),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 14 * scale,
                ),
                child: Row(
                  children: [
                    Text(
                      _setLabelOf(order),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: order == _viewModel.currentSet
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 16 * scale,
                        color: order == _viewModel.currentSet
                            ? AppColors.narText
                            : AppColors.narText2,
                      ),
                    ),
                    if (liveOrders.contains(order)) ...[
                      SizedBox(width: 8 * scale),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 11 * scale,
                          color: AppColors.liveAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (selected != null && selected != _viewModel.currentSet) {
      // 챔피언 픽·라이브 이벤트를 선택 세트로 다시 로드. (선수 평점 탭은 mock 유지)
      // currentSet 은 뷰모델 상태라 selectSet 의 notify 로 헤더가 갱신된다.
      _viewModel.selectSet(_setNumber(_setLabelOf(selected)));
    }
  }

  /// 평점목록 응답의 선수를 UI 행 모델로 변환한다.
  PlayerRating _toPlayerRating(RatingPlayer p) => PlayerRating(
        name: p.playerName,
        position: positionFromRole(p.role),
        rating: p.averageRating,
        raterCount: p.ratingCount,
        playerImageUrl: p.playerImageUrl,
        participantId: p.participantId,
        playerId: p.playerId,
      );

  /// 특정 진영의 팀 요약을 찾는다(없으면 0값).
  TeamRatingSummary _teamSummary(GameRatings? r, String side) {
    final teams = r?.teams ?? const <TeamRatingSummary>[];
    for (final t in teams) {
      if (t.teamSide.toUpperCase() == side) return t;
    }
    return TeamRatingSummary(
        teamSide: side, teamName: '', averageRating: 0, ratingCount: 0);
  }

  /// 선수 평점 행 탭 시 호출. 선수 평점 상세 페이지로 이동한다.
  Future<void> _openPlayerRating(
      PlayerRating player, String teamName, BadgeSide side) async {
    final gameId = _viewModel.currentGameId;
    if (gameId == null || gameId.isEmpty || player.participantId == 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerRatingScreen(
          player: player,
          teamName: teamName,
          side: side,
          sets: _sets,
          initialSet: _currentSet,
          gameId: gameId,
          participantId: player.participantId,
          playerId: player.playerId,
          games: _viewModel.games,
          currentSetNumber: _viewModel.currentSet,
        ),
      ),
    );
    // 상세에서 평가를 작성/수정/삭제했을 수 있으므로 평점 탭을 갱신한다.
    if (mounted) _viewModel.reloadRatings();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더·스코어·중계 버튼·탭바: 스크롤 시 함께 위로 밀려 올라간다.
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NarDetailHeader(
                    title: '경기 상세',
                    // 세트 드롭다운: 기본 선택(LIVE→최신 ENDED→1)·변경이 뷰모델
                    // 상태라 ListenableBuilder 로 라벨을 갱신한다.
                    trailing: ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, _) => NarDropdown(
                        variant: NarDropdownVariant.round,
                        value: _currentSet,
                        onTap: _showSetSheet,
                        scale: scale,
                      ),
                    ),
                    scale: scale,
                  ),
                  _buildScoreSection(scale),
                  SizedBox(height: 16 * scale),
                  _buildActionButton(scale),
                  SizedBox(height: 16 * scale),
                  NarTabBar(
                    tabs: _tabs,
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    scale: scale,
                  ),
                ],
              ),
            ),
            if (_tabIndex == 0)
              SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => _buildChampionPickTab(scale),
                ),
              ),
            if (_tabIndex == 1)
              SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => MatchDetailLiveEventSection(
                    events: _viewModel.liveEvents,
                    blueTeamImageUrl: _viewModel.blueTeamImageUrl,
                    redTeamImageUrl: _viewModel.redTeamImageUrl,
                    initialLoading: _viewModel.loadingEvents &&
                        _viewModel.liveEvents.isEmpty,
                    errorMessage: _viewModel.eventsError,
                    onReload: _viewModel.reloadLiveEvents,
                    status: _viewModel.currentSetStatus,
                    scale: scale,
                  ),
                ),
              ),
            // 선수 평점 탭: 뷰모델의 ratings 로 팀·선수 평점을 렌더한다.
            // 화면이 VM notify 마다 통째로 rebuild 되므로(_onViewModelChanged),
            // pinned 헤더를 가진 슬리버 묶음을 외부 CustomScrollView 에 직접 배치해
            // sticky collapse 가 동작하도록 한다.
            if (_tabIndex == 2) _buildRatingTab(scale),
          ],
        ),
      ),
    );
  }

  /// 선수 평점 탭. 슬리버(MatchDetailPlayerRatingSection)를 그대로 반환해
  /// 외부 CustomScrollView 의 slivers 에 직접 배치한다. (pinned 헤더 sticky 유지)
  Widget _buildRatingTab(double scale) {
    final r = _viewModel.ratings;
    final blue = _teamSummary(r, 'BLUE');
    final red = _teamSummary(r, 'RED');
    final bluePlayers = (r?.players ?? const [])
        .where((p) => p.teamSide.toUpperCase() == 'BLUE')
        .map(_toPlayerRating)
        .toList();
    final redPlayers = (r?.players ?? const [])
        .where((p) => p.teamSide.toUpperCase() == 'RED')
        .map(_toPlayerRating)
        .toList();
    return MatchDetailPlayerRatingSection(
      setLabel: _currentSet,
      blueTeamName: blue.teamName.isNotEmpty
          ? blue.teamName
          : (widget.match?.teamA.teamName ?? 'BLUE'),
      redTeamName: red.teamName.isNotEmpty
          ? red.teamName
          : (widget.match?.teamB.teamName ?? 'RED'),
      blueRating: blue.averageRating,
      redRating: red.averageRating,
      blueRaterCount: blue.ratingCount,
      redRaterCount: red.ratingCount,
      bluePlayers: bluePlayers,
      redPlayers: redPlayers,
      onPlayerTap: _openPlayerRating,
      scale: scale,
    );
  }

  /// 상태별 액션 버튼.
  /// - 라이브: '중계 보기' (liveStreamUrl 이 있으면 활성, 없으면 비활성)
  /// - 완료: '경기 종료' (비활성)
  /// - 그 외(예정 등): '준비중' (비활성)
  Widget _buildActionButton(double scale) {
    final m = widget.match;
    final status = m?.matchStatus ?? '';
    final hasStream =
        m?.liveStreamUrl != null && m!.liveStreamUrl!.isNotEmpty;
    final String label;
    final VoidCallback? onPressed;
    if (_isLiveStatus(status)) {
      label = '중계 보기';
      onPressed = hasStream ? _openLiveStream : null;
    } else if (_isCompletedStatus(status)) {
      label = '경기 종료';
      onPressed = null;
    } else {
      label = '준비중';
      onPressed = null;
    }
    final enabled = onPressed != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: NarButton(
        // 활성(중계 보기)은 set1, 비활성(준비중·경기 종료)은 set1Disabled.
        variant: enabled
            ? NarButtonVariant.set1
            : NarButtonVariant.set1Disabled,
        label: label,
        onPressed: onPressed,
        scale: scale,
      ),
    );
  }

  /// 헤더 스코어 칸. match 가 있으면 실데이터로, 없으면 플레이스홀더로 렌더한다.
  Widget _buildScoreSection(double scale) {
    final m = widget.match;
    final isLive = m != null && _isLiveStatus(m.matchStatus);
    // 좌측 라벨: '리그 + 스테이지'. 예: 'LCK 토너먼트 스테이지'.
    final stage = m != null ? _stageOf(m.matchTitle) : '';
    final leagueLabel = m == null
        ? ''
        : (stage.isEmpty ? m.leagueInfo : '${m.leagueInfo} $stage');
    return MatchDetailScoreSection(
      leagueName: leagueLabel,
      // 좌측: '리그 스테이지' 옆에 점 + 경기 날짜('YY.MM.DD').
      dateText: m != null ? _formatMatchDate(m) : '',
      isLive: isLive,
      // 라이브가 아니면 우측에 경기 시각(scheduledTime, 'HH:mm')을 표시한다.
      time: m?.scheduledTime ?? '',
      blueTeamName: m?.teamA.teamName ?? '',
      redTeamName: m?.teamB.teamName ?? '',
      blueTeamScore: m?.teamA.score ?? 0,
      redTeamScore: m?.teamB.score ?? 0,
      blueTeamLogoUrl: m?.teamA.teamImageUrl,
      redTeamLogoUrl: m?.teamB.teamImageUrl,
      // 세트 라벨('진행중')은 경기 전체가 아니라 선택된 세트가 LIVE일 때만.
      setLabel: _viewModel.isCurrentSetLive ? _setLabel(m.matchStatus) : null,
      scale: scale,
    );
  }

  /// 챔피언 픽 탭 본문. ViewModel 데이터로 렌더링하되 로딩·에러 상태를 처리한다.
  Widget _buildChampionPickTab(double scale) {
    // 최초 로드 중(아직 데이터 없음)이면 플레이스홀더 픽으로 스켈레톤 렌더.
    if (_viewModel.loadingChampion && _viewModel.championPick == null) {
      return MatchDetailChampionPickSection(
        blueTeamName: '',
        redTeamName: '',
        blueBans: const [null, null, null, null, null],
        redBans: const [null, null, null, null, null],
        bluePicks: const [null, null, null, null, null],
        redPicks: const [null, null, null, null, null],
        bluePlayerNames: const ['', '', '', '', ''],
        redPlayerNames: const ['', '', '', '', ''],
        scale: scale,
      );
    }
    final pick = _viewModel.championPick;
    if (pick == null) {
      return _ChampionPickMessage(
        message: _viewModel.championError ?? '챔피언 픽을 불러오지 못했어요',
        scale: scale,
      );
    }
    final blue = pick.blueTeam;
    final red = pick.redTeam;
    return MatchDetailChampionPickSection(
      blueTeamName: blue.teamName,
      redTeamName: red.teamName,
      blueBans: blue.banImageUrls(),
      redBans: red.banImageUrls(),
      bluePicks: blue.pickImageUrls(),
      redPicks: red.pickImageUrls(),
      bluePlayerNames: blue.pickPlayerNames(),
      redPlayerNames: red.pickPlayerNames(),
      scale: scale,
    );
  }
}

/// 챔피언 픽 탭 에러·빈 상태 안내.
class _ChampionPickMessage extends StatelessWidget {
  const _ChampionPickMessage({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.symmetric(vertical: 80 * scale),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 14 * scale,
            color: AppColors.narText2,
          ),
        ),
      ),
    );
  }
}
