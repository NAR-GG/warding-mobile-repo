import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../components/nar_detail_header.dart';
import '../../components/nar_tab_bar.dart';
import '../../model/community_my_activity.dart';
import '../../model/community_remote_post.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/my_community_activity/my_community_activity_viewmodel.dart';
import '../community/component/post_list_item.dart';
import '../community/post_detail_screen.dart';
import 'component/my_comment_row.dart';

/// 마이페이지 "내 활동" 진입 탭. 셋 다 같은 화면을 열고 초기 탭만 다르다.
enum MyCommunityActivityTab { posts, comments, scraps }

/// 내가 쓴 글 · 내가 쓴 댓글 · 스크랩 — 커뮤니티에 남긴 것들을 다시 찾아보는 화면.
///
/// 헤더는 공용 [NarDetailHeader], 탭은 [NarTabBar]. 탭마다 스크롤 위치와
/// 커서가 따로 있어야 해서([_ActivityList] 참고) 커뮤니티 `_BoardList` 와
/// 같은 이유로 각자 [ScrollController] 를 든다.
class MyCommunityActivityScreen extends StatefulWidget {
  const MyCommunityActivityScreen({
    super.key,
    this.initialTab = MyCommunityActivityTab.posts,
  });

  final MyCommunityActivityTab initialTab;

  @override
  State<MyCommunityActivityScreen> createState() =>
      _MyCommunityActivityScreenState();
}

class _MyCommunityActivityScreenState extends State<MyCommunityActivityScreen> {
  final MyCommunityActivityViewModel _vm = MyCommunityActivityViewModel();
  late final PageController _pageController = PageController(
    initialPage: widget.initialTab.index,
  );
  late MyCommunityActivityTab _tab = widget.initialTab;

  @override
  void dispose() {
    _pageController.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// 탭을 누르면 그 페이지로 이동한다. 인접하지 않은 탭이면(예: '스크랩'→
  /// '내가 쓴 글') 바로 점프한다 — [PageController.animateToPage] 는 사이
  /// 페이지를 슬라이드로 지나쳐 순간적으로 스치듯 보인다
  /// ([community_screen.dart]의 `_goToTab`과 같은 이유).
  void _goToTab(MyCommunityActivityTab tab) {
    if ((tab.index - _tab.index).abs() <= 1) {
      _pageController.animateToPage(
        tab.index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(tab.index);
    }
  }

  void _onPageChanged(int index) =>
      setState(() => _tab = MyCommunityActivityTab.values[index]);

  Future<void> _openPost(int postId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<PostDetailResult>(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
            children: [
              NarDetailHeader(
                title: l.myCommunityActivity,
                backIconAsset: 'assets/icons/chevron-left.svg',
                scale: scale,
              ),
              NarTabBar(
                tabs: [
                  l.myCommunityPosts,
                  l.myCommunityComments,
                  l.communityScrap,
                ],
                selectedIndex: _tab.index,
                onChanged: (i) => _goToTab(MyCommunityActivityTab.values[i]),
                scale: scale,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _postsPage(l, scale),
                    _commentsPage(l, scale),
                    _scrapsPage(l, scale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postsPage(AppLocalizations l, double scale) {
    final state = _vm.posts;
    _maybeLoad(
      active: _tab == MyCommunityActivityTab.posts,
      state: state,
      load: _vm.loadPosts,
    );

    if (state.loading && state.items.isEmpty) return const _Loading();
    if (state.error != null && state.items.isEmpty) {
      return _Retry(
        message: state.error!,
        label: l.communityRetry,
        scale: scale,
        onRetry: () => _vm.loadPosts(refresh: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _vm.loadPosts(refresh: true),
      color: AppColors.narText,
      backgroundColor: AppColors.narDark600,
      child: state.items.isEmpty
          ? _emptyList(l.myCommunityPostsEmpty, scale)
          : _ActivityList<CommunityRemotePost>(
              items: state.items,
              loadingMore: state.loadingMore,
              scale: scale,
              onLoadMore: _vm.loadMorePosts,
              itemBuilder: (post) => PostListItem(
                post: post,
                scale: scale,
                showBoardBadge: true,
                onTap: () => _openPost(post.id),
              ),
            ),
    );
  }

  Widget _commentsPage(AppLocalizations l, double scale) {
    final state = _vm.comments;
    _maybeLoad(
      active: _tab == MyCommunityActivityTab.comments,
      state: state,
      load: _vm.loadComments,
    );

    if (state.loading && state.items.isEmpty) return const _Loading();
    if (state.error != null && state.items.isEmpty) {
      return _Retry(
        message: state.error!,
        label: l.communityRetry,
        scale: scale,
        onRetry: () => _vm.loadComments(refresh: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _vm.loadComments(refresh: true),
      color: AppColors.narText,
      backgroundColor: AppColors.narDark600,
      child: state.items.isEmpty
          ? _emptyList(l.myCommunityCommentsEmpty, scale)
          : _ActivityList<CommunityMyComment>(
              items: state.items,
              loadingMore: state.loadingMore,
              scale: scale,
              onLoadMore: _vm.loadMoreComments,
              itemBuilder: (comment) => MyCommentRow(
                comment: comment,
                scale: scale,
                onTap: () => _openPost(comment.postId),
              ),
            ),
    );
  }

  Widget _scrapsPage(AppLocalizations l, double scale) {
    final state = _vm.scraps;
    _maybeLoad(
      active: _tab == MyCommunityActivityTab.scraps,
      state: state,
      load: _vm.loadScraps,
    );

    if (state.loading && state.items.isEmpty) return const _Loading();
    if (state.error != null && state.items.isEmpty) {
      return _Retry(
        message: state.error!,
        label: l.communityRetry,
        scale: scale,
        onRetry: () => _vm.loadScraps(refresh: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _vm.loadScraps(refresh: true),
      color: AppColors.narText,
      backgroundColor: AppColors.narDark600,
      child: state.items.isEmpty
          ? _emptyList(l.communityScrapEmpty, scale)
          : _ActivityList<CommunityScrapItem>(
              items: state.items,
              loadingMore: state.loadingMore,
              scale: scale,
              onLoadMore: _vm.loadMoreScraps,
              itemBuilder: (scrap) => PostListItem(
                post: scrap.post,
                scale: scale,
                showBoardBadge: true,
                onTap: () => _openPost(scrap.post.id),
              ),
            ),
    );
  }

  /// 탭이 활성이고 아직 안 받았으면 로드를 예약한다. 빌드 중에 상태를
  /// 건드리면 안 되므로 프레임이 끝난 뒤에 부른다([community_screen.dart]의
  /// 게시판 로드와 같은 패턴).
  void _maybeLoad({
    required bool active,
    required MyActivityListState state,
    required Future<void> Function() load,
  }) {
    if (!active || state.loaded || state.loading || state.error != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Widget _emptyList(String message, double scale) {
    // 빈 목록에서도 당길 수 있어야 하므로 스크롤 가능한 리스트로 감싼다.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 120 * scale),
        _Empty(message: message, scale: scale),
      ],
    );
  }
}

/// 무한 스크롤이 붙은 목록. 탭마다 스크롤 위치가 따로 있어야 해서
/// [ScrollController] 를 각자 든다([community_screen.dart]의 `_BoardList`와
/// 같은 이유).
class _ActivityList<T> extends StatefulWidget {
  const _ActivityList({
    required this.items,
    required this.loadingMore,
    required this.scale,
    required this.onLoadMore,
    required this.itemBuilder,
  });

  final List<T> items;
  final bool loadingMore;
  final double scale;
  final VoidCallback onLoadMore;
  final Widget Function(T item) itemBuilder;

  @override
  State<_ActivityList<T>> createState() => _ActivityListState<T>();
}

class _ActivityListState<T> extends State<_ActivityList<T>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 200) {
        widget.onLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final scale = widget.scale;

    return ListView.builder(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 170 * scale),
      itemCount: items.length + (widget.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16 * scale),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.narText2,
                ),
              ),
            ),
          );
        }
        return widget.itemBuilder(items[i]);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.narText2,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40 * scale),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 14 * scale,
            height: 1.5,
            color: AppColors.narText2,
          ),
        ),
      ),
    );
  }
}

/// 목록을 못 받았을 때. 빈 화면만 두면 사용자는 없는 건지 실패한 건지 구분할 수 없다.
class _Retry extends StatelessWidget {
  const _Retry({
    required this.message,
    required this.label,
    required this.scale,
    required this.onRetry,
  });

  final String message;
  final String label;
  final double scale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40 * scale),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.5,
                color: AppColors.narText2,
              ),
            ),
          ),
          SizedBox(height: 12 * scale),
          TextButton(
            onPressed: onRetry,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 14 * scale,
                color: AppColors.narTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
