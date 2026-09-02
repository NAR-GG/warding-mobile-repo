import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/nar_badge.dart';
import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import '../../../util/gold_format.dart';

/// 경기 상세 — 챔피언픽 탭 하단의 "Player Stats" 섹션.
///
/// `GET /api/mobile/live/games/{gameId}/champions` 응답의 픽 5명 스코어보드
/// (레벨·KDA·CS·골드·킬관여·딜분배·아이템·룬)를 그대로 렌더링한다.
///
/// 소환사 주문(플래시·텔레포트 등)은 이 API에 없어 자리만 빈 박스로 둔다.
class MatchDetailPlayerStatsSection extends StatelessWidget {
  const MatchDetailPlayerStatsSection({
    super.key,
    required this.blueTeamCode,
    required this.redTeamCode,
    required this.blueWon,
    required this.bluePicks,
    required this.redPicks,
    this.onPlayerTap,
    this.scale = 1,
  });

  final String blueTeamCode;
  final String redTeamCode;

  /// 블루팀 승리 여부. null 이면 진행 중(승/패 라벨 생략).
  final bool? blueWon;

  final List<ChampionPick> bluePicks;
  final List<ChampionPick> redPicks;

  /// 선수 행을 탭했을 때 호출된다(블루팀 여부, 팀 내 인덱스). null 이면 탭 비활성화.
  /// [MatchDetailScreen]이 여기서 "Player Builds" 바텀시트를 띄운다.
  final void Function(bool isBlueSide, int index)? onPlayerTap;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final blueResult = blueWon == null ? null : (blueWon! ? '승' : '패');
    final redResult = blueWon == null ? null : (blueWon! ? '패' : '승');
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeamStatsBlock(
            side: BadgeSide.blue,
            teamCode: blueTeamCode,
            resultLabel: blueResult,
            resultColor: blueWon == true
                ? AppColors.narGreenWin
                : AppColors.narText2,
            picks: bluePicks,
            onPlayerTap: onPlayerTap == null
                ? null
                : (index) => onPlayerTap!(true, index),
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _TeamStatsBlock(
            side: BadgeSide.red,
            teamCode: redTeamCode,
            resultLabel: redResult,
            resultColor: blueWon == false
                ? AppColors.narGreenWin
                : AppColors.narText2,
            picks: redPicks,
            onPlayerTap: onPlayerTap == null
                ? null
                : (index) => onPlayerTap!(false, index),
            scale: scale,
          ),
        ],
      ),
    );
  }
}

/// K/D/A 처럼 "a / b / c" 형태의 텍스트. 팀 총 스코어("25/20/26")와 선수
/// KDA("7/2/4") 둘 다 이 스타일을 쓴다. [deathColor] 를 주면 가운데 값(데스)
/// 만 그 색으로 강조하고, 안 주면 전체가 기본색(narText)으로 통일된다 —
/// 팀 총 스코어·선수별 KDA 둘 다 데스만 강조색(narTextScore)으로 표시한다.
class _SlashTriple extends StatelessWidget {
  const _SlashTriple({
    required this.a,
    required this.b,
    required this.c,
    required this.fontSize,
    required this.fontWeight,
    required this.scale,
    this.deathColor,
  });

  final String a;
  final String b;
  final String c;
  final double fontSize;
  final FontWeight fontWeight;
  final double scale;
  final Color? deathColor;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: fontWeight,
      fontSize: fontSize * scale,
      height: 1.2,
      color: AppColors.narText,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: a),
          const TextSpan(text: ' / '),
          TextSpan(
            text: b,
            style: deathColor == null ? null : TextStyle(color: deathColor),
          ),
          const TextSpan(text: ' / '),
          TextSpan(text: c),
        ],
      ),
    );
  }
}

class _TeamStatsBlock extends StatelessWidget {
  const _TeamStatsBlock({
    required this.side,
    required this.teamCode,
    required this.resultLabel,
    required this.resultColor,
    required this.picks,
    required this.onPlayerTap,
    required this.scale,
  });

  final BadgeSide side;
  final String teamCode;

  /// null 이면(진행 중) 승/패 텍스트를 생략한다.
  final String? resultLabel;
  final Color resultColor;
  final List<ChampionPick> picks;
  final void Function(int index)? onPlayerTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final teamKills = picks.fold<int>(0, (sum, p) => sum + p.kills);
    final teamDeaths = picks.fold<int>(0, (sum, p) => sum + p.deaths);
    final teamAssists = picks.fold<int>(0, (sum, p) => sum + p.assists);
    final teamGold = picks.fold<int>(0, (sum, p) => sum + p.totalGoldEarned);
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.fromLTRB(0, 0, 8 * scale, 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 10 * scale,
            ),
            child: Row(
              children: [
                // 뱃지 라벨은 기본값(BLUE/RED)을 그대로 쓰고, 그 옆에 팀
                // 코드·승패를 별도 텍스트로 붙인다.
                NarBadgeSide(side: side, scale: scale),
                SizedBox(width: 8 * scale),
                Text(
                  teamCode,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16 * scale,
                    height: 1.2,
                    color: AppColors.narText,
                  ),
                ),
                if (resultLabel != null) ...[
                  SizedBox(width: 4 * scale),
                  Text(
                    resultLabel!,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 16 * scale,
                      height: 1.2,
                      color: resultColor,
                    ),
                  ),
                ],
                const Spacer(),
                // 배지+팀 코드+승패 쪽은 정체성 정보라 줄이지 않고, 팀
                // 스코어+골드 쪽만 좁은 화면(320~375)에서 안 맞으면 살짝
                // 줄어들게 한다. FittedBox 는 부모가 폭을 정해줘야 실제로
                // 줄어든다 — Row 의 비-flex 자식으로 그냥 두면 폭 제약이
                // 없어(unbounded) 그냥 원래 크기로 그려져 overflow 가 그대로
                // 났다. 시안의 원래 자리 폭(112, "총" 프레임 기준)을 SizedBox
                // 로 씌워 준다 — 이보다 좁으면(예: 96) FittedBox 가 폰트
                // 크기를 스펙보다 작게 축소해 버린다.
                SizedBox(
                  width: 112 * scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SlashTriple(
                          a: '$teamKills',
                          b: '$teamDeaths',
                          c: '$teamAssists',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          scale: scale,
                          deathColor: AppColors.narTextScore,
                        ),
                        SizedBox(width: 2 * scale),
                        Text(
                          '•',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w500,
                            fontSize: 8 * scale,
                            height: 1.2,
                            color: AppColors.narText,
                          ),
                        ),
                        SizedBox(width: 2 * scale),
                        Text(
                          formatGold(teamGold),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w500,
                            fontSize: 14 * scale,
                            height: 1.2,
                            color: AppColors.narText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < picks.length; i++) ...[
            if (i > 0) SizedBox(height: 12 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPlayerTap == null ? null : () => onPlayerTap!(i),
              child: _PlayerStatsRow(pick: picks[i], scale: scale),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerStatsRow extends StatelessWidget {
  const _PlayerStatsRow({required this.pick, required this.scale});

  final ChampionPick pick;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final killParticipationPct = (pick.killParticipation * 100).round();
    final damageSharePct = (pick.championDamageShare * 100).round();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ChampionBlock(
            imageUrl: pick.imageUrl,
            level: pick.level,
            scale: scale,
          ),
          SizedBox(width: 2 * scale),
          _SpellRuneBlock(
            keystoneIconUrl: pick.keystoneIconUrl,
            subStyleIconUrl: pick.subStyleIconUrl,
            scale: scale,
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pick.playerName,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    height: 1.2,
                    color: AppColors.narText,
                  ),
                ),
                SizedBox(height: 4 * scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        'CS',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 12 * scale,
                          height: 14 / 12,
                          color: AppColors.narText2,
                        ),
                      ),
                      SizedBox(width: 4 * scale),
                      Text(
                        '${pick.creepScore}',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 12 * scale,
                          height: 14 / 12,
                          color: AppColors.narText2,
                        ),
                      ),
                      SizedBox(width: 2 * scale),
                      Text(
                        '•',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 8 * scale,
                          height: 14 / 12,
                          color: AppColors.narText2,
                        ),
                      ),
                      SizedBox(width: 2 * scale),
                      Text(
                        formatGold(pick.totalGoldEarned),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 12 * scale,
                          height: 14 / 12,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          // "킬관여 62%" 라벨이 KDA 숫자보다 넓어서 좁은 화면(320~375)에서
          // 이 칼럼이 outer Row 를 overflow 시켰다. FittedBox 는 부모가 폭을
          // 정해줘야 실제로 줄어든다 — Row 의 비-flex 자식으로 그냥 두면 폭
          // 제약이 없어(unbounded) 원래 크기 그대로 그려져 overflow 가 안
          // 없어졌다. 시안의 원래 자리 폭(60)을 SizedBox 로 씌워 준다.
          SizedBox(
            width: 60 * scale,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SlashTriple(
                    a: '${pick.kills}',
                    b: '${pick.deaths}',
                    c: '${pick.assists}',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    scale: scale,
                    deathColor: AppColors.narTextScore,
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '킬관여 $killParticipationPct%',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 12 * scale,
                      height: 1.2,
                      color: AppColors.narText,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    '딜분배 $damageSharePct%',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 12 * scale,
                      height: 1.2,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          _ItemGrid(
            coreItemImageUrls: pick.coreItemImageUrls,
            questItemImageUrl: pick.questItemImageUrl,
            trinketItemImageUrl: pick.trinketItemImageUrl,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

/// 챔피언 미니 아이콘(42×42) + 우하단 레벨 배지.
class _ChampionBlock extends StatelessWidget {
  const _ChampionBlock({
    required this.imageUrl,
    required this.level,
    required this.scale,
  });

  final String? imageUrl;
  final int level;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 42 * scale;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(6 * scale),
            ),
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 17 * scale,
              height: 18 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x9E141517), // rgba(20,21,23,0.62)
                borderRadius: BorderRadius.circular(6 * scale),
              ),
              child: Text(
                '$level',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 10 * scale,
                  height: 1,
                  color: const Color(0xFFFCFDFE),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스펠 2개(위, 데이터 없어 빈 박스) + 룬 2개(아래, 키스톤·보조 스타일 실데이터).
/// 각 20×20, 배경 narBgSecondary 톤.
class _SpellRuneBlock extends StatelessWidget {
  const _SpellRuneBlock({
    required this.keystoneIconUrl,
    required this.subStyleIconUrl,
    required this.scale,
  });

  final String? keystoneIconUrl;
  final String? subStyleIconUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget slot({String? imageUrl}) {
      final hasImage = imageUrl != null && imageUrl.isNotEmpty;
      return Container(
        width: 20 * scale,
        height: 20 * scale,
        decoration: BoxDecoration(
          color: AppColors.narBgSecondary,
          borderRadius: BorderRadius.circular(4 * scale),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
            : null,
      );
    }

    Widget column(Widget top, Widget bottom) => Column(
      children: [
        top,
        SizedBox(height: 2 * scale),
        bottom,
      ],
    );

    return SizedBox(
      width: 42 * scale,
      height: 42 * scale,
      child: Row(
        children: [
          // 소환사 주문 — API 응답에 없어 빈 슬롯으로 남긴다.
          column(slot(), slot()),
          SizedBox(width: 2 * scale),
          column(
            slot(imageUrl: keystoneIconUrl),
            slot(imageUrl: subStyleIconUrl),
          ),
        ],
      ),
    );
  }
}

/// 아이템 8칸(4열×2행, 20×20, gap 2). 왼쪽 3열(6칸)은 코어 아이템, 맨 끝
/// 오른쪽 열은 위=장신구·아래=퀘스트 아이템(2026 바텀 퀘스트 완료 시 신발).
/// 값이 없는 칸은 빈 박스로 둔다.
class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.coreItemImageUrls,
    required this.questItemImageUrl,
    required this.trinketItemImageUrl,
    required this.scale,
  });

  final List<String> coreItemImageUrls;
  final String? questItemImageUrl;
  final String? trinketItemImageUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget slot({String? imageUrl}) {
      final hasImage = imageUrl != null && imageUrl.isNotEmpty;
      return Container(
        width: 20 * scale,
        height: 20 * scale,
        decoration: BoxDecoration(
          color: AppColors.narBgSecondary,
          borderRadius: BorderRadius.circular(4 * scale),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
            : null,
      );
    }

    String? coreAt(int index) =>
        index < coreItemImageUrls.length ? coreItemImageUrls[index] : null;

    Widget row(List<Widget> slots) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0) SizedBox(width: 2 * scale),
          slots[i],
        ],
      ],
    );

    return SizedBox(
      width: 86 * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row([
            slot(imageUrl: coreAt(0)),
            slot(imageUrl: coreAt(1)),
            slot(imageUrl: coreAt(2)),
            slot(imageUrl: trinketItemImageUrl),
          ]),
          SizedBox(height: 2 * scale),
          row([
            slot(imageUrl: coreAt(3)),
            slot(imageUrl: coreAt(4)),
            slot(imageUrl: coreAt(5)),
            slot(imageUrl: questItemImageUrl),
          ]),
        ],
      ),
    );
  }
}
