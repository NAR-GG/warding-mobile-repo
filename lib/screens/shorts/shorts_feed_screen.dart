import 'package:flutter/material.dart';

import '../../components/nar_tab_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../model/story_video.dart';
import '../../repository/shorts/shorts_repository.dart';
import '../../styles/app_colors.dart';
import '../../util/shorts_url.dart';
import '../../viewmodel/shorts/shorts_feed_viewmodel.dart';
import 'component/shorts_embed.dart';
import 'component/shorts_info_sheet.dart';

/// 전체화면 세로 쇼츠 피드. 위로 스와이프하면 다음 영상, 소리는 항상 끈다.
///
/// 플레이어(WebView)는 현재 ±1 페이지에만 만들어 동시에 최대 3개로 묶는다.
class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({
    super.key,
    required this.initialVideos,
    required this.resolveTeamCode,
    this.startIndex = 0,
    this.filter = ShortsFeedFilter.all,
    this.initialPageSize = ShortsFeedViewModel.defaultPageSize,
    this.repository,
    this.embedBuilder = youtubeShortsEmbed,
  });

  final List<StoryVideo> initialVideos;
  final Future<String?> Function() resolveTeamCode;
  final int startIndex;
  final ShortsFeedFilter filter;
  final int initialPageSize;
  final ShortsRepository? repository;
  final ShortsEmbedBuilder embedBuilder;

  static const Key endKey = ValueKey('shortsFeedEnd');
  static const Key unavailableKey = ValueKey('shortsFeedUnavailable');
  static const Key emptyKey = ValueKey('shortsFeedEmpty');

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  late final ShortsFeedViewModel _vm;
  late PageController _pages;
  int _pageGen = 0;

  @override
  void initState() {
    super.initState();
    _vm = ShortsFeedViewModel(
      initialVideos: widget.initialVideos,
      resolveTeamCode: widget.resolveTeamCode,
      startIndex: widget.startIndex,
      filter: widget.filter,
      initialPageSize: widget.initialPageSize,
      repository: widget.repository,
    );
    _pages = PageController(initialPage: _vm.index);
    _vm.onJumpTo = _jumpTo;
  }

  void _jumpTo(int page) {
    if (!mounted || !_pages.hasClients) return;
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _vm.onJumpTo = null;
    _pages.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _setFilter(ShortsFeedFilter f) async {
    if (f == _vm.filter) return;
    // 목록이 통째로 바뀌므로 페이저도 새로 만든다.
    final old = _pages;
    setState(() {
      _pages = PageController();
      _pageGen++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    await _vm.setFilter(f);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            return Column(
              children: [
                _TopBar(
                  scale: scale,
                  filter: _vm.filter,
                  onFilter: _setFilter,
                  closeLabel: l.shortsFeedClose,
                ),
                Expanded(child: _body(context, scale, l)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double scale, AppLocalizations l) {
    if (_vm.videos.isEmpty) {
      if (_vm.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return KeyedSubtree(
        key: ShortsFeedScreen.emptyKey,
        child: _Message(
          scale: scale,
          title: _vm.teamUnset
              ? l.homeShortsTeamUnset
              : l.homeShortsFilterEmpty,
          actionLabel: l.homeShortsShowAll,
          onAction: () => _setFilter(ShortsFeedFilter.all),
        ),
      );
    }
    if (_vm.unavailable) {
      final v = _vm.videos[_vm.index.clamp(0, _vm.videos.length - 1)];
      return KeyedSubtree(
        key: ShortsFeedScreen.unavailableKey,
        child: _Message(
          scale: scale,
          title: l.shortsFeedUnavailable,
          actionLabel: l.shortsFeedOpenYoutube,
          onAction: () => openShortsExternally(
            v.videoUrl.isNotEmpty
                ? v.videoUrl
                : 'https://www.youtube.com/shorts/${v.youtubeVideoId}',
          ),
          secondaryLabel: l.shortsFeedRetry,
          onSecondary: _vm.retry,
        ),
      );
    }
    return PageView.builder(
      key: ValueKey(_pageGen),
      controller: _pages,
      scrollDirection: Axis.vertical,
      // 이웃 페이지를 미리 만들어 다음 영상을 먼저 불러 둔다(현재 ±1).
      allowImplicitScrolling: true,
      itemCount: _vm.pageCount,
      onPageChanged: _vm.onPageChanged,
      itemBuilder: (context, i) {
        if (i >= _vm.videos.length) {
          return KeyedSubtree(
            key: ShortsFeedScreen.endKey,
            child: _Message(
              scale: scale,
              title: l.shortsFeedEnd,
              subtitle: l.shortsFeedEndHint,
            ),
          );
        }
        final video = _vm.videos[i];
        return Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: widget.embedBuilder(
                    context,
                    videoId: video.youtubeVideoId,
                    active: i == _vm.index,
                    onPlaying: () => _vm.reportPlaying(i),
                    onEnded: () => _vm.reportEnded(i),
                    onError: (code) => _vm.reportError(i, code: code),
                  ),
                ),
              ),
            ),
            ShortsInfoSheet(video: video, scale: scale),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.scale,
    required this.filter,
    required this.onFilter,
    required this.closeLabel,
  });

  final double scale;
  final ShortsFeedFilter filter;
  final ValueChanged<ShortsFeedFilter> onFilter;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        IconButton(
          tooltip: closeLabel,
          icon: const Icon(Icons.close_rounded, color: AppColors.narText),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: NarTabBar(
            tabs: [l.homeShortsFilterAll, l.homeShortsFilterTeam],
            selectedIndex: ShortsFeedFilter.values.indexOf(filter),
            onChanged: (i) => onFilter(ShortsFeedFilter.values[i]),
            variant: NarTabBarVariant.compact,
            compactHorizontalPadding: 4,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.scale,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final double scale;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 16 * scale,
                color: AppColors.narText,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6 * scale),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ],
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            if (secondaryLabel != null)
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ),
      ),
    );
  }
}
