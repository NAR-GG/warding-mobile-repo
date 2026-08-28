import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/nar_tab_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_remote_post.dart';
import '../../model/team.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/community/community_list_viewmodel.dart';
import '../login/login_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import 'community_teams.dart';
import 'component/post_list_item.dart';
import 'component/team_chip_rail.dart';
import 'component/write_lock_bar.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';

/// 커뮤니티 — 전체 · 우리팀 · 다른팀.
///
/// 읽기는 누구에게나 열려 있고 쓰기만 전체 게시판과 내 응원팀 게시판으로
/// 제한된다. 그래서 목록 전체를 `GuestLockOverlay` 로 덮지 않는다 — 비회원도
/// 읽을 수 있어야 하므로 쓰기 버튼에서만 막는다.
///
/// **우리팀을 다른팀과 분리한 이유**: 팀 탭 하나에 10개 팀을 칩으로 늘어놓으면
/// 내 팀에 가려면 매번 레일에서 찾아야 하고, 무엇보다 쓸 수 있는 곳(내 팀)과 못
/// 쓰는 곳(나머지)이 같은 탭에 섞여 잠금 바가 떴다 사라졌다 한다. 탭을 나누면
/// "이 탭은 내가 쓰는 곳, 저 탭은 읽는 곳"이 고정된다.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

/// 상단 탭. 순서가 곧 [PageView] 인덱스다.
enum _CommunityTab { all, myTeam, otherTeams }

class _CommunityScreenState extends State<CommunityScreen> {
  final PageController _pageController = PageController();
  final CommunityListViewModel _vm = CommunityListViewModel();

  _CommunityTab _tab = _CommunityTab.all;

  /// '다른팀' 탭에서 고른 팀. null 이면 아직 안 골랐다는 뜻이고, 팀 목록이
  /// 도착하면 첫 번째 팀으로 정해진다.
  int? _selectedOtherId;

  @override
  void initState() {
    super.initState();
    loadCommunityTeams();
    _vm.init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _vm.dispose();
    super.dispose();
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

  void _goToTab(_CommunityTab tab) {
    _pageController.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// 내 응원팀을 뺀 나머지 팀.
  List<Team> get _otherTeams => [
    for (final team in communityTeams.value)
      if (team.id != _vm.myTeamId) team,
  ];

  /// '다른팀' 탭에서 지금 보고 있는 팀.
  int? get _otherTeamId {
    final others = _otherTeams;
    if (others.isEmpty) return null;
    final selected = _selectedOtherId;
    if (selected != null && others.any((t) => t.id == selected)) {
      return selected;
    }
    return others.first.id;
  }

  /// 지금 탭이 보여주는 게시판. null 은 **전체 게시판**을 뜻하므로, 팀을 아직
  /// 못 정한 탭과 구분하려면 [_tab] 을 같이 봐야 한다.
  int? get _boardTeamId => switch (_tab) {
    _CommunityTab.all => null,
    _CommunityTab.myTeam => _vm.myTeamId,
    _CommunityTab.otherTeams => _otherTeamId,
  };

  /// 지금 탭에 글을 쓸 수 있는가. 다른팀 탭은 어떤 경우에도 못 쓴다 — 탭을
  /// 나눈 이유가 그것이다.
  bool get _canWriteHere => switch (_tab) {
    _CommunityTab.all => _vm.canWrite(null),
    _CommunityTab.myTeam => _vm.myTeamId != null && _vm.canWrite(_vm.myTeamId),
    _CommunityTab.otherTeams => false,
  };

  Future<void> _openLogin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    await _vm.loadSession();
    if (!mounted) return;
    // 로그인하면 서버가 내려주는 쓰기 권한이 달라진다.
    await _vm.load(_boardTeamId, refresh: true);
  }

  Future<void> _openWrite() async {
    if (!_vm.loggedIn) {
      await _openLogin();
      return;
    }
    final boardTeamId = _boardTeamId;
    if (_tab == _CommunityTab.myTeam && boardTeamId == null) return;

    final createdId = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => PostWriteScreen(boardTeamId: boardTeamId),
      ),
    );
    if (createdId == null || !mounted) return;
    await _vm.load(boardTeamId, refresh: true);
  }

  Future<void> _openPost(int? boardTeamId, CommunityRemotePost post) async {
    final result = await Navigator.of(context).push<PostDetailResult>(
      MaterialPageRoute<PostDetailResult>(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
    if (result == null || !mounted) return;
    if (result.removed) {
      _vm.removePost(boardTeamId, post.id);
    } else if (result.updated != null) {
      _vm.applyPostUpdate(boardTeamId, result.updated!);
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
        // 팀 목록(로고·이름)과 게시글 상태는 출처가 달라 각각 구독한다.
        child: ValueListenableBuilder<List<Team>>(
          valueListenable: communityTeams,
          builder: (context, _, _) => ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      title: l.communityTitle,
                      subtitle: _boardName(l),
                      scale: scale,
                    ),
                    NarTabBar(
                      tabs: [
                        l.communityTabAll,
                        l.communityTabMyTeam,
                        l.communityTabOtherTeams,
                      ],
                      selectedIndex: _tab.index,
                      onChanged: (i) => _goToTab(_CommunityTab.values[i]),
                      scale: scale,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          _board(
                            null,
                            scale,
                            active: _tab == _CommunityTab.all,
                          ),
                          _myTeamPage(l, scale),
                          _otherTeamsPage(l, scale),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_canWriteHere)
                  Positioned(
                    right: 20 * scale,
                    // 하단 네비(bottom 26 + 높이 72)와 넉넉히 띄운다. 바짝
                    // 붙이면 네비의 유리 효과가 FAB 그라데이션을 굴절시켜
                    // 마지막 탭이 보라색으로 물들어 활성 탭처럼 보인다.
                    bottom: 128 * scale,
                    child: _WriteFab(
                      label: l.communityWrite,
                      scale: scale,
                      onTap: _openWrite,
                    ),
                  )
                else if (_lockBar(l, scale) case final lock?)
                  Positioned(
                    left: 16 * scale,
                    right: 16 * scale,
                    bottom: 122 * scale,
                    child: lock,
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 26,
                  child: AppBottomNav(
                    currentTab: AppNavTab.community,
                    onTabSelected: _onTabSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPageChanged(int index) =>
      setState(() => _tab = _CommunityTab.values[index]);

  /// 헤더 아래에 지금 보고 있는 게시판 이름을 붙인다. 탭 라벨('우리팀')만으로는
  /// 어느 팀 게시판인지, 다른팀 탭에서 어떤 팀을 고른 상태인지 알 수 없다.
  String? _boardName(AppLocalizations l) {
    if (_tab == _CommunityTab.all) return l.communityBoardAll;
    final team = communityTeam(_boardTeamId);
    if (team == null) return null;
    return l.communityBoardTeam(team.name);
  }

  Widget _myTeamPage(AppLocalizations l, double scale) {
    if (!_vm.sessionLoaded) return const _Loading();
    final myTeamId = _vm.myTeamId;
    if (myTeamId == null) {
      return _Empty(
        message: _vm.loggedIn ? l.communityNoTeamTitle : l.communityGuestWrite,
        scale: scale,
      );
    }
    return _board(myTeamId, scale, active: _tab == _CommunityTab.myTeam);
  }

  Widget _otherTeamsPage(AppLocalizations l, double scale) {
    final others = _otherTeams;
    final selected = _otherTeamId;
    if (others.isEmpty || selected == null) return const _Loading();

    return Column(
      children: [
        TeamChipRail(
          teams: others,
          selectedId: selected,
          myTeamId: null, // 내 팀은 이 목록에 없으므로 별표도 없다.
          scale: scale,
          onSelected: (id) => setState(() => _selectedOtherId = id),
        ),
        Expanded(
          child: _board(
            selected,
            scale,
            active: _tab == _CommunityTab.otherTeams,
          ),
        ),
      ],
    );
  }

  /// [active] 는 지금 보이는 탭인지. 안 보이는 탭까지 미리 받아오면 화면을
  /// 열자마자 요청이 셋 나간다 — 정작 볼 게시판은 하나다.
  ///
  /// 로드 조건을 탭 전환 콜백이 아니라 여기서 보는 이유: 게시판이 정해지는
  /// 시점이 탭 전환보다 늦을 수 있다(팀 목록·응원팀 조회가 아직 안 끝난 상태로
  /// '다른팀'에 들어와 있을 수 있다). 그리면서 판단하면 그 순서를 안 탄다.
  Widget _board(int? boardTeamId, double scale, {required bool active}) {
    final l = AppLocalizations.of(context)!;
    final state = _vm.board(boardTeamId);

    if (active && !state.loaded && !state.loading && state.error == null) {
      // 빌드 중에 상태를 건드리면 안 되므로 프레임이 끝난 뒤에 부른다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.load(boardTeamId);
      });
    }

    if (state.loading && state.posts.isEmpty) return const _Loading();
    if (state.error != null && state.posts.isEmpty) {
      return _Retry(
        message: state.error!,
        label: l.communityRetry,
        scale: scale,
        onRetry: () => _vm.load(boardTeamId, refresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _vm.load(boardTeamId, refresh: true),
      color: AppColors.narText,
      backgroundColor: AppColors.narDark600,
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
              onLoadMore: () => _vm.loadMore(boardTeamId),
              onTap: (post) => _openPost(boardTeamId, post),
            ),
    );
  }

  /// 쓰기가 막힌 이유는 셋 중 하나다 — 비회원 / 응원팀 미설정 / 다른 팀 게시판.
  /// 각각 다음에 할 수 있는 행동이 다르다.
  ///
  /// **우리팀 게시판에는 잠금이 없다.** 응원팀이면 자기 게시판에는 언제나 쓴다.
  /// 팀 갈아타기 제한(30일)은 프로필 수정의 팀 변경에서 막으므로 여기까지
  /// 내려오지 않는다.
  /// 띄울 안내가 없으면 null — 아무것도 그리지 않는다. 이유를 모르는 잠금에
  /// 아무 문구나 붙이면 틀린 안내가 된다(예: 팀이 있는데 "응원팀을 정하세요").
  Widget? _lockBar(AppLocalizations l, double scale) {
    if (!_vm.loggedIn) {
      return WriteLockBar(
        title: l.communityGuestWrite,
        body: null,
        actionLabel: l.loginRequired,
        scale: scale,
        onAction: _openLogin,
      );
    }
    if (_tab == _CommunityTab.myTeam) {
      if (_vm.myTeamId != null) return null;
      return WriteLockBar(
        title: l.communityNoTeamTitle,
        body: null,
        actionLabel: l.communityNoTeamAction,
        scale: scale,
        onAction: () => Navigator.of(
          context,
        ).pushReplacement(tabRoute(const MypageScreen())),
      );
    }
    final team = communityTeam(_otherTeamId);
    return WriteLockBar(
      title: team == null
          ? l.communityGuestWrite
          : l.communityLockedTitle(team.name),
      body: l.communityLockedBody,
      actionLabel: l.communityLockedAction,
      scale: scale,
      onAction: () => _goToTab(_CommunityTab.all),
    );
  }
}

/// 무한 스크롤이 붙은 글 목록. 페이지마다 스크롤 위치가 따로 있어야 해서
/// [ScrollController] 를 각자 든다.
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.scale,
  });

  final String title;

  /// 지금 보고 있는 게시판 이름. 아직 정해지지 않았으면 null.
  final String? subtitle;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        14 * scale,
        20 * scale,
        10 * scale,
      ),
      // 바깥 Column 의 crossAxisAlignment 기본값이 center 라, 폭을 명시하지
      // 않으면 이 헤더가 자기 글자 폭만큼 줄어들며 화면 가운데로 밀린다.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 20 * scale,
                height: 1.35,
                color: AppColors.narText,
              ),
            ),
            if (sub != null)
              Text(
                sub,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 13 * scale,
                  height: 1.45,
                  color: AppColors.narText2,
                ),
              ),
          ],
        ),
      ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44 * scale,
        padding: EdgeInsets.symmetric(horizontal: 18 * scale),
        decoration: BoxDecoration(
          gradient: AppColors.narBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/pencil.svg',
              width: 16 * scale,
              height: 16 * scale,
              colorFilter: const ColorFilter.mode(
                AppColors.narText,
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
                color: AppColors.narText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
