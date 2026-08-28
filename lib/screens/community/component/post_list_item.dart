import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../model/community_remote_post.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';
import 'author_line.dart';
import 'community_image.dart';

/// 글 목록의 한 줄 — 제목 · 본문 미리보기 2줄 · 메타 · (있으면) 사진 썸네일.
///
/// 팀 로고는 팀 게시판에서도 그린다. 전원이 같은 팀이라 정보량은 적지만,
/// 게시판마다 작성자 줄 모양이 달라지는 쪽이 더 어색하다.
class PostListItem extends StatelessWidget {
  const PostListItem({
    super.key,
    required this.post,
    required this.scale,
    required this.onTap,
  });

  final CommunityRemotePost post;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = post.thumbnailUrl;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
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
                  SizedBox(height: 4 * scale),
                  Text(
                    post.bodyPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      fontSize: 12.5 * scale,
                      height: 1.5,
                      color: AppColors.narText3,
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  // 추천 · 댓글 · 시간 · 작성자 순으로 왼쪽에 붙여 나열한다.
                  Row(
                    children: [
                      // 추천·댓글은 0 이면 아예 그리지 않는다. 아무도 반응하지
                      // 않은 글에 '0' 을 붙여두면 그 사실만 강조된다.
                      if (post.likeCount > 0) ...[
                        _iconMeta(
                          'assets/icons/thumb-up.svg',
                          '${post.likeCount}',
                          scale,
                          color: AppColors.narTextRed,
                        ),
                        SizedBox(width: 9 * scale),
                      ],
                      if (post.commentCount > 0) ...[
                        _iconMeta(
                          'assets/icons/message-circle.svg',
                          '${post.commentCount}',
                          scale,
                          color: AppColors.narChipActive,
                        ),
                        SizedBox(width: 9 * scale),
                      ],
                      _meta(ratingTimeAgo(post.createdAt), scale),
                      SizedBox(width: 9 * scale),
                      Flexible(
                        child: AuthorLine(author: post.author, scale: scale),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (thumb != null && thumb.isNotEmpty) ...[
              SizedBox(width: 12 * scale),
              CommunityImage(
                source: thumb,
                width: 62 * scale,
                height: 62 * scale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _meta(String text, double scale) => Text(
  text,
  style: TextStyle(
    fontFamily: 'Pretendard',
    fontWeight: FontWeight.w400,
    fontSize: 11 * scale,
    height: 1.45,
    color: AppColors.narText2,
  ),
);

Widget _iconMeta(
  String asset,
  String text,
  double scale, {
  required Color color,
}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SvgPicture.asset(
      asset,
      width: 13 * scale,
      height: 13 * scale,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
    SizedBox(width: 3 * scale),
    Text(
      text,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w600,
        fontSize: 11 * scale,
        height: 1.45,
        color: color,
      ),
    ),
  ],
);
