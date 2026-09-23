import 'package:flutter/material.dart';

import '../../../components/nar_chip_multi_select.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/community_remote_post.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import '../../../model/home_models.dart';
import '../../community/community_screen.dart';
import 'home_section_header.dart';

/// 커뮤니티 — 최신순 / 인기순 / 평점 한줄평 3탭.
class HomeCommunitySection extends StatelessWidget {
  const HomeCommunitySection({
    super.key,
    required this.viewModel,
    required this.scale,
  });

  final HomeViewModel viewModel;
  final double scale;

  String _labelFor(AppLocalizations l, HomeCommunitySort sort) =>
      switch (sort) {
        HomeCommunitySort.latest => l.homeSortLatest,
        HomeCommunitySort.hot => l.homeSortHot,
        HomeCommunitySort.review => l.homeSortReview,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeCommunityTitle,
            scale: scale,
            trailingLabel: l.homeSeeAllCommunity,
            onTapTrailing: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
          ),
        ),
        // NarChipMultiSelect 는 자체 16*scale 좌우 패딩을 갖는 공용 컴포넌트라
        // 다른 자식처럼 20*scale 로 감싸지 않고 그대로 둔다.
        NarChipMultiSelect(
          options: [for (final s in HomeCommunitySort.values) s.name],
          selectedValues: {viewModel.communitySort.name},
          labelBuilder: (v) => _labelFor(l, HomeCommunitySort.values.byName(v)),
          scale: scale,
          onChanged: (next) {
            final added = next.difference({viewModel.communitySort.name});
            if (added.isNotEmpty) {
              viewModel.setCommunitySort(
                HomeCommunitySort.values.byName(added.first),
              );
            }
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: viewModel.communitySort == HomeCommunitySort.review
              ? Column(
                  children: [
                    for (final review in viewModel.reviews)
                      _ReviewTile(review: review, scale: scale),
                  ],
                )
              : Column(
                  children: [
                    for (final post in viewModel.communityPosts)
                      _PostTile(
                        post: post,
                        hot: viewModel.communitySort == HomeCommunitySort.hot,
                        scale: scale,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.hot, required this.scale});

  final CommunityRemotePost post;
  final bool hot;
  final double scale;

  String _ago(AppLocalizations l, DateTime? at) {
    if (at == null) return '';
    final h = DateTime.now().difference(at).inHours;
    if (h < 1) return l.homeJustNow;
    if (h < 24) return l.homeHoursAgo(h);
    return l.homeDaysAgo((h / 24).round());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeamCodeBadge(
            teamCode: post.author?.teamCode ?? 'LoL',
            size: 28 * scale,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    color: AppColors.narText,
                  ),
                ),
                SizedBox(height: 2 * scale),
                Text(
                  hot
                      ? '♥ ${post.likeCount} · ${l.communityCommentCount(post.commentCount)} · ${l.communityViewCount(post.viewCount)}'
                      : '${_ago(l, post.createdAt)} · ${l.communityCommentCount(post.commentCount)}',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11 * scale,
                    color: AppColors.narText2,
                  ),
                ),
              ],
            ),
          ),
          if (post.thumbnailUrl != null) ...[
            SizedBox(width: 8 * scale),
            Container(
              width: 40 * scale,
              height: 40 * scale,
              decoration: BoxDecoration(
                color: AppColors.narBgLast,
                borderRadius: BorderRadius.circular(6 * scale),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.scale});

  final HomeReviewItem review;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
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
                        fontSize: 11 * scale,
                        color: AppColors.narYellow6,
                      ),
                    ),
                    Text(
                      '☆' * (5 - review.stars),
                      style: TextStyle(
                        fontSize: 11 * scale,
                        color: AppColors.narLine2,
                      ),
                    ),
                    SizedBox(width: 4 * scale),
                    Expanded(
                      child: Text(
                        '${review.playerName} ${review.champion} · ${review.nickname} · ${l.homeMinutesAgo(review.minutesAgo)}',
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
    );
  }
}
