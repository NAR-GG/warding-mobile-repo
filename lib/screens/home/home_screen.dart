import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/nar_banner.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/home/home_viewmodel.dart';
import '../community/community_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
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
/// 로그인 후 진입점은 여전히 [ScheduleScreen]이다 — 홈 탭을 눌러야 들어온다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeViewModel _viewModel = HomeViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
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
                  _TopBar(scale: scale),
                  if (_viewModel.bannerVisible)
                    NarBanner(
                      scale: scale,
                      icon: Text('📢', style: TextStyle(fontSize: 16 * scale)),
                      text: l.homeNoticeDefault,
                      onClose: _viewModel.dismissBanner,
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      // 좌우 여백은 각 섹션이 스스로 20*scale 패딩을 두른다 —
                      // NarChipMultiSelect(순위표 리그 칩, 커뮤니티 정렬,
                      // 콘텐츠 탭)는 자체 16*scale 패딩을 가진 공용 컴포넌트라
                      // 여기서 일괄로 좌우 패딩을 주면 겹쳐서 더 좁아 보인다.
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
                          ),
                          SizedBox(height: 28 * scale),
                          HomeTodayMatchesSection(
                            viewModel: _viewModel,
                            scale: scale,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.scale});

  final double scale;

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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
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
                      '3',
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
