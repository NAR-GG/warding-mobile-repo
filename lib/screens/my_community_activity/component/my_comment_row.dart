import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/board_badge.dart';
import '../../../model/community_my_activity.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';

/// "내가 쓴 댓글" 목록의 한 줄 — [배지] 원글 제목 · 댓글 본문(2줄) · 시각·추천수.
///
/// 탭하면 [comment.postId] 로 원글 상세를 연다. 원글이 삭제·블라인드되면
/// 서버가 이미 목록에서 빼주므로 `postId` 는 항상 유효한 이동 대상이다.
class MyCommentRow extends StatelessWidget {
  const MyCommentRow({
    super.key,
    required this.comment,
    required this.scale,
    required this.onTap,
  });

  final CommunityMyComment comment;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 20 * scale,
          vertical: 18 * scale,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.narLine, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [배지] 원글 제목.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BoardBadge(
                  boardTeamId: comment.boardTeamId,
                  boardTeamCode: comment.boardTeamCode,
                  scale: scale,
                ),
                SizedBox(width: 6 * scale),
                Expanded(
                  child: Text(
                    comment.postTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5 * scale,
                      height: 1.4,
                      color: AppColors.narText3,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6 * scale),
            // 댓글 본문.
            Text(
              comment.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 14.5 * scale,
                height: 1.4,
                color: AppColors.narText,
              ),
            ),
            SizedBox(height: 6 * scale),
            // 시각 · 추천수.
            Text(
              l.myCommunityCommentMeta(
                ratingTimeAgo(comment.createdAt),
                comment.likeCount,
              ),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 11 * scale,
                height: 1.45,
                color: AppColors.narText2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
