import 'package:flutter/material.dart';

import '../../../components/solo_face.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import 'home_solo_cheer.dart';
import 'home_solo_rank_section.dart';

/// "12분 전" / "2시간 전".
String _ago(AppLocalizations l, int minutes) =>
    minutes < 60 ? l.homeMinutesAgo(minutes) : l.homeHoursAgo(minutes ~/ 60);

/// 첫 구독 조회 중([SoloCardState.loading])에 보여줄 스켈레톤.
///
/// 응답 후 가장 흔히 보이는 큰 카드(`SoloHeroCard`)와 같은 높이(196)·모서리(14)로
/// 맞춰, 구독 중인 선수가 있는 사용자가 겪는 레이아웃 튐(CLS)을 없앤다. 구독
/// 0명으로 끝나 [HomeSoloEmptyCard](186)나 [HomeSoloQuietRow]로 바뀌는 경우엔
/// 약간의 높이 차가 남지만, 셋 모두를 동시에 맞출 수는 없어 가장 흔한 경로를
/// 우선한다.
class HomeSoloHeroSkeleton extends StatefulWidget {
  const HomeSoloHeroSkeleton({super.key, required this.scale});

  final double scale;

  @override
  State<HomeSoloHeroSkeleton> createState() => _HomeSoloHeroSkeletonState();
}

class _HomeSoloHeroSkeletonState extends State<HomeSoloHeroSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final opacity = 0.3 + (_ctrl.value * 0.3);
        Widget box({double? w, required double h, double r = 4}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.narLine2.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(r * scale),
          ),
        );

        return Container(
          height: 196 * scale,
          padding: EdgeInsets.fromLTRB(
            15 * scale,
            13 * scale,
            15 * scale,
            13 * scale,
          ),
          decoration: BoxDecoration(
            color: AppColors.narSoloHeroBg,
            borderRadius: BorderRadius.circular(14 * scale),
            border: Border.all(color: AppColors.narLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  box(w: 18 * scale, h: 18 * scale, r: 9),
                  SizedBox(width: 6 * scale),
                  box(w: 32 * scale, h: 12 * scale),
                ],
              ),
              SizedBox(height: 10 * scale),
              box(w: 140 * scale, h: 27 * scale, r: 6),
              SizedBox(height: 10 * scale),
              box(w: 90 * scale, h: 30 * scale, r: 6),
              const Spacer(),
              box(w: 100 * scale, h: 24 * scale, r: 12),
            ],
          ),
        );
      },
    );
  }
}

/// 월즈 큰 카드 아래 — 응원 영역 자리에 "{name} 구독하면 / 솔랭 시작할 때 바로
/// 알려드려요" 와 그라데이션 "구독하기" 버튼.
class HomeWorldsSubscribeBar extends StatelessWidget {
  const HomeWorldsSubscribeBar({
    super.key,
    required this.player,
    required this.scale,
    this.onSubscribe,
  });

  final HomeLiveSoloPlayer player;
  final double scale;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(10 * scale);
    return Container(
      height: SoloCheerCard.barHeight * scale,
      padding: EdgeInsets.only(left: 15 * scale, right: 12 * scale),
      decoration: const BoxDecoration(
        color: AppColors.narBgTertiary,
        border: Border(top: BorderSide(color: AppColors.narDark500)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.worldsSoloSubscribePrompt(player.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    color: AppColors.narTextTertiary,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  l.worldsSoloSubscribePromptSub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12 * scale,
                    color: AppColors.narText2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
          Material(
            color: Colors.transparent,
            child: Ink(
              height: 44 * scale,
              decoration: BoxDecoration(
                gradient: AppColors.narBg,
                borderRadius: radius,
              ),
              child: InkWell(
                key: HomeSoloRankSection.worldsSubscribeKey(player.name),
                borderRadius: radius,
                onTap: onSubscribe,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                  child: Center(
                    child: Text(
                      l.worldsSoloSubscribe,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 15 * scale,
                        color: AppColors.narText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스와이프 위치 점. 5개까지만 그리고 넘치면 "+N".
class HomeSoloSwipeDots extends StatelessWidget {
  const HomeSoloSwipeDots({
    super.key,
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
class HomeSoloFinishedChip extends StatelessWidget {
  const HomeSoloFinishedChip({
    super.key,
    required this.player,
    required this.scale,
  });

  final HomeFinishedSoloPlayer player;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final duration = player.durationMinutes;
    return Container(
      height: 44 * scale,
      padding: EdgeInsets.only(left: 6 * scale, right: 14 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoloFace(
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
                      fontSize: 14 * scale,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                  if (duration != null) ...[
                    SizedBox(width: 5 * scale),
                    Text(
                      l.homeSoloDuration(duration),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12 * scale,
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
                  fontSize: 11 * scale,
                  // 승자 빨강 / 패자 회색 — 스코어 표시 관례(policy/design.md).
                  color: player.won ? AppColors.scoreWin : AppColors.narDark200,
                ),
              ),
            ],
          ),
          if (player.cheerTotal > 0) ...[
            SizedBox(width: 10 * scale),
            Icon(
              Icons.local_fire_department_rounded,
              size: 13 * scale,
              color: AppColors.narGuideAccent,
            ),
            SizedBox(width: 2 * scale),
            Text(
              formatCheerCount(player.cheerTotal),
              key: HomeSoloRankSection.finishedCheerKey(player.name),
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w700,
                fontSize: 12 * scale,
                color: AppColors.narGuideAccent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 섹션 맨 아래 "구독 N명 전체" / "월즈 선수 전체" 버튼.
class HomeSoloSeeAllButton extends StatelessWidget {
  const HomeSoloSeeAllButton({
    super.key,
    required this.label,
    required this.scale,
    this.onTap,
  });

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
                fontSize: 14 * scale,
                color: AppColors.narText2,
              ),
            ),
            SizedBox(width: 3 * scale),
            Icon(
              Icons.chevron_right,
              size: 15 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}
