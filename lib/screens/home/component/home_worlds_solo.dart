import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_live_dot.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../my_players/component/my_player_tile.dart';
import 'home_solo_rank_section.dart';

// 홈 솔랭 섹션의 월즈 블록. 구독 선수 카드 상태에 따라 하나만 붙는다
// (HomeSoloRankSection 참고):
// - 구독 선수가 솔랭 중 → [HomeWorldsEntryRow]
// - 구독 선수는 쉬는데 월즈 선수가 솔랭 중 → [HomeWorldsLabel] + [HomeWorldsMiniCards]
// - 월즈 선수도 모두 쉬는 중 → [HomeWorldsLine]

const String _worldsIcon = 'assets/icons/leagues/worlds.png';

/// 월즈 솔랭 진입 줄 — 구독 선수 카드 아래. 솔랭 중인 월즈 선수 얼굴 + 인원.
class HomeWorldsEntryRow extends StatelessWidget {
  const HomeWorldsEntryRow({
    super.key,
    required this.live,
    required this.scale,
    this.onTap,
  });

  static const Key rowKey = ValueKey('homeWorldsEntry');
  static const int _maxFaces = 3;

  final List<HomeLiveSoloPlayer> live;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final faces = live.take(_maxFaces).toList();
    final extra = live.length - faces.length;
    final size = 38 * scale;
    final step = 26 * scale;
    final count = faces.length + (extra > 0 ? 1 : 0);

    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          children: [
            SizedBox(
              width: size + step * (count - 1),
              height: size,
              child: Stack(
                children: [
                  for (final (i, p) in faces.indexed)
                    Positioned(
                      left: step * i,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          HomeSoloFace(
                            name: p.name,
                            url: resolveImageUrl(p.playerImageUrl),
                            size: size,
                            scale: scale,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 1 * scale,
                            child: Container(
                              width: 9 * scale,
                              height: 9 * scale,
                              decoration: BoxDecoration(
                                color: AppColors.narSoloDot,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.narBgTertiary,
                                  width: 2 * scale,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (extra > 0)
                    Positioned(
                      left: step * faces.length,
                      child: HomeSoloFace(
                        name: '+$extra',
                        url: null,
                        size: size,
                        scale: scale,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 14 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        _worldsIcon,
                        width: 18 * scale,
                        height: 18 * scale,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        l.worldsSoloTitle,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 15 * scale,
                          height: 1.35,
                          color: AppColors.narTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    l.worldsSoloEntrySub(live.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13 * scale,
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

/// "월즈 솔랭 중인 LCK 선수 N명" 라벨 줄. [onSeeAll] 이 있으면 오른쪽에 "전체 >".
class HomeWorldsLabel extends StatelessWidget {
  const HomeWorldsLabel({
    super.key,
    required this.count,
    required this.scale,
    this.onSeeAll,
  });

  final int count;
  final double scale;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Opacity(
          opacity: 0.75,
          child: Image.asset(
            _worldsIcon,
            width: 16 * scale,
            height: 16 * scale,
          ),
        ),
        SizedBox(width: 6 * scale),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l.worldsSoloLiveLabel),
                TextSpan(
                  text: '  ${l.myPlayersGroupCount(count)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.narDark300,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 13 * scale,
              color: AppColors.narDark200,
            ),
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeAll,
            child: Row(
              children: [
                Text(
                  l.worldsSoloAll,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13 * scale,
                    color: AppColors.narText2,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16 * scale,
                  color: AppColors.narText2,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 월즈 선수 작은 카드 가로 줄 — 구독 선수가 모두 쉬는 동안 홈 위쪽을 채운다.
/// 카드마다 구독 벨이 있어 바로 구독한다.
class HomeWorldsMiniCards extends StatelessWidget {
  const HomeWorldsMiniCards({
    super.key,
    required this.live,
    required this.secondsOf,
    required this.tick,
    required this.scale,
    this.onSubscribe,
    this.onOpen,
  });

  static Key cardKey(String name) => ValueKey('homeWorldsMini-$name');
  static Key bellKey(String name) => ValueKey('homeWorldsMiniBell-$name');

  final List<HomeLiveSoloPlayer> live;
  final int Function(HomeLiveSoloPlayer) secondsOf;
  final ValueListenable<int> tick;
  final double scale;
  final ValueChanged<int>? onSubscribe;
  final VoidCallback? onOpen;

  static const double cardWidth = 148;
  static const double height = 104 + 64;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
        itemCount: live.length,
        separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
        itemBuilder: (context, i) => _MiniCard(
          key: cardKey(live[i].name),
          player: live[i],
          secondsOf: () => secondsOf(live[i]),
          tick: tick,
          scale: scale,
          onSubscribe: onSubscribe,
          onOpen: onOpen,
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    super.key,
    required this.player,
    required this.secondsOf,
    required this.tick,
    required this.scale,
    this.onSubscribe,
    this.onOpen,
  });

  final HomeLiveSoloPlayer player;
  final int Function() secondsOf;
  final ValueListenable<int> tick;
  final double scale;
  final ValueChanged<int>? onSubscribe;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final splash = championSplashUrl(player.champion);
    final photo = resolveImageUrl(player.playerImageUrl);
    final region = player.overseasRegion;
    final id = player.playerId;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        width: HomeWorldsMiniCards.cardWidth * scale,
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 104 * scale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.narSoloHeroBg),
                  if (splash != null)
                    CachedNetworkImage(
                      imageUrl: splash,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.4),
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.narPlayedChampOverlay,
                    ),
                  ),
                  if (photo != null && photo.isNotEmpty)
                    Positioned(
                      right: -14 * scale,
                      bottom: -6 * scale,
                      width: 118 * scale,
                      height: 100 * scale,
                      child: CachedNetworkImage(
                        imageUrl: photo,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        fadeInDuration: const Duration(milliseconds: 150),
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  Positioned(
                    left: 8 * scale,
                    top: 8 * scale,
                    child: Row(
                      children: [
                        TeamCodeBadge(
                          teamCode: player.teamCode,
                          size: 18 * scale,
                        ),
                        if (region != null) ...[
                          SizedBox(width: 4 * scale),
                          RegionChip(region: region, scale: scale),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12 * scale,
                10 * scale,
                10 * scale,
                10 * scale,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 15 * scale,
                            color: AppColors.narTextTertiary,
                          ),
                        ),
                        SizedBox(height: 2 * scale),
                        Row(
                          children: [
                            NarLiveDot(
                              size: 5 * scale,
                              color: AppColors.narSoloDot,
                            ),
                            SizedBox(width: 4 * scale),
                            Flexible(
                              child: ValueListenableBuilder<int>(
                                valueListenable: tick,
                                builder: (_, _, _) => Text(
                                  [
                                    if (player.champion.isNotEmpty)
                                      player.champion,
                                    _clock(secondsOf()),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Open Sans',
                                    fontSize: 12 * scale,
                                    color: AppColors.narSoloText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (id != null && onSubscribe != null)
                    Semantics(
                      button: true,
                      label: l.worldsSoloSubscribeSemantics(player.name),
                      child: GestureDetector(
                        key: HomeWorldsMiniCards.bellKey(player.name),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSubscribe!(id),
                        child: Container(
                          width: 32 * scale,
                          height: 32 * scale,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.narDark500,
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/icons/bell-plus.svg',
                            width: 16 * scale,
                            height: 16 * scale,
                            colorFilter: const ColorFilter.mode(
                              AppColors.narText2,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
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

/// 월즈 선수도 모두 쉬는 중 — 접힌 한 줄. 마지막으로 솔랭한 선수를 보여준다.
class HomeWorldsLine extends StatelessWidget {
  const HomeWorldsLine({
    super.key,
    required this.last,
    required this.scale,
    this.onTap,
  });

  static const Key lineKey = ValueKey('homeWorldsLine');

  final HomeFinishedSoloPlayer? last;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final done = last;
    final ago = done == null
        ? null
        : done.minutesAgo < 60
        ? l.homeMinutesAgo(done.minutesAgo)
        : l.homeHoursAgo(done.minutesAgo ~/ 60);

    return GestureDetector(
      key: lineKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40 * scale,
        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: 0.75,
              child: Image.asset(
                _worldsIcon,
                width: 16 * scale,
                height: 16 * scale,
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l.worldsSoloTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.narText3,
                      ),
                    ),
                    if (done != null && ago != null)
                      TextSpan(text: '  ${l.worldsSoloLast(done.name, ago)}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ),
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

/// 경과 시간 "m:ss". 1시간이 넘으면 "h:mm:ss" (홈 솔랭 카드와 같은 표기).
String _clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}
