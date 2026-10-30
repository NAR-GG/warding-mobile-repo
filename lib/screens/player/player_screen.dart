import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../components/app_refresh_indicator.dart';
import '../../components/load_error.dart';
import '../../components/nar_badge.dart';
import '../../components/nar_card.dart';
import '../../components/nar_stat_box.dart';
import '../../components/solo_hero_card.dart';
import '../../components/subscribe_bell.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_tab_bar.dart';
import '../../components/team_code_badge.dart';
import '../../l10n/app_localizations.dart';
import '../../model/player_detail.dart';
import '../../styles/app_colors.dart';
import '../../util/analytics_events.dart';
import '../../util/app_image.dart';
import '../../util/rating_mapping.dart';
import '../../viewmodel/home/solo_cheer_controller.dart';
import '../../viewmodel/player/player_viewmodel.dart';
import '../home/component/home_solo_cheer.dart';
import '../login/login_screen.dart';
import '../match_detail/component/match_detail_team_rating_section.dart'
    show PlayerRating;
import '../my_players/component/worlds_player_sheet.dart';
import '../player_rating/player_rating_screen.dart';
import '../match_list/component/match_alarm_sheet.dart';
import 'component/player_next_match_card.dart';
import 'component/player_skeleton.dart';
import 'component/player_parts.dart';
import 'component/player_solo_tab.dart';
import 'component/player_worlds_tab.dart';

/// 선수 페이지 — 솔랭 중이면 큰 카드 + 응원, 쉬면 프로필 줄 + 마지막 솔랭.
/// 그 아래 다음 경기·지표 줄·월즈/솔랭 탭.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.playerId,
    this.cheers,
    this.viewModel,
  });

  final int playerId;

  /// 홈의 응원 컨트롤러. 넘기면 홈 카드와 응원 수가 함께 움직인다.
  final SoloCheerController? cheers;

  /// 테스트 주입용.
  final PlayerViewModel? viewModel;

  static const Key subscribeKey = ValueKey('playerSubscribeBell');
  static const Key restingKey = ValueKey('playerResting');
  static const Key liveKey = ValueKey('playerLive');

  /// 선수 페이지를 연다. 홈·월즈 솔랭 어디서 열어도 같은 라우트 이름이다.
  static Future<void> open(
    BuildContext context,
    int playerId, {
    SoloCheerController? cheers,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsPage.playerDetail),
      builder: (_) => PlayerScreen(playerId: playerId, cheers: cheers),
    ),
  );

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerViewModel _vm =
      widget.viewModel ??
      PlayerViewModel(playerId: widget.playerId, cheers: widget.cheers);

  // 한줄평을 바닥 근처에서 이어 받는다(더 보기 버튼 대신).
  final ScrollController _scroll = ScrollController();

  // 큰 카드 경과 시간만 매초 다시 그린다(홈과 같은 방식).
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  late final Timer _clock = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted && _vm.detail?.live != null) _tick.value++;
  });

  // 백그라운드에서는 폴링을 멈추고, 돌아오면 바로 한 번 갱신한다(홈과 같은 방식).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: _vm.stopLivePolling,
    onShow: () {
      _vm.startLivePolling();
      unawaited(_vm.refreshLive());
    },
  );

  @override
  void initState() {
    super.initState();
    _clock;
    _lifecycle;
    _scroll.addListener(_onScroll);
    _vm.addListener(_checkScrollable);
    unawaited(_vm.load());
    _vm.startLivePolling();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _vm.removeListener(_checkScrollable);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _vm.stopLivePolling();
    _clock.cancel();
    _tick.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  /// 한줄평만 스크롤로 이어 받는다(서버 페이징). 최근 솔랭·챔피언 표는 이미
  /// 받아 둔 목록이라 "더 보기" 버튼으로 한 번에 편다.
  /// 중복 호출·끝 도달은 [PlayerViewModel.loadMoreReviews] 가 막는다.
  void _loadMore() {
    if (_vm.tab != PlayerTab.worlds) return;
    unawaited(_vm.loadMoreReviews());
  }

  /// 바닥까지 남은 거리가 이 값 안쪽이면 다음 장을 당긴다.
  static const double _loadMoreThreshold = 300;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent - p.pixels < _loadMoreThreshold) _loadMore();
  }

  /// 콘텐츠가 화면보다 짧거나 바닥에 거의 붙어 있으면 [_onScroll] 이 안 불린다
  /// (큰 화면·한줄평이 적을 때). 목록이 바뀐 다음 프레임에 한 번만 재서, 아직
  /// 더 받을 게 남았으면 바로 다음 장을 당긴다.
  ///
  /// 빌드마다 걸면 안 된다 — [_loadMore] 가 `notifyListeners` 를 부르므로
  /// 리빌드 → 콜백 → 리빌드 루프에 빠져 화면이 멈춘다.
  void _checkScrollable() {
    if (_checkScheduled) return;
    // 더 받을 게 없으면 아예 예약하지 않는다 — 예약해 두면 매 알림마다
    // 프레임 콜백이 깨어나 낭비된다.
    if (!_vm.canLoadMoreReviews) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      // 스크롤이 아예 없을 때만이 아니라, 이미 바닥 [_loadMoreThreshold] 안쪽에
      // 들어와 있으면 당긴다 — 그 사이 구간은 사용자가 다시 스크롤하지 않는 한
      // _onScroll 이 안 불려 다음 장이 영영 안 붙는다.
      final p = _scroll.position;
      if (p.maxScrollExtent - p.pixels >= _loadMoreThreshold) return;
      _loadMore();
    });
  }

  /// 이번 프레임에 이미 확인을 예약했는지. 한 프레임에 알림이 여러 번 와도
  /// 확인은 한 번만 한다(루프 방지). 더 받을 게 없으면 [_loadMore] 가 즉시
  /// 돌아오므로 알림도 멈춘다.
  bool _checkScheduled = false;

  Future<void> _toLogin() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

  /// 상단 벨 — 월즈 솔랭 벨과 같은 선수 구독 시트(구독·해제·알림 토글).
  void _openSubscribeSheet(double scale) => showWorldsPlayerSheet(
    context,
    viewModel: _vm,
    playerId: widget.playerId,
    scale: scale,
  );

  /// 경기 알림 — 경기 카드 벨과 같은 흐름(신청·변경·끄기 모두 시트에서).
  Future<void> _onMatchAlarm(PlayerNextMatch match) async {
    if (!await _vm.isLoggedIn()) {
      if (mounted) await _toLogin();
      return;
    }
    if (!mounted) return;
    final after = await runMatchAlarmFlow(
      context,
      matchId: match.matchId,
      subscribed: _vm.matchAlarmOn,
      homeName: match.team.teamCode.isNotEmpty
          ? match.team.teamCode
          : match.team.teamName,
      homeLogoUrl: match.team.teamImageUrl,
      homeCode: match.team.teamCode,
      awayName: match.opponent.teamCode.isNotEmpty
          ? match.opponent.teamCode
          : match.opponent.teamName,
      awayLogoUrl: match.opponent.teamImageUrl,
      awayCode: match.opponent.teamCode,
      repository: _vm.matchSubscriptions,
    );
    if (after != null) _vm.setMatchAlarmOn(after);
  }

  /// 한줄평 → 그 판 평점 상세(홈 한줄평과 같은 방식).
  void _openReview(PlayerReview review) {
    final d = _vm.detail;
    final gameId = review.gameId;
    final participantId = review.participantId;
    if (d == null || gameId == null || participantId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AnalyticsPage.playerRating),
        builder: (_) => PlayerRatingScreen(
          player: PlayerRating(
            name: d.playerName,
            position: '',
            rating: review.rating.toDouble(),
            raterCount: 0,
            participantId: participantId,
            playerId: d.playerId,
          ),
          teamName: d.teamCode,
          teamCode: d.teamCode,
          side: review.teamSide?.toUpperCase() == 'RED'
              ? BadgeSide.red
              : BadgeSide.blue,
          gameId: gameId,
          participantId: participantId,
          playerId: d.playerId,
          highlightRatingId: review.ratingId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final d = _vm.detail;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NarDetailHeader(
                  title: d?.playerName ?? '',
                  scale: scale,
                  centerTitle: false,
                  backIconAsset: 'assets/icons/chevron-left.svg',
                  onBack: () => Navigator.of(context).pop(),
                  trailing: d == null
                      ? null
                      : SubscribeBell(
                          key: PlayerScreen.subscribeKey,
                          subscribed: d.subscribed,
                          semanticsLabel: d.subscribed
                              ? l.playerUnsubscribeSemantics(d.playerName)
                              : l.playerSubscribeSemantics(d.playerName),
                          scale: scale,
                          onTap: () => _openSubscribeSheet(scale),
                        ),
                ),
                Expanded(child: _body(l, d, scale)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l, PlayerDetail? d, double scale) {
    if (_vm.loading && d == null) return PlayerSkeleton(scale: scale);
    if (d == null) {
      return LoadError(
        message: _vm.notFound ? l.playerNotFound : l.playerLoadFailed,
        onRetry: _vm.load,
      );
    }
    final live = d.liveAsHome;
    final next = d.nextMatch;
    return AppRefreshIndicator(
      onRefresh: _vm.load,
      showCompleteSnackBar: false,
      child: ListView(
        controller: _scroll,
        physics: AppRefreshIndicator.physics,
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          12 * scale,
          20 * scale,
          40 * scale,
        ),
        children: [
          if (live != null)
            SoloCheerCard(
              key: PlayerScreen.liveKey,
              playerName: _vm.cheerKey,
              controller: _vm.cheers,
              heroHeight: 196 * scale,
              scale: scale,
              hero: SoloHeroCard(
                player: live,
                secondsOf: () {
                  final s = live.startedAt;
                  return s == null
                      ? live.elapsedSeconds
                      : DateTime.now()
                            .difference(s)
                            .inSeconds
                            .clamp(0, 1 << 30);
                },
                tick: _tick,
                scale: scale,
                embedded: true,
                role: d.role.isEmpty ? null : d.role.toUpperCase(),
                showRegion: true,
              ),
            )
          else
            _RestingCard(detail: d, scale: scale),
          if (next != null) ...[
            SizedBox(height: 12 * scale),
            PlayerNextMatchCard(
              match: next,
              alarmOn: _vm.matchAlarmOn,
              onAlarm: () => _onMatchAlarm(next),
              scale: scale,
            ),
          ],
          SizedBox(height: 12 * scale),
          _StatsRow(stats: d.stats, scale: scale),
          SizedBox(height: 20 * scale),
          NarTabBar(
            tabs: [l.playerTabWorlds, l.playerTabSolo],
            selectedIndex: _vm.tab.index,
            onChanged: (i) => _vm.setTab(PlayerTab.values[i]),
            scale: scale,
          ),
          if (_vm.tab == PlayerTab.worlds)
            PlayerWorldsTab(
              viewModel: _vm,
              scale: scale,
              onOpenReview: _openReview,
            )
          else
            PlayerSoloTab(
              viewModel: _vm,
              scale: scale,
              onOpenPlayer: (id) =>
                  PlayerScreen.open(context, id, cheers: _vm.cheers),
            ),
        ],
      ),
    );
  }
}

/// 쉬는 중(⑧-2) — 팀·포지션, 마지막 솔랭 한 판, 오른쪽 선수 사진.
class _RestingCard extends StatelessWidget {
  const _RestingCard({required this.detail, required this.scale});

  final PlayerDetail detail;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final last = detail.lastGame;
    final photo = resolveImageUrl(detail.playerImageUrl);
    final role = detail.role.isEmpty ? null : detail.role.toUpperCase();
    return NarCard(
      key: PlayerScreen.restingKey,
      scale: scale,
      child: SizedBox(
        height: 100 * scale,
        child: Stack(
          children: [
            if (photo != null && photo.isNotEmpty)
              Positioned(
                right: 24 * scale,
                bottom: 0,
                child: CachedNetworkImage(
                  imageUrl: photo,
                  height: 84 * scale,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16 * scale,
                14 * scale,
                110 * scale,
                12 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TeamCodeBadge(
                        teamCode: detail.teamCode,
                        size: 20 * scale,
                        fallbackImageUrl: detail.teamImageUrl,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        [detail.teamCode, ?role].join(' · '),
                        style: playerText(
                          scale,
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.narGray400,
                          family: 'Open Sans',
                        ),
                      ),
                    ],
                  ),
                  if (last != null) ...[
                    const Spacer(),
                    Text(
                      l.playerLastSolo(ratingTimeAgo(last.endedAt)),
                      style: playerText(
                        scale,
                        size: 12,
                        color: AppColors.narText2,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Row(
                      children: [
                        ChampionIcon(
                          name: last.championName,
                          url: last.championImageUrl,
                          size: 20,
                          scale: scale,
                        ),
                        SizedBox(width: 6 * scale),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: last.win ? l.playerWin : l.playerLoss,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: last.win
                                        ? AppColors.scoreWin
                                        : AppColors.narText2,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' ${last.championName} · ${l.homeSoloDuration(last.durationSeconds ~/ 60)} · ${last.kills}/${last.deaths}/${last.assists}',
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: playerText(scale, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독자 · 최근 7일 응원 · 월즈 팬 평점.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.scale});

  final PlayerStats stats;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rating = stats.worldsRating;
    final value = playerText(
      scale,
      size: 17,
      weight: FontWeight.w700,
      family: 'Open Sans',
    );
    return NarStatRow(
      scale: scale,
      boxes: [
        NarStatBox(
          label: l.playerStatSubscribers,
          scale: scale,
          value: Text(formatCheerCount(stats.subscriberCount), style: value),
        ),
        NarStatBox(
          label: l.playerStatCheers7d,
          scale: scale,
          value: Text(formatCheerCount(stats.cheers7d), style: value),
        ),
        NarStatBox(
          label: l.playerStatWorldsRating,
          scale: scale,
          value: rating == null
              ? Text('-', style: value)
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: oneDecimal(rating.average),
                        style: const TextStyle(color: AppColors.narGuideAccent),
                      ),
                      TextSpan(
                        text: ' / 5',
                        style: playerText(
                          scale,
                          size: 11,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                  style: value,
                ),
        ),
      ],
    );
  }
}
