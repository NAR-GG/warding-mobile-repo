import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/nar_chip_multi_select.dart';
import '../../../components/nar_tab_bar.dart';
import '../../../components/dashed_border.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import '../../../viewmodel/shorts/shorts_feed_viewmodel.dart';
import '../../shorts/shorts_feed_screen.dart';
import 'home_section_header.dart';
import 'home_skeletons.dart';

export '../../../util/shorts_url.dart' show shortsLaunchUri;

/// 콘텐츠 — 밖에서 온 것(뉴스·쇼츠). 평점 한줄평은 유저가 쓴 것이라 커뮤니티
/// 섹션 탭에 있다(spec 결정: 섹션을 둘로 나눈다).
///
/// 기본 탭은 뉴스다(spec 결정). 뉴스가 없으면 뉴스 탭을 숨기고 쇼츠만 둔다. 쇼츠 "내 선수" 같은 필터가 0건이면 점선 박스를
/// 보여준다(spec "상태" 표). 로딩·에러는 그리지 않는다.
///
/// 쇼츠를 누르면 앱 안 전체화면 세로 피드([ShortsFeedScreen])가 열린다.

class HomeContentSection extends StatelessWidget {
  const HomeContentSection({
    super.key,
    required this.viewModel,
    required this.scale,
  });

  final HomeViewModel viewModel;
  final double scale;

  static const Key shortsEmptyKey = ValueKey('homeShortsEmpty');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tab = viewModel.contentTab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(
            title: l.homeContentTitle,
            scale: scale,
            subtitle: tab == HomeContentTab.news ? l.homeSortLatest : null,
          ),
        ),
        SizedBox(height: 2 * scale),
        NarChipMultiSelect.single(
          // 뉴스가 없으면(릴리즈 빈 소스) 뉴스 탭을 그리지 않는다.
          options: [for (final t in viewModel.availableContentTabs) t.name],
          selected: tab.name,
          onSelected: (name) =>
              viewModel.setContentTab(HomeContentTab.values.byName(name)),
          labelBuilder: (name) => switch (HomeContentTab.values.byName(name)) {
            HomeContentTab.news => l.homeContentTabNews,
            HomeContentTab.shorts => l.homeContentTabShorts,
          },
          horizontalPadding: 20,
          scale: scale,
        ),
        if (tab == HomeContentTab.news)
          viewModel.newsLoading && viewModel.news.isEmpty
              ? HomeNewsSkeleton(scale: scale)
              : _NewsList(articles: viewModel.news, scale: scale)
        else
          _ShortsDeck(viewModel: viewModel, scale: scale),
      ],
    );
  }
}

class _NewsList extends StatelessWidget {
  const _NewsList({required this.articles, required this.scale});

  final List<HomeNewsArticle> articles;
  final double scale;

  String _ago(AppLocalizations l, int minutes) {
    if (minutes < 60) return l.homeMinutesAgo(minutes);
    if (minutes < 60 * 24) return l.homeHoursAgo(minutes ~/ 60);
    return l.homeDaysAgo(minutes ~/ (60 * 24));
  }

  /// 기사 원문을 외부 브라우저로 연다. URL 이 없으면 아무 일도 하지 않는다.
  Future<void> _open(HomeNewsArticle article) async {
    final url = article.postUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
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
          for (final (i, article) in articles.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.narLine),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(article),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 13 * scale,
                  vertical: 11 * scale,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NewsThumbnail(url: article.thumbnailUrl, scale: scale),
                    SizedBox(width: 11 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15 * scale,
                              height: 1.4,
                              color: AppColors.narTextTertiary,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            '${article.office} · ${_ago(l, article.minutesAgo)}',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13 * scale,
                              color: AppColors.narDark200,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 뉴스 행 왼쪽 썸네일. 이미지가 없거나 못 불러오면 빈 자리만 그린다.
class _NewsThumbnail extends StatelessWidget {
  const _NewsThumbnail({required this.url, required this.scale});

  final String? url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveImageUrl(url);
    return Container(
      width: 62 * scale,
      height: 47 * scale,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.narBgLast,
        borderRadius: BorderRadius.circular(7 * scale),
      ),
      child: resolved == null || resolved.isEmpty
          ? null
          : CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              memCacheWidth: (62 * scale * 3).round(),
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}

class _ShortsDeck extends StatelessWidget {
  const _ShortsDeck({required this.viewModel, required this.scale});

  final HomeViewModel viewModel;
  final double scale;

  /// 탭한 카드부터 전체화면 피드를 연다. 닫으면 홈으로 돌아와 스크롤 위치는 그대로다.
  void _openFeed(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ShortsFeedScreen(
          initialVideos: viewModel.shortsVideosFiltered,
          startIndex: index,
          filter: viewModel.shortsFilter == HomeShortsFilter.team
              ? ShortsFeedFilter.team
              : ShortsFeedFilter.all,
          initialPageSize: viewModel.shortsFetchSize,
          resolveTeamCode: viewModel.preferredTeamCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final videos = viewModel.shortsFiltered;

    final filterLabels = [
      for (final f in HomeShortsFilter.values)
        switch (f) {
          HomeShortsFilter.all => l.homeShortsFilterAll,
          HomeShortsFilter.team => l.homeShortsFilterTeam,
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 경기 상세(경기 데이터·라이브 이벤트·선수 평점)와 같은 탭 스타일로
        // 통일한다 — 칩(NarChipMultiSelect)이 아니라 밑줄 강조 탭.
        NarTabBar(
          tabs: filterLabels,
          selectedIndex: HomeShortsFilter.values.indexOf(
            viewModel.shortsFilter,
          ),
          onChanged: (i) =>
              viewModel.setShortsFilter(HomeShortsFilter.values[i]),
          variant: NarTabBarVariant.compact,
          compactHorizontalPadding: 20,
          scale: scale,
        ),
        SizedBox(height: 8 * scale),
        if (viewModel.shortsLoading)
          _ShortsDeckSkeleton(scale: scale)
        else if (videos.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: KeyedSubtree(
              key: HomeContentSection.shortsEmptyKey,
              child: DashedBorder(
                radius: 10 * scale,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 120 * scale),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        viewModel.shortsFilter == HomeShortsFilter.team &&
                                !viewModel.hasPreferredTeam
                            ? l.homeShortsTeamUnset
                            : l.homeShortsFilterEmpty,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14 * scale,
                          color: AppColors.narText2,
                        ),
                      ),
                      if (viewModel.shortsFilter != HomeShortsFilter.all)
                        TextButton(
                          onPressed: () =>
                              viewModel.setShortsFilter(HomeShortsFilter.all),
                          child: Text(l.homeShortsShowAll),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SizedBox(
            // 9:16 썸네일(112 × 199) + 제목 두 줄.
            height: 250 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20 * scale),
              itemCount: videos.length,
              separatorBuilder: (_, _) => SizedBox(width: 10 * scale),
              itemBuilder: (context, i) => _ShortsCard(
                video: videos[i],
                scale: scale,
                onTap: () => _openFeed(context, i),
              ),
            ),
          ),
      ],
    );
  }
}

/// "내 팀" 필터로 바꾼 직후 응원팀·영상을 다시 받는 동안 보여주는 스켈레톤.
/// [_ShortsCard]와 같은 자리(9:16 썸네일 112×199 + 제목 두 줄)를 차지해,
/// 데이터가 도착했을 때 레이아웃이 튀지 않는다. 카드 4장이면 가로 스크롤
/// 폭을 넘겨 "로딩 중"임이 자연스럽게 드러난다.
class _ShortsDeckSkeleton extends StatefulWidget {
  const _ShortsDeckSkeleton({required this.scale});

  final double scale;

  @override
  State<_ShortsDeckSkeleton> createState() => _ShortsDeckSkeletonState();
}

class _ShortsDeckSkeletonState extends State<_ShortsDeckSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final width = 112 * scale;
    return SizedBox(
      height: 250 * scale,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final opacity = 0.3 + (_ctrl.value * 0.3);
          final blockColor = AppColors.narLine2.withValues(alpha: opacity);
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            itemCount: 4,
            separatorBuilder: (_, _) => SizedBox(width: 10 * scale),
            itemBuilder: (context, i) => Container(
              width: width,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.narBgTertiary,
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border.all(color: AppColors.narLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: width,
                    height: width * 16 / 9,
                    color: blockColor,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      8 * scale,
                      8 * scale,
                      8 * scale,
                      0,
                    ),
                    child: Container(
                      height: 12 * scale,
                      decoration: BoxDecoration(
                        color: blockColor,
                        borderRadius: BorderRadius.circular(4 * scale),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      8 * scale,
                      6 * scale,
                      8 * scale,
                      0,
                    ),
                    child: Container(
                      height: 12 * scale,
                      width: width * 0.6,
                      decoration: BoxDecoration(
                        color: blockColor,
                        borderRadius: BorderRadius.circular(4 * scale),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShortsCard extends StatelessWidget {
  const _ShortsCard({
    required this.video,
    required this.scale,
    required this.onTap,
  });

  final HomeShortsVideo video;
  final double scale;
  final VoidCallback onTap;

  Widget _fallbackThumbnail() => video.thumbnailUrl.isEmpty
      ? const SizedBox.shrink()
      : CachedNetworkImage(
          imageUrl: video.thumbnailUrl,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vertical = video.verticalThumbnailUrl;
    final width = 112 * scale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: width * 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.narBgLast),
                  // 9:16 세로 썸네일을 먼저 시도하고, 없는 영상(404)이면 서버가 준
                  // 4:3 썸네일로 폴백한다.
                  if (vertical != null)
                    CachedNetworkImage(
                      imageUrl: vertical,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (_, _, _) => _fallbackThumbnail(),
                    )
                  else
                    _fallbackThumbnail(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.narShortsScrim,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.narText,
                      size: 26 * scale,
                    ),
                  ),
                  if (video.teamCode.isNotEmpty)
                    Positioned(
                      right: 6 * scale,
                      top: 6 * scale,
                      child: TeamCodeBadge(
                        teamCode: video.teamCode,
                        size: 22 * scale,
                      ),
                    ),
                  Positioned(
                    left: 7 * scale,
                    bottom: 6 * scale,
                    child: Text(
                      l.communityViewCount(video.views),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 12 * scale,
                        color: AppColors.narText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 6 * scale, 8 * scale, 0),
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 13 * scale,
                  height: 1.35,
                  color: AppColors.narTextTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
