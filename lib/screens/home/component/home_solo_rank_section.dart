import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/dashed_border.dart';
import '../../../components/nar_live_dot.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../model/player_subscription.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/champion_name_map.dart';
import '../../../viewmodel/home/home_viewmodel.dart';

/// 구독 선수 솔랭 상태 — spec "상태" 표의 세 갈래를 [HomeViewModel.soloState]
/// 로 나눠 그린다.
///
/// - 구독 0명([SoloCardState.noSubscription]): 점선 빈 카드 + 빈 프로필.
/// - 진행 중 0명([SoloCardState.noneActive]): 한 줄짜리 조용한 상태.
/// - 진행 중([SoloCardState.active]): 위는 진행 중인 선수만 스와이프하는 큰
///   카드, 아래는 오늘 끝난 경기 줄 + "+N명" + "구독 N명 전체".
///
/// 라이브 카드에 보여주는 숫자는 경과 시간 하나뿐이다 — 관전하기·포지션·진행 중
/// 스코어는 spectator-v5 가 주지 않는다(spec 결정). 로딩·에러는 그리지 않는다.
class HomeSoloRankSection extends StatefulWidget {
  const HomeSoloRankSection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onOpenMyPlayers,
    this.onSubscribe,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// "구독 N명 전체"·조용한 상태 줄 — 내 선수(구독 전체) 화면으로.
  final VoidCallback? onOpenMyPlayers;

  /// 빈 카드의 "선수 구독하기".
  final VoidCallback? onSubscribe;

  static const Key emptyCardKey = ValueKey('homeSoloEmpty');
  static const Key quietKey = ValueKey('homeSoloQuiet');
  static Key heroKey(String name) => ValueKey('homeSoloHero-$name');
  static Key finishedKey(String name) => ValueKey('homeSoloDone-$name');

  @override
  State<HomeSoloRankSection> createState() => _HomeSoloRankSectionState();
}

class _HomeSoloRankSectionState extends State<HomeSoloRankSection> {
  // 컨트롤러를 build 마다 새로 만들면 스와이프 → notifyListeners → 재빌드 때
  // 첫 장으로 되돌아간다. 상태에 붙여 둔다.
  late final PageController _pages = PageController(
    viewportFraction: 0.92,
    initialPage: widget.viewModel.soloSwipeIndex,
  );

  // 큰 카드의 경과 시간을 매초 다시 그린다(기기 시계 카운트업 — spec에서
  // 미뤄뒀던 항목). ViewModel 은 API 응답이 올 때만 갱신되므로, 그 사이는
  // 이 타이머의 setState 로만 화면을 다시 그린다. 진행 중 카드가 없을 때는
  // 다시 그려도 보이는 게 안 바뀌니 그때만 건너뛴다.
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.viewModel.soloState == SoloCardState.active) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pages.dispose();
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

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final scale = widget.scale;
    return switch (vm.soloState) {
      SoloCardState.noSubscription => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
        child: _EmptyCard(scale: scale, onSubscribe: widget.onSubscribe),
      ),
      SoloCardState.noneActive => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
        child: _QuietRow(
          faces: vm.subscribedFaces,
          subscribedTotal: vm.subscribedTotal,
          scale: scale,
          onTap: widget.onOpenMyPlayers,
        ),
      ),
      SoloCardState.active => _buildActive(context),
    };
  }

  Widget _buildActive(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final scale = widget.scale;
    final live = vm.soloLive;
    final done = vm.soloFinished;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 진행 중인 선수가 없으면(끝난 경기만 있어 active 상태) 스와이프할
        // 카드가 없다 — 대신 조용한 상태 줄(_QuietRow)을 그대로 보여주고
        // 그 아래에 끝난 경기 줄을 잇는다(2026-09-29 결정, spec.md "상태" 표).
        if (live.isNotEmpty) ...[
          SizedBox(
            height: 196 * scale,
            child: PageView.builder(
              controller: _pages,
              onPageChanged: vm.setSoloSwipeIndex,
              itemCount: live.length,
              // 한 장이 폭의 92% — 가운데 정렬(padEnds)이라 첫 장 왼쪽 여백이
              // 4% + 5 로 다른 섹션의 20 여백과 맞고, 옆 카드가 살짝 보인다.
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                child: _HeroCard(
                  key: HomeSoloRankSection.heroKey(live[i].name),
                  player: live[i],
                  elapsedSeconds: _liveElapsedSeconds(live[i]),
                  scale: scale,
                ),
              ),
            ),
          ),
          if (live.length > 1) ...[
            SizedBox(height: 10 * scale),
            _SwipeDots(
              count: live.length,
              index: vm.soloSwipeIndex,
              scale: scale,
            ),
          ],
        ] else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: _QuietRow(
              faces: vm.subscribedFaces,
              subscribedTotal: vm.subscribedTotal,
              scale: scale,
              onTap: widget.onOpenMyPlayers,
            ),
          ),
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
                fontSize: 11 * scale,
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
              itemBuilder: (context, i) => _FinishedChip(
                key: HomeSoloRankSection.finishedKey(done[i].name),
                player: done[i],
                scale: scale,
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 0),
          child: _SeeAllButton(
            label: l.homeSubscribedSeeAll(vm.subscribedTotal),
            scale: scale,
            onTap: widget.onOpenMyPlayers,
          ),
        ),
      ],
    );
  }
}

/// 경과 시간 "m:ss". 1시간이 넘으면 "h:mm:ss".
String _clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// "12분 전" / "2시간 전".
String _ago(AppLocalizations l, int minutes) =>
    minutes < 60 ? l.homeMinutesAgo(minutes) : l.homeHoursAgo(minutes ~/ 60);

/// 구독 0명 — 점선 빈 카드와 빈 프로필 원.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.scale, this.onSubscribe});

  final double scale;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return KeyedSubtree(
      key: HomeSoloRankSection.emptyCardKey,
      child: DashedBorder(
        radius: 14 * scale,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 186 * scale),
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 24 * scale,
          ),
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            borderRadius: BorderRadius.circular(14 * scale),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DashedBorder(
                circle: true,
                child: Container(
                  width: 64 * scale,
                  height: 64 * scale,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.narBgTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 34 * scale,
                    color: AppColors.narDark400,
                  ),
                ),
              ),
              SizedBox(height: 12 * scale),
              Text(
                l.homeHeroEmptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14 * scale,
                  height: 1.55,
                  color: AppColors.narGray400,
                ),
              ),
              SizedBox(height: 14 * scale),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSubscribe,
                child: Container(
                  height: 40 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 22 * scale),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.narBg,
                    borderRadius: BorderRadius.circular(20 * scale),
                  ),
                  child: Text(
                    l.homeHeroEmptyButton,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 13 * scale,
                      color: AppColors.narText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 구독은 있는데 진행 중인 선수도 오늘 끝난 경기도 0명 — 한 줄짜리 조용한
/// 상태. 누르면 내 선수 화면.
///
/// 끝난 경기가 하나라도 있으면 이 대신 끝난 경기 줄(활성 상태)을 보여주므로,
/// 여기는 정말 아무 소식도 없을 때만 그린다 — "마지막 경기" 같은 보조 정보는
/// 없다. 시안(`mockup.html`)의 `.quiet`: 구독 선수 얼굴이 겹쳐 놓인 스택 +
/// 구독 수 한 줄 + 화살표. 구독이 얼굴 수보다 많으면 "+N" 칸이 붙는다.
class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.faces,
    required this.subscribedTotal,
    required this.scale,
    this.onTap,
  });

  final List<PlayerSubscription> faces;
  final int subscribedTotal;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return GestureDetector(
      key: HomeSoloRankSection.quietKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 18 * scale,
        ),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          children: [
            if (faces.isNotEmpty) ...[
              _FaceStack(
                faces: faces,
                extra: subscribedTotal - faces.length,
                scale: scale,
              ),
              SizedBox(width: 14 * scale),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.homeSoloQuietTitle,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5 * scale,
                      height: 1.35,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    l.homeSoloQuietSubscribed(subscribedTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5 * scale,
                      height: 1.5,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8 * scale),
            Icon(
              Icons.chevron_right,
              size: 16 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독 선수 얼굴을 겹쳐 놓은 스택 — 38 원, 12씩 겹치고 카드 색 2px 테두리로
/// 서로를 갈라 놓는다. 뒤에 오는 얼굴이 위에 올라온다. [extra] 가 0보다 크면
/// 마지막에 "+N" 칸을 붙인다.
class _FaceStack extends StatelessWidget {
  const _FaceStack({
    required this.faces,
    required this.extra,
    required this.scale,
  });

  final List<PlayerSubscription> faces;
  final int extra;
  final double scale;

  static const double _size = 38;
  static const double _step = 26; // 38 - 겹침 12

  @override
  Widget build(BuildContext context) {
    final count = faces.length + (extra > 0 ? 1 : 0);
    final size = _size * scale;
    return SizedBox(
      width: (_size + _step * (count - 1)) * scale,
      height: size,
      child: Stack(
        children: [
          for (final (i, p) in faces.indexed)
            Positioned(
              left: _step * i * scale,
              child: _Face(
                name: p.playerName,
                url: resolveImageUrl(p.playerImageUrl),
                size: size,
                scale: scale,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: _step * faces.length * scale,
              child: _Face(
                name: '+$extra',
                url: null,
                size: size,
                scale: scale,
              ),
            ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.name,
    required this.url,
    required this.size,
    required this.scale,
  });

  final String name;
  final String? url;
  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final label = name.startsWith('+')
        ? name
        : (name.length >= 2 ? name.substring(0, 2) : name).toUpperCase();
    final initials = Center(
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: 12 * scale,
          color: AppColors.narText2,
        ),
      ),
    );
    final photo = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.narLine2,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.narBgTertiary, width: 2 * scale),
      ),
      child: ClipOval(
        child: photo == null || photo.isEmpty
            ? initials
            : CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                // 전신 사진이라 얼굴이 위쪽에 있다 — 시안의 `center 12%`.
                alignment: const Alignment(0, -0.75),
                memCacheWidth: (size * 3).round(),
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => initials,
                errorWidget: (_, _, _) => initials,
              ),
      ),
    );
  }
}

/// 진행 중인 선수 한 명의 큰 카드. 숫자는 경과 시간 하나뿐이다.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    super.key,
    required this.player,
    required this.elapsedSeconds,
    required this.scale,
  });

  final HomeLiveSoloPlayer player;

  /// [player.elapsedSeconds] 의 매초 카운트업 값(부모가 기기 시계로 다시
  /// 계산해 내려준다). [HomeLiveSoloPlayer.startedAt] 참고.
  final int elapsedSeconds;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final splashUrl = championSplashUrl(championToEn(player.champion));
    final photoUrl = resolveImageUrl(player.playerImageUrl);
    final radius = BorderRadius.circular(14 * scale);

    // 테두리를 배경 데코레이션이 아니라 foregroundDecoration으로 그린다 —
    // 배경 데코레이션은 Stack(챔피언 스플래시·선수 사진) 뒤에 깔리고 그 위에
    // Stack 이 덮어 그려지는 순서라, 사진이 모서리까지 닿으면 안쪽 클립은
    // 맞아도 테두리 선 자체가 사진에 가려 그 구간만 끊겨 보였다. 테두리를
    // 맨 위(foreground)에 그리면 어떤 내용이 깔려도 항상 온전히 보인다.
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.narLine),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: AppColors.narSoloHeroBg,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
          // 배경: 챔피언 스플래시 아트. 카드가 세로로 짧아 상단(얼굴)이 잘리기
          // 쉬워 top 쪽으로 정렬한다.
          if (splashUrl != null)
            LayoutBuilder(
              builder: (context, constraints) => CachedNetworkImage(
                imageUrl: splashUrl,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3),
                memCacheWidth: decodeWidthFor(
                  context,
                  boxWidth: constraints.maxWidth,
                  boxHeight: constraints.maxHeight,
                  sourceWidth: kChampionSplashWidth,
                  sourceHeight: kChampionSplashHeight,
                ),
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          // 배경 위 어두운 그라데이션 — 콘텐츠 가독성 확보.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.narPlayedChampOverlay,
            ),
          ),
          // 선수 사진 — 카드 우측 하단에 붙인다. 시안(mockup.html `.hero .ph`)
          // 대로 카드 가장자리 밖으로 살짝 흘러넘치게 키워, 안쪽 클립이 정확히
          // 모서리에서 잘라낸다. 없으면 빈 자리 유지.
          if (photoUrl != null && photoUrl.isNotEmpty)
            Positioned(
              right: -6 * scale,
              bottom: -10 * scale,
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: 176 * scale,
                height: 214 * scale,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          // 우상단: "아리 플레이 중" — 챔피언을 모르면 그리지 않는다.
          if (player.champion.isNotEmpty)
            Positioned(
              top: 10 * scale,
              right: 10 * scale,
              child: Container(
                height: 22 * scale,
                padding: EdgeInsets.symmetric(horizontal: 9 * scale),
                decoration: BoxDecoration(
                  color: AppColors.narDarkOpacity62,
                  borderRadius: BorderRadius.circular(11 * scale),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NarLiveDot(
                      scale: scale,
                      size: 5,
                      color: AppColors.narSoloDot,
                    ),
                    SizedBox(width: 5 * scale),
                    Text(
                      l.homeSoloPlaying(player.champion),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5 * scale,
                        color: AppColors.narGray400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              15 * scale,
              13 * scale,
              126 * scale,
              13 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TeamCodeBadge(teamCode: player.teamCode, size: 18 * scale),
                    SizedBox(width: 6 * scale),
                    Text(
                      player.teamCode,
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 12 * scale,
                        color: AppColors.narGray400,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * scale),
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 27 * scale,
                    height: 1.1,
                    color: AppColors.narText,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _clock(elapsedSeconds),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 30 * scale,
                        height: 1,
                        color: AppColors.narText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 3 * scale),
                        child: Text(
                          l.homeSoloInProgress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11 * scale,
                            color: AppColors.narText2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // "솔로 랭크" 배지 — 브랜드 3색을 옅게 깐다(신호색 없음).
                Container(
                  height: 24 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                  decoration: BoxDecoration(
                    gradient: AppColors.narSoloTint,
                    borderRadius: BorderRadius.circular(12 * scale),
                    border: Border.all(color: AppColors.narSoloLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NarLiveDot(
                        scale: scale,
                        size: 6,
                        color: AppColors.narSoloDot,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        l.homeSoloQueueBadge,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5 * scale,
                          color: AppColors.narSoloText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// 스와이프 위치 점. 5개까지만 그리고 넘치면 "+N".
class _SwipeDots extends StatelessWidget {
  const _SwipeDots({
    required this.count,
    required this.index,
    required this.scale,
  });

  static const int _maxDots = 5;

  final int count;
  final int index;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final shown = count < _maxDots ? count : _maxDots;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < shown; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.symmetric(horizontal: 2 * scale),
            width: i == index ? 14 * scale : 5 * scale,
            height: 5 * scale,
            decoration: BoxDecoration(
              color: i == index ? AppColors.narGray400 : AppColors.narLine2,
              borderRadius: BorderRadius.circular(3 * scale),
            ),
          ),
        if (count > _maxDots) ...[
          SizedBox(width: 6 * scale),
          Text(
            '+${count - _maxDots}',
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 10 * scale,
              height: 1,
              color: AppColors.narDark200,
            ),
          ),
        ],
      ],
    );
  }
}

/// 오늘 끝난 경기 한 명. 종료 시각("12분 전 종료")과 경기 길이("32분")를
/// 다른 줄에 둔다 — 한 줄에 같이 두면 "32분"이 "32분 전"으로 읽힌다.
class _FinishedChip extends StatelessWidget {
  const _FinishedChip({super.key, required this.player, required this.scale});

  final HomeFinishedSoloPlayer player;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final duration = player.durationMinutes;
    return Container(
      height: 44 * scale,
      padding: EdgeInsets.only(left: 6 * scale, right: 11 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Face(
            name: player.name,
            url: resolveImageUrl(player.playerImageUrl),
            size: 32 * scale,
            scale: scale,
          ),
          SizedBox(width: 7 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5 * scale,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                  if (duration != null) ...[
                    SizedBox(width: 5 * scale),
                    Text(
                      l.homeSoloDuration(duration),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10 * scale,
                        color: AppColors.narDark200,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 1 * scale),
              Text(
                '${l.homeSoloEndedAgo(_ago(l, player.minutesAgo))} · '
                '${player.won ? l.homeSoloWin : l.homeSoloLoss}',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 10 * scale,
                  // 승자 빨강 / 패자 회색 — 스코어 표시 관례(policy/design.md).
                  color: player.won ? AppColors.scoreWin : AppColors.narDark200,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.label, required this.scale, this.onTap});

  final String label;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 12.5 * scale,
                color: AppColors.narText2,
              ),
            ),
            SizedBox(width: 3 * scale),
            Icon(
              Icons.chevron_right,
              size: 13 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}
