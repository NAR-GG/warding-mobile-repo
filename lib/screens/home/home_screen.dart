import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/nar_banner.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../model/notice.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/home/home_viewmodel.dart';
import '../community/community_screen.dart';
import '../match_list/match_list_screen.dart';
import '../my_players/my_players_screen.dart';
import '../mypage/mypage_screen.dart';
import '../notice/notice_detail_screen.dart';
import '../notification/notification_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import 'component/home_community_section.dart';
import 'component/home_content_section.dart';
import 'component/home_solo_rank_section.dart';
import 'component/home_standings_section.dart';
import 'component/home_today_matches_section.dart';

/// 홈 화면 — 구독 선수 솔랭 상태 · 오늘 경기 · 순위표 · 커뮤니티 · 콘텐츠
/// 5개 섹션 + 하단 네비 '홈' 탭에 해당한다.
///
/// 앱 진입점(스플래시·로그인·온보딩 완료 이후 첫 화면)이기도 하다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final HomeViewModel _viewModel = HomeViewModel();

  /// 배너 탭 — 스케줄 화면과 같은 공지 상세로 연다.
  void _openNotice(Notice notice) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NoticeDetailScreen(notice: notice, showListButton: true),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
  }

  /// 앱이 포그라운드로 돌아오면 홈을 다시 불러온다(최근에 불렀으면 건너뜀).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _viewModel.refreshOnResume();
  }

  /// "커뮤니티 전체" — 커뮤니티 탭으로 전환한다. push 하면 탭 루트가 쌓인다.
  void _openCommunity() {
    Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
  }

  /// 오늘 경기 "일정 전체" — 일정 탭으로 전환한다(spec 사용자 흐름 4).
  void _openSchedule() {
    Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
  }

  /// "구독 N명 전체"·조용한 상태 줄 — 내 선수 화면. push 라서 뒤로가기가
  /// 홈으로 돌아온다(spec 사용자 흐름 3).
  void _openMyPlayers() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyPlayersScreen()));
  }

  /// 구독 0명 빈 카드의 "선수 구독하기" — 마이구독 탭(비회원은 그 화면이
  /// 로그인 안내를 띄운다).
  void _openSubscription() {
    Navigator.of(context).pushReplacement(tabRoute(const SubscriptionScreen()));
  }

  /// 벨 — 알림함. 읽고 돌아오면 배지를 다시 센다.
  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationScreen()));
    await _viewModel.refreshUnreadNotifications();
  }

  /// 하단 네비 탭 선택. '홈'을 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
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
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => Column(
                children: [
                  _TopBar(
                    scale: scale,
                    unreadCount: _viewModel.unreadNotificationCount,
                    onBellTap: _openNotifications,
                  ),
                  if (_viewModel.bannerVisible)
                    NarBanner(
                      scale: scale,
                      icon: Text('📢', style: TextStyle(fontSize: 16 * scale)),
                      text:
                          _viewModel.promotedNotice?.title ??
                          l.homeNoticeDefault,
                      // 배너는 promotedNotice 가 있을 때만 보이므로 보통 열 공지가 있다.
                      onTap: _viewModel.promotedNotice == null
                          ? null
                          : () => _openNotice(_viewModel.promotedNotice!),
                      onClose: _viewModel.dismissBanner,
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      // 좌우 여백은 각 섹션이 스스로 20*scale 패딩을 두른다 —
                      // 칩 줄(NarChipMultiSelect)은 가로 스크롤 영역이라 자체
                      // horizontalPadding(홈은 20)을 받으므로, 여기서 일괄로
                      // 좌우 패딩을 주면 겹쳐서 더 좁아 보인다.
                      padding: EdgeInsets.only(
                        top: 16 * scale,
                        // 떠 있는 하단 네비(72*scale + 바닥 26 + 간격 8)에
                        // 안 가리도록 나머지 화면들과 같은 계산을 쓴다.
                        bottom: 72 * scale + 34,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeSoloRankSection(
                            viewModel: _viewModel,
                            scale: scale,
                            onOpenMyPlayers: _openMyPlayers,
                            onSubscribe: _openSubscription,
                          ),
                          SizedBox(height: 28 * scale),
                          HomeTodayMatchesSection(
                            viewModel: _viewModel,
                            scale: scale,
                            onSeeSchedule: _openSchedule,
                          ),
                          SizedBox(height: 28 * scale),
                          HomeStandingsSection(
                            viewModel: _viewModel,
                            scale: scale,
                          ),
                          SizedBox(height: 28 * scale),
                          HomeCommunitySection(
                            viewModel: _viewModel,
                            scale: scale,
                            onSeeAllCommunity: _openCommunity,
                          ),
                          SizedBox(height: 28 * scale),
                          HomeContentSection(
                            viewModel: _viewModel,
                            scale: scale,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 공용 하단 네비 — 바닥에서 26px 띄움 (다른 탭 화면들과 동일)
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: AppBottomNav(
                currentTab: AppNavTab.home,
                onTabSelected: _onTabSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로고 + 알림 벨. 배지는 커뮤니티 알림함 미읽음 수이고 0 이면 숨긴다.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.scale,
    required this.unreadCount,
    required this.onBellTap,
  });

  final double scale;
  final int unreadCount;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 12 * scale,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset('assets/images/warding.svg', height: 20 * scale),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBellTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36 * scale,
                  height: 36 * scale,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.narBgTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/bell.svg',
                    width: 18 * scale,
                    height: 18 * scale,
                    colorFilter: const ColorFilter.mode(
                      AppColors.narText,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2 * scale,
                    right: -2 * scale,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.5 * scale,
                        vertical: 1.5 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.liveAccent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.narDark800,
                          width: 2 * scale,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5 * scale,
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
