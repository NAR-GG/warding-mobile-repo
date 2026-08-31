import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/profile_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/community_remote_comment.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';
import 'author_line.dart';

/// 댓글 한 줄. 답글([CommunityRemoteComment.parentId] 이 있는 것)이면
/// [isReply] 가 true 이고 왼쪽으로 한 단 들여쓴다.
///
/// 들여쓰기는 딱 한 단까지다. 답글에 달린 답글도 같은 층에 쌓이고, 대신 본문
/// 앞에 `@닉네임` 멘션이 붙는다 — 좁은 화면에서 무한 depth 는 읽을 수가 없다.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.scale,
    required this.isReply,
    required this.onLike,
    required this.onReply,
    required this.onMore,
  });

  final CommunityRemoteComment comment;
  final double scale;
  final bool isReply;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final avatar = (isReply ? 24.0 : 28.0) * scale;
    final mention = comment.mentionNickname;

    // 삭제·차단·숨김 댓글은 본문과 작성자가 안 온다. 행 자체는 남긴다 —
    // 지우면 그 아래 답글들이 누구에게 단 건지 알 수 없게 된다.
    if (comment.status != CommunityCommentStatus.visible) {
      return _Placeholder(
        text: switch (comment.status) {
          CommunityCommentStatus.deleted => l.communityCommentDeleted,
          CommunityCommentStatus.blocked => l.communityCommentBlocked,
          _ => l.communityCommentHidden,
        },
        isReply: isReply,
        scale: scale,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: (isReply ? 40.0 : 20.0) * scale,
        right: 20 * scale,
        top: 10 * scale,
        bottom: 10 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(url: comment.author?.profileImageUrl, size: avatar),
          SizedBox(width: 9 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AuthorLine(
                        author: comment.author,
                        scale: scale,
                        fontSize: 12,
                        // 내가 쓴 댓글은 닉네임을 멘션·답글과 같은 보라색으로 둬서
                        // 목록을 훑을 때 내 글만 바로 눈에 띄게 한다.
                        color: comment.mine
                            ? AppColors.narViolet3
                            : AppColors.narText,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onMore,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                        child: SvgPicture.asset(
                          'assets/icons/dots.svg',
                          width: 15 * scale,
                          height: 15 * scale,
                          colorFilter: const ColorFilter.mode(
                            AppColors.narText2,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3 * scale),
                Text.rich(
                  TextSpan(
                    children: [
                      if (mention != null)
                        TextSpan(
                          text: '@$mention ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.narViolet3,
                          ),
                        ),
                      TextSpan(text: comment.body ?? ''),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 13 * scale,
                    height: 1.5,
                    color: AppColors.narText3,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Row(
                  children: [
                    Text(
                      comment.edited
                          ? '${ratingTimeAgo(comment.createdAt)} · ${l.communityEdited}'
                          : ratingTimeAgo(comment.createdAt),
                      style: _metaStyle(scale),
                    ),
                    SizedBox(width: 12 * scale),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            comment.liked
                                ? 'assets/icons/thumb-up-filled.svg'
                                : 'assets/icons/thumb-up.svg',
                            width: 12 * scale,
                            height: 12 * scale,
                            colorFilter: ColorFilter.mode(
                              comment.liked
                                  ? AppColors.narTextRed
                                  : AppColors.narText2,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: 4 * scale),
                          Text(
                            '${comment.likeCount}',
                            style: _metaStyle(scale),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReply,
                      child: Text(l.communityReply, style: _metaStyle(scale)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 삭제·차단·숨김 댓글 자리. 작성자도 본문도 없으니 회색 한 줄로 둔다.
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.text,
    required this.isReply,
    required this.scale,
  });

  final String text;
  final bool isReply;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final avatar = (isReply ? 24.0 : 28.0) * scale;

    // 일반 댓글 행과 같은 골격·타이포를 그대로 쓰고 색만 죽인다 — 박스·아이콘
    // 같은 별도 장식은 주변 댓글들과 톤이 어긋난다(1.0.23 피드백 두 번).
    return Padding(
      padding: EdgeInsets.only(
        left: (isReply ? 40.0 : 20.0) * scale,
        right: 20 * scale,
        top: 10 * scale,
        bottom: 10 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 실제 행과 같은 기본 아바타(회색 사람 원) — 좌측 정렬 유지.
          ProfileAvatar(url: null, size: avatar),
          SizedBox(width: 9 * scale),
          Expanded(
            child: Text(
              text,
              // 본문과 같은 서체·크기, 색만 보조 텍스트로.
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 13 * scale,
                height: 1.5,
                color: AppColors.narText2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "답글 N개" 접기·펼치기 줄. 기본은 접힌 상태다.
class ReplyToggle extends StatelessWidget {
  const ReplyToggle({
    super.key,
    required this.count,
    required this.expanded,
    required this.scale,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 49 * scale,
          right: 20 * scale,
          top: 2 * scale,
          bottom: 8 * scale,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 15 * scale,
              color: AppColors.narViolet3,
            ),
            SizedBox(width: 4 * scale),
            Text(
              l.communityReplyCount(count),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 12 * scale,
                height: 1.45,
                color: AppColors.narViolet3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _metaStyle(double scale) => TextStyle(
  fontFamily: 'Pretendard',
  fontWeight: FontWeight.w400,
  fontSize: 11 * scale,
  height: 1.45,
  color: AppColors.narText2,
);
