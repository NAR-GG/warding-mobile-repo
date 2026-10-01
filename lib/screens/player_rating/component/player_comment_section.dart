import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';

/// 한 선수 평점 코멘트.
class PlayerComment {
  const PlayerComment({
    required this.ratingId,
    required this.username,
    required this.timeAgo,
    required this.rating,
    this.comment,
    this.profileImageUrl,
    this.teamImageUrl,
  });

  /// 평가 ID. 홈 평점 섹션에서 들어왔을 때 그 한줄평으로 스크롤·하이라이트하는 데 쓴다.
  final int ratingId;

  /// 작성자 닉네임(예: 'Faker_팬티도둑').
  final String username;

  /// 상대 시간(예: '2시간 전').
  final String timeAgo;

  /// 부여한 평점(0~5).
  final double rating;

  /// 코멘트 본문. 없으면 별점만 노출.
  final String? comment;

  /// 작성자 프로필 이미지 URL. 없으면 기본 person 자산.
  final String? profileImageUrl;

  /// 작성자 응원팀 이미지 URL(구독뱃지). 없으면 placeholder.
  final String? teamImageUrl;
}

/// 선수 평점 상세 — 평점/코멘트 헤더 + 코멘트 리스트.
///
/// 상단 헤더: 좌측 '평점·코멘트', 우측 '총 N개'.
/// 그 아래 코멘트 카드(프로필·닉네임·시간 / 별점 / 코멘트)를 narLine2 하단선으로 구분해 쌓는다.
/// 프로필 이미지는 없으면 기본 person 자산, 구독뱃지(팀 이미지)는 비워 둔다(추후 연결).
class PlayerCommentSection extends StatelessWidget {
  const PlayerCommentSection({
    super.key,
    required this.comments,
    this.scale = 1,
    this.highlightRatingId,
    this.commentKeys,
  });

  final List<PlayerComment> comments;
  final double scale;

  /// 홈 평점 섹션에서 들어왔을 때 강조할 한줄평 ID. 없으면 평소대로 그린다.
  final int? highlightRatingId;

  /// [highlightRatingId] 로 스크롤하기 위한 타일 키. 호출부가 `ratingId → GlobalKey`
  /// 맵을 미리 만들어 넘기면, 로드된 리스트에서 해당 타일을 찾아 `ensureVisible` 할 수 있다.
  final Map<int, GlobalKey>? commentKeys;

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
          _CommentTile(
            key: commentKeys?[comment.ratingId],
            comment: comment,
            scale: scale,
            highlighted: comment.ratingId == highlightRatingId,
          ),
      ],
    );
  }
}

/// 코멘트 한 장. padding 16/0, gap 8, 하단 narLine2 구분선.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.scale,
    this.highlighted = false,
  });

  final PlayerComment comment;
  final double scale;

  /// 홈에서 이 한줄평을 보려고 들어왔을 때 배경을 강조한다.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final hasComment = comment.comment != null && comment.comment!.isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: highlighted ? 10 * scale : 0,
        vertical: 16 * scale,
      ),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.narBgTertiary : null,
        borderRadius: highlighted
            ? BorderRadius.circular(10 * scale)
            : BorderRadius.zero,
        border: highlighted
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.narLine2, width: 1),
              ),
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
                    _profileImage(comment.profileImageUrl, 32 * scale),
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
  final resolved = resolveImageUrl(url);
  if (resolved == null || resolved.isEmpty) return placeholder;
  return ClipOval(
    child: CachedNetworkImage(
      imageUrl: resolved,
      width: size,
      height: size,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      errorWidget: (_, _, _) => placeholder,
    ),
  );
}

/// 작성자 프로필 이미지. [url] 이 없거나 로드 실패하면 기본 person 자산으로 폴백.
Widget _profileImage(String? url, double size) {
  final fallback = Image.asset(
    'assets/images/person.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
  final resolved = resolveImageUrl(url);
  if (resolved == null || resolved.isEmpty) return ClipOval(child: fallback);
  return ClipOval(
    child: CachedNetworkImage(
      imageUrl: resolved,
      width: size,
      height: size,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      errorWidget: (_, _, _) => fallback,
    ),
  );
}
