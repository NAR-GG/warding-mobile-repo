import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/solo_hero_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import '../../../viewmodel/player/player_viewmodel.dart';
import '../../my_players/component/worlds_player_sheet.dart';
import '../../login/login_screen.dart';
import 'home_skeletons.dart';
import 'home_solo_cheer.dart';
import 'home_solo_parts.dart';
import 'home_solo_states.dart';
import 'home_worlds_solo.dart';

/// 구독 선수 솔랭 상태 — spec "상태" 표의 세 갈래를 [HomeViewModel.soloState]
/// 로 나눠 그린다.
///
/// - 로딩([SoloCardState.loading]): 첫 구독 조회가 끝나기 전 — 스켈레톤.
///   빈 카드로 시작했다가 실제 카드로 바뀌면 레이아웃이 튀므로(CLS), 응답이
///   오기 전까지는 확정된 상태(빈 카드/조용한 행/카드) 중 하나를 먼저
///   보여주지 않는다.
/// - 구독 0명([SoloCardState.noSubscription]): 점선 빈 카드 + 빈 프로필.
/// - 진행 중 0명([SoloCardState.noneActive]): 한 줄짜리 조용한 상태.
/// - 진행 중([SoloCardState.active]): 위는 진행 중인 선수만 스와이프하는 큰
///   카드, 아래는 오늘 끝난 경기 줄 + "+N명" + "구독 N명 전체".
///
/// 라이브 카드에 보여주는 숫자는 경과 시간 하나뿐이다 — 관전하기·포지션·진행 중
/// 스코어는 spectator-v5 가 주지 않는다(spec 결정). 에러는 그리지 않는다.
///
/// 상태별 위젯은 [home_solo_states.dart], 카드 아래 부품(스켈레톤·스와이프
/// 점·끝난 경기 칩·전체 버튼)은 [home_solo_parts.dart] 에 있다. 큰 카드와 얼굴
/// 아바타는 선수 페이지와 같이 쓰므로 `lib/components/` 의 [SoloHeroCard],
/// `SoloFace` 다.
class HomeSoloRankSection extends StatefulWidget {
  const HomeSoloRankSection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onOpenMyPlayers,
    this.onSubscribe,
    this.onOpenWorlds,
    this.onOpenPlayer,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// "구독 N명 전체"·조용한 상태 줄 — 내 선수(구독 전체) 화면으로.
  final VoidCallback? onOpenMyPlayers;

  /// 빈 카드의 "선수 구독하기".
  final VoidCallback? onSubscribe;

  /// 월즈 블록(진입 줄·작은 카드·한 줄·전체) — 월즈 솔랭 화면으로.
  final VoidCallback? onOpenWorlds;

  /// 큰 카드·끝난 경기 칩 — 선수 페이지로. playerId 를 모르는 선수는 반응 없다.
  final void Function(int playerId)? onOpenPlayer;

  static Key worldsHeroKey(String name) => ValueKey('homeWorldsHero-$name');
  static Key worldsSubscribeKey(String name) =>
      ValueKey('homeWorldsSubscribe-$name');

  static const Key emptyCardKey = ValueKey('homeSoloEmpty');
  static const Key quietKey = ValueKey('homeSoloQuiet');
  static Key heroKey(String name) => ValueKey('homeSoloHero-$name');
  static Key finishedKey(String name) => ValueKey('homeSoloDone-$name');
  static Key finishedCheerKey(String name) =>
      ValueKey('homeSoloDoneCheer-$name');

  @override
  State<HomeSoloRankSection> createState() => _HomeSoloRankSectionState();
}

class _HomeSoloRankSectionState extends State<HomeSoloRankSection>
    with WidgetsBindingObserver {
  // 컨트롤러를 build 마다 새로 만들면 스와이프 → notifyListeners → 재빌드 때
  // 첫 장으로 되돌아간다. 상태에 붙여 둔다.
  late final PageController _pages = PageController(
    viewportFraction: 0.92,
    initialPage: widget.viewModel.soloSwipeIndex,
  );

  // 구독 0명일 때 빈 카드 자리를 채우는 월즈 카드 스와이프.
  final PageController _worldsPages = PageController(viewportFraction: 0.92);
  int _worldsIndex = 0;

  // 큰 카드의 경과 시간을 매초 다시 그린다(기기 시계 카운트업 — spec에서
  // 미뤄뒀던 항목). ViewModel 은 API 응답이 올 때만 갱신되므로, 그 사이는
  // 이 타이머가 화면을 다시 그린다.
  //
  // 예전엔 틱마다 `setState(() {})` 를 불러 **섹션 전체**(스플래시·선수 사진
  // 3장과 PageView, 끝난 경기 칩 줄까지)를 매초 재구성했다. 실제로 바뀌는 건
  // 카드 하단의 경과 시간 텍스트 하나뿐이라, 이 notifier 를 구독하는 그
  // 텍스트만 다시 그린다([SoloHeroCard] 의 `tick`).
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant HomeSoloRankSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 폴링 응답으로 진행 중 선수가 생기거나 사라지면 타이머도 따라 켜고 끈다.
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면이 안 보이는 동안 초당 리빌드를 돌릴 이유가 없다. 솔랭 폴링이
    // `HomeViewModel.pauseSoloPolling` 으로 멈추는 것과 같은 맥락이다.
    _syncClock(foreground: state == AppLifecycleState.resumed);
    // 응원은 묶어서 보내므로, 앱이 내려가기 전에 남은 걸 flush 한다.
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.viewModel.flushCheers());
    }
  }

  /// 카운트업이 **실제로 필요할 때만** 타이머를 돌린다.
  ///
  /// 조건이 `soloState == active` 였는데, 끝난 경기만 있어도 active 라
  /// (`HomeViewModel.soloState` 참고) 카운트업할 카드가 없는데도 매초 돌았다.
  /// 경과 시간이 올라가는 건 진행 중(`soloLive`) 카드뿐이라 그걸 본다.
  void _syncClock({bool foreground = true}) {
    final vm = widget.viewModel;
    // 월즈 카드(큰 카드·작은 카드)도 경과 시간이 올라간다.
    final needsClock =
        foreground &&
        (vm.soloLive.isNotEmpty ||
            (vm.worldsVisible && vm.worldsLive.isNotEmpty));
    if (needsClock == (_clockTimer != null)) return;
    if (!needsClock) {
      _clockTimer?.cancel();
      _clockTimer = null;
      return;
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _tick.dispose();
    _pages.dispose();
    _worldsPages.dispose();
    super.dispose();
  }

  /// [player.elapsedSeconds] 의 조회 시점 스냅샷을, [HomeLiveSoloPlayer.startedAt]
  /// 이 있으면 기기 시계로 다시 계산해 매초 카운트업한다.
  int _liveElapsedSeconds(HomeLiveSoloPlayer player) {
    final startedAt = player.startedAt;
    if (startedAt == null) return player.elapsedSeconds;
    final seconds = DateTime.now().difference(startedAt).inSeconds;
    return seconds > player.elapsedSeconds ? seconds : player.elapsedSeconds;
  }

  /// [playerId] 가 있을 때만 선수 페이지로 가는 탭 콜백.
  VoidCallback? _openPlayer(int? playerId) {
    final open = widget.onOpenPlayer;
    if (open == null || playerId == null) return null;
    return () => open(playerId);
  }

  /// 월즈 카드 구독 벨 — 바로 구독하지 않고 선수 구독 시트(선수 페이지 벨과
  /// 같은 시트)를 띄워 알림 종류를 고르게 한다. 비회원이면 로그인 화면으로 보낸다.
  Future<void> _subscribeWorlds(int playerId) async {
    final sheet = PlayerViewModel(
      playerId: playerId,
      cheers: widget.viewModel.cheers,
    );
    try {
      if (!await sheet.isLoggedIn()) {
        if (!mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
        return;
      }
      // 시트는 선수 상세(구독·알림 상태)를 읽어 그린다.
      await sheet.load();
      if (!mounted || sheet.detail == null) return;
      await showWorldsPlayerSheet(
        context,
        viewModel: sheet,
        playerId: playerId,
        scale: widget.scale,
      );
      await widget.viewModel.refreshSubscriptionsOnReturn();
    } finally {
      sheet.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final scale = widget.scale;
    return switch (vm.soloState) {
      SoloCardState.loading => Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: HomeSoloHeroSkeleton(scale: scale),
          ),
          // 오늘 끝난 경기 줄 자리 — 구독 조회가 끝나기 전엔 몇 명인지 몰라
          // 칩 줄 모양만 잡아 둔다.
          SizedBox(height: 10 * scale),
          HomeFinishedSoloSkeleton(scale: scale),
        ],
      ),
      SoloCardState.noSubscription =>
        vm.worldsVisible && vm.worldsLive.isNotEmpty
            ? _buildWorldsHeroes(context)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                    child: HomeSoloEmptyCard(
                      scale: scale,
                      onSubscribe: widget.onSubscribe,
                    ),
                  ),
                  ..._worldsBelow(),
                ],
              ),
      SoloCardState.noneActive => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: HomeSoloQuietRow(
              faces: vm.subscribedFaces,
              subscribedTotal: vm.subscribedTotal,
              scale: scale,
              onTap: widget.onOpenMyPlayers,
            ),
          ),
          ..._worldsBelow(),
        ],
      ),
      SoloCardState.active => _buildActive(context),
    };
  }

  /// 구독 카드 아래에 붙는 월즈 블록. 명단이 비면(대회 전·후) 아무것도 없다.
  ///
  /// 구독 선수가 솔랭 중이면 진입 줄 하나만 — 위쪽은 내 선수 자리다. 구독
  /// 선수가 쉬는 동안엔 솔랭 중인 월즈 선수를 작은 카드로 채우고, 월즈 선수도
  /// 모두 쉬면 마지막 솔랭만 한 줄로 접는다.
  List<Widget> _worldsBelow() {
    final vm = widget.viewModel;
    final scale = widget.scale;
    if (!vm.worldsVisible) return const [];
    final pad = EdgeInsets.fromLTRB(20 * scale, 12 * scale, 20 * scale, 0);

    if (vm.soloLive.isNotEmpty) {
      final all = vm.worldsLiveAll;
      return [
        Padding(
          padding: pad,
          child: all.isNotEmpty
              ? HomeWorldsEntryRow(
                  live: all,
                  teamCount: vm.worldsTeamCount,
                  scale: scale,
                  onTap: widget.onOpenWorlds,
                )
              : HomeWorldsLine(
                  last: vm.worldsLastFinished,
                  scale: scale,
                  onTap: widget.onOpenWorlds,
                ),
        ),
      ];
    }

    final live = vm.worldsLive;
    if (live.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 0),
          child: HomeWorldsLine(
            last: vm.worldsLastFinished,
            scale: scale,
            onTap: widget.onOpenWorlds,
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 0),
        child: HomeWorldsLabel(
          count: live.length,
          scale: scale,
          onSeeAll: widget.onOpenWorlds,
        ),
      ),
      SizedBox(height: 10 * scale),
      HomeWorldsMiniCards(
        live: live,
        secondsOf: _liveElapsedSeconds,
        tick: _tick,
        scale: scale,
        onSubscribe: _subscribeWorlds,
        onOpen: widget.onOpenWorlds,
        onOpenPlayer: widget.onOpenPlayer,
      ),
    ];
  }

  /// 구독 0명 — 빈 카드 대신 솔랭 중인 월즈 선수를 큰 카드로. 응원 영역 자리에
  /// "구독하면 알려드려요 + 구독하기" 를 둔다.
  Widget _buildWorldsHeroes(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final scale = widget.scale;
    final live = vm.worldsLive;
    final index = _worldsIndex < live.length ? _worldsIndex : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 10 * scale),
          child: HomeWorldsLabel(count: live.length, scale: scale),
        ),
        SizedBox(
          height: (196 + SoloCheerCard.barHeight) * scale,
          child: PageView.builder(
            controller: _worldsPages,
            onPageChanged: (i) => setState(() => _worldsIndex = i),
            itemCount: live.length,
            itemBuilder: (context, i) {
              final player = live[i];
              final radius = BorderRadius.circular(14 * scale);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: radius),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: AppColors.narLine),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 196 * scale,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openPlayer(player.playerId),
                          child: SoloHeroCard(
                            key: HomeSoloRankSection.worldsHeroKey(player.name),
                            player: player,
                            secondsOf: () => _liveElapsedSeconds(player),
                            tick: _tick,
                            scale: scale,
                            embedded: true,
                          ),
                        ),
                      ),
                      HomeWorldsSubscribeBar(
                        player: player,
                        scale: scale,
                        onSubscribe: player.playerId == null
                            ? null
                            : () => _subscribeWorlds(player.playerId!),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (live.length > 1) ...[
          SizedBox(height: 10 * scale),
          HomeSoloSwipeDots(count: live.length, index: index, scale: scale),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 0),
          child: HomeSoloSeeAllButton(
            label: l.worldsSoloSeeAll,
            scale: scale,
            onTap: widget.onOpenWorlds,
          ),
        ),
      ],
    );
  }

  Widget _buildActive(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final scale = widget.scale;
    final live = vm.soloLive;
    final done = vm.soloFinished;

    // 새로고침(5초 폴링 포함)으로 진행 중 선수 수가 줄면
    // HomeViewModel._recomputeSolo 가 soloSwipeIndex 를 0으로 되돌린다.
    // PageController 는 이미 만들어진 페이지 범위에 맞춰 스스로 마지막
    // 페이지로 clamp 될 뿐 onPageChanged 를 부르지 않는다 — 그대로 두면
    // SwipeDots 는 0번째를 표시하는데 실제로는 다른 카드가 보이는 상태로
    // 어긋난다. 빌드 후 컨트롤러 위치와 뷰모델 인덱스를 비교해 다르면
    // 강제로 맞춘다.
    if (live.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pages.hasClients) return;
        final target = vm.soloSwipeIndex;
        if ((_pages.page ?? 0).round() != target) {
          _pages.jumpToPage(target);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 진행 중인 선수가 없으면(끝난 경기만 있어 active 상태) 스와이프할
        // 카드가 없다 — 대신 조용한 상태 줄(HomeSoloQuietRow)을 그대로 보여주고
        // 그 아래에 끝난 경기 줄을 잇는다(2026-09-29 결정, spec.md "상태" 표).
        if (live.isNotEmpty) ...[
          SizedBox(
            // 솔랭 카드 196 + 응원 영역 74.
            height: (196 + SoloCheerCard.barHeight) * scale,
            child: PageView.builder(
              controller: _pages,
              onPageChanged: vm.setSoloSwipeIndex,
              itemCount: live.length,
              // 한 장이 폭의 92% — 가운데 정렬(padEnds)이라 첫 장 왼쪽 여백이
              // 4% + 5 로 다른 섹션의 20 여백과 맞고, 옆 카드가 살짝 보인다.
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                child: SoloCheerCard(
                  playerName: live[i].name,
                  controller: vm.cheers,
                  heroHeight: 196 * scale,
                  scale: scale,
                  hero: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openPlayer(live[i].playerId),
                    child: SoloHeroCard(
                      key: HomeSoloRankSection.heroKey(live[i].name),
                      player: live[i],
                      secondsOf: () => _liveElapsedSeconds(live[i]),
                      tick: _tick,
                      scale: scale,
                      embedded: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (live.length > 1) ...[
            SizedBox(height: 10 * scale),
            HomeSoloSwipeDots(
              count: live.length,
              index: vm.soloSwipeIndex,
              scale: scale,
            ),
          ],
        ] else ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: HomeSoloQuietRow(
              faces: vm.subscribedFaces,
              subscribedTotal: vm.subscribedTotal,
              scale: scale,
              onTap: widget.onOpenMyPlayers,
            ),
          ),
          ..._worldsBelow(),
        ],
        if (done.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 0),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l.homeDoneRowLabel),
                  TextSpan(
                    text: '  ${l.homeDoneRowSub}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.narDark300,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 13 * scale,
                color: AppColors.narDark200,
              ),
            ),
          ),
          SizedBox(height: 10 * scale),
          SizedBox(
            height: 44 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20 * scale),
              itemCount: done.length,
              separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
              itemBuilder: (context, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openPlayer(done[i].playerId),
                child: HomeSoloFinishedChip(
                  key: HomeSoloRankSection.finishedKey(done[i].name),
                  player: done[i],
                  scale: scale,
                ),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 0),
          child: HomeSoloSeeAllButton(
            label: l.homeSubscribedSeeAll(vm.subscribedTotal),
            scale: scale,
            onTap: widget.onOpenMyPlayers,
          ),
        ),
        if (live.isNotEmpty) ..._worldsBelow(),
      ],
    );
  }
}
