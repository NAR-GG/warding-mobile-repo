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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 14 * scale),
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(
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
            SizedBox(width: 8 * scale),
          ],
          Text(
            leagueName,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              fontSize: 20 * scale,
              height: 24 / 20,
              color: AppColors.narText,
            ),
          ),
        ],
      ),
    );
  }
}
