import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../util/live_elapsed.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/rating_mapping.dart';
import '../../../viewmodel/my_players/my_players_viewmodel.dart';

/// 내 선수 목록 한 줄 — 얼굴(+팀 배지) · 이름 · 팀·포지션 · 오늘 상태.
///
/// 내 선수 화면에서는 보기 전용이다(구독 관리는 마이페이지). 월즈 솔랭 화면은
/// [onTap](선수 시트)과 [trailing](구독 벨)을 넘긴다. 한 묶음의 줄들이
/// 한 장의 카드처럼 보이도록 [isFirst]/[isLast] 로 위아래 모서리만 둥글린다 —
/// 묶음 전체를 한 위젯으로 감싸면 100명을 지연 생성할 수 없어서다.
class MyPlayerTile extends StatelessWidget {
  const MyPlayerTile({
    super.key,
    required this.entry,
    required this.scale,
    required this.isFirst,
    required this.isLast,
    this.onTap,
    this.trailing,
    this.tick,
  });

  final MyPlayerEntry entry;
  final double scale;
  final bool isFirst;
  final bool isLast;

  /// 초당 틱. 진행 중인 판의 경과 시간을 매초 올리려면 넘긴다.
  final ValueListenable<int>? tick;
  final VoidCallback? onTap;

  /// 줄 오른쪽 끝에 붙는 위젯(월즈: 구독 벨). 없으면 아무것도 두지 않는다.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    final radius = Radius.circular(12 * scale);
    final role = positionFromRole(player.role);
    final sub = [
      if (player.teamCode.isNotEmpty) player.teamCode,
      if (role.isNotEmpty) role,
    ].join(' · ');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? radius : Radius.zero,
          bottom: isLast ? radius : Radius.zero,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFirst) Container(height: 1, color: AppColors.narLine),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                13 * scale,
                11 * scale,
                (trailing == null ? 13 : 10) * scale,
                11 * scale,
              ),
              child: Row(
                children: [
                  MyPlayerAvatar(
                    name: player.playerName,
                    imageUrl: player.playerImageUrl,
                    teamCode: player.teamCode,
                    teamImageUrl: player.teamImageUrl,
                    scale: scale,
                  ),
                  SizedBox(width: 11 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: player.playerName,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16 * scale,
                                  color: AppColors.narTextTertiary,
                                ),
                              ),
                              if (sub.isNotEmpty)
                                TextSpan(
                                  text: '  $sub',
                                  style: TextStyle(
                                    fontFamily: 'Open Sans',
                                    fontSize: 13 * scale,
                                    color: AppColors.narText2,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2 * scale),
                        MyPlayerStatusLine(
                          entry: entry,
                          scale: scale,
                          tick: tick,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: 8 * scale),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 오늘 상태 한 줄. 솔랭 중은 솔랭 톤 점 + "챔피언 · 경과", 오늘 경기함은
/// "N분 전 · 승/패", 소식 없음은 흐린 "오늘 솔랭 없음".
class MyPlayerStatusLine extends StatelessWidget {
  const MyPlayerStatusLine({
    super.key,
    required this.entry,
    required this.scale,
    this.tick,
  });

  final MyPlayerEntry entry;
  final double scale;

  /// 초당 올라가는 틱. 주면 진행 중인 판의 경과 시간이 매초 갱신된다.
  /// 서버의 `elapsedSeconds` 는 조회 시점 스냅샷이라 그대로 두면 멈춰 보인다.
  final ValueListenable<int>? tick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    TextStyle style(Color color) =>
        TextStyle(fontFamily: 'Open Sans', fontSize: 13 * scale, color: color);

    switch (entry.status) {
      case MyPlayerStatus.liveSolo:
        final live = entry.live!;
        String statusText() => [
          if (live.champion.isNotEmpty) live.champion,
          formatElapsed(
            liveElapsedSeconds(
              snapshotSeconds: live.elapsedSeconds,
              startedAt: live.startedAt,
            ),
          ),
        ].join(' · ');
        final listenable = tick;
        return Row(
          children: [
            Container(
              width: 5 * scale,
              height: 5 * scale,
              decoration: const BoxDecoration(
                color: AppColors.narSoloDot,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 4 * scale),
            Flexible(
              // 매초 바뀌는 건 이 텍스트 하나라, 타일 전체를 다시 그리지 않고
              // 여기만 틱을 구독한다(홈 솔랭 카드와 같은 방식).
              child: listenable == null
                  ? Text(
                      statusText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(AppColors.narSoloText),
                    )
                  : ValueListenableBuilder<int>(
                      valueListenable: listenable,
                      builder: (_, _, _) => Text(
                        statusText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style(AppColors.narSoloText),
                      ),
                    ),
            ),
            if (live.overseasRegion != null) ...[
              SizedBox(width: 6 * scale),
              RegionChip(region: live.overseasRegion!, scale: scale),
            ],
          ],
        );
      case MyPlayerStatus.playedToday:
        final done = entry.finished!;
        final ago = done.minutesAgo < 60
            ? l.homeMinutesAgo(done.minutesAgo)
            : l.homeHoursAgo(done.minutesAgo ~/ 60);
        return Text(
          '$ago · ${done.won ? l.homeSoloWin : l.homeSoloLoss}',
          maxLines: 1,
          style: style(done.won ? AppColors.scoreWin : AppColors.narText2),
        );
      case MyPlayerStatus.quiet:
        return Text(
          l.myPlayersNoGameToday,
          maxLines: 1,
          style: style(AppColors.narDark200),
        );
    }
  }
}

/// 얼굴 사진(없으면 이니셜 원) + 오른쪽 아래 팀 코드 배지.
class MyPlayerAvatar extends StatelessWidget {
  const MyPlayerAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.teamCode,
    required this.scale,
    this.teamImageUrl,
    this.diameter = 40,
  });

  final String name;
  final String imageUrl;
  final String teamCode;

  /// 응답이 준 팀 로고. 로고 사전(LCK 팀만)에 없는 해외 팀일 때만 쓴다.
  final String? teamImageUrl;
  final double scale;

  /// 얼굴 지름(스케일 전). 목록은 40, 월즈 선수 시트는 56.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final size = diameter * scale;
    final url = resolveImageUrl(imageUrl);
    final initials = Center(
      child: Text(
        name.length <= 2
            ? name.toUpperCase()
            : name.substring(0, 2).toUpperCase(),
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: 14 * scale,
          color: AppColors.narText3,
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: ColoredBox(
                color: AppColors.narLine2,
                child: url == null || url.isEmpty
                    ? initials
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.75),
                        memCacheWidth:
                            (size * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        fadeInDuration: const Duration(milliseconds: 150),
                        errorWidget: (_, _, _) => initials,
                      ),
              ),
            ),
          ),
          if (teamCode.isNotEmpty)
            Positioned(
              right: -3 * scale,
              bottom: -3 * scale,
              child: TeamCodeBadge(
                teamCode: teamCode,
                size: (diameter >= 56 ? 22 : 18) * scale,
                fallbackImageUrl: teamImageUrl,
              ),
            ),
        ],
      ),
    );
  }
}

/// 해외 계정으로 하는 판 표시 — "NA" 같은 작은 테두리 칩.
class RegionChip extends StatelessWidget {
  const RegionChip({super.key, required this.region, required this.scale});

  final String region;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.narLine2),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      child: Text(
        region,
        style: TextStyle(
          fontFamily: 'Open Sans',
          fontWeight: FontWeight.w600,
          fontSize: 10 * scale,
          height: 1.4,
          color: AppColors.narText2,
        ),
      ),
    );
  }
}
