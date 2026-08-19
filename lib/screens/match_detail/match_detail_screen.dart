import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/game_rating.dart';
import '../../model/match_game.dart';
import '../../model/schedule_match.dart';
import '../../util/match_status.dart';
import '../../util/match_title_l10n.dart';
import '../../util/rating_mapping.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/app_refresh_indicator.dart';
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
import 'component/match_detail_locked_empty.dart';
import 'component/match_detail_player_rating_section.dart';
import 'component/match_detail_player_rating_skeleton.dart';
import 'component/match_detail_score_section.dart';
import 'component/match_detail_team_rating_section.dart';

/// 경기 상세 페이지. 경기 리스트에서 카드를 탭하면 진입한다.
class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    this.match,
    this.initialTabIndex = 0,
    this.initialSet,
  });

  /// 상세를 볼 경기 ID. 탭(챔피언/이벤트) 로드의 기준.
  final String matchId;

  /// 헤더에 표시할 경기 정보. null 이면 헤더는 플레이스홀더로 렌더한다.
  final ScheduleMatch? match;

  /// 진입 시 선택할 탭 인덱스(0: 챔피언 픽, 1: 라이브 이벤트, 2: 선수 평점).
  final int initialTabIndex;

  /// 진입 시 선택할 세트 번호. null 이면 진행 상태로 자동 판단한다.
  final int? initialSet;

  @override
  State<MatchDetailScreen> createState() => MatchDetailScreenState();
}

/// 딥링크 라우터가 이미 떠 있는 상세를 재사용할 수 있게 public 이다.
/// ([MatchDetailRouter] 가 GlobalKey 로 이 State 를 잡아 탭·세트를 갈아끼운다.)
class MatchDetailScreenState extends State<MatchDetailScreen> {
  List<String> _buildTabs(AppLocalizations l) => [
    l.championPick,
    l.liveEvent,
    l.tabPlayerRating,
  ];
  late int _tabIndex = widget.initialTabIndex;

  /// 이 화면이 보여주고 있는 경기. 라우터가 같은 경기인지 판단할 때 쓴다.
  String get matchId => widget.matchId;

  /// 이미 떠 있는 상태에서 같은 경기 딥링크가 또 들어왔을 때 호출된다.
  /// 화면을 새로 쌓지 않고 탭·세트만 바꾼다.
  void applyDeepLink({required int tabIndex, int? setNumber}) {
    if (!mounted) return;
    // 탭 인덱스는 화면 로컬 상태(_tabIndex)와 뷰모델(_activeTab) 양쪽에 있다.
    setState(() => _tabIndex = tabIndex);
    _viewModel.applyDeepLink(tabIndex: tabIndex, setNumber: setNumber);
  }

  late final MatchDetailViewModel _viewModel = MatchDetailViewModel(
    matchId: widget.matchId,
    initialMatch: widget.match,
    initialTabIndex: widget.initialTabIndex,
    initialSet: widget.initialSet,
  );

  /// widget.match 가 있으면 그것을, 없으면 뷰모델이 API 로 로드한 정보를 사용한다.
  ScheduleMatch? get _effectiveMatch => widget.match ?? _viewModel.matchInfo;

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
  String _setLabelOf(int order) =>
      AppLocalizations.of(context)!.setLabel(order);

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
    final raw = (idx >= 0 ? matchTitle.substring(0, idx) : matchTitle).trim();
    return localizeMatchTitle(raw, AppLocalizations.of(context)!);
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

  /// 라이브 판정은 경기리스트·경기 일정과 같은 공용 유틸을 쓴다.
  bool _isLiveStatus(String status) => isLiveMatchStatus(status);

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
    return AppLocalizations.of(context)!.setInProgress(_setNumber(_currentSet));
  }

  /// 스코어 아래 라벨. 선택된 세트가 LIVE면 'SET N 진행중', 종료된 세트고
  /// 승자가 확인되면 'SET N {팀코드} 승'. 그 외(예정 등)엔 표시 안 함.
  String? _currentSetResultLabel(ScheduleMatch m) {
    if (_viewModel.isCurrentSetLive) return _setLabel(m.matchStatus);
    if (_viewModel.currentSetStatus != MatchGameStatus.ended) return null;
    final winnerCode = _viewModel.currentSetWinnerTeamCode;
    if (winnerCode == null || winnerCode.isEmpty) return null;
    if (winnerCode != m.teamA.teamCode && winnerCode != m.teamB.teamCode) {
      return null;
    }
    return AppLocalizations.of(
      context,
    )!.setWinner(_viewModel.currentSet, winnerCode);
  }

  /// '중계 보기' 탭. 중계 채널이 복수(치지직/SOOP)면 선택 시트를 띄우고,
  /// 하나뿐이면 바로 외부 브라우저/앱으로 연다.
  Future<void> _openLiveStream() async {
    final links = _effectiveMatch?.effectiveStreamLinks ?? const [];
    if (links.isEmpty) return;
    if (links.length == 1) {
      await launchUrl(
        Uri.parse(links.first.url),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    final selected = await _showStreamPickerSheet(links);
    if (selected == null) return;
    await launchUrl(
      Uri.parse(selected.url),
      mode: LaunchMode.externalApplication,
    );
  }

  /// 중계 채널 선택 바텀시트. 플랫폼별 로고 칩 + 이름/설명, 공식 채널엔 뱃지.
  Future<StreamLink?> _showStreamPickerSheet(List<StreamLink> links) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    return showAppBottomSheet<StreamLink>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              8 * scale,
              4 * scale,
              8 * scale,
              2 * scale,
            ),
            child: Text(
              AppLocalizations.of(context)!.broadcastChannelSelect,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 16 * scale,
                color: AppColors.narText,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8 * scale, 0, 8 * scale, 12 * scale),
            child: Text(
              AppLocalizations.of(context)!.watchOnPlatform,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 12.5 * scale,
                color: AppColors.narText2,
              ),
            ),
          ),
          for (final link in links)
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 0, 8 * scale, 8 * scale),
              child: InkWell(
                borderRadius: BorderRadius.circular(12 * scale),
                onTap: () => Navigator.of(context).pop(link),
                child: Container(
                  padding: EdgeInsets.all(13 * scale),
                  decoration: BoxDecoration(
                    color: AppColors.narDark600,
                    borderRadius: BorderRadius.circular(12 * scale),
                    border: Border.all(color: AppColors.narLine),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38 * scale,
                        height: 38 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _brandColorOf(
                            link.provider,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10 * scale),
                        ),
                        child: Text(
                          link.provider.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w900,
                            fontSize: 9 * scale,
                            color: _brandColorOf(link.provider),
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.label,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5 * scale,
                                color: AppColors.narText,
                              ),
                            ),
                            if (link.description.isNotEmpty)
                              Text(
                                link.description,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12 * scale,
                                  color: AppColors.narText2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (link.description.contains('공식'))
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale,
                            vertical: 3 * scale,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.chzzkBrand.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.official,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5 * scale,
                              color: AppColors.chzzkBrand,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(height: 8 * scale),
        ],
      ),
    );
  }

  /// 플랫폼별 브랜드색. 미지정 플랫폼은 기본 회색.
  Color _brandColorOf(String provider) {
    switch (provider) {
      case 'chzzk':
        return AppColors.chzzkBrand;
      case 'soop':
        return AppColors.soopBrand;
      default:
        return AppColors.narGray500;
    }
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
    final liveOrders = games
        .where((g) => g.isLive)
        .map((g) => g.gameOrder)
        .toSet();
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
      teamSide: side,
      teamName: '',
      averageRating: 0,
      ratingCount: 0,
    );
  }

  /// 선수 평점 행 탭 시 호출. 선수 평점 상세 페이지로 이동한다.
  Future<void> _openPlayerRating(
    PlayerRating player,
    String teamName,
    BadgeSide side,
  ) async {
    final gameId = _viewModel.currentGameId;
    if (gameId == null || gameId.isEmpty || player.participantId == 0) return;
    // playerName 에 teamName 대신 팀코드가 이미 붙어 오는 응답의 중복 표기
    // 판별에 쓴다(예: playerName='KRX Frog', teamName='Kiwoom Drx').
    final teamCode = side == BadgeSide.blue
        ? (_effectiveMatch?.teamA.teamCode ?? '')
        : (_effectiveMatch?.teamB.teamCode ?? '');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerRatingScreen(
          player: player,
          teamName: teamName,
          teamCode: teamCode,
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
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: _viewModel.refresh,
          child: CustomScrollView(
            // 내용이 짧아 스크롤이 생기지 않는 탭(잠금 안내·빈 상태)에서도
            // 당길 수 있어야 한다.
            physics: AppRefreshIndicator.physics,
            slivers: [
              // 헤더·스코어·중계 버튼·탭바: 스크롤 시 함께 위로 밀려 올라간다.
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NarDetailHeader(
                      title: l.matchDetail,
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
                      tabs: _buildTabs(l),
                      selectedIndex: _tabIndex,
                      onChanged: (i) => setState(() {
                        _tabIndex = i;
                        // 지연 로딩: 처음 전환하는 탭이면 여기서 데이터를 로드한다.
                        _viewModel.setActiveTab(i);
                      }),
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
                    builder: (context, _) => _buildLiveEventTab(scale),
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
      ),
    );
  }

  /// 선수 평점 탭. 슬리버(MatchDetailPlayerRatingSection)를 그대로 반환해
  /// 외부 CustomScrollView 의 slivers 에 직접 배치한다. (pinned 헤더 sticky 유지)
  Widget _buildRatingTab(double scale) {
    // 세트 목록(games)을 아직 못 받아온 동안은 currentSetStatus 가 기본값
    // (SCHEDULED)이라, 실제로는 이미 종료된 경기여도 '경기 종료 후' 잠금 안내가
    // 잠깐 잘못 스칠 수 있다. 이 구간은 스켈레톤으로 대신한다.
    if (_viewModel.loadingGames) {
      return SliverToBoxAdapter(
        child: MatchDetailPlayerRatingSkeleton(scale: scale),
      );
    }
    // 선수 평점은 세트 종료 후에만 남길 수 있다. 종료 전에는 배너·평점 대신
    // 잠금(lock-off) 빈 상태를 보여준다. (배너도 자연히 종료 후에만 노출)
    if (_viewModel.currentSetStatus != MatchGameStatus.ended) {
      return SliverToBoxAdapter(
        child: ColoredBox(
          color: AppColors.narBgContent,
          child: MatchDetailLockedEmpty(
            message: AppLocalizations.of(context)!.playerRatingAfterMatch,
            scale: scale,
          ),
        ),
      );
    }
    // 이 세트로 처음 로드 중(아직 데이터도 에러도 없음)이면 스켈레톤.
    // (loadingRatings 플래그가 true 로 바뀌기 전 찰나에도 스켈레톤을 유지해야
    // '평점 없음' 빈 상태가 잘못 스치지 않는다.) 로드 실패(ratingsError)면
    // 무한 스켈레톤 대신 기존처럼 빈 데이터로 렌더한다.
    if (_viewModel.ratings == null && _viewModel.ratingsError == null) {
      return SliverToBoxAdapter(
        child: MatchDetailPlayerRatingSkeleton(scale: scale),
      );
    }
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
    // 이 세트의 어떤 선수에게든 내 평점(myRating>0)이 있으면 상단 배너를 숨긴다.
    final hasMyRating = (r?.players ?? const <RatingPlayer>[]).any(
      (p) => p.myRating > 0,
    );
    return MatchDetailPlayerRatingSection(
      setLabel: _currentSet,
      showBanner: !hasMyRating,
      blueTeamName: blue.teamName.isNotEmpty
          ? blue.teamName
          : (_effectiveMatch?.teamA.teamName ?? 'BLUE'),
      redTeamName: red.teamName.isNotEmpty
          ? red.teamName
          : (_effectiveMatch?.teamB.teamName ?? 'RED'),
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

  /// 선택된 세트의 다시보기 VOD 를 외부 브라우저/앱으로 연다.
  Future<void> _openVod() async {
    final url = _viewModel.currentSetVodUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// 상태별 액션 버튼.
  /// - 라이브: '중계 보기' (liveStreamUrl 이 있으면 활성, 없으면 비활성)
  /// - 완료: 선택 세트에 VOD 가 있으면 '다시보기'(활성), 없으면 '경기 종료'(비활성)
  /// - 그 외(예정 등): '준비중' (비활성)
  Widget _buildActionButton(double scale) {
    final m = _effectiveMatch;
    final status = m?.matchStatus ?? '';
    final hasStream = (m?.effectiveStreamLinks ?? const []).isNotEmpty;
    final vodUrl = _viewModel.currentSetVodUrl;
    final hasVod = vodUrl != null && vodUrl.isNotEmpty;
    final l = AppLocalizations.of(context)!;
    final String label;
    final VoidCallback? onPressed;
    if (_isLiveStatus(status)) {
      label = l.watchBroadcast;
      onPressed = hasStream ? _openLiveStream : null;
    } else if (_isCompletedStatus(status)) {
      label = hasVod ? l.rewatch : l.matchEnded;
      onPressed = hasVod ? _openVod : null;
    } else {
      label = l.preparing;
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
    final m = _effectiveMatch;
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
      // 세트 라벨: 선택된 세트가 LIVE면 '진행중', 종료됐고 승자가 있으면 '승리'.
      setLabel: m != null ? _currentSetResultLabel(m) : null,
      scale: scale,
    );
  }

  /// 라이브 이벤트 탭 본문. 경기 전(SCHEDULED)이면 잠금 안내, 아니면 이벤트 섹션.
  Widget _buildLiveEventTab(double scale) {
    // games 를 아직 못 받아온 동안은 currentSetStatus 가 기본값(SCHEDULED)이라
    // 실제로는 이미 시작된 경기여도 잠금 안내가 잠깐 잘못 스칠 수 있다.
    if (_viewModel.loadingGames) {
      return MatchDetailLiveEventSection(
        events: const [],
        initialLoading: true,
        status: MatchGameStatus.live,
        scale: scale,
      );
    }
    if (_viewModel.currentSetStatus == MatchGameStatus.scheduled) {
      return ColoredBox(
        color: AppColors.narBgContent,
        child: MatchDetailLockedEmpty(
          message: AppLocalizations.of(context)!.liveEventAfterMatch,
          scale: scale,
        ),
      );
    }
    return MatchDetailLiveEventSection(
      events: _viewModel.liveEvents,
      blueTeamImageUrl: _viewModel.blueTeamImageUrl,
      redTeamImageUrl: _viewModel.redTeamImageUrl,
      initialLoading: _viewModel.loadingEvents && _viewModel.liveEvents.isEmpty,
      errorMessage: _viewModel.eventsError,
      onReload: _viewModel.reloadLiveEvents,
      status: _viewModel.currentSetStatus,
      scale: scale,
    );
  }

  /// 챔피언 픽 탭 본문. ViewModel 데이터로 렌더링하되 로딩·에러 상태를 처리한다.
  Widget _buildChampionPickTab(double scale) {
    // games 를 아직 못 받아온 동안은 currentSetStatus 가 기본값(SCHEDULED)이라
    // 실제로는 이미 시작된 경기여도 '경기 시작 후' 잠금 안내가 잠깐 잘못 스칠 수
    // 있다. 이 구간은 스켈레톤으로 대신한다.
    if (_viewModel.loadingGames) {
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
    // 경기 전(SCHEDULED)이면 잠금(lock-off) 안내를 보여준다.
    if (_viewModel.currentSetStatus == MatchGameStatus.scheduled) {
      return ColoredBox(
        color: AppColors.narBgContent,
        child: MatchDetailLockedEmpty(
          message: AppLocalizations.of(context)!.championPickAfterMatch,
          scale: scale,
        ),
      );
    }
    // 최초 로드 중이거나(아직 데이터·에러 모두 없음) 처리 중이면 플레이스홀더
    // 픽으로 스켈레톤 렌더. (championError 가 있으면 실패이므로 건너뛴다.)
    if (_viewModel.championPick == null && _viewModel.championError == null) {
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
      return ColoredBox(
        color: AppColors.narBgContent,
        child: MatchDetailLockedEmpty(
          message:
              _viewModel.championError ??
              AppLocalizations.of(context)!.championPickAfterMatchAlt,
          scale: scale,
        ),
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
