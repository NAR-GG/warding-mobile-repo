import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/nar_chip_multi_select.dart';
import '../../../components/dashed_border.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/home_models.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import 'home_section_header.dart';

/// 콘텐츠 — 밖에서 온 것(뉴스·쇼츠). 평점 한줄평은 유저가 쓴 것이라 커뮤니티
/// 섹션 탭에 있다(spec 결정: 섹션을 둘로 나눈다).
///
/// 기본 탭은 뉴스다(spec 결정). 뉴스가 없으면 뉴스 탭을 숨기고 쇼츠만 둔다. 쇼츠 "내 선수" 같은 필터가 0건이면 점선 박스를
/// 보여준다(spec "상태" 표). 로딩·에러는 그리지 않는다.
///
/// 쇼츠를 누르면 유튜브를 앱 밖에서 연다. 홈 안에서 재생할지·전체화면 피드로
/// 보낼지는 spec 미결이라, 결정 전까지 가장 가벼운 외부 열기로 둔다.
/// 쇼츠 카드가 외부로 열 주소. https 만 허용한다 — 서버가 준 값이라
/// `javascript:`·`intent:`·`file:` 같은 스킴이나 깨진 주소는 열지 않는다.
/// 열 수 없으면 null.
Uri? shortsLaunchUri(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

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
        SizedBox(height: 10 * scale),
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
          _NewsList(articles: viewModel.news, scale: scale)
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
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 13 * scale,
                vertical: 11 * scale,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 썸네일 자리. 기사 이미지는 뉴스 소스가 붙으면 채운다.
                  Container(
                    width: 62 * scale,
                    height: 47 * scale,
                    decoration: BoxDecoration(
                      color: article.hasThumbnail
                          ? AppColors.narLine2
                          : AppColors.narBgLast,
                      borderRadius: BorderRadius.circular(7 * scale),
                    ),
                  ),
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
                            fontSize: 13.5 * scale,
                            height: 1.4,
                            color: AppColors.narTextTertiary,
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          '${article.office} · ${_ago(l, article.minutesAgo)}',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11 * scale,
                            color: AppColors.narDark200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortsDeck extends StatelessWidget {
  const _ShortsDeck({required this.viewModel, required this.scale});

  final HomeViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final videos = viewModel.shortsFiltered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NarChipMultiSelect.single(
          options: [for (final f in HomeShortsFilter.values) f.name],
          selected: viewModel.shortsFilter.name,
          onSelected: (name) =>
              viewModel.setShortsFilter(HomeShortsFilter.values.byName(name)),
          labelBuilder: (name) => switch (HomeShortsFilter.values.byName(name)) {
            HomeShortsFilter.all => l.homeShortsFilterAll,
            HomeShortsFilter.player => l.homeShortsFilterPlayer,
            HomeShortsFilter.team => l.homeShortsFilterTeam,
          },
          horizontalPadding: 20,
          scale: scale,
        ),
        if (videos.isEmpty)
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
                  child: Text(
                    l.homeShortsFilterEmpty,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5 * scale,
                      color: AppColors.narText2,
                    ),
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
              itemBuilder: (context, i) =>
                  _ShortsCard(video: videos[i], scale: scale),
            ),
          ),
      ],
    );
  }
}

class _ShortsCard extends StatelessWidget {
  const _ShortsCard({required this.video, required this.scale});

  final HomeShortsVideo video;
  final double scale;

  Future<void> _open() async {
    final uri = shortsLaunchUri(video.url);
    if (uri == null) {
      debugPrint('[Home] 쇼츠 주소가 https 가 아니라 열지 않음: ${video.url}');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) debugPrint('[Home] 쇼츠 열기 실패: $uri');
    } catch (e) {
      debugPrint('[Home] 쇼츠 열기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mine = video.matchedPlayer != null;
    final width = 112 * scale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: shortsLaunchUri(video.url) == null ? null : _open,
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(
            color: mine ? AppColors.narSoloLine : AppColors.narLine,
          ),
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
                  if (video.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
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
                  if (mine)
                    Positioned(
                      left: 6 * scale,
                      top: 6 * scale,
                      child: _Tag(
                        text: video.matchedPlayer!,
                        mine: true,
                        scale: scale,
                      ),
                    )
                  else if (video.teamCode.isNotEmpty)
                    Positioned(
                      left: 6 * scale,
                      top: 6 * scale,
                      child: _Tag(
                        text: video.teamCode,
                        mine: false,
                        scale: scale,
                      ),
                    ),
                  Positioned(
                    left: 7 * scale,
                    bottom: 6 * scale,
                    child: Text(
                      l.communityViewCount(video.views),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 10 * scale,
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
                  fontSize: 11.5 * scale,
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

/// 썸네일 좌상단 배지 — 내 선수면 브랜드 3색을 옅게, 내 팀이면 무채색.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.mine, required this.scale});

  final String text;
  final bool mine;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 19 * scale,
      padding: EdgeInsets.symmetric(horizontal: 7 * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: mine ? AppColors.narSoloTint : null,
        color: mine ? null : AppColors.narWhite14,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(
          color: mine ? AppColors.narSoloLine : AppColors.narLine2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 10 * scale,
          height: 1,
          color: mine ? AppColors.narSoloText : AppColors.narGray400,
        ),
      ),
    );
  }
}
