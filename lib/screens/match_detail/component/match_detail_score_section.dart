import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/nar_badge.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 경기 상세 페이지 스코어 칸.
///
/// 구성:
/// - 상단 메타 행: 리그명 · 날짜 / 우측 LIVE 뱃지(경기중) 또는 시간 뱃지.
/// - 16 간격 아래 팀 행: [BLUE 진영팀] · 스코어(중앙) · [RED 진영팀], 좌우 32 간격.
class MatchDetailScoreSection extends StatelessWidget {
  const MatchDetailScoreSection({
    super.key,
    required this.leagueName,
    required this.dateText,
    required this.isLive,
    required this.time,
    required this.blueTeamName,
    required this.redTeamName,
    required this.blueTeamScore,
    required this.redTeamScore,
    this.blueTeamLogoUrl,
    this.redTeamLogoUrl,
    this.setLabel,
    this.scale = 1,
  });

  final String leagueName;
  final String dateText;
  final bool isLive;

  /// 예정/종료 경기에서 LIVE 자리에 표시할 시간 라벨. 예: '17:00'.
  /// 비어 있으면 뱃지를 표시하지 않는다.
  final String time;

  final String blueTeamName;
  final String redTeamName;
  final int blueTeamScore;
  final int redTeamScore;
  final String? blueTeamLogoUrl;
  final String? redTeamLogoUrl;

  /// 라이브 경기일 때 스코어 아래에 표시할 라벨. 예: 'SET 1 진행중'.
  final String? setLabel;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final metaTextStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w500,
      fontSize: 14 * scale,
      height: 17 / 14,
      color: AppColors.narText,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: 16 * scale,
        left: 20 * scale,
        right: 20 * scale,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 리그명 + 날짜를 하나의 Expanded 로 묶어 남는 공간을 모두 차지하게 한다.
              // (Flexible 과 Spacer 를 따로 두면 둘이 flex 를 반씩 나눠 가져,
              //  리그명이 짧을 때 남는 몫이 뱃지 뒤 빈 공간으로 깔려 뱃지가 우측 끝에서
              //  밀려나 아래 버튼과 라인이 어긋난다.)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        leagueName,
                        style: metaTextStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // dateText 가 있을 때만 점 구분자 + 날짜를 함께 표시한다.
                    if (dateText.isNotEmpty) ...[
                      SizedBox(width: 8 * scale),
                      Container(
                        width: 4 * scale,
                        height: 4 * scale,
                        decoration: const BoxDecoration(
                          color: AppColors.narTextTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Text(dateText, style: metaTextStyle),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              if (isLive)
                NarBadgeLive(scale: scale)
              else if (time.isNotEmpty)
                NarBadge(label: time, scale: scale),
            ],
          ),
          SizedBox(height: 16 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TeamColumn(
                side: BadgeSide.blue,
                name: blueTeamName,
                logoUrl: blueTeamLogoUrl,
                scale: scale,
              ),
              SizedBox(width: 32 * scale),
              _ScoreColumn(
                homeScore: blueTeamScore,
                awayScore: redTeamScore,
                setLabel: isLive ? setLabel : null,
                scale: scale,
              ),
              SizedBox(width: 32 * scale),
              _TeamColumn(
                side: BadgeSide.red,
                name: redTeamName,
                logoUrl: redTeamLogoUrl,
                scale: scale,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 진영 뱃지 + 로고 박스(80×80) + 팀명(폭 80) 한 컬럼.
class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.side,
    required this.name,
    required this.logoUrl,
    required this.scale,
  });

  final BadgeSide side;
  final String name;
  final String? logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NarBadgeSide(side: side, scale: scale),
        SizedBox(height: 8 * scale),
        Container(
          width: 80 * scale,
          height: 80 * scale,
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: hasLogo
              ? CachedNetworkImage(
                  imageUrl: resolveImageUrl(logoUrl)!,
                  width: 60 * scale,
                  height: 60 * scale,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 150),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                )
              : null,
        ),
        SizedBox(height: 8 * scale),
        SizedBox(
          width: 80 * scale,
          child: Text(
            name,
            textAlign: TextAlign.center,
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

/// 가운데 스코어 + (라이브 시) SET 라벨 컬럼.
/// 승자 스코어는 red/7(narTextScore), 패자는 gray/1(scoreTextSub), 콜론은 narText2.
class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.homeScore,
    required this.awayScore,
    required this.setLabel,
    required this.scale,
  });

  final int homeScore;
  final int awayScore;
  final String? setLabel;
  final double scale;

  Color _colorFor(int self, int other) {
    if (self > other) return AppColors.narTextScore;
    if (self < other) return AppColors.scoreTextSub;
    return AppColors.scoreTextSub;
  }

  TextStyle _scoreStyle(Color color) => TextStyle(
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w700,
    fontSize: 36 * scale,
    height: 43 / 36,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    final hasLabel = setLabel != null && setLabel!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$homeScore',
              style: _scoreStyle(_colorFor(homeScore, awayScore)),
            ),
            SizedBox(width: 14 * scale),
            Text(':', style: _scoreStyle(AppColors.narText2)),
            SizedBox(width: 14 * scale),
            Text(
              '$awayScore',
              style: _scoreStyle(_colorFor(awayScore, homeScore)),
            ),
          ],
        ),
        if (hasLabel) ...[
          SizedBox(height: 8 * scale),
          Text(
            setLabel!,
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 16 / 14,
              color: AppColors.narTextScore,
            ),
          ),
        ],
      ],
    );
  }
}
