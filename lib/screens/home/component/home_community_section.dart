import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/community_remote_post.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import 'home_section_header.dart';

/// 커뮤니티 — 유저가 쓴 글 목록.
///
/// 콘텐츠 섹션의 "뉴스" 탭처럼 정렬 칩 없이 헤더 부제로 현재 정렬만
/// 보여준다(2026-09-29 결정). 인기순(hot)은 글이 적을 때 늘 같은 글이 보여
/// 애초에 노출하지 않는다(spec 결정) — 관련 로직(순위·좋아요순 정렬)은
/// 남겨 뒀다가 글이 쌓이면 다시 켤 수 있다. 글 메타 줄의 추천·댓글 아이콘은
/// 커뮤니티 탭([PostListItem])과 같다. 평점 한줄평은 별도 섹션
/// ([HomeReviewSection])이다. 로딩·에러는 그리지 않는다 — 아직 없으면 목록
/// 자리를 비운다.
class HomeCommunitySection extends StatelessWidget {
  const HomeCommunitySection({
    super.key,
    required this.viewModel,
    required this.scale,
    this.onSeeAllCommunity,
    this.onTapPost,
  });

  final HomeViewModel viewModel;
  final double scale;

  /// "커뮤니티 전체" — 커뮤니티 탭으로 전환한다. 탭 루트끼리 쌓이지 않게
  /// 화면 전환은 홈 화면이 `pushReplacement` 로 한다.
  final VoidCallback? onSeeAllCommunity;

  /// 글 타일 탭 — 게시글 상세로 이동한다.
  final void Function(CommunityRemotePost post)? onTapPost;

  String _labelFor(AppLocalizations l, HomeCommunitySort sort) =>
      switch (sort) {
        HomeCommunitySort.latest => l.homeSortLatest,
        HomeCommunitySort.hot => l.homeSortHot,
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
            subtitle: _labelFor(l, viewModel.communitySort),
            trailingLabel: l.homeSeeAllCommunity,
            onTapTrailing: onSeeAllCommunity,
          ),
        ),
        SizedBox(height: 10 * scale),
        HomeListBox(
          scale: scale,
          children: [
            for (final (i, post) in viewModel.communityPosts.indexed)
              _PostTile(
                post: post,
                rank: viewModel.communitySort == HomeCommunitySort.hot
                    ? i + 1
                    : null,
                scale: scale,
                onTap: onTapPost == null ? null : () => onTapPost!(post),
              ),
          ],
        ),
      ],
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.post,
    required this.scale,
    this.rank,
    this.onTap,
  });

  final CommunityRemotePost post;

  /// 인기순이면 순위(1부터). 최신순이면 null.
  final int? rank;
  final double scale;
  final VoidCallback? onTap;

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
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
                    fontSize: 14 * scale,
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
                      fontSize: 16 * scale,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Row(
                    children: [
                      if (!hot) ...[
                        _metaText(_ago(l, post.createdAt), scale),
                        SizedBox(width: 8 * scale),
                      ],
                      if (post.likeCount > 0) ...[
                        _iconMeta(
                          'assets/icons/thumb-up.svg',
                          '${post.likeCount}',
                          scale,
                          color: AppColors.narTextRed,
                        ),
                        SizedBox(width: 8 * scale),
                      ],
                      if (post.commentCount > 0)
                        _iconMeta(
                          'assets/icons/message-circle.svg',
                          '${post.commentCount}',
                          scale,
                          color: AppColors.narChipActive,
                        ),
                      if (hot) ...[
                        SizedBox(width: 8 * scale),
                        _metaText(l.communityViewCount(post.viewCount), scale),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (post.thumbnailUrl != null) ...[
              SizedBox(width: 8 * scale),
              _PostThumbnail(url: post.thumbnailUrl, scale: scale),
            ],
          ],
        ),
      ),
    );
  }
}

/// 글 목록 오른쪽 썸네일. 이미지가 없거나 못 불러오면 빈 회색 자리만 그린다.
class _PostThumbnail extends StatelessWidget {
  const _PostThumbnail({required this.url, required this.scale});

  final String? url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveImageUrl(url);
    return Container(
      width: 44 * scale,
      height: 44 * scale,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narLine2,
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: resolved == null || resolved.isEmpty
          ? null
          : CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              memCacheWidth: (44 * scale * 3).round(),
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}

/// 시간·조회수 같은 아이콘 없는 메타 텍스트.
Widget _metaText(String text, double scale) => Text(
  text,
  style: TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 13 * scale,
    color: AppColors.narText2,
  ),
);

/// 추천·댓글 — 커뮤니티 탭([PostListItem])과 같은 아이콘+숫자 조합.
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
        fontSize: 13 * scale,
        color: color,
      ),
    ),
  ],
);
