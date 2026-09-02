import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import '../../../util/gold_format.dart';
import '../../../util/lane_asset.dart';

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
class MatchDetailPlayerBuildSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final picks = selectedBlueSide ? bluePicks : redPicks;
    final pick = selectedIndex < picks.length ? picks[selectedIndex] : null;
    final teamCode = selectedBlueSide ? blueTeamCode : redTeamCode;

    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.fromLTRB(10 * scale, 16 * scale, 10 * scale, 36 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideSelectorRow(
            bluePicks: bluePicks,
            redPicks: redPicks,
            blueTeamCode: blueTeamCode,
            redTeamCode: redTeamCode,
            selectedBlue: selectedBlueSide,
            selectedIndex: selectedIndex,
            scale: scale,
            onSelect: onSelect,
          ),
          SizedBox(height: 16 * scale),
          if (pick != null)
            _PlayerBuildCard(pick: pick, teamCode: teamCode, scale: scale),
        ],
      ),
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
      children: alignEnd
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
              key: ValueKey('player_build_lane_${alignEnd ? 'red' : 'blue'}_$i'),
              onTap: () => onSelect(i),
              child: SizedBox(
                width: 30 * scale,
                height: 30 * scale,
                child: Center(
                  child: Opacity(
                    opacity: selected ? 1 : 0.4,
                    child: asset == null
                        ? SizedBox(width: 20 * scale, height: 20 * scale)
                        : SvgPicture.asset(
                            asset,
                            width: 20 * scale,
                            height: 20 * scale,
                            colorFilter: const ColorFilter.mode(
                              AppColors.narText,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
    ];

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        SizedBox(height: 6 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: alignEnd ? icons.reversed.toList() : icons,
        ),
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

/// 선택된 한 선수의 빌드 카드 — 챔피언·레벨·포지션·이름, KDA/CS/GOLD/킬관여/딜비중,
/// 아이템 8칸, 룬(주/부 트리 전체), 능력치 파편.
class _PlayerBuildCard extends StatelessWidget {
  const _PlayerBuildCard({
    required this.pick,
    required this.teamCode,
    required this.scale,
  });

  final ChampionPick pick;
  final String teamCode;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasImage = pick.imageUrl != null && pick.imageUrl!.isNotEmpty;
    final laneIcon = laneAssetPath(pick.position);
    final killParticipationPct = (pick.killParticipation * 100).round();
    final damageSharePct = (pick.championDamageShare * 100).round();
    final runes = pick.runes;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24 * scale, horizontal: 8 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(10 * scale),
      ),
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
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: pick.imageUrl!,
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
                          colorFilter: const ColorFilter.mode(
                            AppColors.narText,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                      ],
                      Text(
                        '$teamCode ${pick.playerName}',
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
                  child: _StatColumn(
                    label: 'KDA',
                    scale: scale,
                    child: _SlashTripleText(
                      a: '${pick.kills}',
                      b: '${pick.deaths}',
                      c: '${pick.assists}',
                      scale: scale,
                    ),
                  ),
                ),
                _StatDivider(scale: scale),
                Expanded(
                  child: _StatColumn(
                    label: 'CS',
                    value: '${pick.creepScore}',
                    scale: scale,
                  ),
                ),
                _StatDivider(scale: scale),
                Expanded(
                  child: _StatColumn(
                    label: 'GOLD',
                    value: formatGold(pick.totalGoldEarned),
                    scale: scale,
                  ),
                ),
                _StatDivider(scale: scale),
                Expanded(
                  child: _StatColumn(
                    label: '킬관여',
                    value: '$killParticipationPct%',
                    scale: scale,
                  ),
                ),
                _StatDivider(scale: scale),
                Expanded(
                  child: _StatColumn(
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
          _ItemRow(pick: pick, scale: scale),
          if (runes != null) ...[
            SizedBox(height: 16 * scale),
            Text('runes', style: _sectionLabelStyle(scale)),
            SizedBox(height: 4 * scale),
            _RunesRow(runes: runes, scale: scale),
            if (runes.shards.isNotEmpty) ...[
              SizedBox(height: 16 * scale),
              _ShardsRow(shards: runes.shards, scale: scale),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    this.value,
    this.child,
    required this.scale,
  });

  final String label;
  final String? value;
  final Widget? child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12 * scale,
            height: 14 / 12,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 3 * scale),
        child ??
            Text(
              value ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 14 * scale,
                height: 17 / 14,
                color: AppColors.narText,
              ),
            ),
      ],
    );
  }
}

/// KDA "a/b/c" — 데스(가운데)만 [AppColors.narTextScore]로 강조한다
/// (Player Stats 의 데스 색상 표기와 동일 규칙).
class _SlashTripleText extends StatelessWidget {
  const _SlashTripleText({
    required this.a,
    required this.b,
    required this.c,
    required this.scale,
  });

  final String a;
  final String b;
  final String c;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 14 * scale,
      height: 17 / 14,
      color: AppColors.narText,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: a),
          const TextSpan(text: '/'),
          TextSpan(text: b, style: TextStyle(color: AppColors.narTextScore)),
          const TextSpan(text: '/'),
          TextSpan(text: c),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 20 * scale, color: AppColors.narLine2);
}

/// 아이템 8칸 — 코어 6 + 퀘스트 아이템(신발) + 장신구, 한 줄에 나란히.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.pick, required this.scale});

  final ChampionPick pick;
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget slot(String? url) {
      final hasImage = url != null && url.isNotEmpty;
      return Container(
        width: 37 * scale,
        height: 37 * scale,
        decoration: BoxDecoration(
          color: AppColors.narBgSecondary,
          borderRadius: BorderRadius.circular(4 * scale),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              )
            : null,
      );
    }

    final core = pick.coreItemImageUrls;
    String? coreAt(int index) => index < core.length ? core[index] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 6; i++) slot(coreAt(i)),
        slot(pick.questItemImageUrl),
        slot(pick.trinketItemImageUrl),
      ],
    );
  }
}

/// 룬 트리 두 칸(주/부) — 주 트리는 키스톤(큰 아이콘)+나머지 3개, 부 트리는
/// 선택된 룬 2개 모두 같은 크기로.
class _RunesRow extends StatelessWidget {
  const _RunesRow({required this.runes, required this.scale});

  final PlayerRunes runes;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RuneTreeColumn(style: runes.primary, isPrimary: true, scale: scale),
        ),
        SizedBox(width: 16 * scale),
        Expanded(
          child: _RuneTreeColumn(style: runes.sub, isPrimary: false, scale: scale),
        ),
      ],
    );
  }
}

class _RuneTreeColumn extends StatelessWidget {
  const _RuneTreeColumn({
    required this.style,
    required this.isPrimary,
    required this.scale,
  });

  final RuneStyle style;
  final bool isPrimary;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasIcon = style.styleIconUrl != null && style.styleIconUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.narWhiteBorder62,
                width: 3 * scale,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Container(
                  width: 22 * scale,
                  height: 22 * scale,
                  color: AppColors.narBgSecondary,
                  child: hasIcon
                      ? CachedNetworkImage(
                          imageUrl: style.styleIconUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        )
                      : null,
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(
                style.styleName,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 14 * scale,
                  height: 20 / 14,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < style.runes.length; i++) ...[
                if (i > 0) SizedBox(height: 8 * scale),
                _RuneEntryRow(
                  entry: style.runes[i],
                  large: isPrimary && i == 0,
                  scale: scale,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 룬 한 칸 — 키스톤([large])은 33px 원형(배경 있음), 나머지는 24px(테두리만).
class _RuneEntryRow extends StatelessWidget {
  const _RuneEntryRow({
    required this.entry,
    required this.large,
    required this.scale,
  });

  final RuneEntry entry;
  final bool large;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = (large ? 33.0 : 24.0) * scale;
    final hasIcon = entry.iconUrl != null && entry.iconUrl!.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: large ? AppColors.narBgSecondary : null,
            border: Border.all(color: AppColors.narWhiteBorder15, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasIcon
              ? CachedNetworkImage(
                  imageUrl: entry.iconUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                )
              : null,
        ),
        SizedBox(width: 8 * scale),
        Flexible(
          child: Text(
            entry.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 12 * scale,
              height: 17 / 12,
              color: AppColors.narText,
            ),
          ),
        ),
      ],
    );
  }
}

/// 능력치 파편 칩 — "{name} {label}"(예: '적응형 능력치 +9').
class _ShardsRow extends StatelessWidget {
  const _ShardsRow({required this.shards, required this.scale});

  final List<RuneShard> shards;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4 * scale,
      runSpacing: 4 * scale,
      children: [for (final shard in shards) _ShardPill(shard: shard, scale: scale)],
    );
  }
}

class _ShardPill extends StatelessWidget {
  const _ShardPill({required this.shard, required this.scale});

  final RuneShard shard;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasIcon = shard.iconUrl != null && shard.iconUrl!.isNotEmpty;
    final text = shard.label != null ? '${shard.name} ${shard.label}' : shard.name;
    return Container(
      padding: EdgeInsets.fromLTRB(2 * scale, 2 * scale, 8 * scale, 2 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.narWhiteBorder15, width: 0.5),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 19 * scale,
            height: 19 * scale,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2 * scale)),
            child: hasIcon
                ? CachedNetworkImage(
                    imageUrl: shard.iconUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  )
                : null,
          ),
          SizedBox(width: 2 * scale),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 11 * scale,
              height: 13 / 11,
              color: AppColors.narText,
            ),
          ),
        ],
      ),
    );
  }
}
