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
/// `summary`(TeamStatsSummary)로 실데이터 연결한다. 골드·와드 설치·와드
/// 파괴 세 줄 모두 같은 비율 바 구조([_StatBarRow])를 공유한다(Figma 최신
/// 시안). "Total Damage"(양팀 합산 데미지)는 라이브 중 산출이 어렵다고
/// 확인돼(CH) 시안에서 골드로 대체됐다.
///
/// **와드 설치·파괴는 팀 합산 `summary` 자체엔 없다**(항상 0) — 대신 각
/// 선수([ChampionPick.wardsPlaced]/`wardsDestroyed`)에 직접 내려오는 값을
/// [ChampionTeam.summaryWithWards] 가 5명분 더해 채운다
/// (`MatchDetailViewModel.blueTeamSummary`/`redTeamSummary`). 시야점수
/// (vision score) 자체는 와드 개수만으로 만들 수 없어 API에 없다. 팀 로고·팀명·리그는
/// 호출부(match_detail_screen.dart)가
/// ScheduleMatch.teamA/teamB/leagueInfo 에서 받아 넘기고, 값이 없으면
/// (로딩 전 등) 목데이터로 대체한다. 두 킬 숫자 사이의 "경기 로고" 자리는
/// 리그 아이콘([leagueIconWidget])으로 채운다.
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
        16 * scale,
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
          SizedBox(height: 24 * scale),
          _StatBarRow(
            icon: _StatIcon.gold,
            label: 'Total Gold',
            leftText: formatGold(blue.totalGoldEarned),
            rightText: formatGold(red.totalGoldEarned),
            leftAmount: blue.totalGoldEarned,
            rightAmount: red.totalGoldEarned,
            scale: scale,
          ),
          SizedBox(height: 12 * scale),
          _StatBarRow(
            icon: _StatIcon.wardPlaced,
            label: 'Placed',
            leftText: '${blue.wardsPlaced}',
            rightText: '${red.wardsPlaced}',
            leftAmount: blue.wardsPlaced,
            rightAmount: red.wardsPlaced,
            scale: scale,
          ),
          SizedBox(height: 12 * scale),
          _StatBarRow(
            icon: _StatIcon.wardDestroyed,
            label: 'Destroyed',
            leftText: '${blue.wardsKilled}',
            rightText: '${red.wardsKilled}',
            leftAmount: blue.wardsKilled,
            rightAmount: red.wardsKilled,
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
      // _StatBarRow(335)와 같은 폭으로 맞춰 아래 통계 줄들과 좌우 정렬축이 일치하게 한다.
      width: 335 * scale,
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
          child: hasLogo
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6 * scale),
                  child: CachedNetworkImage(
                    imageUrl: resolveImageUrl(logoUrl)!,
                    width: 41 * scale,
                    height: 41 * scale,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) => Container(
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
    final labelStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 14 * scale,
      height: 1.45,
      color: AppColors.narText2,
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
      width: 129 * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 시안 텍스트 그대로 — 로케일과 무관하게 항상 영문 "Total Kills".
          Text('Total Kills', textAlign: TextAlign.center, style: labelStyle),
          // 킬 숫자+리그 아이콘 행의 자연 폭(147)이 시안 폭(129)보다 넓다 —
          // FittedBox 로 넘치는 만큼만 살짝 줄인다(다른 곳의 좁은 화면
          // 대응과 같은 패턴).
          SizedBox(
            width: 129 * scale,
            height: 44 * scale,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  killNumber(kill1),
                  SizedBox(width: 8 * scale),
                  SizedBox(
                    width: 35 * scale,
                    height: 35 * scale,
                    child: Center(
                      child: leagueIcon != null
                          // 리그 svg 원본은 fill 이 검정(#101113)으로
                          // 고정돼 있어 어두운 배경 위에선 안 보인다 —
                          // MatchLeagueHeader 와 같은 방식으로
                          // 흰색(narText)으로 틴트한다.
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
                              height: 15.71 * scale,
                              decoration: BoxDecoration(
                                color: AppColors.narText,
                                borderRadius: BorderRadius.circular(
                                  2 * scale,
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  killNumber(kill2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [_StatBarRow] 아이콘 종류.
enum _StatIcon { gold, wardPlaced, wardDestroyed }

/// 통계 한 줄: [아이콘+값 … 라벨 … 값+아이콘] 위에 좌우 비율 막대바, 그
/// 아래 퍼센트 텍스트. Gold·Wards Placed·Wards Destroyed 세 줄이 모두 이
/// 구조를 공유한다(Figma 최신 시안).
class _StatBarRow extends StatelessWidget {
  const _StatBarRow({
    required this.icon,
    required this.label,
    required this.leftText,
    required this.rightText,
    required this.leftAmount,
    required this.rightAmount,
    required this.scale,
  });

  final _StatIcon icon;
  final String label;
  final String leftText;
  final String rightText;
  final int leftAmount;
  final int rightAmount;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 14 * scale,
      height: 1.55,
      color: const Color(0xFFFCFDFE),
    );
    final labelStyle = valueStyle.copyWith(color: AppColors.narText2);
    final percentStyle = TextStyle(
      fontFamily: 'SF Pro',
      fontWeight: FontWeight.w500,
      fontSize: 12 * scale,
      height: 1.55,
      color: const Color(0xFFFCFDFE),
    );

    final total = leftAmount + rightAmount;
    // 둘 다 0이면(데이터 로드 전이거나 아직 값이 없으면) 반반으로 둔다.
    final leftRatio = total > 0 ? leftAmount / total : 0.5;
    final rightRatio = total > 0 ? rightAmount / total : 0.5;
    // 동률이면 왼쪽을 우세로 본다(일관된 기본값).
    final leftLeads = leftRatio >= rightRatio;
    final leaderRatio = leftLeads ? leftRatio : rightRatio;
    const pillRadius = BorderRadius.all(Radius.circular(999));

    final iconAsset = switch (icon) {
      _StatIcon.gold => 'assets/icons/gold.svg',
      _StatIcon.wardPlaced => 'assets/icons/ward.svg',
      // 와드 파괴 — 설치 아이콘에 사선(스트라이크)이 더해진 전용 아이콘.
      _StatIcon.wardDestroyed => 'assets/icons/destroy-ward.svg',
    };
    Widget iconWidget() =>
        SvgPicture.asset(iconAsset, width: 20 * scale, height: 16 * scale);

    return SizedBox(
      width: 335 * scale,
      child: Column(
        children: [
          Row(
            children: [
              iconWidget(),
              SizedBox(width: 4 * scale),
              Text(leftText, style: valueStyle),
              const Spacer(),
              Text(label, style: labelStyle),
              const Spacer(),
              Text(rightText, style: valueStyle),
              SizedBox(width: 4 * scale),
              iconWidget(),
            ],
          ),
          SizedBox(height: 8 * scale),
          // 전체 배경은 항상 narLine2 로 꽉 채운 트랙이고, 그 위에 비율이
          // 더 높은 쪽에서부터 자란 둥근 알약 모양의 메인 그라데이션
          // (narBg) 바를 얹는다.
          //
          // 두 시도가 실패했다 — 둘 다 폭 계산이 어긋나(비율 무시) 위젯
          // 테스트로 잡았다.
          // 1) Stack + Positioned.fill(트랙) + FractionallySizedBox(오버레이):
          //    Stack 은 자기 크기를 "포지션 안 된(non-positioned) 자식"
          //    기준으로 정하는데 FractionallySizedBox 가 유일한 그런
          //    자식이라, Stack 자체가 그 자식 크기로 줄어들고 트랙도 같이
          //    줄어들어 버렸다(항상 절반씩 렌더).
          // 2) Row + Expanded(flex): 폭은 맞았지만 트랙이 항상 전체
          //    폭이어야 한다는 요구를 못 담는다(두 구간이 합쳐서 전체
          //    폭이라 트랙이 따로 안 보임).
          //
          // 지금 구조는 바깥 SizedBox 에 폭·높이를 모두 명시해 Stack 에
          // 타이트 제약을 강제한다 — 제약이 타이트하면 Stack 크기는 자식과
          // 무관하게 그 크기로 고정되므로 1)의 문제가 재발하지 않는다.
          SizedBox(
            width: 335 * scale,
            height: 7 * scale,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.narLine2,
                      borderRadius: pillRadius,
                    ),
                  ),
                ),
                Align(
                  alignment: leftLeads
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: leaderRatio,
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.narBg,
                        borderRadius: pillRadius,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(leftRatio * 100).toStringAsFixed(1)}%',
                style: percentStyle,
              ),
              Text(
                '${(rightRatio * 100).toStringAsFixed(1)}%',
                style: percentStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
