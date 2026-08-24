import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/nar_tab_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_post.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../login/login_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import 'community_dummy.dart';
import 'community_permission.dart';
import 'community_teams.dart';
import 'component/post_list_item.dart';
import 'component/team_chip_rail.dart';
import 'component/write_lock_bar.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';

/// 커뮤니티 — 전체 · 우리팀 · 다른팀.
///
/// 읽기는 누구에게나 열려 있고, 글쓰기만 전체 게시판과 내 응원팀 게시판으로
/// 제한된다([canWriteToBoard]). 그래서 목록 전체를 `GuestLockOverlay` 로 덮지
/// 않는다 — 비회원도 읽을 수 있어야 하므로 쓰기 버튼에서만 막는다.
///
/// **우리팀을 다른팀과 분리한 이유**: 팀 탭 하나에 10개 팀을 칩으로 늘어놓으면
/// 내 팀에 가려면 매번 레일에서 찾아야 하고, 무엇보다 쓸 수 있는 곳(내 팀)과 못
/// 쓰는 곳(나머지)이 같은 탭에 섞여 잠금 바가 떴다 사라졌다 한다. 탭을 나누면
/// "이 탭은 내가 쓰는 곳, 저 탭은 읽는 곳"이 고정된다.
///
/// 이번 회차는 백엔드 API 가 없어 [community_dummy] 의 정적 데이터를 쓴다.
/// 그래서 ViewModel 없이 화면 안 [setState] 로만 상태를 둔다.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

/// 상단 탭. 순서가 곧 [PageView] 인덱스다.
enum _CommunityTab { all, myTeam, otherTeams }

class _CommunityScreenState extends State<CommunityScreen> {
  final PageController _pageController = PageController();

  _CommunityTab _tab = _CommunityTab.all;

  /// '다른팀' 탭에서 보고 있는 팀. 내 팀은 이 목록에서 빠진다.
  late int _otherTeamId = _otherTeams.first.id;

  /// 내 응원팀을 뺀 나머지 팀 게시판.
  static List<CommunityBoard> get _otherTeams => [
    for (final board in kDummyTeamBoards)
      if (board.id != kDummyMyTeamId) board,
  ];

  int? get _boardId => switch (_tab) {
    _CommunityTab.all => CommunityBoard.allId,
    // 응원팀 미설정이면 '우리팀' 탭에 띄울 게시판 자체가 없다.
    _CommunityTab.myTeam => kDummyMyTeamId,
    _CommunityTab.otherTeams => _otherTeamId,
  };

  @override
  void initState() {
    super.initState();
    // 게시글은 더미지만 팀 로고·이름은 실제 API 로 채운다. 실패해도 색 원
    // 폴백으로 그려지므로 결과를 기다리거나 에러를 띄우지 않는다.
    loadCommunityTeams();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  void _openWrite() {
    if (!kDummyLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
      return;
    }
    final boardId = _boardId;
    if (boardId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostWriteScreen(initialBoardId: boardId),
      ),
    );
  }

  /// 당겨서 새로고침. 더미라 다시 그릴 것이 없어 짧게 쉬었다 끝낸다.
  /// 백엔드가 붙으면 여기서 리포지토리를 다시 부른다.
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final canWrite = canWriteToBoard(
      loggedIn: kDummyLoggedIn,
      myTeamId: kDummyMyTeamId,
      boardId: _boardId ?? CommunityBoard.allId,
    );

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
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
                    onPageChanged: (i) =>
                        setState(() => _tab = _CommunityTab.values[i]),
                    children: [
                      _board(CommunityBoard.allId, scale),
                      _myTeamPage(l, scale),
                      _otherTeamsPage(scale),
                    ],
                  ),
                ),
              ],
            ),
            if (canWrite)
              Positioned(
                right: 20 * scale,
                // 하단 네비(bottom 26 + 높이 72)와 넉넉히 띄운다. 바짝 붙이면
                // 네비의 유리 효과가 FAB 그라데이션을 굴절시켜 마지막 탭이
                // 보라색으로 물들어 활성 탭처럼 보인다.
                bottom: 128 * scale,
                child: _WriteFab(
                  label: l.communityWrite,
                  scale: scale,
                  onTap: _openWrite,
                ),
              )
            else
              Positioned(
                left: 16 * scale,
                right: 16 * scale,
                bottom: 122 * scale,
                child: _lockBar(l, scale),
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
    );
  }

  /// 헤더 아래에 지금 보고 있는 게시판 이름을 붙인다. 탭 라벨('우리팀')만으로는
  /// 어느 팀 게시판인지, 다른팀 탭에서 어떤 팀을 고른 상태인지 알 수 없다.
  String? _boardName(AppLocalizations l) {
    final boardId = _boardId;
    if (boardId == null) return null;
    if (boardId == CommunityBoard.allId) return l.communityBoardAll;
    return l.communityBoardTeam(boardDisplayName(dummyBoard(boardId)));
  }

  Widget _myTeamPage(AppLocalizations l, double scale) {
    final myTeamId = kDummyMyTeamId;
    if (myTeamId == null) {
      return _Empty(message: l.communityNoTeamTitle, scale: scale);
    }
    return _board(myTeamId, scale);
  }

  Widget _otherTeamsPage(double scale) {
    return Column(
      children: [
        TeamChipRail(
          boards: _otherTeams,
          selectedId: _otherTeamId,
          myTeamId: null, // 내 팀은 이 목록에 없으므로 별표도 없다.
          scale: scale,
          onSelected: (id) => setState(() => _otherTeamId = id),
        ),
        Expanded(child: _board(_otherTeamId, scale)),
      ],
    );
  }

  Widget _board(int boardId, double scale) {
    final l = AppLocalizations.of(context)!;
    final posts = dummyPosts(boardId);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.narText,
      backgroundColor: AppColors.narDark600,
      child: posts.isEmpty
          // 빈 목록에서도 당길 수 있어야 하므로 스크롤 가능한 리스트로 감싼다.
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 120 * scale),
                _Empty(message: l.communityEmpty, scale: scale),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 170 * scale),
              itemCount: posts.length,
              itemBuilder: (context, i) => PostListItem(
                post: posts[i],
                scale: scale,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetailScreen(post: posts[i]),
                  ),
                ),
              ),
            ),
    );
  }

  /// 쓰기가 막힌 이유는 셋 중 하나다 — 비회원 / 응원팀 미설정 / 다른 팀 게시판.
  /// 각각 다음에 할 수 있는 행동이 다르므로 문구와 액션을 나눈다.
  Widget _lockBar(AppLocalizations l, double scale) {
    if (!kDummyLoggedIn) {
      return WriteLockBar(
        title: l.communityGuestWrite,
        body: null,
        actionLabel: l.loginRequired,
        scale: scale,
        onAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
      );
    }
    if (kDummyMyTeamId == null) {
      return WriteLockBar(
        title: l.communityNoTeamTitle,
        body: null,
        actionLabel: l.communityNoTeamAction,
        scale: scale,
        // 실제로는 온보딩 팀 스텝(또는 프로필 수정)으로 보낸다.
        onAction: () => Navigator.of(
          context,
        ).pushReplacement(tabRoute(const MypageScreen())),
      );
    }
    return WriteLockBar(
      title: l.communityLockedTitle(boardDisplayName(dummyBoard(_otherTeamId))),
      body: l.communityLockedBody,
      actionLabel: l.communityLockedAction,
      scale: scale,
      onAction: () => _goToTab(_CommunityTab.all),
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

  /// 지금 보고 있는 게시판 이름. 우리팀 게시판이 없는 상태면 null.
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
