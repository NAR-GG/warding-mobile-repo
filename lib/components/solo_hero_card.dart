import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../model/home_models.dart';
import '../styles/app_colors.dart';
import '../util/app_image.dart';
import 'nar_live_dot.dart';
import 'team_code_badge.dart';

/// 경과 시간 "m:ss". 1시간이 넘으면 "h:mm:ss".
String _clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// 솔랭 진행 중인 선수 한 명의 큰 카드. 숫자는 경과 시간 하나뿐이다.
///
/// 홈 솔랭 섹션(구독 선수 카드·월즈 선수 카드)과 선수 페이지가 같이 쓴다.
class SoloHeroCard extends StatelessWidget {
  const SoloHeroCard({
    super.key,
    required this.player,
    required this.secondsOf,
    required this.tick,
    required this.scale,
    this.embedded = false,
    this.role,
    this.showRegion = false,
  });

  final HomeLiveSoloPlayer player;

  /// 선수 페이지 — 팀 옆에 포지션("T1 · MID")을 붙인다. 홈은 null.
  final String? role;

  /// 선수 페이지 — "솔로 랭크 · NA" 처럼 해외 계정 지역을 배지에 붙인다.
  final bool showRegion;

  /// 응원 영역과 한 장으로 묶일 때 true — 모서리·테두리는 바깥 `SoloCheerCard` 가
  /// 그린다.
  final bool embedded;

  /// 지금 보여줄 경과 초를 계산한다(기기 시계 기준).
  /// [tick] 이 바뀔 때마다 다시 불러 초를 갱신한다.
  /// [HomeLiveSoloPlayer.startedAt] 참고.
  final int Function() secondsOf;

  /// 1초마다 값이 바뀌는 카운터. 이 카드에서 경과 시간 텍스트만 구독한다 —
  /// 카드(스플래시·선수 사진)까지 매초 다시 그리지 않기 위해서다.
  final ValueListenable<int> tick;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 가로형 Data Dragon 스플래시(1215×717)를 먼저 쓴다. 백엔드의
    // `championImageUrl` 은 400×600 세로형으로 이미 잘려 와서, 가로로 긴 이
    // 카드에 `cover` 로 깔면 한가운데만 크게 확대돼 보였다. 이름으로 URL 을
    // 만들 수 없을 때(`championSplashUrl` 이 null)만 서버 이미지로 폴백한다.
    // `resolveImageUrl` 은 빈 문자열을 빈 문자열로 돌려주므로 ?? 로는 폴백이
    // 걸리지 않는다 — 비었는지 직접 본다.
    final fromServer = resolveImageUrl(player.championImageUrl);
    final splashUrl =
        championSplashUrl(player.champion) ??
        ((fromServer != null && fromServer.isNotEmpty) ? fromServer : null);
    final photoUrl = resolveImageUrl(player.playerImageUrl);
    final radius = BorderRadius.circular(14 * scale);

    // 테두리를 배경 데코레이션이 아니라 foregroundDecoration으로 그린다 —
    // 배경 데코레이션은 Stack(챔피언 스플래시·선수 사진) 뒤에 깔리고 그 위에
    // Stack 이 덮어 그려지는 순서라, 사진이 모서리까지 닿으면 안쪽 클립은
    // 맞아도 테두리 선 자체가 사진에 가려 그 구간만 끊겨 보였다. 테두리를
    // 맨 위(foreground)에 그리면 어떤 내용이 깔려도 항상 온전히 보인다.
    return Container(
      foregroundDecoration: embedded
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.narLine),
            ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: embedded ? null : radius,
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
                right: -10 * scale,
                bottom: -10 * scale,
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 216 * scale,
                  height: 258 * scale,
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
                          fontSize: 12 * scale,
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
                138 * scale,
                13 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TeamCodeBadge(
                        teamCode: player.teamCode,
                        size: 20 * scale,
                        fallbackImageUrl: player.teamImageUrl,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        [player.teamCode, ?role].join(' · '),
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 13 * scale,
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
                      // 매초 바뀌는 건 이 텍스트뿐이다 — 섹션 전체가 아니라
                      // 여기만 다시 그린다(홈 솔랭 섹션의 `_tick`).
                      ValueListenableBuilder<int>(
                        valueListenable: tick,
                        builder: (context, _, _) => Text(
                          _clock(secondsOf()),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 30 * scale,
                            height: 1,
                            color: AppColors.narText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
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
                              fontSize: 13 * scale,
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
                          [
                            l.homeSoloQueueBadge,
                            if (showRegion) ?player.overseasRegion,
                          ].join(' · '),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 13 * scale,
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
