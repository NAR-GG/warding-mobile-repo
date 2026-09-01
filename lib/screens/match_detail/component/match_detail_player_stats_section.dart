import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_badge.dart';
import '../../../styles/app_colors.dart';

/// 경기 상세 — 챔피언픽 탭 하단의 "Player Stats" 섹션.
///
/// **실데이터 없음.** 챔피언 레벨·CS·골드·아이템·스펠·룬 같은 값은 지금
/// 어떤 API 응답에도 없어서(KDA·챔피언명만 [RatingPlayer] 에 있음), 시안의
/// 목업 텍스트("DNS DuDu", "317", "7/2/4" 등)를 위치 그대로 하드코딩해
/// UI를 먼저 완성한다. 5명 선수 값이 전부 동일한 것도 시안 원본이 그렇다
/// (선수별로 다른 목업이 아니라 같은 자리 예시를 반복한 것). 챔피언 아이콘·
/// 아이템 자리는 이미지 자산이 없어 회색 placeholder 로 남긴다. 스펠·룬
/// 자리에는 받은 샘플 아이콘([flash], [teleport], [ignite], [arcaneComet],
/// [domination], [oracleLens])을 그대로 쓴다 — 실제 선수별 스펠/룬이 아니다.
/// 백엔드가 값을 내려주기 시작하면 이 텍스트들을 실제 데이터 바인딩으로
/// 바꿔야 한다.
class MatchDetailPlayerStatsSection extends StatelessWidget {
  const MatchDetailPlayerStatsSection({super.key, this.scale = 1});

  final double scale;

  static const String flash = 'assets/images/flash.png';
  static const String teleport = 'assets/images/teleport.png';
  static const String ignite = 'assets/images/ignite.svg';
  static const String arcaneComet = 'assets/images/arcane-comet.png';
  static const String domination = 'assets/images/domination.png';
  static const String oracleLens = 'assets/images/oracle-lens.png';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeamStatsBlock(
            side: BadgeSide.blue,
            teamCode: 'DNS',
            resultLabel: '승',
            resultColor: AppColors.narGreenWin,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _TeamStatsBlock(
            side: BadgeSide.red,
            teamCode: 'T1',
            resultLabel: '패',
            resultColor: AppColors.narText2,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

/// K/D/A 처럼 "a / b / c" 형태의 텍스트. 팀 총 스코어("25/20/26")와 선수
/// KDA("7/2/4") 둘 다 이 스타일을 쓴다. [deathColor] 를 주면 가운데 값(데스)
/// 만 그 색으로 강조하고, 안 주면 전체가 [color] 로 통일된다 — 팀 총
/// 스코어는 가운데(데스)만 강조색(narTextScore), 선수별 KDA는 데스도
/// 나머지와 같은 흰색(narText)으로 표시한다.
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
    required this.scale,
  });

  final BadgeSide side;
  final String teamCode;
  final String resultLabel;
  final Color resultColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
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
                SizedBox(width: 4 * scale),
                Text(
                  resultLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16 * scale,
                    height: 1.2,
                    color: resultColor,
                  ),
                ),
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
                          a: '25',
                          b: '20',
                          c: '26',
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
                          '78.6k',
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
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) SizedBox(height: 12 * scale),
            _PlayerStatsRow(scale: scale),
          ],
        ],
      ),
    );
  }
}

class _PlayerStatsRow extends StatelessWidget {
  const _PlayerStatsRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ChampionBlock(scale: scale),
          SizedBox(width: 2 * scale),
          _SpellRuneBlock(scale: scale),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DNS DuDu',
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
                        '317',
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
                        '14.4k',
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
                    a: '7',
                    b: '2',
                    c: '4',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    scale: scale,
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '킬관여 62%',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 12 * scale,
                      height: 1.2,
                      color: AppColors.narText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          _ItemGrid(scale: scale),
        ],
      ),
    );
  }
}

/// 챔피언 미니 아이콘(42×42) + 우하단 레벨 배지. 챔피언 식별 데이터가
/// 없어 아이콘 자리는 회색 박스로 두되, 레벨 값은 시안 목업 "17"을 그대로 쓴다.
class _ChampionBlock extends StatelessWidget {
  const _ChampionBlock({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 42 * scale;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(6 * scale),
            ),
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
                '17',
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

/// 스펠 2개(위) + 룬 2개(아래) — 각 20×20, 배경 narBgSecondary 톤.
/// 받은 샘플 아이콘을 그대로 쓴다(선수별 실제 스펠/룬 아님).
class _SpellRuneBlock extends StatelessWidget {
  const _SpellRuneBlock({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget slot(String asset) => Container(
      width: 20 * scale,
      height: 20 * scale,
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          asset.endsWith('.svg')
              ? SvgPicture.asset(asset, fit: BoxFit.cover)
              : Image.asset(asset, fit: BoxFit.cover),
    );
    Widget column(String top, String bottom) => Column(
      children: [slot(top), SizedBox(height: 2 * scale), slot(bottom)],
    );

    return SizedBox(
      width: 42 * scale,
      height: 42 * scale,
      child: Row(
        children: [
          column(
            MatchDetailPlayerStatsSection.flash,
            MatchDetailPlayerStatsSection.ignite,
          ),
          SizedBox(width: 2 * scale),
          column(
            MatchDetailPlayerStatsSection.domination,
            MatchDetailPlayerStatsSection.arcaneComet,
          ),
        ],
      ),
    );
  }
}

/// 아이템 8칸(4열×2행, 20×20, gap 2). 실제 구매 아이템 데이터가 없어
/// 대부분 회색 박스이고, 1행 마지막 칸(신발류 추정)·2행 마지막 칸(트린켓)만
/// 받은 샘플 아이콘을 쓴다.
class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget slot({String? asset}) => Container(
      width: 20 * scale,
      height: 20 * scale,
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset == null ? null : Image.asset(asset, fit: BoxFit.cover),
    );
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
          row([slot(), slot(), slot(), slot()]),
          SizedBox(height: 2 * scale),
          row([
            slot(),
            slot(),
            slot(),
            slot(asset: MatchDetailPlayerStatsSection.oracleLens),
          ]),
        ],
      ),
    );
  }
}
