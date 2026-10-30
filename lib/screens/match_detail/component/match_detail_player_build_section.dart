import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import '../../../util/gold_format.dart';
import '../../../util/lane_asset.dart';
import 'match_detail_build_items.dart';
import 'match_detail_build_runes.dart';
import 'match_detail_build_stats.dart';

/// 경기 상세 — 챔피언픽 탭 맨 아래의 "Player Builds" 섹션.
///
/// 같은 API 응답(`GET /api/mobile/live/games/{gameId}/champions`)의 픽 데이터를
/// 재사용한다. KDA·CS·골드·킬관여·딜분배는 [ChampionPick]에 이미 있는 값 그대로고,
/// 여기서 처음으로 아이템 전체(코어 6+퀘스트+장신구)·룬 전체(주/부 트리+파편)를
/// 보여준다.
///
/// 선택 상태([selectedBlueSide]/[selectedIndex])는 이 위젯이 아니라 호출부
/// ([MatchDetailScreen])가 들고 있다 — Champion Pick 섹션에서 챔피언을 탭하거나
/// Player Stats 섹션에서 선수 행을 탭하면 호출부가 선택을 바꾸고 이 섹션으로
/// 스크롤을 당긴다. 이 섹션 안의 포지션 아이콘을 직접 탭해도 [onSelect]로 같은
/// 경로를 탄다.
class MatchDetailPlayerBuildSection extends StatefulWidget {
  const MatchDetailPlayerBuildSection({
    super.key,
    required this.bluePicks,
    required this.redPicks,
    required this.blueTeamCode,
    required this.redTeamCode,
    required this.selectedBlueSide,
    required this.selectedIndex,
    required this.onSelect,
    this.scale = 1,
  });

  final List<ChampionPick> bluePicks;
  final List<ChampionPick> redPicks;
  final String blueTeamCode;
  final String redTeamCode;
  final bool selectedBlueSide;
  final int selectedIndex;
  final void Function(bool blueSide, int index) onSelect;
  final double scale;

  @override
  State<MatchDetailPlayerBuildSection> createState() =>
      _MatchDetailPlayerBuildSectionState();
}

class _MatchDetailPlayerBuildSectionState
    extends State<MatchDetailPlayerBuildSection> {
  late final PageController _pageController;

  /// 페이지마다 카드 높이가 달라서(룬 유무 등) 현재 페이지 카드를 실측해
  /// [PageView]의 높이로 반영한다. 초기값은 첫 프레임 렌더 전 임시값.
  double _height = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageOf(widget));
  }

  @override
  void didUpdateWidget(covariant MatchDetailPlayerBuildSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _pageOf(widget);
    if (page != _pageOf(oldWidget) && _pageController.hasClients) {
      final current = _pageController.page?.round();
      if (current != page) {
        // animateToPage 는 목표 페이지까지 중간 페이지를 거쳐 슬라이드한다
        // — 포지션 아이콘을 탭했을 때(예: 탑→원딜) 엉뚱한 라인이 잠깐
        // 스쳐 지나가 보인다. 아이콘 탭은 즉시 전환이 맞고, 스와이프
        // 자체의 애니메이션은 PageView 가 알아서 처리하니 영향 없다.
        _pageController.jumpToPage(page);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 블루 탑~원딜(0~4) 다음 레드 탑~원딜(5~9), 총 10페이지 중 현재 인덱스.
  static int _pageOf(MatchDetailPlayerBuildSection w) =>
      (w.selectedBlueSide ? 0 : 5) + w.selectedIndex;

  void _onPageChanged(int page) {
    final isBlueSide = page < 5;
    final index = isBlueSide ? page : page - 5;
    if (isBlueSide != widget.selectedBlueSide ||
        index != widget.selectedIndex) {
      widget.onSelect(isBlueSide, index);
    }
  }

  void _onHeightMeasured(double height) {
    if ((height - _height).abs() > 0.5) {
      setState(() => _height = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final pages = <_BuildPage>[
      for (var i = 0; i < widget.bluePicks.length && i < 5; i++)
        _BuildPage(pick: widget.bluePicks[i], teamCode: widget.blueTeamCode),
      for (var i = 0; i < widget.redPicks.length && i < 5; i++)
        _BuildPage(pick: widget.redPicks[i], teamCode: widget.redTeamCode),
    ];
    final currentPage = _pageOf(
      widget,
    ).clamp(0, pages.isEmpty ? 0 : pages.length - 1);

    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.fromLTRB(
        10 * scale,
        16 * scale,
        10 * scale,
        36 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideSelectorRow(
            bluePicks: widget.bluePicks,
            redPicks: widget.redPicks,
            blueTeamCode: widget.blueTeamCode,
            redTeamCode: widget.redTeamCode,
            selectedBlue: widget.selectedBlueSide,
            selectedIndex: widget.selectedIndex,
            scale: scale,
            onSelect: widget.onSelect,
          ),
          SizedBox(height: 16 * scale),
          if (pages.isNotEmpty)
            // 카드 틀(배경·둥근 모서리)과 하단 인디케이터는 여기 고정 —
            // 안쪽 콘텐츠만 PageView 로 스와이프된다. 틀까지 같이
            // 슬라이드되면 인디케이터도 카드를 따라 움직여 보여 어색하다.
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 24 * scale),
              decoration: BoxDecoration(
                color: AppColors.narDark600,
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: _height,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          _MeasuredBuildCard(
                            pick: pages[i].pick,
                            teamCode: pages[i].teamCode,
                            scale: scale,
                            active: i == currentPage,
                            onHeightMeasured: _onHeightMeasured,
                          ),
                      ],
                    ),
                  ),
                  if (pages.length > 1) ...[
                    SizedBox(height: 16 * scale),
                    _BuildPageDots(
                      count: pages.length,
                      current: currentPage,
                      scale: scale,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// [_PlayerBuildCard]를 감싸 렌더 후 실제 높이를 상위에 보고한다. 현재
/// 페이지([active])만 보고한다 — [PageView]는 이웃 페이지도 미리 빌드하므로,
/// 그 높이가 섞여 들어가면 카드 전환마다 높이가 잘못 튀는 것을 막기 위함.
class _MeasuredBuildCard extends StatefulWidget {
  const _MeasuredBuildCard({
    required this.pick,
    required this.teamCode,
    required this.scale,
    required this.active,
    required this.onHeightMeasured,
  });

  final ChampionPick pick;
  final String teamCode;
  final double scale;
  final bool active;
  final void Function(double height) onHeightMeasured;

  @override
  State<_MeasuredBuildCard> createState() => _MeasuredBuildCardState();
}

class _MeasuredBuildCardState extends State<_MeasuredBuildCard> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(covariant _MeasuredBuildCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted || !widget.active) return;
    final height = _key.currentContext?.size?.height;
    if (height != null) widget.onHeightMeasured(height);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: _PlayerBuildCard(
        key: _key,
        pick: widget.pick,
        scale: widget.scale,
      ),
    );
  }
}

class _BuildPage {
  const _BuildPage({required this.pick, required this.teamCode});

  final ChampionPick pick;
  final String teamCode;
}

/// 점 페이지네이션 — 현재 페이지는 17px 흰 막대, 나머지는 3px 흰 반투명 점.
class _BuildPageDots extends StatelessWidget {
  const _BuildPageDots({
    required this.count,
    required this.current,
    required this.scale,
  });

  final int count;
  final int current;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: 7 * scale),
          if (i == current)
            Container(
              width: 17 * scale,
              height: 3 * scale,
              decoration: BoxDecoration(
                color: AppColors.narText,
                borderRadius: BorderRadius.circular(1.5 * scale),
              ),
            )
          else
            Container(
              width: 3 * scale,
              height: 3 * scale,
              decoration: const BoxDecoration(
                color: AppColors.narWhiteBorder15,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ],
    );
  }
}

/// 양 팀의 진영 배지+팀 코드, 그 아래 포지션 아이콘 5개(탭하면 해당 선수로 전환).
class _SideSelectorRow extends StatelessWidget {
  const _SideSelectorRow({
    required this.bluePicks,
    required this.redPicks,
    required this.blueTeamCode,
    required this.redTeamCode,
    required this.selectedBlue,
    required this.selectedIndex,
    required this.scale,
    required this.onSelect,
  });

  final List<ChampionPick> bluePicks;
  final List<ChampionPick> redPicks;
  final String blueTeamCode;
  final String redTeamCode;
  final bool selectedBlue;
  final int selectedIndex;
  final double scale;
  final void Function(bool blueSide, int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TeamPositionColumn(
            side: BadgeSide.blue,
            code: blueTeamCode,
            picks: bluePicks,
            selectedIndex: selectedBlue ? selectedIndex : -1,
            alignEnd: false,
            scale: scale,
            onSelect: (i) => onSelect(true, i),
          ),
        ),
        SizedBox(width: 16 * scale),
        Expanded(
          child: _TeamPositionColumn(
            side: BadgeSide.red,
            code: redTeamCode,
            picks: redPicks,
            selectedIndex: !selectedBlue ? selectedIndex : -1,
            alignEnd: true,
            scale: scale,
            onSelect: (i) => onSelect(false, i),
          ),
        ),
      ],
    );
  }
}

/// 라인 svg(`top`/`mid`/`bot`)의 2색 구조 — 프레임(`#343A40`)은 항상
/// [AppColors.narLine]. 주 라인(사선, 원본 `white`)은 선택 시 흰색, 비선택 시
/// [AppColors.narDark200]. 프레임이 없는 svg(`jug`/`sup`, 전체 `white` 단색)는
/// 주 라인 규칙만 적용돼 선택 여부로 전체 색이 바뀐다.
class _LaneIconColorMapper extends ColorMapper {
  const _LaneIconColorMapper({required this.selected});

  final bool selected;

  static const _frameColor = Color(0xFF343A40);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == _frameColor) return AppColors.narLine;
    return selected ? AppColors.narText : AppColors.narDark200;
  }
}

class _TeamPositionColumn extends StatelessWidget {
  const _TeamPositionColumn({
    required this.side,
    required this.code,
    required this.picks,
    required this.selectedIndex,
    required this.alignEnd,
    required this.scale,
    required this.onSelect,
  });

  final BadgeSide side;
  final String code;
  final List<ChampionPick> picks;
  final int selectedIndex;
  final bool alignEnd;
  final double scale;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final codeText = Text(
      code,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w600,
        fontSize: 16 * scale,
        height: 19 / 16,
        color: AppColors.narText,
      ),
    );
    final badge = NarBadgeSide(side: side, scale: scale);
    final header = Row(
      mainAxisSize: MainAxisSize.min,
      children:
          alignEnd
              ? [codeText, SizedBox(width: 8 * scale), badge]
              : [badge, SizedBox(width: 8 * scale), codeText],
    );

    final icons = <Widget>[
      for (var i = 0; i < picks.length && i < 5; i++)
        Builder(
          builder: (context) {
            final asset = laneAssetPath(picks[i].position);
            final selected = selectedIndex == i;
            return GestureDetector(
              key: ValueKey(
                'player_build_lane_${alignEnd ? 'red' : 'blue'}_$i',
              ),
              onTap: () => onSelect(i),
              child: SizedBox(
                width: 30 * scale,
                height: 30 * scale,
                child: Center(
                  child:
                      asset == null
                          ? SizedBox(width: 20 * scale, height: 20 * scale)
                          : SvgPicture.asset(
                            asset,
                            width: 20 * scale,
                            height: 20 * scale,
                            colorMapper: _LaneIconColorMapper(
                              selected: selected,
                            ),
                          ),
                ),
              ),
            );
          },
        ),
    ];

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        SizedBox(height: 6 * scale),
        Row(mainAxisSize: MainAxisSize.min, children: icons),
      ],
    );
  }
}

TextStyle _sectionLabelStyle(double scale) => TextStyle(
  fontFamily: 'Pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 14 * scale,
  height: 1.45,
  color: AppColors.narText2,
);

/// 선택된 한 선수의 빌드 카드 콘텐츠 — 챔피언·레벨·포지션·이름,
/// KDA/CS/GOLD/킬관여/딜비중, 아이템 8칸, 룬(주/부 트리 전체), 능력치 파편.
///
/// 카드 틀(배경·테두리·둥근 모서리)과 하단 페이지 인디케이터는 이 위젯이
/// 아니라 호출부([_MatchDetailPlayerBuildSectionState])가 그린다 — 이
/// 콘텐츠만 [PageView] 안에서 스와이프로 넘어가고, 틀·인디케이터는 고정된
/// 채로 있어야 하기 때문이다(스와이프할 때 인디케이터까지 카드처럼
/// 밀려나가면 어색해 보인다).
class _PlayerBuildCard extends StatelessWidget {
  const _PlayerBuildCard({super.key, required this.pick, required this.scale});

  final ChampionPick pick;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // 헤더 썸네일은 정사각 — 스플래시 크롭이 아니라 정사각 아이콘을 쓴다.
    final iconUrl = pick.iconUrl;
    final hasImage = iconUrl != null && iconUrl.isNotEmpty;
    final laneIcon = laneAssetPath(pick.position);
    final killParticipationPct = (pick.killParticipation * 100).round();
    final damageSharePct = (pick.championDamageShare * 100).round();
    final runes = pick.runes;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4 * scale),
                child: Container(
                  width: 46 * scale,
                  height: 46 * scale,
                  color: AppColors.narBgSecondary,
                  child:
                      hasImage
                          ? CachedNetworkImage(
                            imageUrl: iconUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          )
                          : null,
                ),
              ),
              SizedBox(width: 8 * scale),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * scale,
                      vertical: 2 * scale,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.narText, width: 0.5),
                      borderRadius: BorderRadius.circular(4 * scale),
                    ),
                    child: Text(
                      'Lv.${pick.level}',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: 11 * scale,
                        height: 13 / 11,
                        color: AppColors.narText,
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (laneIcon != null) ...[
                        SvgPicture.asset(
                          laneIcon,
                          width: 20 * scale,
                          height: 20 * scale,
                          colorMapper: const _LaneIconColorMapper(
                            selected: true,
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                      ],
                      Text(
                        pick.playerName,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 16 * scale,
                          height: 19 / 16,
                          color: AppColors.narText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10 * scale),
            decoration: BoxDecoration(
              color: AppColors.narBuildStatsBg,
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BuildStatColumn(
                    label: 'KDA',
                    scale: scale,
                    child: BuildSlashTripleText(
                      a: '${pick.kills}',
                      b: '${pick.deaths}',
                      c: '${pick.assists}',
                      scale: scale,
                    ),
                  ),
                ),
                BuildStatDivider(scale: scale),
                Expanded(
                  child: BuildStatColumn(
                    label: 'CS',
                    value: '${pick.creepScore}',
                    scale: scale,
                  ),
                ),
                BuildStatDivider(scale: scale),
                Expanded(
                  child: BuildStatColumn(
                    label: 'GOLD',
                    value: formatGold(pick.totalGoldEarned),
                    scale: scale,
                  ),
                ),
                BuildStatDivider(scale: scale),
                Expanded(
                  child: BuildStatColumn(
                    label: '킬관여',
                    value: '$killParticipationPct%',
                    scale: scale,
                  ),
                ),
                BuildStatDivider(scale: scale),
                Expanded(
                  child: BuildStatColumn(
                    label: '딜비중',
                    value: '$damageSharePct%',
                    scale: scale,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16 * scale),
          Text('Item', style: _sectionLabelStyle(scale)),
          SizedBox(height: 4 * scale),
          BuildItemRow(pick: pick, scale: scale),
          if (runes != null) ...[
            SizedBox(height: 16 * scale),
            Text('runes', style: _sectionLabelStyle(scale)),
            SizedBox(height: 4 * scale),
            BuildRunesRow(runes: runes, scale: scale),
            if (runes.shards.isNotEmpty) ...[
              SizedBox(height: 16 * scale),
              BuildShardsRow(shards: runes.shards, scale: scale),
            ],
          ],
        ],
      ),
    );
  }
}
