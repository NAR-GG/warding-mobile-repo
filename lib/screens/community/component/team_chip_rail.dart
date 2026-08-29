import 'package:flutter/material.dart';

import '../../../model/team.dart';
import '../../../styles/app_colors.dart';
import 'author_line.dart';

/// 팀 게시판 전환용 가로 칩 레일.
///
/// 내 응원팀([myTeamId])이 맨 앞에 고정되고 별표가 붙는다 — 팀 탭에서 가장 자주
/// 누르는 게 자기 팀이라 스크롤 없이 닿아야 한다.
class TeamChipRail extends StatelessWidget {
  const TeamChipRail({
    super.key,
    required this.teams,
    required this.selectedId,
    required this.myTeamId,
    required this.scale,
    required this.onSelected,
  });

  final List<Team> teams;
  final int? selectedId;
  final int? myTeamId;
  final double scale;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ordered = [...teams];
    final mine = myTeamId;
    if (mine != null) {
      final index = ordered.indexWhere((t) => t.id == mine);
      if (index > 0) ordered.insert(0, ordered.removeAt(index));
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.narLine, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: 20 * scale,
          vertical: 10 * scale,
        ),
        child: Row(
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              if (i > 0) SizedBox(width: 6 * scale),
              _Chip(
                team: ordered[i],
                selected: ordered[i].id == selectedId,
                isMine: mine != null && ordered[i].id == mine,
                scale: scale,
                onTap: () => onSelected(ordered[i].id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.team,
    required this.selected,
    required this.isMine,
    required this.scale,
    required this.onTap,
  });

  final Team team;
  final bool selected;
  final bool isMine;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 11 * scale,
          vertical: 5 * scale,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.narChipSelectedBg : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.narChipActive : AppColors.narLine2,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine) ...[
              Icon(
                Icons.star_rounded,
                size: 11 * scale,
                color: AppColors.narYellow6,
              ),
              SizedBox(width: 3 * scale),
            ],
            TeamLogoDot(imageUrl: team.imageUrl, size: 14 * scale),
            SizedBox(width: 5 * scale),
            Text(
              // 팀 이름이 아니라 코드. 'Hanwha Life Esports' 칩 하나가 레일을
              // 혼자 다 먹으면 나머지 팀은 스크롤해야 나온다.
              team.code.isNotEmpty ? team.code : team.name,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 12 * scale,
                height: 1.45,
                color: selected ? AppColors.narText : AppColors.narText3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
