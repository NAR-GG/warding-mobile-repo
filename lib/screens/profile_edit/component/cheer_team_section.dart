import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 응원 팀 항목.
class CheerTeam {
  const CheerTeam({required this.name, this.logoAsset});

  final String name;

  /// 팀 로고 자산 경로. 없으면 placeholder.
  final String? logoAsset;
}

/// 응원 팀 설정 요약 행 (양옆 0, padding 상하 10, 높이 70).
///
/// 좌측: '응원 팀 설정' + 설명 문구.
/// 우측: 현재 선택된 팀 로고를 담은 46×46 다크 박스.
class CheerTeamSettingRow extends StatelessWidget {
  const CheerTeamSettingRow({
    super.key,
    this.selectedTeam,
    this.onTap,
    this.scale = 1,
  });

  final CheerTeam? selectedTeam;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 70 * scale,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '응원 팀 설정',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 16 * scale,
                      height: 25 / 16,
                      color: AppColors.narText,
                    ),
                  ),
                  Text(
                    '응원 팀 설정시 닉네임 옆에 뱃지가 생겨요',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 14 * scale,
                      height: 25 / 14,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10 * scale),
            // 현재 응원 팀 로고 박스.
            Container(
              width: 46 * scale,
              height: 46 * scale,
              padding: EdgeInsets.all(5 * scale),
              decoration: BoxDecoration(
                color: AppColors.narBgTertiary,
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: _TeamLogo(team: selectedTeam, size: 36 * scale),
            ),
          ],
        ),
      ),
    );
  }
}

/// 응원 팀 선택 리스트 (테두리 카드, 단일 선택).
///
/// 각 행: 좌측 로고+팀명, 우측 하트 토글.
/// 선택된(응원) 팀은 채워진 하트([heart.svg])와 [AppColors.narBgSecondary] 배경,
/// 나머지는 빈 하트([empty-heart.svg]).
class CheerTeamList extends StatelessWidget {
  const CheerTeamList({
    super.key,
    required this.teams,
    required this.selectedIndex,
    required this.onSelect,
    this.scale = 1,
  });

  final List<CheerTeam> teams;

  /// 선택된(응원) 팀 인덱스. null 이면 미설정(채워진 하트 없음).
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      // 테두리는 foregroundDecoration 으로 — 행 배경색이 테두리를 덮지 않게
      // child 위에 그린다(상단 라인 잘림 방지).
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: AppColors.narInputBorder),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < teams.length; i++)
            _CheerTeamRow(
              team: teams[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
              scale: scale,
            ),
        ],
      ),
    );
  }
}

/// 응원 팀 리스트의 한 행 (padding 8/20, 높이 60).
class _CheerTeamRow extends StatelessWidget {
  const _CheerTeamRow({
    required this.team,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  final CheerTeam team;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 60 * scale,
        color: selected ? AppColors.narBgSecondary : null,
        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 좌측: 로고 + 팀명.
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TeamLogo(team: team, size: 33 * scale),
                  SizedBox(width: 8 * scale),
                  Flexible(
                    child: Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 16 * scale,
                        height: 19 / 16,
                        letterSpacing: 0.21 * scale,
                        color: AppColors.narText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10 * scale),
            // 우측: 하트 토글 (44×44 탭 영역).
            SizedBox(
              width: 44 * scale,
              height: 44 * scale,
              child: Center(
                child: SvgPicture.asset(
                  selected
                      ? 'assets/icons/heart.svg'
                      : 'assets/icons/empty-heart.svg',
                  width: 20 * scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 팀 로고 — 자산이 있으면 이미지, 없으면 원형 placeholder.
class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.team, required this.size});

  final CheerTeam? team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = team?.logoAsset;
    if (asset == null) {
      // TODO: 팀 로고 이미지 연결 — 현재 원형 placeholder.
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.narDark200,
          shape: BoxShape.circle,
        ),
      );
    }
    return ClipOval(
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
    );
  }
}
