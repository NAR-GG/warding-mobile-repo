import 'package:flutter/material.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import 'home_section_header.dart';
import 'home_skeletons.dart';

/// 평점 — 최근 선수 한줄평. 커뮤니티 섹션과 같은 레이아웃(헤더 + 둥근
/// 목록 상자)을 쓰는 독립 섹션이다. 한줄평이 없으면([ReviewSource] 계약)
/// 섹션 전체를 그리지 않는다 — 커뮤니티 글이 없을 때와 달리 평점은 섹션
/// 자체가 선택적이라 헤더까지 숨긴다.
class HomeReviewSection extends StatelessWidget {
  const HomeReviewSection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onTapReview,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// 한줄평 탭 — 그 선수의 평점 상세(한줄평 목록)로 이동한다. 식별자
  /// (`gameId`·`participantId`·`playerId`) 가 없는 항목은 탭해도 아무 일도
  /// 하지 않는다.
  final void Function(HomeReviewItem review)? onTapReview;

  @override
  Widget build(BuildContext context) {
    final reviews = viewModel.reviews;
    if (reviews.isEmpty && !viewModel.reviewsLoading) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeReviewTitle,
            scale: scale,
            subtitle: l.homeSortLatest,
          ),
        ),
        SizedBox(height: 10 * scale),
        if (reviews.isEmpty)
          HomeListSkeleton(scale: scale)
        else
          HomeListBox(
            scale: scale,
            children: [
              for (final review in reviews)
                _ReviewTile(
                  review: review,
                  scale: scale,
                  onTap: onTapReview == null
                      ? null
                      : () => onTapReview!(review),
                ),
            ],
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.scale, this.onTap});

  final HomeReviewItem review;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 11 * scale,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamCodeBadge(teamCode: review.teamCode, size: 28 * scale),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.comment,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14 * scale,
                      color: AppColors.narText,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Row(
                    children: [
                      Text(
                        '★' * review.stars,
                        style: TextStyle(
                          fontSize: 12 * scale,
                          color: AppColors.narYellow6,
                        ),
                      ),
                      Text(
                        '☆' * (5 - review.stars),
                        style: TextStyle(
                          fontSize: 12 * scale,
                          color: AppColors.narLine2,
                        ),
                      ),
                      SizedBox(width: 4 * scale),
                      Expanded(
                        child: Text(
                          '${review.playerName} ${review.champion} · ${review.nickname} · ${(review.minutesAgo < 60 ? l.homeMinutesAgo(review.minutesAgo) : l.homeHoursAgo(review.minutesAgo ~/ 60))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11 * scale,
                            color: AppColors.narText2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
