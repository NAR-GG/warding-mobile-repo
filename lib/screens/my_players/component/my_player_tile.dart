import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/rating_mapping.dart';
import '../../../viewmodel/my_players/my_players_viewmodel.dart';

/// 내 선수 목록 한 줄 — 얼굴(+팀 배지) · 이름 · 팀·포지션 · 오늘 상태.
///
/// 보기 전용이라 누를 곳이 없다(구독 관리는 마이페이지). 한 묶음의 줄들이
/// 한 장의 카드처럼 보이도록 [isFirst]/[isLast] 로 위아래 모서리만 둥글린다 —
/// 묶음 전체를 한 위젯으로 감싸면 100명을 지연 생성할 수 없어서다.
class MyPlayerTile extends StatelessWidget {
  const MyPlayerTile({
    super.key,
    required this.entry,
    required this.scale,
    required this.isFirst,
    required this.isLast,
  });

  final MyPlayerEntry entry;
  final double scale;
  final bool isFirst;
  final bool isLast;

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
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 13 * scale,
              vertical: 11 * scale,
            ),
            child: Row(
              children: [
                _Avatar(
                  name: player.playerName,
                  imageUrl: player.playerImageUrl,
                  teamCode: player.teamCode,
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
                                fontSize: 14 * scale,
                                color: AppColors.narTextTertiary,
                              ),
                            ),
                            if (sub.isNotEmpty)
                              TextSpan(
                                text: '  $sub',
                                style: TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 11 * scale,
                                  color: AppColors.narText2,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2 * scale),
                      _StatusLine(entry: entry, scale: scale),
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

/// 오늘 상태 한 줄. 솔랭 중은 솔랭 톤 점 + "챔피언 · 경과", 오늘 경기함은
/// "N분 전 · 승/패", 소식 없음은 흐린 "오늘 경기 없음".
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.entry, required this.scale});

  final MyPlayerEntry entry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    TextStyle style(Color color) =>
        TextStyle(fontFamily: 'Open Sans', fontSize: 11 * scale, color: color);

    switch (entry.status) {
      case MyPlayerStatus.liveSolo:
        final live = entry.live!;
        final text = [
          if (live.champion.isNotEmpty) live.champion,
          _clock(live.elapsedSeconds),
        ].join(' · ');
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
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style(AppColors.narSoloText),
              ),
            ),
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
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.imageUrl,
    required this.teamCode,
    required this.scale,
  });

  final String name;
  final String imageUrl;
  final String teamCode;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 40 * scale;
    final url = resolveImageUrl(imageUrl);
    final initials = Center(
      child: Text(
        name.length <= 2
            ? name.toUpperCase()
            : name.substring(0, 2).toUpperCase(),
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: 13 * scale,
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
              child: TeamCodeBadge(teamCode: teamCode, size: 18 * scale),
            ),
        ],
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
