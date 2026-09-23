import 'package:flutter/material.dart';

import '../../../components/nar_chip_multi_select.dart';
import '../../../components/team_code_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/home/home_viewmodel.dart';
import 'home_section_header.dart';

/// 콘텐츠 — 뉴스 / 쇼츠 탭 전환. (평점 한줄평은 커뮤니티 섹션 쪽 탭이다 —
/// 목업 구조 그대로.)
class HomeContentSection extends StatelessWidget {
  const HomeContentSection({
    super.key,
    required this.viewModel,
    required this.scale,
  });

  final HomeViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tab = viewModel.contentTab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: HomeSectionHeader(title: l.homeContentTitle, scale: scale),
        ),
        // NarChipMultiSelect 는 자체 16*scale 좌우 패딩을 갖는 공용 컴포넌트라
        // 다른 자식처럼 20*scale 로 감싸지 않고 그대로 둔다.
        NarChipMultiSelect(
          options: const ['news', 'shorts'],
          selectedValues: {tab == HomeContentTab.news ? 'news' : 'shorts'},
          labelBuilder: (v) =>
              v == 'news' ? l.homeContentTabNews : l.homeContentTabShorts,
          scale: scale,
          onChanged: (next) {
            if (next.contains('shorts') && tab != HomeContentTab.shorts) {
              viewModel.setContentTab(HomeContentTab.shorts);
            } else if (next.contains('news') && tab != HomeContentTab.news) {
              viewModel.setContentTab(HomeContentTab.news);
            }
          },
        ),
        if (tab == HomeContentTab.news)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: _NewsList(scale: scale),
          )
        else
          _ShortsDeck(viewModel: viewModel, scale: scale),
      ],
    );
  }
}

class _NewsList extends StatelessWidget {
  const _NewsList({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final article in HomeViewModel.mockNews)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * scale),
            child: Row(
              children: [
                if (article.hasThumbnail) ...[
                  Container(
                    width: 56 * scale,
                    height: 40 * scale,
                    decoration: BoxDecoration(
                      color: AppColors.narBgLast,
                      borderRadius: BorderRadius.circular(6 * scale),
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 13 * scale,
                          color: AppColors.narText,
                        ),
                      ),
                      Text(
                        '${article.office} · ${_ago(context, article.minutesAgo)}',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11 * scale,
                          color: AppColors.narText2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _ago(BuildContext context, int minutes) {
    final l = AppLocalizations.of(context)!;
    if (minutes < 60) return l.homeMinutesAgo(minutes);
    return l.homeHoursAgo(minutes ~/ 60);
  }
}

class _ShortsDeck extends StatelessWidget {
  const _ShortsDeck({required this.viewModel, required this.scale});

  final HomeViewModel viewModel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String labelFor(HomeShortsFilter f) => switch (f) {
      HomeShortsFilter.all => l.homeShortsFilterAll,
      HomeShortsFilter.player => l.homeShortsFilterPlayer,
      HomeShortsFilter.team => l.homeShortsFilterTeam,
    };
    final videos = viewModel.shortsFiltered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NarChipMultiSelect 는 자체 16*scale 좌우 패딩을 갖는 공용 컴포넌트라
        // 다른 자식처럼 20*scale 로 감싸지 않고 그대로 둔다.
        NarChipMultiSelect(
          options: [for (final f in HomeShortsFilter.values) f.name],
          selectedValues: {viewModel.shortsFilter.name},
          labelBuilder: (v) => labelFor(HomeShortsFilter.values.byName(v)),
          scale: scale,
          onChanged: (next) {
            final added = next.difference({viewModel.shortsFilter.name});
            if (added.isNotEmpty) {
              viewModel.setShortsFilter(
                HomeShortsFilter.values.byName(added.first),
              );
            }
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: SizedBox(
            height: 168 * scale,
            child: videos.isEmpty
                ? Center(
                    child: Text(
                      l.homeShortsFilterEmpty,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13 * scale,
                        color: AppColors.narText2,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: videos.length,
                    separatorBuilder: (_, _) => SizedBox(width: 8 * scale),
                    itemBuilder: (context, i) =>
                        _ShortsCard(video: videos[i], scale: scale),
                  ),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SizedBox(
      width: 96 * scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 96 * scale,
                height: 128 * scale,
                decoration: BoxDecoration(
                  color: AppColors.narBgLast,
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.narText2,
                  size: 28 * scale,
                ),
              ),
              if (video.matchedPlayer != null)
                Positioned(
                  left: 6 * scale,
                  top: 6 * scale,
                  child: _Badge(text: video.matchedPlayer!, scale: scale),
                )
              else
                Positioned(
                  left: 6 * scale,
                  top: 6 * scale,
                  child: TeamCodeBadge(
                    teamCode: video.teamCode,
                    size: 18 * scale,
                  ),
                ),
              Positioned(
                right: 6 * scale,
                bottom: 6 * scale,
                child: Text(
                  l.communityViewCount(video.views),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10 * scale,
                    color: AppColors.narText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11 * scale,
              color: AppColors.narText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: AppColors.narChipActive,
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          fontSize: 10 * scale,
          color: AppColors.narText,
        ),
      ),
    );
  }
}
