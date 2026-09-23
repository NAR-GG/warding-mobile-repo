import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/dashed_border.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
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
          subscribedTotal: vm.subscribedTotal,
          lastFinished: vm.soloFinished.isEmpty ? null : vm.soloFinished.first,
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
    final hidden = vm.soloHiddenCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (done.isNotEmpty || hidden > 0) ...[
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
              itemCount: done.length + (hidden > 0 ? 1 : 0),
              separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
              itemBuilder: (context, i) {
                if (i == done.length) {
                  return _HiddenCountChip(count: hidden, scale: scale);
                }
                return _FinishedChip(
                  key: HomeSoloRankSection.finishedKey(done[i].name),
                  player: done[i],
                  scale: scale,
                );
              },
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

/// 구독은 있는데 진행 중 0명 — 한 줄짜리 조용한 상태. 누르면 내 선수 화면.
class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.subscribedTotal,
    required this.lastFinished,
    required this.scale,
    this.onTap,
  });

  final int subscribedTotal;
  final HomeFinishedSoloPlayer? lastFinished;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final last = lastFinished;
    final sub = last == null
        ? l.homeSoloQuietSubscribed(subscribedTotal)
        : '${l.homeSoloQuietSubscribed(subscribedTotal)} · '
              '${last.won ? l.homeSoloLastGameWin(_ago(l, last.minutesAgo), last.name) : l.homeSoloLastGameLoss(_ago(l, last.minutesAgo), last.name)}';

    return GestureDetector(
      key: HomeSoloRankSection.quietKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 14 * scale,
        ),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Row(
          children: [
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
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5 * scale,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
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

/// 진행 중인 선수 한 명의 큰 카드. 숫자는 경과 시간 하나뿐이다.
class _HeroCard extends StatelessWidget {
  const _HeroCard({super.key, required this.player, required this.scale});

  final HomeLiveSoloPlayer player;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final splashUrl = championSplashUrl(championToEn(player.champion));
    final photoUrl = resolveImageUrl(player.playerImageUrl);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: AppColors.narLine),
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
          // 선수 사진 — 카드 우측 하단에 붙인다. 없으면 빈 자리 유지.
          if (photoUrl != null && photoUrl.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: 120 * scale,
                height: 168 * scale,
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
                    _Dot(size: 5 * scale),
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
                      _clock(player.elapsedSeconds),
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
                      _Dot(size: 6 * scale),
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
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.narSoloDot,
      shape: BoxShape.circle,
    ),
  );
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
          Container(
            width: 32 * scale,
            height: 32 * scale,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.narLine2,
              shape: BoxShape.circle,
            ),
            child: TeamCodeBadge(teamCode: player.teamCode, size: 20 * scale),
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

class _HiddenCountChip extends StatelessWidget {
  const _HiddenCountChip({required this.count, required this.scale});

  final int count;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 44 * scale,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 15 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Text(
        l.homeHiddenCount(count),
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 12.5 * scale,
          color: AppColors.narText2,
        ),
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
