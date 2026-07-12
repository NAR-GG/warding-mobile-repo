import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/lane_asset.dart';

/// 선수 평점 상세 — '플레이한 챔프' 카드.
///
/// 흰 카드(라운드 10) + 하단 inset 그림자 근사 그라데이션.
/// 배경에 선수가 플레이한 챔피언 스플래시 아트를 채우고(있으면), 그 위에
/// 어두운 그라데이션을 덧대 콘텐츠 가독성을 확보한다. 콘텐츠는 하단 정렬.
/// - 좌측: 선수 이미지(62×62) + 'T1 Faker' / 포지션mini 아이콘 + 포지션명
/// - 우측: 'KDA' / '4/1/7'
class PlayedChampCard extends StatelessWidget {
  const PlayedChampCard({
    super.key,
    required this.teamName,
    required this.playerName,
    required this.position,
    required this.kda,
    this.championName = '',
    this.playerImageUrl,
    this.scale = 1,
  });

  /// 'T1 Faker' 표기에 쓰는 팀명/선수명.
  final String teamName;
  final String playerName;

  /// 배경에 채울 챔피언 영문 키(예: 'Vayne'). 비어 있으면 배경 없음.
  final String championName;

  /// 선수 사진 URL(상대경로면 호스트 부착). 없으면 빈 자리.
  final String? playerImageUrl;

  /// 포지션명(예: '미드').
  final String position;

  /// KDA 표기(예: '4/1/7').
  final String kda;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Container(
        height: 101 * scale,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.narPlayedChampBg,
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 배경: 챔피언 스플래시 아트(있으면). 캐릭터가 잘 보이게 상단 쪽 정렬.
            if (championSplashUrl(championName) != null)
              CachedNetworkImage(
                imageUrl: championSplashUrl(championName)!,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                memCacheWidth: 480,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            // 배경 위 어두운 세로 그라데이션(콘텐츠 가독성 + 하단 inset 그림자 근사).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.narPlayedChampOverlay,
              ),
            ),
            // 콘텐츠 — 카드 하단 정렬.
            Padding(
              padding: EdgeInsets.only(
                left: 8 * scale,
                right: 7 * scale,
                bottom: 10 * scale,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 62 * scale,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 좌측: 선수 이미지(비움) + 선수명/포지션.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 선수 사진 62×62. 없거나 로드 실패 시 빈 자리 유지.
                          SizedBox(
                            width: 62 * scale,
                            height: 62 * scale,
                            child:
                                (playerImageUrl != null &&
                                        playerImageUrl!.isNotEmpty)
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        8 * scale,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: resolveImageUrl(
                                          playerImageUrl,
                                        )!,
                                        fit: BoxFit.cover,
                                        fadeInDuration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        errorWidget:
                                            (_, _, _) =>
                                                const SizedBox.shrink(),
                                      ),
                                    )
                                    : null,
                          ),
                          SizedBox(width: 10 * scale),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$teamName $playerName',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18 * scale,
                                  height: 1.45,
                                  color: AppColors.narText,
                                ),
                              ),
                              // 포지션 라인: mini 아이콘 + 포지션명.
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 포지션 mini 아이콘 — 라인별 svg. 매칭 라인이 없으면 회색 placeholder.
                                  _buildLaneIcon(position, scale),
                                  SizedBox(width: 8 * scale),
                                  Text(
                                    position,
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16 * scale,
                                      height: 1.45,
                                      color: AppColors.narText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      // 우측: KDA.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'KDA',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              fontSize: 14 * scale,
                              height: 1.45,
                              color: AppColors.narText,
                            ),
                          ),
                          Text(
                            kda,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              fontSize: 16 * scale,
                              height: 1.45,
                              color: AppColors.narText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 포지션명을 라인 svg 아이콘으로 렌더링. 매칭 라인이 없으면 회색 placeholder.
  Widget _buildLaneIcon(String position, double scale) {
    final asset = laneAssetPath(position);
    final size = 14 * scale;
    if (asset == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.narDark200,
          borderRadius: BorderRadius.circular(3 * scale),
        ),
      );
    }
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
