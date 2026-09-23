import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/champion_name_map.dart';
import '../../../viewmodel/home/home_viewmodel.dart';

/// 구독 선수 솔랭 상태 — 목업의 "구독 다수" 상태(heroMany)를 재현한다.
/// 위: 지금 진행 중인 선수 스와이프 카드. 아래: 오늘 끝난 경기 가로 줄.
class HomeSoloRankSection extends StatelessWidget {
  const HomeSoloRankSection({
    super.key,
    required this.viewModel,
    required this.scale,
  });

  final HomeViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final live = HomeViewModel.mockLiveNow;
    final done = HomeViewModel.mockFinishedToday;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 196 * scale,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.92),
              onPageChanged: viewModel.setSoloSwipeIndex,
              itemCount: live.length,
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.only(
                  right: i == live.length - 1 ? 0 : 8 * scale,
                ),
                child: _HeroCard(player: live[i], scale: scale),
              ),
            ),
          ),
          if (live.length > 1) ...[
            SizedBox(height: 8 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < live.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: 2 * scale),
                    width: i == viewModel.soloSwipeIndex
                        ? 14 * scale
                        : 5 * scale,
                    height: 5 * scale,
                    decoration: BoxDecoration(
                      color: i == viewModel.soloSwipeIndex
                          ? AppColors.narGray400
                          : AppColors.narLine2,
                      borderRadius: BorderRadius.circular(3 * scale),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: 16 * scale),
          Text(
            '${l.homeDoneRowLabel} · ${l.homeDoneRowSub}',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12 * scale,
              color: AppColors.narText2,
            ),
          ),
          SizedBox(height: 8 * scale),
          SizedBox(
            height: 56 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: done.length + 1,
              separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
              itemBuilder: (context, i) {
                if (i == done.length) {
                  return _HiddenCountChip(
                    count: viewModel.soloHiddenCount,
                    scale: scale,
                  );
                }
                return _FinishedChip(player: done[i], scale: scale);
              },
            ),
          ),
          SizedBox(height: 8 * scale),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l.homeSubscribedSeeAll(HomeViewModel.mockSubscribedTotal),
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
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.player, required this.scale});

  final HomeLiveSoloPlayer player;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final m = player.elapsedSeconds ~/ 60;
    final s = player.elapsedSeconds % 60;
    final clock = '$m:${s.toString().padLeft(2, '0')}';
    final splashUrl = championSplashUrl(championToEn(player.champion));
    final photoUrl = resolveImageUrl(player.playerImageUrl);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: AppColors.narLine),
        color: AppColors.narPlayedChampBg,
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
          // 선수 사진 — 카드 우측 하단에 붙여 자연스럽게 잘려 나가게 둔다.
          // 없으면(서버 데이터 미제공) 빈 자리 유지.
          if (photoUrl != null && photoUrl.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14 * scale),
                ),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 92 * scale,
                  height: 128 * scale,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  fadeInDuration: const Duration(milliseconds: 150),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(14 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.narDarkOpacity62,
                    borderRadius: BorderRadius.circular(6 * scale),
                  ),
                  child: Text(
                    '${player.champion} 플레이 중',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 12 * scale,
                      color: AppColors.narText,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TeamCodeBadge(
                          teamCode: player.teamCode,
                          size: 16 * scale,
                        ),
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
                    SizedBox(height: 4 * scale),
                    Text(
                      player.name,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 20 * scale,
                        color: AppColors.narText,
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Row(
                      children: [
                        Text(
                          clock,
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontWeight: FontWeight.w600,
                            fontSize: 13 * scale,
                            color: AppColors.narTextTertiary,
                          ),
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          l.homeSoloInProgress,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12 * scale,
                            color: AppColors.narText2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale,
                            vertical: 3 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.narNavSelectedBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.homeSoloQueueBadge,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11 * scale,
                              color: AppColors.narGray400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedChip extends StatelessWidget {
  const _FinishedChip({required this.player, required this.scale});

  final HomeFinishedSoloPlayer player;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TeamCodeBadge(teamCode: player.teamCode, size: 28 * scale),
          SizedBox(width: 8 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player.name,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 13 * scale,
                  color: AppColors.narText,
                ),
              ),
              Text(
                '${l.homeMinutesAgo(player.minutesAgo)} · ${player.won ? '승' : '패'}',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11 * scale,
                  color: player.won
                      ? AppColors.narGreenWin
                      : AppColors.narTextRed,
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
    if (count <= 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Text(
        l.homeHiddenCount(count),
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 13 * scale,
          color: AppColors.narText2,
        ),
      ),
    );
  }
}
