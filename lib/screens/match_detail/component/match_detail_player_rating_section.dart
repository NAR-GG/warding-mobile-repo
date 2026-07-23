import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../components/nar_banner.dart';
import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';
import 'match_detail_team_rating_section.dart';

/// 경기 상세 — 선수 평점 탭 콘텐츠.
///
/// 위에서부터:
/// 1. 세트 종료 안내 배너(별 아이콘 + 문구, narBg 20% 그라데이션)
/// 2. 패딩 16 안의 '전체 선수 평점' 요약(팀별 평균 평점·별점·참여 인원)
/// 3. 팀별 선수 평점 리스트([MatchDetailTeamRatingSection], 두 팀 모두 노출)
class MatchDetailPlayerRatingSection extends StatelessWidget {
  const MatchDetailPlayerRatingSection({
    super.key,
    required this.setLabel,
    required this.blueTeamName,
    required this.redTeamName,
    this.blueRating = 4.5,
    this.redRating = 4.5,
    this.blueRaterCount = 12,
    this.redRaterCount = 12,
    this.bluePlayers = const [],
    this.redPlayers = const [],
    this.onPlayerTap,
    this.showBanner = true,
    this.scale = 1,
  });

  /// 상단 '세트 종료 → 평점 남기기' 배너 노출 여부.
  /// 이미 이 세트에 평점을 남긴 사용자에겐 숨긴다(false).
  final bool showBanner;

  /// 현재 선택된 세트 라벨. 예) '세트 1'. 배너 문구의 '1세트', 요약 제목의 'SET 1' 에 쓴다.
  final String setLabel;

  /// 팀별 요약에 노출할 두 팀 이름.
  final String blueTeamName;
  final String redTeamName;

  /// 팀별 평균 평점(0~5)과 평점에 참여한 인원 수.
  final double blueRating;
  final double redRating;
  final int blueRaterCount;
  final int redRaterCount;

  /// 팀별 선수 평점 행 데이터(탑→정글→미드→원딜→서폿 순).
  final List<PlayerRating> bluePlayers;
  final List<PlayerRating> redPlayers;

  /// 선수 행을 탭하면 선수·소속 팀명·진영과 함께 호출된다.
  final void Function(PlayerRating player, String teamName, BadgeSide side)?
  onPlayerTap;

  final double scale;

  /// '세트 1' → '1' 처럼 라벨에서 숫자만 뽑는다. 못 찾으면 빈 문자열.
  String get _setNumber {
    final match = RegExp(r'\d+').firstMatch(setLabel);
    return match?.group(0) ?? '';
  }

  /// 배너 문구용 표기. 이미 로케일에 맞춰진 setLabel 을 그대로 쓴다.
  String get _setText => setLabel;

  /// 요약 제목용 'SET 1' 표기.
  String get _setTitle => _setNumber.isNotEmpty ? 'SET $_setNumber' : setLabel;

  @override
  Widget build(BuildContext context) {
    // 배너는 상단에 고정(pinned)하고, 그 아래로 요약·팀별 리스트가 스크롤된다.
    // 이미 이 세트에 평점을 남긴 사용자에겐 배너를 숨긴다.
    return SliverMainAxisGroup(
      slivers: [
        if (showBanner)
          SliverPersistentHeader(
            pinned: true,
            delegate: _BannerStickyDelegate(
              bannerHeight: 44 * scale,
              banner: ColoredBox(
                color: AppColors.narBgContent,
                child: _RatingBanner(setText: _setText, scale: scale),
              ),
            ),
          ),
        // 요약 + 팀 리스트 — 배너 아래로 스크롤.
        SliverToBoxAdapter(
          child: ColoredBox(
            color: AppColors.narBgContent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 전체 선수 평점 요약 + 하단 narLine 구분선.
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.narLine, width: 1),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16 * scale),
                    child: _OverallRating(
                      title: AppLocalizations.of(context)!.allPlayerRatingForSet(_setTitle),
                      blueTeamName: blueTeamName,
                      redTeamName: redTeamName,
                      blueRating: blueRating,
                      redRating: redRating,
                      blueRaterCount: blueRaterCount,
                      redRaterCount: redRaterCount,
                      scale: scale,
                    ),
                  ),
                ),
                MatchDetailTeamRatingSection(
                  teamName: blueTeamName,
                  side: BadgeSide.blue,
                  players: bluePlayers,
                  onPlayerTap:
                      onPlayerTap == null
                          ? null
                          : (player) => onPlayerTap!(
                            player,
                            blueTeamName,
                            BadgeSide.blue,
                          ),
                  scale: scale,
                ),
                MatchDetailTeamRatingSection(
                  teamName: redTeamName,
                  side: BadgeSide.red,
                  players: redPlayers,
                  onPlayerTap:
                      onPlayerTap == null
                          ? null
                          : (player) => onPlayerTap!(
                            player,
                            redTeamName,
                            BadgeSide.red,
                          ),
                  scale: scale,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 세트 종료 안내 배너 pinned 헤더 델리게이트.
///
/// minExtent = maxExtent = 배너 높이라 스크롤해도 상단에 고정된다.
class _BannerStickyDelegate extends SliverPersistentHeaderDelegate {
  _BannerStickyDelegate({required this.bannerHeight, required this.banner});

  final double bannerHeight;
  final Widget banner;

  @override
  double get minExtent => bannerHeight;

  @override
  double get maxExtent => bannerHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: banner);
  }

  @override
  bool shouldRebuild(_BannerStickyDelegate old) =>
      old.bannerHeight != bannerHeight || old.banner != banner;
}

/// 세트 종료 안내 배너. 좌측 24×24 별 아이콘 + 안내 문구.
/// 공용 [NarBanner] 로 렌더링한다.
class _RatingBanner extends StatelessWidget {
  const _RatingBanner({required this.setText, required this.scale});

  final String setText;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return NarBanner(
      scale: scale,
      icon: SvgPicture.asset(
        'assets/icons/stars.svg',
        width: 24 * scale,
        height: 24 * scale,
      ),
      text: AppLocalizations.of(context)!.setEndedLeaveRating(setText),
    );
  }
}

/// '전체 선수 평점' 요약. 제목 아래 두 팀(블루/레드)의 평균 평점·별점·참여 인원을
/// 가운데 narLine2 세로 구분선을 두고 좌우로 배치한다.
class _OverallRating extends StatelessWidget {
  const _OverallRating({
    required this.title,
    required this.blueTeamName,
    required this.redTeamName,
    required this.blueRating,
    required this.redRating,
    required this.blueRaterCount,
    required this.redRaterCount,
    required this.scale,
  });

  final String title;
  final String blueTeamName;
  final String redTeamName;
  final double blueRating;
  final double redRating;
  final int blueRaterCount;
  final int redRaterCount;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 16 * scale,
            height: 19 / 16,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 16 * scale),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TeamRatingColumn(
                  side: BadgeSide.blue,
                  teamName: blueTeamName,
                  rating: blueRating,
                  raterCount: blueRaterCount,
                  scale: scale,
                ),
              ),
              // 가운데 세로 구분선.
              Container(width: 1 * scale, color: AppColors.narLine2),
              Expanded(
                child: _TeamRatingColumn(
                  side: BadgeSide.red,
                  teamName: redTeamName,
                  rating: redRating,
                  raterCount: redRaterCount,
                  scale: scale,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 한 팀의 평점 컬럼. 진영 뱃지 + 팀명 / 평균 평점 숫자 + 별점 / '총 N명 참여'.
class _TeamRatingColumn extends StatelessWidget {
  const _TeamRatingColumn({
    required this.side,
    required this.teamName,
    required this.rating,
    required this.raterCount,
    required this.scale,
  });

  final BadgeSide side;
  final String teamName;
  final double rating;
  final int raterCount;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NarBadgeSide(side: side, scale: scale),
        SizedBox(height: 5 * scale),
        Text(
          teamName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 16 * scale,
            height: 19 / 16,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 16 * scale),
        Text(
          rating.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            fontSize: 28 * scale,
            height: 1.45,
            color: AppColors.narText,
          ),
        ),
        NarStarRating(rating: rating, scale: scale),
        Builder(
          builder: (context) {
            final l = AppLocalizations.of(context)!;
            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l.totalPrefix),
                  TextSpan(text: '$raterCount'),
                  TextSpan(text: l.participantsSuffix),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 12 * scale,
                height: 1.4,
                color: AppColors.narText2,
              ),
            );
          },
        ),
      ],
    );
  }
}
