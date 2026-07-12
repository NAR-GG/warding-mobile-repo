import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/nar_badge.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 경기 상세 — 챔피언 픽 탭 콘텐츠.
///
/// 위 BLUE 팀 프레임(밴 → 픽 → 진영/팀명) + 가운데 그라데이션 VS + 아래 RED 팀 프레임(진영/팀명 → 픽 → 밴).
/// 양 팀 프레임은 209.4 높이로, 가운데 VS 텍스트는 두 프레임의 경계를 살짝 덮으며 떠 있는다.
class MatchDetailChampionPickSection extends StatelessWidget {
  const MatchDetailChampionPickSection({
    super.key,
    required this.blueTeamName,
    required this.redTeamName,
    required this.blueBans,
    required this.redBans,
    required this.bluePicks,
    required this.redPicks,
    required this.bluePlayerNames,
    required this.redPlayerNames,
    this.scale = 1,
  });

  final String blueTeamName;
  final String redTeamName;

  /// 밴된 챔피언 5명의 이미지 URL. null/빈문자열이면 플레이스홀더.
  final List<String?> blueBans;
  final List<String?> redBans;

  /// 픽된 챔피언 5명의 이미지 URL. null/빈문자열이면 플레이스홀더.
  final List<String?> bluePicks;
  final List<String?> redPicks;

  /// 픽된 챔피언 위에 표시할 선수 5명의 이름.
  final List<String> bluePlayerNames;
  final List<String> redPlayerNames;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent,
      padding: EdgeInsets.symmetric(
        vertical: 16 * scale,
        horizontal: 10 * scale,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TeamPickFrame(
                side: BadgeSide.blue,
                teamName: blueTeamName,
                bans: blueBans,
                picks: bluePicks,
                playerNames: bluePlayerNames,
                scale: scale,
              ),
              SizedBox(height: 16 * scale),
              _TeamPickFrame(
                side: BadgeSide.red,
                teamName: redTeamName,
                bans: redBans,
                picks: redPicks,
                playerNames: redPlayerNames,
                scale: scale,
              ),
            ],
          ),
          // VS 텍스트 — BLUE 프레임 끝(209.4) 근처에 떠서 두 프레임 경계를 덮는다.
          // 시안: 콘텐츠 영역 top 190 기준. 컨테이너 padding-top 16 제외 시 174.
          Positioned(
            top: 174 * scale,
            child: _VsText(scale: scale),
          ),
        ],
      ),
    );
  }
}

/// 한 팀의 픽 프레임. BLUE 면 [밴, 픽, 팀행] 순서·왼쪽 정렬, RED 면 [팀행, 픽, 밴] 순서·오른쪽 정렬.
class _TeamPickFrame extends StatelessWidget {
  const _TeamPickFrame({
    required this.side,
    required this.teamName,
    required this.bans,
    required this.picks,
    required this.playerNames,
    required this.scale,
  });

  final BadgeSide side;
  final String teamName;
  final List<String?> bans;
  final List<String?> picks;
  final List<String> playerNames;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isBlue = side == BadgeSide.blue;

    final bansRow = _BansRow(bans: bans, scale: scale);
    final picksRow = _PicksRow(
      picks: picks,
      playerNames: playerNames,
      side: side,
      scale: scale,
    );
    final teamMetaRow = _TeamMetaRow(
      side: side,
      teamName: teamName,
      scale: scale,
    );

    final children = isBlue
        ? <Widget>[
            bansRow,
            SizedBox(height: 9 * scale),
            picksRow,
            SizedBox(height: 9 * scale),
            teamMetaRow,
          ]
        : <Widget>[
            teamMetaRow,
            SizedBox(height: 9 * scale),
            picksRow,
            SizedBox(height: 9 * scale),
            bansRow,
          ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 14 * scale,
        horizontal: 7 * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            isBlue ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: children,
      ),
    );
  }
}

/// 밴된 챔피언 5명 가로 행. 각 36.4×36.4, gap 2.
class _BansRow extends StatelessWidget {
  const _BansRow({required this.bans, required this.scale});

  final List<String?> bans;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < bans.length; i++) ...[
          if (i > 0) SizedBox(width: 2 * scale),
          _ChampionBan(imageUrl: bans[i], scale: scale),
        ],
      ],
    );
  }
}

/// 픽된 챔피언 5명 가로 행. 카드 60×101, 카드 간 간격 없음.
/// BLUE 면 왼쪽 정렬, RED 면 오른쪽 정렬.
class _PicksRow extends StatelessWidget {
  const _PicksRow({
    required this.picks,
    required this.playerNames,
    required this.side,
    required this.scale,
  });

  final List<String?> picks;
  final List<String> playerNames;
  final BadgeSide side;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isBlue = side == BadgeSide.blue;
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment:
            isBlue ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          for (var i = 0; i < picks.length; i++)
            _ChampionPick(
              imageUrl: picks[i],
              playerName: i < playerNames.length ? playerNames[i] : '',
              scale: scale,
            ),
        ],
      ),
    );
  }
}

/// 진영 뱃지 + 팀명 행. BLUE 면 [badge | name], RED 면 [name | badge] 로 spaceBetween 배치.
/// 폭은 픽 그리드 폭(5×60=300)에 맞춰, 부모 Column 의 cross-axis 정렬에 따라 그리드 끝에 정렬된다.
class _TeamMetaRow extends StatelessWidget {
  const _TeamMetaRow({
    required this.side,
    required this.teamName,
    required this.scale,
  });

  final BadgeSide side;
  final String teamName;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isBlue = side == BadgeSide.blue;
    final badge = NarBadgeSide(side: side, scale: scale);
    final name = Text(
      teamName,
      style: TextStyle(
        fontFamily: 'SF Pro',
        fontWeight: FontWeight.w600,
        fontSize: 22 * scale,
        height: 26 / 22,
        color: AppColors.narTextTertiary,
      ),
    );

    return SizedBox(
      width: 300 * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: isBlue ? [badge, name] : [name, badge],
      ),
    );
  }
}

class _ChampionBan extends StatelessWidget {
  const _ChampionBan({required this.imageUrl, required this.scale});

  final String? imageUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      width: 36.4 * scale,
      height: 36.4 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 이미지 + 슬래시는 둥근 모양으로 클립. 테두리는 이 클립 밖(아래 별도 레이어)에서
          // 그려서 모서리가 깎이지 않게 한다.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 챔피언 박스 — 배경 + 챔피언 이미지(풀컬러).
                  Positioned.fill(
                    child: Container(
                      color: AppColors.narDark400,
                      child: hasImage
                          ? CachedNetworkImage(
                              imageUrl: resolveImageUrl(imageUrl)!,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 150),
                              errorWidget: (_, _, _) => const SizedBox.shrink(),
                            )
                          : null,
                    ),
                  ),
                  // 대각선 슬래시(회색) — 36.4 박스 대각선(=√2배) 길이. OverflowBox 로 Stack 의
                  // max 제약(36.4)을 해제해 본래 51.5 폭으로 그려지게 한다. ClipRRect 가 둥근
                  // 모양으로 잘라서 슬래시는 박스 안에서만 그려진다.
                  OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 36.4 * scale * math.sqrt2,
                        height: 2 * scale,
                        color: AppColors.narGray500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 회색 테두리 — 클립 밖에서 그려 모서리가 잘리지 않는다.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.narGray500, width: 2 * scale),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 픽된 챔피언 카드 (60×101). 챔피언 스플래시 + 하단 인셋 섀도우 + 가운데 정렬 선수명.
class _ChampionPick extends StatelessWidget {
  const _ChampionPick({
    required this.imageUrl,
    required this.playerName,
    required this.scale,
  });

  final String? imageUrl;
  final String playerName;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: 60 * scale,
      height: 101 * scale,
      decoration: BoxDecoration(
        color: AppColors.narDark500,
        border: Border.all(color: AppColors.narLine, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (hasImage)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: resolveImageUrl(imageUrl)!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          // 인셋 섀도우 근사 — 중앙부터 하단까지 narDark800 62% 그라데이션.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, 0.1),
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x9E141517)],
                ),
              ),
            ),
          ),
          // 선수명 — 카드 하단 가까이 (시안 top 71.1 ≈ 카드 바닥에서 9px).
          Positioned(
            left: 0,
            right: 0,
            bottom: 9 * scale,
            child: Text(
              playerName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w700,
                fontSize: 14 * scale,
                height: 1.5,
                color: AppColors.narText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 가운데 'VS' 그라데이션 텍스트 (Pretendard 700 50px, indigo → red).
class _VsText extends StatelessWidget {
  const _VsText({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        // 시안 121.5deg ≈ 좌상단 → 우하단 방향에 가까움.
        begin: Alignment(-0.85, -0.52),
        end: Alignment(0.85, 0.52),
        colors: [Color(0xFF1971C2), Color(0xFFF03E3E)],
      ).createShader(bounds),
      child: Text(
        'vs',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: 50 * scale,
          height: 75 / 50,
          color: Colors.white,
        ),
      ),
    );
  }
}
