import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../model/match_champion_pick.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/gold_format.dart';
import '../../../util/league_icon.dart';

/// 경기 상세 — 챔피언픽 탭 맨 아래의 "Team Summary" 섹션.
///
/// 킬 합계·골드는 `GET /api/mobile/live/games/{gameId}/champions` 응답의
/// `summary`(TeamStatsSummary)로 실데이터 연결한다. 원래 시안의 막대바는
/// "Total Damage"(양팀 합산 데미지)였으나 그 값은 라이브 중 산출이 어렵다고
/// 확인돼(CH) 대신 골드 비교로 채운다([_GoldBarBox]).
///
/// **와드 설치·파괴 실데이터 없음(필드명 미확정).** 시야점수(vision score)
/// 자체는 API에 없지만 와드 설치·파괴 수는 CH 확인상 가능하다고 해 자리는
/// 만들어 뒀다 — 스펙이 확정되기 전까진 항상 0 이다. 팀 로고·팀명·리그는
/// 호출부(match_detail_screen.dart)가 ScheduleMatch.teamA/teamB/leagueInfo
/// 에서 받아 넘기고, 값이 없으면(로딩 전 등) 목데이터로 대체한다. 와드
/// 아이콘은 받은 [ward.svg]를 그대로 쓴다. 두 킬 숫자 사이의 "경기 로고"
/// 자리는 리그 아이콘([leagueIconWidget])으로 채운다.
class MatchDetailTeamSummarySection extends StatelessWidget {
  const MatchDetailTeamSummarySection({
    super.key,
    this.leagueCode = 'LCK',
    this.blueTeamCode = 'DNS',
    this.redTeamCode = 'T1',
    this.blueTeamLogoUrl,
    this.redTeamLogoUrl,
    this.blueSummary,
    this.redSummary,
    this.scale = 1,
  });

  /// 킬 숫자 사이 "경기 로고" 자리에 표시할 리그 코드.
  final String leagueCode;

  /// 팀 이름 대신 약자(팀 코드)로 표시한다. 예: 'T1', 'GEN'.
  final String blueTeamCode;
  final String redTeamCode;

  /// 팀 로고 URL. null/빈 문자열이면 목데이터 색상 placeholder 를 보여준다.
  final String? blueTeamLogoUrl;
  final String? redTeamLogoUrl;

  /// 팀 합산 킬·골드. null 이면(데이터 로드 전) 0 으로 렌더링한다.
  final TeamStatsSummary? blueSummary;
  final TeamStatsSummary? redSummary;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final blue = blueSummary ?? const TeamStatsSummary();
    final red = redSummary ?? const TeamStatsSummary();
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.fromLTRB(
        10 * scale,
        4 * scale,
        10 * scale,
        36 * scale,
      ),
      child: Column(
        children: [
          _TeamLogosKillsRow(
            leagueCode: leagueCode,
            blueTeamCode: blueTeamCode,
            redTeamCode: redTeamCode,
            blueTeamLogoUrl: blueTeamLogoUrl,
            redTeamLogoUrl: redTeamLogoUrl,
            blueKills: blue.kills,
            redKills: red.kills,
            scale: scale,
          ),
          SizedBox(height: 17 * scale),
          SizedBox(
            width: double.infinity,
            child: _GoldBarBox(
              blueGold: blue.totalGoldEarned,
              redGold: red.totalGoldEarned,
              scale: scale,
            ),
          ),
          SizedBox(height: 17 * scale),
          _VisionGoldRow(
            blueWardsPlaced: blue.wardsPlaced,
            blueWardsKilled: blue.wardsKilled,
            redWardsPlaced: red.wardsPlaced,
            redWardsKilled: red.wardsKilled,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _TeamLogosKillsRow extends StatelessWidget {
  const _TeamLogosKillsRow({
    required this.leagueCode,
    required this.blueTeamCode,
    required this.redTeamCode,
    required this.blueTeamLogoUrl,
    required this.redTeamLogoUrl,
    required this.blueKills,
    required this.redKills,
    required this.scale,
  });

  final String leagueCode;
  final String blueTeamCode;
  final String redTeamCode;
  final String? blueTeamLogoUrl;
  final String? redTeamLogoUrl;
  final int blueKills;
  final int redKills;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // _VisionGoldRow(333)와 같은 폭으로 맞춰 두 행의 중심축(리그 아이콘 ↔
      // 골드 차이 배지)이 일치하게 한다.
      width: 333 * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TeamLogoBlock(
            code: blueTeamCode,
            logoUrl: blueTeamLogoUrl,
            scale: scale,
          ),
          _KillsBlock(
            kill1: '$blueKills',
            kill2: '$redKills',
            leagueCode: leagueCode,
            scale: scale,
          ),
          _TeamLogoBlock(
            code: redTeamCode,
            logoUrl: redTeamLogoUrl,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _TeamLogoBlock extends StatelessWidget {
  const _TeamLogoBlock({
    required this.code,
    required this.logoUrl,
    required this.scale,
  });

  final String code;
  final String? logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 49 * scale,
          height: 49 * scale,
          padding: EdgeInsets.all(4 * scale),
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          child:
              hasLogo
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(6 * scale),
                    child: CachedNetworkImage(
                      imageUrl: resolveImageUrl(logoUrl)!,
                      width: 41 * scale,
                      height: 41 * scale,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget:
                          (_, _, _) => Container(
                            decoration: BoxDecoration(
                              color: AppColors.narDark600,
                              borderRadius: BorderRadius.circular(6 * scale),
                            ),
                          ),
                    ),
                  )
                  : Container(
                    decoration: BoxDecoration(
                      color: AppColors.narDark600,
                      borderRadius: BorderRadius.circular(6 * scale),
                    ),
                  ),
        ),
        SizedBox(
          width: 59 * scale,
          child: Text(
            code,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 16 * scale,
              height: 19 / 16,
              color: AppColors.narText,
            ),
          ),
        ),
      ],
    );
  }
}

class _KillsBlock extends StatelessWidget {
  const _KillsBlock({
    required this.kill1,
    required this.kill2,
    required this.leagueCode,
    required this.scale,
  });

  final String kill1;
  final String kill2;
  final String leagueCode;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final killStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 28 * scale,
      height: 1.3,
      color: const Color(0xFFFCFDFE),
    );
    // 시안의 "경기 로고" 자리 — 리그 아이콘이 있으면 그걸, 없는 리그면
    // 기존처럼 얇은 흰 막대로 대신한다.
    final leagueIcon = leagueIconWidget(leagueCode);
    // 킬 숫자 자릿수가 좌우로 다르면(예: '7' vs '25']) mainAxisSize.min 인
    // Row 가 그 차이만큼 리그 아이콘을 한쪽으로 밀어낸다. 양쪽을 같은 고정
    // 폭(2자리 기준)에 가운데 정렬해 리그 아이콘이 항상 정확한 중앙에 오게 한다.
    const killNumberWidth = 40.0;
    Widget killNumber(String value) => SizedBox(
      width: killNumberWidth * scale,
      child: Text(value, textAlign: TextAlign.center, style: killStyle),
    );
    return SizedBox(
      height: 36 * scale,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          killNumber(kill1),
          SizedBox(width: 16 * scale),
          SizedBox(
            width: 35 * scale,
            height: 35 * scale,
            child: Center(
              child:
                  leagueIcon != null
                      // 리그 svg 원본은 fill 이 검정(#101113)으로 고정돼 있어
                      // 어두운 배경 위에선 안 보인다 — MatchLeagueHeader 와
                      // 같은 방식으로 흰색(narText)으로 틴트한다.
                      ? SizedBox(
                        width: 35 * scale,
                        height: 35 * scale,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            AppColors.narText,
                            BlendMode.srcIn,
                          ),
                          child: leagueIcon,
                        ),
                      )
                      : Container(
                        width: 35 * scale,
                        height: 3 * scale,
                        decoration: BoxDecoration(
                          color: AppColors.narText,
                          borderRadius: BorderRadius.circular(2 * scale),
                        ),
                      ),
            ),
          ),
          SizedBox(width: 16 * scale),
          killNumber(kill2),
        ],
      ),
    );
  }
}

Widget _diffBadge(String text, Color background, double scale) {
  // Container 에 alignment 를 주면 폭이 정해지지 않은 한 부모가 준 가로
  // 제약을 꽉 채우려 든다(Positioned(left:0,right:0) 라 그 제약이 항상
  // bounded). IntrinsicWidth 로 감싸 텍스트+패딩만큼만 차지하게 한다.
  return IntrinsicWidth(
    child: Container(
      height: 19 * scale,
      padding: EdgeInsets.symmetric(horizontal: 3 * scale),
      alignment: Alignment.center,
      color: background,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w500,
          fontSize: 12 * scale,
          height: 1.55,
          color: AppColors.narText,
        ),
      ),
    ),
  );
}

/// 양팀 골드 비교 막대바. 원래 시안은 "Total Damage"(양팀 합산 데미지)였으나
/// 그 값은 라이브 중 산출이 어렵다고 확인돼(CH) 대신 골드로 채운다.
class _GoldBarBox extends StatelessWidget {
  const _GoldBarBox({
    required this.blueGold,
    required this.redGold,
    required this.scale,
  });

  final int blueGold;
  final int redGold;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 14 * scale,
      height: 1.55,
      color: const Color(0xFFFCFDFE),
    );
    final percentStyle = TextStyle(
      fontFamily: 'SF Pro',
      fontWeight: FontWeight.w500,
      fontSize: 12 * scale,
      height: 1.55,
      color: const Color(0xFFFCFDFE),
    );

    final total = blueGold + redGold;
    // 둘 다 0이면(데이터 로드 전) 반반으로 둔다.
    final blueRatio = total > 0 ? blueGold / total : 0.5;
    final redRatio = total > 0 ? redGold / total : 0.5;
    final blueFlex = (blueRatio * 1000).round().clamp(1, 999);
    final redFlex = (1000 - blueFlex).clamp(1, 999);
    final goldDiff = blueGold - redGold;
    final diffLabel =
        '${goldDiff >= 0 ? '+' : '-'}${formatGold(goldDiff.abs())}';
    final diffColor = goldDiff >= 0
        ? const Color(0x99228BE6)
        : const Color(0x80FA5252);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: 4 * scale,
            horizontal: 16 * scale,
          ),
          child: Column(
            children: [
              // 좌우 수치(67,200 / 68,200)는 막대그래프 양 끝에 맞춰 이
              // Row 의 양 끝으로 벌어져야 한다 — FittedBox 로 감싸면
              // 컨텐츠 크기만큼만 차지해 spaceBetween 이 실제로 벌어지지
              // 않으므로 걷어내고, 대신 각 숫자 텍스트에 FittedBox 를 개별로
              // 씌워 'SF Pro' 폴백이 시안보다 넓게 렌더될 때만 그 텍스트만
              // 살짝 줄어들게 한다(전체를 줄이지 않는다).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatGold(blueGold), style: labelStyle),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Total Gold',
                        style: labelStyle.copyWith(color: AppColors.narText2),
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatGold(redGold), style: labelStyle),
                  ),
                ],
              ),
              SizedBox(height: 4 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 7 * scale,
                  child: Row(
                    children: [
                      Expanded(
                        flex: blueFlex,
                        child: Container(color: const Color(0xCC228BE6)),
                      ),
                      Expanded(
                        flex: redFlex,
                        child: Container(color: const Color(0xCCFA5252)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(blueRatio * 100).toStringAsFixed(1)}%',
                    style: percentStyle,
                  ),
                  Text(
                    '${(redRatio * 100).toStringAsFixed(1)}%',
                    style: percentStyle,
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 2 * scale,
          left: 0,
          right: 0,
          child: Center(
            child: _diffBadge(diffLabel, diffColor, scale),
          ),
        ),
      ],
    );
  }
}

/// 와드 설치·파괴 수. 시야점수(vision score) 자체는 API에 없지만 이 두
/// 값은 CH 확인상 가능하다고 함 — 필드명 미확정이라 지금은 항상 0(목업).
/// 골드는 위 [_GoldBarBox] 막대바에 이미 표시되므로 여기서는 뺐다.
class _VisionGoldRow extends StatelessWidget {
  const _VisionGoldRow({
    required this.blueWardsPlaced,
    required this.blueWardsKilled,
    required this.redWardsPlaced,
    required this.redWardsKilled,
    required this.scale,
  });

  final int blueWardsPlaced;
  final int blueWardsKilled;
  final int redWardsPlaced;
  final int redWardsKilled;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final statStyle = TextStyle(
      fontFamily: 'SF Pro Display',
      fontWeight: FontWeight.w500,
      fontSize: 16 * scale,
      height: 1.5,
      color: const Color(0xFFFCFDFE),
    );
    final labelStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 12 * scale,
      height: 1.5,
      color: AppColors.narText2,
    );
    Widget ward() => SvgPicture.asset(
      'assets/icons/ward.svg',
      width: 20 * scale,
      height: 16 * scale,
    );

    return SizedBox(
      width: 333 * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ward(),
                  SizedBox(width: 7 * scale),
                  Text('$blueWardsPlaced', style: statStyle),
                  SizedBox(width: 4 * scale),
                  Text('설치', style: labelStyle),
                ],
              ),
              SizedBox(height: 9 * scale),
              Row(
                children: [
                  ward(),
                  SizedBox(width: 7 * scale),
                  Text('$blueWardsKilled', style: statStyle),
                  SizedBox(width: 4 * scale),
                  Text('파괴', style: labelStyle),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('설치', style: labelStyle),
                  SizedBox(width: 4 * scale),
                  Text('$redWardsPlaced', style: statStyle),
                  SizedBox(width: 7 * scale),
                  ward(),
                ],
              ),
              SizedBox(height: 9 * scale),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('파괴', style: labelStyle),
                  SizedBox(width: 4 * scale),
                  Text('$redWardsKilled', style: statStyle),
                  SizedBox(width: 7 * scale),
                  ward(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
