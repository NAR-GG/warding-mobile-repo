import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../styles/app_colors.dart';

/// 게시판 배지 — `boardTeamCode` 로만 그린다(팀 목록 조회 없음).
///
/// 마이페이지 "내 활동"(내가 쓴 글·내가 쓴 댓글·스크랩)은 전체 게시판과 팀
/// 게시판 글이 한 목록에 섞여 나와 줄마다 어느 게시판인지 표시해야 한다.
/// `boardTeamId`만으로는 이름을 몰라 팀 목록을 따로 조회해야 하는데, 그
/// 조회가 실패하면 줄마다 붙는 배지가 통째로 사라진다. 그래서 서버가 같이
/// 내려주는 `boardTeamCode`를 그대로 쓴다.
///
/// - `boardTeamId == null` → '전체'.
/// - `boardTeamId != null` 인데 `boardTeamCode` 가 없으면(구버전 응답) 아무것도
///   그리지 않는다 — 틀린 코드를 보이는 것보다 낫다.
class BoardBadge extends StatelessWidget {
  const BoardBadge({
    super.key,
    required this.boardTeamId,
    required this.boardTeamCode,
    this.scale = 1,
  });

  final int? boardTeamId;
  final String? boardTeamCode;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final String? text = boardTeamId == null
        ? l.myCommunityBadgeAll
        : boardTeamCode;
    if (text == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark500,
        border: Border.all(color: AppColors.narLine),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 11 * scale,
          height: 1.3,
          color: AppColors.narText3,
        ),
      ),
    );
  }
}
