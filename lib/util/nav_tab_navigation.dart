import 'package:flutter/material.dart';

import '../components/app_bottom_nav.dart';
import '../screens/community/community_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/match_list/match_list_screen.dart';
import '../screens/mypage/mypage_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import 'analytics.dart';
import 'analytics_events.dart';
import 'analytics_route_observer.dart';
import 'tab_route.dart';

/// 하단 네비 탭 선택을 처리한다. 6개 탭 화면이 공통으로 쓴다.
///
/// 화면마다 같은 분기를 복사해 두면 탭이 늘거나 이름이 바뀔 때 한 곳을
/// 빠뜨리기 쉬워서 하나로 모았다. `bottom_nav_tab_click` 계측도 여기서 한다.
///
/// [current] 는 지금 화면의 탭이다. 같은 탭을 다시 누르면 화면 전환은 하지
/// 않지만 **이벤트는 찍는다** — 아무 반응 없는 버튼을 반복해 누르는 것은
/// UX 신호라서, 재탭 여부는 `location_page == tab_name` 으로 판별한다.
void handleNavTabSelected(
  BuildContext context,
  AppNavTab current,
  AppNavTab tab,
) {
  Analytics.track(AnalyticsEvent.bottomNavTabClick, {
    AnalyticsProp.locationPage: current.analyticsValue,
    AnalyticsProp.locationSection: AnalyticsSection.navigationBottom,
    AnalyticsProp.tabName: tab.analyticsValue,
  });

  if (tab == current) return;

  final (Widget screen, String page) = switch (tab) {
    AppNavTab.home => (const HomeScreen(), AnalyticsPage.home),
    AppNavTab.schedule => (const ScheduleScreen(), AnalyticsPage.schedule),
    AppNavTab.matchList => (const MatchListScreen(), AnalyticsPage.matchList),
    AppNavTab.community => (const CommunityScreen(), AnalyticsPage.community),
    AppNavTab.subscription => (
      const SubscriptionScreen(),
      AnalyticsPage.subscription,
    ),
    AppNavTab.mypage => (const MypageScreen(), AnalyticsPage.mypage),
  };

  Navigator.of(context).pushReplacement(tabRoute(screen, name: page));
}

/// 탭 화면 밖(홈의 '커뮤니티 전체' 등)에서 탭 화면으로 건너갈 때 쓴다.
/// 하단 네비 클릭이 아니므로 `bottom_nav_tab_click` 은 찍지 않는다.
void replaceWithTabScreen(BuildContext context, AppNavTab tab) {
  final (Widget screen, String page) = switch (tab) {
    AppNavTab.home => (const HomeScreen(), AnalyticsPage.home),
    AppNavTab.schedule => (const ScheduleScreen(), AnalyticsPage.schedule),
    AppNavTab.matchList => (const MatchListScreen(), AnalyticsPage.matchList),
    AppNavTab.community => (const CommunityScreen(), AnalyticsPage.community),
    AppNavTab.subscription => (
      const SubscriptionScreen(),
      AnalyticsPage.subscription,
    ),
    AppNavTab.mypage => (const MypageScreen(), AnalyticsPage.mypage),
  };
  Navigator.of(context).pushReplacement(tabRoute(screen, name: page));
}

/// 로그인·온보딩을 거쳐 홈으로 들어갈 때처럼 스택을 비우는 이동.
/// 직전 화면이 사라지므로 `prev_page` 를 [prevPage] 로 맞춘다.
void resetToHome(BuildContext context, {String? prevPage}) {
  AnalyticsRouteObserver.instance.overridePrevPage(prevPage);
  Navigator.of(context).pushAndRemoveUntil(
    tabRoute(const HomeScreen(), name: AnalyticsPage.home),
    (route) => false,
  );
}
