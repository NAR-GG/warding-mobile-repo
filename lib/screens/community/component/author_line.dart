import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../model/team.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../community_dummy.dart';
import '../community_teams.dart';

/// 작성자 표기 — 닉네임 + 원형 팀 로고.
///
/// 선수 평점 댓글(`player_comment_section.dart`)과 같은 패턴이다. "T1 팬" 같은
/// 텍스트 태그는 쓰지 않는다.
///
/// [teamId] 는 **작성 시점** 응원팀이다. 작성자가 팀을 옮겨도 과거 글의 로고는
/// 바뀌지 않아야 하므로 현재 팀을 조회해 그리지 않는다.
/// [teamId] 가 null 이면 응원팀 없이 쓴 글이라 회색 원을 그린다.
///
/// [showTeam] 을 false 로 주면 로고를 생략한다 — 팀 게시판 목록처럼 전원이 같은
/// 팀이라 로고가 정보를 주지 않는 자리에서 쓴다.
class AuthorLine extends StatelessWidget {
  const AuthorLine({
    super.key,
    required this.name,
    required this.teamId,
    required this.scale,
    this.showTeam = true,
    this.logoSize = 13,
    this.fontSize = 11,
    this.color,
  });

  final String name;
  final int? teamId;
  final double scale;
  final bool showTeam;
  final double logoSize;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: fontSize * scale,
              height: 1.45,
              color: color ?? AppColors.narText3,
            ),
          ),
        ),
        if (showTeam) ...[
          SizedBox(width: 4 * scale),
          TeamLogoDot(teamId: teamId, size: logoSize * scale),
        ],
      ],
    );
  }
}

/// 원형 팀 로고.
///
/// 로고는 온보딩 팀 API 에서 받은 **실제** 이미지를 쓴다([communityTeams]).
/// 아직 안 받았거나 받기에 실패했으면 팀 대표색 원으로 떨어뜨린다 — 로고는
/// 장식이라 없다고 화면이 비면 안 된다.
class TeamLogoDot extends StatelessWidget {
  const TeamLogoDot({super.key, required this.teamId, required this.size});

  final int? teamId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final id = teamId;
    if (id == null) return _fallback(AppColors.narDark500);

    final color = Color(dummyBoard(id).color);

    return ValueListenableBuilder<List<Team>>(
      valueListenable: communityTeams,
      builder: (context, _, _) {
        final url = teamForBoard(id)?.imageUrl ?? '';
        if (url.isEmpty) return _fallback(color);

        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolveImageUrl(url) ?? url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 150),
            errorWidget: (_, _, _) => _fallback(color),
          ),
        );
      },
    );
  }

  Widget _fallback(Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.narDark400, width: 0.5),
    ),
  );
}
