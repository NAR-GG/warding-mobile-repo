import 'package:flutter/material.dart';

import '../../../components/common_button.dart';
import '../../../components/nar_badge.dart';
import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';

/// 내 리뷰 한 건.
class MyReview {
  const MyReview({
    required this.league,
    required this.teamName,
    required this.playerName,
    required this.position,
    required this.side,
    required this.username,
    required this.timeAgo,
    required this.rating,
    this.raterCount = 0,
    this.comment,
    this.profileImageUrl,
    this.teamImageUrl,
    this.teamBadgeAsset,
  });

  /// 리그/시즌 (예: 'LCK 2025 스프링').
  final String league;

  /// 팀명 (예: 'T1').
  final String teamName;

  /// 선수명 (예: 'Faker').
  final String playerName;

  /// 포지션 (예: '미드').
  final String position;

  /// 진영(선수 평점 페이지 뱃지용).
  final BadgeSide side;

  /// 작성자 닉네임 (예: '전데요').
  final String username;

  /// 작성 시각 (예: '방금').
  final String timeAgo;

  /// 별점 (0~5).
  final double rating;

  /// 참여 인원(선수 평점 페이지용).
  final int raterCount;

  /// 리뷰 본문. null 이면 별점만.
  final String? comment;

  /// 작성자(나) 프로필 이미지 URL. 없으면 기본 아바타.
  final String? profileImageUrl;

  /// 작성자(나) 응원팀 로고 URL. 없으면 placeholder.
  final String? teamImageUrl;

  /// (구) 작성자 구독 팀 뱃지 로컬 자산. teamImageUrl 우선, 둘 다 없으면 placeholder.
  final String? teamBadgeAsset;

  /// 표시용 '팀 선수' (예: 'T1 Faker').
  String get playerTeam => '$teamName $playerName';
}

/// 내 리뷰/평점 — 일자 구분 헤더 (padding 10/20, narBgSecondary 배경).
class ReviewDateHeader extends StatelessWidget {
  const ReviewDateHeader({super.key, required this.date, this.scale = 1});

  final String date;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.narBgSecondary,
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      child: Text(
        date,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w500,
          fontSize: 14 * scale,
          height: 17 / 14,
          color: AppColors.narText,
        ),
      ),
    );
  }
}

/// 내 리뷰 카드 (narDark600 배경, padding 10/20).
///
/// 리그·선수 / 작성자·시각 / 별점 / (옵션) 본문 + 리뷰보기·리뷰삭제 버튼.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onView,
    this.onDelete,
    this.scale = 1,
  });

  final MyReview review;
  final VoidCallback? onView;
  final VoidCallback? onDelete;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final subStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w500,
      fontSize: 14 * scale,
      height: 17 / 14,
      color: AppColors.narText2,
    );

    return Container(
      width: double.infinity,
      color: AppColors.narDark600,
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 리그 · 선수 라인.
          Row(
            children: [
              Text(review.league, style: subStyle),
              SizedBox(width: 5 * scale),
              Text(review.playerTeam, style: subStyle),
            ],
          ),
          SizedBox(height: 8 * scale),
          // 작성자 라인: 아바타 + 닉네임 + 뱃지 ... 시각.
          Row(
            children: [
              _Avatar(url: review.profileImageUrl, size: 37 * scale),
              SizedBox(width: 5 * scale),
              Text(
                review.username,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
              SizedBox(width: 5 * scale),
              // 구독 뱃지 (팀 로고) — 없으면 placeholder.
              _SubscribeBadge(
                url: review.teamImageUrl,
                asset: review.teamBadgeAsset,
                scale: scale,
              ),
              const Spacer(),
              Text(
                review.timeAgo,
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
          // 별점.
          Align(
            alignment: Alignment.centerLeft,
            child: NarStarRating(rating: review.rating, scale: scale),
          ),
          // 본문 (옵션).
          if (review.comment != null) ...[
            SizedBox(height: 8 * scale),
            Text(
              review.comment!,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
            ),
          ],
          SizedBox(height: 16 * scale),
          // 리뷰보기 / 리뷰삭제 — 공용 버튼(dark/text), 폭 반반.
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  label: '리뷰보기',
                  variant: CommonButtonVariant.dark,
                  scale: scale,
                  onPressed: onView,
                ),
              ),
              SizedBox(width: 40 * scale),
              Expanded(
                child: CommonButton(
                  label: '리뷰삭제',
                  variant: CommonButtonVariant.text,
                  scale: scale,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 작성자 아바타 (37×37) — 프로필 URL 있으면 네트워크 이미지, 없거나 실패 시 기본 person 자산.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/person.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    return ClipOval(
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

/// 구독 뱃지 (21×21) — 팀 로고 URL > 로컬 자산 > 원형 placeholder 순.
class _SubscribeBadge extends StatelessWidget {
  const _SubscribeBadge({this.url, required this.asset, required this.scale});

  final String? url;
  final String? asset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 21 * scale;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.narDark200,
        shape: BoxShape.circle,
      ),
    );
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }
    if (asset != null) {
      return ClipOval(
        child: Image.asset(asset!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return placeholder;
  }
}
