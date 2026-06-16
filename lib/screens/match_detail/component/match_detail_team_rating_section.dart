import 'package:flutter/material.dart';

import '../../../components/nar_badge.dart';
import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';

/// 한 선수의 평점 행 데이터.
class PlayerRating {
  const PlayerRating({
    required this.name,
    required this.position,
    required this.rating,
    required this.raterCount,
    this.championImageUrl,
    this.participantId = 0,
    this.playerId = 0,
    this.playerImageUrl,
  });

  /// 선수명(예: 'DuDu').
  final String name;

  /// 포지션 라벨(예: '탑', '정글', '미드', '원딜', '서폿').
  final String position;

  /// 평균 평점(0~5)과 참여 인원.
  final double rating;
  final int raterCount;

  /// 사용 챔피언 이미지 URL. 없으면 빈 박스.
  final String? championImageUrl;

  /// 평점 상세 진입에 필요한 식별자(목업 기본값 0).
  final int participantId;
  final int playerId;
  final String? playerImageUrl;
}

/// 경기 상세 — 선수 평점 탭의 팀별 선수 평점 리스트.
///
/// 상단에 'DNS(BLUE)' 형식의 팀 헤딩(진영 컬러)을 두고, 그 아래 선수 행을
/// 지브라 배경(짝수 행 [AppColors.narBgSecondary])으로 늘어놓는다.
/// 각 행: 좌측 챔피언 미니 + 선수명·포지션, 우측 별점 + '4.5 (23명)'.
class MatchDetailTeamRatingSection extends StatelessWidget {
  const MatchDetailTeamRatingSection({
    super.key,
    required this.teamName,
    required this.side,
    required this.players,
    this.onPlayerTap,
    this.scale = 1,
  });

  final String teamName;
  final BadgeSide side;
  final List<PlayerRating> players;

  /// 선수 행을 탭하면 해당 선수로 호출된다. 선수 평점 상세로 이동하는 데 쓴다.
  final ValueChanged<PlayerRating>? onPlayerTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isBlue = side == BadgeSide.blue;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 'DNS(BLUE)' 헤딩 — 진영 텍스트 컬러(indigo/8 · red/8).
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: Text(
              '$teamName(${isBlue ? 'BLUE' : 'RED'})',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 16 * scale,
                height: 19 / 16,
                color: isBlue ? AppColors.sideBlueText : AppColors.sideRedText,
              ),
            ),
          ),
          SizedBox(height: 16 * scale),
          for (var i = 0; i < players.length; i++)
            _PlayerRatingRow(
              player: players[i],
              // 짝수 행만 narBgSecondary 배경(지브라).
              filled: i.isEven,
              onTap:
                  onPlayerTap == null ? null : () => onPlayerTap!(players[i]),
              scale: scale,
            ),
        ],
      ),
    );
  }
}

/// 선수 평점 한 행. 높이 60, 좌우 10 inset, padding 10, 좌우 spaceBetween.
class _PlayerRatingRow extends StatelessWidget {
  const _PlayerRatingRow({
    required this.player,
    required this.filled,
    this.onTap,
    required this.scale,
  });

  final PlayerRating player;
  final bool filled;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10 * scale),
        padding: EdgeInsets.all(10 * scale),
        color: filled ? AppColors.narBgSecondary : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 좌측: 챔피언 미니 + 선수명/포지션.
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChampionMini(
                    imageUrl: player.championImageUrl,
                    scale: scale,
                  ),
                  SizedBox(width: 6 * scale),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * scale,
                            height: 1.45,
                            color: AppColors.narText,
                          ),
                        ),
                        Text(
                          player.position,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * scale,
                            height: 1.45,
                            color: AppColors.narText2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            // 우측: 별점 + '4.5 (23명)'.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                NarStarRating(rating: player.rating, scale: scale),
                SizedBox(height: 2 * scale),
                Text(
                  '${player.rating.toStringAsFixed(1)} (${player.raterCount}명)',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    height: 1.45,
                    color: AppColors.narText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 챔피언 미니 (38×38 라운드 8). 이미지 없으면 narDark500 빈 박스.
class _ChampionMini extends StatelessWidget {
  const _ChampionMini({required this.imageUrl, required this.scale});

  final String? imageUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 38 * scale;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.narDark500,
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          hasImage
              ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
              : null,
    );
  }
}
