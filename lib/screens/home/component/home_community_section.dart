import 'package:flutter/material.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/community_remote_post.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import '../../../model/home_models.dart';
import 'home_pill_tabs.dart';
import 'home_section_header.dart';

/// 커뮤니티 — 유저가 쓴 것(글·평점 한줄평). 최신순 / 인기순 / 평점 한줄평 3탭.
///
/// 기본 탭은 최신순이다 — 글이 적을 때 인기순이면 늘 같은 글이 보인다(spec
/// 결정). 평점은 한줄평이 달린 것만 온다([ReviewSource] 계약).
/// 로딩·에러는 그리지 않는다 — 아직 없으면 목록 자리를 비운다.
class HomeCommunitySection extends StatelessWidget {
  const HomeCommunitySection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onSeeAllCommunity,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// "커뮤니티 전체" — 커뮤니티 탭으로 전환한다. 탭 루트끼리 쌓이지 않게
  /// 화면 전환은 홈 화면이 `pushReplacement` 로 한다.
  final VoidCallback? onSeeAllCommunity;

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
            onTapTrailing: onSeeAllCommunity,
          ),
        ),
        SizedBox(height: 10 * scale),
        HomePillTabs<HomeCommunitySort>(
          tabs: [
            // 한줄평이 없으면(릴리즈 빈 소스) 평점 탭을 그리지 않는다.
            for (final sort in viewModel.availableCommunitySorts)
              HomePillTab(value: sort, label: _labelFor(l, sort)),
          ],
          selected: viewModel.communitySort,
          onSelected: viewModel.setCommunitySort,
          scale: scale,
        ),
        _ListBox(
          scale: scale,
          children: viewModel.communitySort == HomeCommunitySort.review
              ? [
                  for (final review in viewModel.reviews)
                    _ReviewTile(review: review, scale: scale),
                ]
              : [
                  for (final (i, post) in viewModel.communityPosts.indexed)
                    _PostTile(
                      post: post,
                      rank: viewModel.communitySort == HomeCommunitySort.hot
                          ? i + 1
                          : null,
                      scale: scale,
                    ),
                ],
        ),
      ],
    );
  }
}

/// 목록을 담는 둥근 상자 — 행 사이는 구분선. 비어 있으면 아무것도 그리지 않는다.
class _ListBox extends StatelessWidget {
  const _ListBox({required this.children, required this.scale});

  final List<Widget> children;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * scale),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.narLine),
            child,
          ],
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.scale, this.rank});

  final CommunityRemotePost post;

  /// 인기순이면 순위(1부터). 최신순이면 null.
  final int? rank;
  final double scale;

  bool get hot => rank != null;

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
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 11 * scale,
      ),
      child: Row(
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 18 * scale,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * scale,
                  color: AppColors.narDark200,
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
          ],
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
                    fontWeight: FontWeight.w500,
                    fontSize: 14 * scale,
                    color: AppColors.narTextTertiary,
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
              width: 44 * scale,
              height: 44 * scale,
              decoration: BoxDecoration(
                color: AppColors.narLine2,
                borderRadius: BorderRadius.circular(8 * scale),
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
    );
  }
}
