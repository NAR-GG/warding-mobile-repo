import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_refresh_indicator.dart';
import '../../config/app_globals.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_remote_post.dart';
import '../../repository/notification/member_notification_repository.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/community/community_list_viewmodel.dart';
import '../login/login_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../notification/notification_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import 'community_search_screen.dart';
import 'component/post_list_item.dart';
import 'component/post_list_item_skeleton.dart';
import 'component/write_lock_bar.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';

/// 커뮤니티 — 단일 전체 게시판.
///
/// 팀별 게시판(전체·응원팀·상대팀 3탭)은 팀원 피드백(글 리젠 악순환 우려)으로
/// 보류했다 — 하나의 게시판으로 시작해 사용 패턴을 보고 되살릴지 정한다.
/// 서버의 팀 게시판 API·검사는 걷어내지 않고 잠들어 있다(boardTeamId=null 고정).
///
/// 읽기는 누구에게나 열려 있고 쓰기만 로그인으로 제한된다. 그래서 목록 전체를
/// `GuestLockOverlay` 로 덮지 않는다 — 비회원도 읽을 수 있어야 하므로 쓰기
/// 버튼에서만 막는다.
///
/// 알림함 진입점(벨·미읽음 배지)은 이 화면 우측 상단이다 — 커뮤니티 알림
/// 전용이라 커뮤니티 안에 있어야 맥락이 맞다(경기 알림은 마이구독이 담당).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final CommunityListViewModel _vm = CommunityListViewModel();

  /// 헤더 벨 배지용 미읽음 수 — 커뮤니티 묶음 기준(경기 알림은 안 센다).
  /// 비로그인·실패는 0(배지 숨김)으로 조용히 넘어간다.
  int _unreadCount = 0;

  /// 목록을 내리는 동안 [AppBottomNav] 를 살짝 축소한다([BottomNavShrinkController]).
  final BottomNavShrinkController _navShrink = BottomNavShrinkController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm.init();
    _refreshUnreadCount();
    // 앱이 떠 있는 동안 푸시가 오면 배지를 다시 센다 — 서버는 발송 전에
    // 알림함을 적재하므로 지금 읽으면 방금 온 알림이 반영돼 있다. 목록을
    // 새로고침해야만 배지가 갱신되던 문제의 답(마이구독 피드와 같은 신호).
    feedRefreshTick.addListener(_refreshUnreadCount);
  }

  @override
  void dispose() {
    feedRefreshTick.removeListener(_refreshUnreadCount);
    WidgetsBinding.instance.removeObserver(this);
    _vm.dispose();
    _navShrink.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에 있는 동안 온 알림은 푸시 신호를 못 받는다 — 복귀 시 재조회.
    if (state == AppLifecycleState.resumed) _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final page = await MemberNotificationRepository.instance
          .fetchNotifications(group: 'COMMUNITY', page: 0, size: 1);
      if (mounted) setState(() => _unreadCount = page.unreadCount);
    } catch (_) {
      if (mounted) setState(() => _unreadCount = 0);
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CommunitySearchScreen()),
    );
    if (!mounted) return;
    // 검색 결과에서 글을 지웠을 수 있어 목록을 다시 받는다.
    await _vm.load(null, refresh: true);
  }

  Future<void> _openNotificationInbox() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationScreen()));
    // 알림함에서 읽고 돌아오면 배지를 다시 센다.
    _refreshUnreadCount();
  }

  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }

  /// 남은 작성 간격(초). 게시판은 하나뿐이라 전체 게시판 기준이다.
  int get _cooldown => _vm.writeCooldownSeconds(null);

  Future<void> _openLogin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    await _vm.loadSession();
    if (!mounted) return;
    // 로그인하면 서버가 내려주는 쓰기 권한이 달라진다. 배지도 이제 셀 수 있다.
    await _vm.load(null, refresh: true);
    _refreshUnreadCount();
  }

  Future<void> _openWrite() async {
    if (!_vm.loggedIn) {
      await _openLogin();
      return;
    }
    final createdId = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) =>
            PostWriteScreen(boardTeamId: null, tester: _vm.isTester(null)),
      ),
    );
    if (createdId == null || !mounted) return;
    await _vm.load(null, refresh: true);
  }

  Future<void> _openPost(CommunityRemotePost post) async {
    final result = await Navigator.of(context).push<PostDetailResult>(
      MaterialPageRoute<PostDetailResult>(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
    if (result == null || !mounted) return;
    if (result.removed) {
      _vm.removePost(null, post.id);
    } else if (result.updated != null) {
      _vm.applyPostUpdate(null, result.updated!);
    }
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
          builder: (context, _) => Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _navShrink.handleNotification,
                child: Column(
                  children: [
                    _Header(
                      title: l.communityTitle,
                      scale: scale,
                      unreadCount: _unreadCount,
                      onBellTap: _openNotificationInbox,
                      onSearchTap: _openSearch,
                    ),
                    Expanded(child: _board(scale)),
                  ],
                ),
              ),
              if (_vm.canWrite(null))
                Positioned(
                  right: 20 * scale,
                  // 하단 네비(bottom 26 + 높이 72)와 넉넉히 띄운다. 바짝
                  // 붙이면 네비의 유리 효과가 FAB 그라데이션을 굴절시켜
                  // 마지막 탭이 보라색으로 물들어 활성 탭처럼 보인다.
                  bottom: 128 * scale,
                  child: _WriteFab(
                    // 작성 간격이 남았으면 남은 초를 버튼에 띄우고 잠근다.
                    // 다 쓰고 등록에서 429 를 받는 것보다 낫다.
                    label: _cooldown > 0
                        ? l.communityWriteCooldown(_cooldown)
                        : l.communityWrite,
                    scale: scale,
                    onTap: _cooldown > 0 ? null : _openWrite,
                  ),
                )
              else if (!_vm.loggedIn)
                Positioned(
                  left: 16 * scale,
                  right: 16 * scale,
                  bottom: 122 * scale,
                  child: WriteLockBar(
                    title: l.communityGuestWrite,
                    body: null,
                    actionLabel: l.loginRequired,
                    scale: scale,
                    onAction: _openLogin,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: ListenableBuilder(
                  listenable: _navShrink,
                  builder: (context, _) => AppBottomNav(
                    currentTab: AppNavTab.community,
                    onTabSelected: _onTabSelected,
                    compact: _navShrink.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(double scale) {
    final l = AppLocalizations.of(context)!;
    final state = _vm.board(null);

    if (!state.loaded && !state.loading && state.error == null) {
      // 빌드 중에 상태를 건드리면 안 되므로 프레임이 끝난 뒤에 부른다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.load(null);
      });
    }

    if (state.loading && state.posts.isEmpty) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, i) => PostListItemSkeleton(scale: scale),
      );
    }
    if (state.error != null && state.posts.isEmpty) {
      return _Retry(
        message: state.error!,
        label: l.communityRetry,
        scale: scale,
        onRetry: () => _vm.load(null, refresh: true),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => _vm.load(null, refresh: true),
      child: state.posts.isEmpty
          // 빈 목록에서도 당길 수 있어야 하므로 스크롤 가능한 리스트로 감싼다.
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 120 * scale),
                _Empty(message: l.communityEmpty, scale: scale),
              ],
            )
          : _BoardList(
              state: state,
              scale: scale,
              onLoadMore: () => _vm.loadMore(null),
              onTap: _openPost,
            ),
    );
  }
}

/// 무한 스크롤이 붙은 글 목록.
class _BoardList extends StatefulWidget {
  const _BoardList({
    required this.state,
    required this.scale,
    required this.onLoadMore,
    required this.onTap,
  });

  final CommunityBoardState state;
  final double scale;
  final VoidCallback onLoadMore;
  final ValueChanged<CommunityRemotePost> onTap;

  @override
  State<_BoardList> createState() => _BoardListState();
}

class _BoardListState extends State<_BoardList> {
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
    final posts = widget.state.posts;
    final scale = widget.scale;

    return ListView.builder(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 170 * scale),
      itemCount: posts.length + (widget.state.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= posts.length) {
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
        return PostListItem(
          post: posts[i],
          scale: scale,
          onTap: () => widget.onTap(posts[i]),
        );
      },
    );
  }
}

/// 타이틀 + 우측 벨(알림함 진입점). 배지는 여기에만 단다 — 두 군데 배지가
/// 있으면 사용자가 어디를 봐야 할지 모른다.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.scale,
    required this.unreadCount,
    required this.onBellTap,
    required this.onSearchTap,
  });

  final String title;
  final double scale;

  /// 미읽음 알림 수. 0 이면 배지를 숨긴다.
  final int unreadCount;

  final VoidCallback onBellTap;

  /// 검색 화면 진입.
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        14 * scale,
        20 * scale,
        10 * scale,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 20 * scale,
                height: 1.35,
                color: AppColors.narText,
              ),
            ),
          ),
          // 검색은 벨 왼쪽 — 같은 원형 슬롯으로 톤을 맞춘다.
          GestureDetector(
            onTap: onSearchTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40 * scale,
              height: 40 * scale,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.narBgTertiary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                size: 21 * scale,
                color: AppColors.narText,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          GestureDetector(
            onTap: onBellTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40 * scale,
                  height: 40 * scale,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.narBgTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/bell.svg',
                    width: 20 * scale,
                    height: 20 * scale,
                    colorFilter: const ColorFilter.mode(
                      AppColors.narText,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 1 * scale,
                    right: 1 * scale,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.5 * scale,
                        vertical: 1.5 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.liveAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5 * scale,
                          height: 1.2,
                          color: AppColors.narText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

/// 목록을 못 받았을 때. 빈 화면만 두면 사용자는 글이 없는 건지 실패한 건지
/// 구분할 수 없다.
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * scale,
                vertical: 9 * scale,
              ),
              decoration: BoxDecoration(
                color: AppColors.narDark600,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.narLine2, width: 1),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WriteFab extends StatelessWidget {
  const _WriteFab({
    required this.label,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final double scale;

  /// null 이면 잠긴 상태 — 그라데이션을 걷고 회색으로 떨어뜨린다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = onTap == null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44 * scale,
        padding: EdgeInsets.symmetric(horizontal: 18 * scale),
        decoration: BoxDecoration(
          gradient: locked ? null : AppColors.narBg,
          color: locked ? AppColors.narDark500 : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/pencil.svg',
              width: 16 * scale,
              height: 16 * scale,
              colorFilter: ColorFilter.mode(
                locked ? AppColors.narText2 : AppColors.narText,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 7 * scale),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 14 * scale,
                height: 1.4,
                color: locked ? AppColors.narText2 : AppColors.narText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
