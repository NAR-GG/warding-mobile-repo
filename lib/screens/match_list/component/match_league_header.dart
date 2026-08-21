import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import '../../../util/league_icon.dart';

/// 경기 리스트의 리그 그룹 헤더. 리그 로고 + 리그명.
///
/// 리그 필터가 '전체'일 때만 쓴다 — 같은 날짜 헤더 아래에서도 리그가 섞여
/// 있으면 어느 리그 경기인지 구분이 안 되므로, 날짜 그룹 안을 리그별로 다시
/// 묶어 그 앞에 붙인다.
class MatchLeagueHeader extends StatelessWidget {
  const MatchLeagueHeader({
    super.key,
    required this.leagueName,
    this.scale = 1,
  });

  /// 리그명(=서버 리그 코드). 예: 'LCK'.
  final String leagueName;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final icon = leagueIconWidget(leagueName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 20 * scale,
            right: 20 * scale,
            bottom: 4 * scale,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                // 시안 '경기 로고' 프레임 50×50(패딩 10) — 카드 팀 로고(50×50)와 세로로 맞춘다.
                SizedBox(
                  width: 50 * scale,
                  height: 50 * scale,
                  child: Center(
                    child: SizedBox(
                      width: 30 * scale,
                      height: 30 * scale,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          AppColors.narText,
                          BlendMode.srcIn,
                        ),
                        child: icon,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10 * scale),
              ],
              Text(
                leagueName,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
                  fontSize: 18 * scale,
                  height: 21 / 18,
                  color: AppColors.narText,
                ),
              ),
            ],
          ),
        ),
        // 리그 헤더 밑 시작줄 겸 구분줄(시안 'Line 16') — 왼쪽 흰색에서 오른쪽
        // 어두운 색으로 옅어지는 그라데이션. border 로는 그라데이션을 못 그려
        // 별도 Container 를 얹는다. 카드 쪽(showTopBorder)엔 안 그린다 — 이
        // 줄과 카드 위 구분선이 겹쳐 보이면 안 되므로.
        Container(
          height: 2 * scale,
          decoration: const BoxDecoration(gradient: AppColors.narFadeLine),
        ),
      ],
    );
  }
}
