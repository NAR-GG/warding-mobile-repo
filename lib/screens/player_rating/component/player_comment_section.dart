import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';

/// 한 선수 평점 코멘트.
class PlayerComment {
  const PlayerComment({
    required this.username,
    required this.timeAgo,
    required this.rating,
    this.comment,
    this.profileImageUrl,
    this.teamImageUrl,
  });

  /// 작성자 닉네임(예: 'Faker_팬티도둑').
  final String username;

  /// 상대 시간(예: '2시간 전').
  final String timeAgo;

  /// 부여한 평점(0~5).
  final double rating;

  /// 코멘트 본문. 없으면 별점만 노출.
  final String? comment;

  /// 작성자 프로필 이미지 URL. 없으면 placeholder.
  final String? profileImageUrl;

  /// 작성자 응원팀 이미지 URL(구독뱃지). 없으면 placeholder.
  final String? teamImageUrl;
}

/// 선수 평점 상세 — 평점/코멘트 헤더 + 코멘트 리스트.
///
/// 상단 헤더: 좌측 '평점·코멘트', 우측 '총 N개'.
/// 그 아래 코멘트 카드(프로필·닉네임·시간 / 별점 / 코멘트)를 narLine2 하단선으로 구분해 쌓는다.
/// 프로필 이미지와 구독뱃지(팀 이미지)는 비워 둔다(추후 연결).
class PlayerCommentSection extends StatelessWidget {
  const PlayerCommentSection({
    super.key,
    required this.comments,
    this.scale = 1,
  });

  final List<PlayerComment> comments;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더: 평점·코멘트 / 총 N개.
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l.ratingAndComment,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
              Text(
                l.totalCount(comments.length),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.4,
                  color: AppColors.narText2,
                ),
              ),
            ],
          ),
        ),
        for (final comment in comments)
          _CommentTile(comment: comment, scale: scale),
      ],
    );
  }
}

/// 코멘트 한 장. padding 16/0, gap 8, 하단 narLine2 구분선.
class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.scale});

  final PlayerComment comment;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hasComment = comment.comment != null && comment.comment!.isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16 * scale),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.narLine2, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 + 닉네임 + 시간.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _circleImage(comment.profileImageUrl, 37 * scale),
                    SizedBox(width: 5 * scale),
                    Flexible(
                      child: Text(
                        comment.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 14 * scale,
                          height: 1.45,
                          color: AppColors.narText,
                        ),
                      ),
                    ),
                    SizedBox(width: 5 * scale),
                    _circleImage(comment.teamImageUrl, 21 * scale),
                  ],
                ),
              ),
              SizedBox(width: 11 * scale),
              Text(
                comment.timeAgo,
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
          SizedBox(height: 8 * scale),
          NarStarRating(rating: comment.rating, scale: scale),
          if (hasComment) ...[
            SizedBox(height: 8 * scale),
            Text(
              comment.comment!,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 원형 이미지. [url] 이 없거나 로드 실패하면 narDark500 원형 placeholder 로 폴백.
Widget _circleImage(String? url, double size) {
  final placeholder = Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.narDark500,
      shape: BoxShape.circle,
    ),
  );
  if (url == null || url.isEmpty) return placeholder;
  return ClipOval(
    child: CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      errorWidget: (_, _, _) => placeholder,
    ),
  );
}
