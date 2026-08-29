import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/community_author.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 작성자 표기 — 닉네임 + 원형 팀 로고.
///
/// 선수 평점 댓글(`player_comment_section.dart`)과 같은 패턴이다. "T1 팬" 같은
/// 텍스트 태그는 쓰지 않는다.
///
/// [author] 의 팀은 **작성 시점** 응원팀이다(서버가 글 행에 박아 둔다). 작성자가
/// 팀을 옮겨도 과거 글의 로고는 바뀌지 않는다.
/// [author] 가 null 이면 탈퇴한 회원의 글이다.
///
/// [showTeam] 을 false 로 주면 로고를 생략한다 — 팀 게시판 목록처럼 전원이 같은
/// 팀이라 로고가 정보를 주지 않는 자리에서 쓴다.
class AuthorLine extends StatelessWidget {
  const AuthorLine({
    super.key,
    required this.author,
    required this.scale,
    this.showTeam = true,
    this.logoSize = 13,
    this.fontSize = 11,
    this.color,
  });

  final CommunityAuthor? author;
  final double scale;
  final bool showTeam;
  final double logoSize;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = author?.nickname ?? l.communityDeletedAuthor;

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
        if (showTeam && author?.teamId != null) ...[
          SizedBox(width: 4 * scale),
          TeamLogoDot(imageUrl: author?.teamImageUrl, size: logoSize * scale),
        ],
      ],
    );
  }
}

/// 원형 팀 로고. URL 이 없거나 로딩에 실패하면 회색 원으로 떨어진다 — 로고는
/// 장식이라 없다고 자리가 비면 안 된다.
class TeamLogoDot extends StatelessWidget {
  const TeamLogoDot({super.key, required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? '';
    if (url.isEmpty) return _fallback();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolveImageUrl(url) ?? url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.narDark500,
      shape: BoxShape.circle,
    ),
  );
}
