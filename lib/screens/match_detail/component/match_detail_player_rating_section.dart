import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../components/nar_chip_multi_select.dart';
import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';
import 'match_detail_team_rating_section.dart';

/// 경기 상세 — 선수 평점 탭 콘텐츠.
///
/// 위에서부터:
/// 1. 세트 종료 안내 배너(별 아이콘 + 문구, narBg 20% 그라데이션)
/// 2. '전체 / 팀' 칩 필터([NarChipMultiSelect]) + 하단 구분선
/// 3. 패딩 16 안의 '전체 선수 평점' 요약(팀별 평균 평점·별점·참여 인원)
/// 4. 팀별 선수 평점 리스트([MatchDetailTeamRatingSection]). 칩 필터로 노출 팀을 거른다.
class MatchDetailPlayerRatingSection extends StatefulWidget {
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
    this.scale = 1,
  });

  /// 현재 선택된 세트 라벨. 예) '세트 1'. 배너 문구의 '1세트', 요약 제목의 'SET 1' 에 쓴다.
  final String setLabel;

  /// 칩 필터·팀별 요약에 노출할 두 팀 이름.
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

  @override
  State<MatchDetailPlayerRatingSection> createState() =>
      _MatchDetailPlayerRatingSectionState();
}

class _MatchDetailPlayerRatingSectionState
    extends State<MatchDetailPlayerRatingSection> {
  static const String _allLabel = '전체';

  /// 선택된 팀 필터. '전체'면 비워 두고, 팀이 선택되면 해당 팀 이름들을 담는다.
  Set<String> _selectedTeams = {};

  /// '세트 1' → '1' 처럼 라벨에서 숫자만 뽑는다. 못 찾으면 빈 문자열.
  String get _setNumber {
    final match = RegExp(r'\d+').firstMatch(widget.setLabel);
    return match?.group(0) ?? '';
  }

  /// 배너 문구용 '1세트' 표기. 숫자를 못 찾으면 원본 라벨을 그대로 쓴다.
  String get _setText =>
      _setNumber.isNotEmpty ? '$_setNumber세트' : widget.setLabel;

  /// 요약 제목용 'SET 1' 표기.
  String get _setTitle =>
      _setNumber.isNotEmpty ? 'SET $_setNumber' : widget.setLabel;

  List<String> get _options => [
    _allLabel,
    widget.blueTeamName,
    widget.redTeamName,
  ];

  /// 칩 선택값은 '전체'가 다른 팀과 공존하지 않도록 정규화한다.
  /// - '전체'를 새로 누르면 나머지 해제
  /// - 팀을 누르면 '전체' 해제
  /// - 두 팀 모두 선택되거나 아무것도 안 남으면 '전체'로 복귀
  void _handleChanged(Set<String> next) {
    final allTeams = {widget.blueTeamName, widget.redTeamName};
    final justAddedAll =
        next.contains(_allLabel) && !_selectedTeams.contains(_allLabel);

    Set<String> normalized;
    if (justAddedAll || next.isEmpty) {
      normalized = {};
    } else {
      normalized = next.where(allTeams.contains).toSet();
      if (normalized.length >= allTeams.length) normalized = {};
    }
    setState(() => _selectedTeams = normalized);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    // '전체' 칩은 팀이 하나도 선택되지 않았을 때 활성으로 보이도록 매핑.
    final chipSelection = _selectedTeams.isEmpty ? {_allLabel} : _selectedTeams;

    // 배너+멀티셀렉터를 하나의 축소(shrink) 헤더로. 스크롤하면 배너는 상단에 걸린 채
    // 멀티셀렉터가 위로 올라와 배너를 덮으며 상단에 고정된다(maxExtent→minExtent).
    // 전체를 SliverMainAxisGroup 으로 묶어, 요약·리스트가 다 지나가면 멀티셀렉터도 풀린다.
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _BannerSelectorStickyDelegate(
            bannerHeight: 44 * scale,
            selectorHeight: 54 * scale,
            banner: ColoredBox(
              color: AppColors.narBgContent,
              child: _RatingBanner(setText: _setText, scale: scale),
            ),
            selector: ColoredBox(
              color: AppColors.narBgContent,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.narLine, width: 1),
                  ),
                ),
                child: NarChipMultiSelect(
                  options: _options,
                  selectedValues: chipSelection,
                  onChanged: _handleChanged,
                  scale: scale,
                ),
              ),
            ),
          ),
        ),
        // 요약 + 팀 리스트 — 멀티셀렉터 아래로 스크롤.
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
                      title: '$_setTitle 전체 선수 평점',
                      blueTeamName: widget.blueTeamName,
                      redTeamName: widget.redTeamName,
                      blueRating: widget.blueRating,
                      redRating: widget.redRating,
                      blueRaterCount: widget.blueRaterCount,
                      redRaterCount: widget.redRaterCount,
                      scale: scale,
                    ),
                  ),
                ),
                // 칩 필터로 선택된 팀만 노출('전체'면 두 팀 모두).
                if (_showTeam(widget.blueTeamName))
                  MatchDetailTeamRatingSection(
                    teamName: widget.blueTeamName,
                    side: BadgeSide.blue,
                    players: widget.bluePlayers,
                    onPlayerTap:
                        widget.onPlayerTap == null
                            ? null
                            : (player) => widget.onPlayerTap!(
                              player,
                              widget.blueTeamName,
                              BadgeSide.blue,
                            ),
                    scale: scale,
                  ),
                if (_showTeam(widget.redTeamName))
                  MatchDetailTeamRatingSection(
                    teamName: widget.redTeamName,
                    side: BadgeSide.red,
                    players: widget.redPlayers,
                    onPlayerTap:
                        widget.onPlayerTap == null
                            ? null
                            : (player) => widget.onPlayerTap!(
                              player,
                              widget.redTeamName,
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

  /// 칩 필터 기준 해당 팀 리스트를 보일지. '전체'(선택 없음)면 모두 보인다.
  bool _showTeam(String teamName) =>
      _selectedTeams.isEmpty || _selectedTeams.contains(teamName);
}

/// 배너+멀티셀렉터 축소(shrink) pinned 헤더 델리게이트.
///
/// maxExtent = 배너+셀렉터 높이, minExtent = 셀렉터 높이.
/// 배너는 헤더 상단에 고정(걸림)되고, 셀렉터는 헤더 하단(bottom: 0)에 붙어 있어
/// 스크롤로 헤더가 줄면 셀렉터가 위로 올라와 배너를 덮고 상단에 고정된다.
/// (셀렉터를 Stack 마지막에 둬 배너 위로 그려지게 한다.)
class _BannerSelectorStickyDelegate extends SliverPersistentHeaderDelegate {
  _BannerSelectorStickyDelegate({
    required this.bannerHeight,
    required this.selectorHeight,
    required this.banner,
    required this.selector,
  });

  final double bannerHeight;
  final double selectorHeight;
  final Widget banner;
  final Widget selector;

  @override
  double get minExtent => selectorHeight;

  @override
  double get maxExtent => bannerHeight + selectorHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // 배너: 상단 고정. 셀렉터가 올라오며 덮는다.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: banner,
          ),
          // 셀렉터: 헤더 하단에 붙음 → 헤더가 줄면 위로 올라와 상단 고정.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: selectorHeight,
            child: selector,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_BannerSelectorStickyDelegate old) =>
      old.bannerHeight != bannerHeight ||
      old.selectorHeight != selectorHeight ||
      old.banner != banner ||
      old.selector != selector;
}

/// 세트 종료 안내 배너. 좌측 24×24 별 아이콘 + 안내 문구.
/// padding 10/16, gap 8, narBg 20% 불투명도 그라데이션 배경.
class _RatingBanner extends StatelessWidget {
  const _RatingBanner({required this.setText, required this.scale});

  final String setText;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 10 * scale,
        horizontal: 16 * scale,
      ),
      decoration: const BoxDecoration(gradient: AppColors.narRatingBannerBg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/stars.svg',
            width: 24 * scale,
            height: 24 * scale,
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              '$setText 경기가 끝났어요! 각 선수 평점을 남겨보세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 1.55,
                color: AppColors.narText,
              ),
            ),
          ),
        ],
      ),
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
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '총 '),
              TextSpan(text: '$raterCount'),
              const TextSpan(text: '명 참여'),
            ],
          ),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12 * scale,
            height: 1.4,
            color: AppColors.narText2,
          ),
        ),
      ],
    );
  }
}
