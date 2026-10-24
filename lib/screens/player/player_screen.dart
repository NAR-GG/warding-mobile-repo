import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_refresh_indicator.dart';
import '../../components/load_error.dart';
import '../../components/nar_badge.dart';
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
import '../home/component/home_solo_rank_section.dart';
import '../login/login_screen.dart';
import '../match_detail/component/match_detail_team_rating_section.dart'
    show PlayerRating;
import '../my_players/component/worlds_player_sheet.dart';
import '../player_rating/player_rating_screen.dart';
import '../match_list/component/match_alarm_sheet.dart';
import 'component/player_next_match_card.dart';
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

  // 큰 카드 경과 시간만 매초 다시 그린다(홈과 같은 방식).
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  late final Timer _clock = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted && _vm.detail?.live != null) _tick.value++;
  });

  @override
  void initState() {
    super.initState();
    _clock;
    unawaited(_vm.load());
  }

  @override
  void dispose() {
    _clock.cancel();
    _tick.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

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
      homeName: match.team.teamName,
      homeLogoUrl: match.team.teamImageUrl,
      homeCode: match.team.teamCode,
      awayName: match.opponent.teamName,
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
                      : _SubscribeBell(
                          subscribed: d.subscribed,
                          name: d.playerName,
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
    if (_vm.loading && d == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.narChipActive),
      );
    }
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
              hero: HomeSoloHeroCard(
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

class _SubscribeBell extends StatelessWidget {
  const _SubscribeBell({
    required this.subscribed,
    required this.name,
    required this.scale,
    required this.onTap,
  });

  final bool subscribed;
  final String name;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: subscribed
          ? l.playerUnsubscribeSemantics(name)
          : l.playerSubscribeSemantics(name),
      excludeSemantics: true,
      child: GestureDetector(
        key: PlayerScreen.subscribeKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36 * scale,
          height: 36 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: subscribed ? AppColors.narChipBadgeBg : AppColors.narDark600,
          ),
          child: SvgPicture.asset(
            subscribed
                ? 'assets/icons/bell-check.svg'
                : 'assets/icons/bell-plus.svg',
            width: 20 * scale,
            height: 20 * scale,
            colorFilter: ColorFilter.mode(
              subscribed ? AppColors.narViolet3 : AppColors.narText2,
              BlendMode.srcIn,
            ),
          ),
        ),
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
    return PlayerCard(
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
    Widget box(String label, Widget v) => Expanded(
      child: PlayerCard(
        scale: scale,
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          10 * scale,
          8 * scale,
          10 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: playerText(scale, size: 11, color: AppColors.narText2),
            ),
            SizedBox(height: 4 * scale),
            v,
          ],
        ),
      ),
    );
    return Row(
      children: [
        box(
          l.playerStatSubscribers,
          Text(formatCheerCount(stats.subscriberCount), style: value),
        ),
        SizedBox(width: 8 * scale),
        box(
          l.playerStatCheers7d,
          Text(formatCheerCount(stats.cheers7d), style: value),
        ),
        SizedBox(width: 8 * scale),
        box(
          l.playerStatWorldsRating,
          rating == null
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
