/// Mixpanel 이벤트 설계(P0)의 이름·값 상수.
///
/// 설계 원본은 노션 "이벤트 로그" 문서다. 규칙 요약:
/// - `event_name = {object}_{action}`, 모두 소문자·언더바
/// - `page`·`section` 은 예약어라 화면·섹션 단위 이벤트에만 쓴다
/// - 화면 구분은 이벤트명이 아니라 [AnalyticsPage] 로 한다
/// - 프로퍼티 값도 소문자·언더바 (`match_detail`)
/// - 값이 없으면 키를 보내지 않는다. `prev_page` 만 [AnalyticsPage.none] 을 쓴다
///
/// 문자열을 호출부에 흩뿌리지 않고 여기 모아 둔다 — 오타 하나가 집계를
/// 조용히 쪼개는데, 그건 대시보드를 볼 때까지 아무도 모른다.
library;

/// 이벤트명. `{object}_{action}` 규칙.
class AnalyticsEvent {
  AnalyticsEvent._();

  // 화면·섹션 단위 (object = page / section)
  static const String pageView = 'page_view';
  static const String sectionView = 'section_view';

  // 화면 안 요소 (object = 요소 이름)
  static const String bottomNavTabClick = 'bottom_nav_tab_click';
  static const String matchCardClick = 'match_card_click';
  static const String postCardClick = 'post_card_click';
  static const String loginButtonClick = 'login_button_click';
  static const String guestStartButtonClick = 'guest_start_button_click';
  static const String withdrawButtonClick = 'withdraw_button_click';
  static const String leagueCardClick = 'league_card_click';
  static const String teamCardClick = 'team_card_click';
  static const String playerCardClick = 'player_card_click';
  static const String nextButtonClick = 'next_button_click';
  static const String skipButtonClick = 'skip_button_click';
  static const String pushPermissionButtonClick =
      'push_permission_button_click';
  static const String subscribeButtonClick = 'subscribe_button_click';
  static const String reviewSubmitButtonClick = 'review_submit_button_click';
}

/// 프로퍼티 키.
class AnalyticsProp {
  AnalyticsProp._();

  // 모든 이벤트 공통
  static const String locationPage = 'location_page';
  static const String locationSection = 'location_section';

  /// 앱 버전(`1.0.36+86`). super property 로 등록해 모든 이벤트에 자동으로
  /// 붙는다([Analytics.init]) — 호출부에서 직접 실을 필요가 없다.
  static const String appVersion = 'app_version';

  // page 단위
  static const String prevPage = 'prev_page';

  // 식별자
  /// match_id 는 **string** 이다. 18자리라(예: 113990000000000001) JS 안전 정수
  /// 한계(2^53-1)를 넘어서, 숫자로 보내면 믹스패널에서 끝자리가 뭉개진다.
  static const String matchId = 'match_id';
  static const String postId = 'post_id';
  static const String playerId = 'player_id';
  static const String teamId = 'team_id';
  static const String league = 'league';

  // 상태·맥락
  static const String tabName = 'tab_name';
  static const String position = 'position';
  static const String month = 'month';
  static const String sortOrder = 'sort_order';
  static const String spoilerPrevention = 'spoiler_prevention';
  static const String entryPoint = 'entry_point';
  static const String matchState = 'match_state';
  static const String loginStatus = 'login_status';
  static const String loginMethod = 'login_method';
  static const String step = 'step';
  static const String selectedCount = 'selected_count';
  static const String permissionResult = 'permission_result';
  static const String isOn = 'is_on';
  static const String targetType = 'target_type';
  static const String ratingScore = 'rating_score';
  static const String commentLength = 'comment_length';
  static const String setNo = 'set_no';
}

/// `location_page` / `prev_page` 값.
///
/// 라우트 이름으로도 그대로 쓴다([RouteSettings.name]) — observer 가 이 값을
/// 읽어 `location_page`·`prev_page` 를 채운다.
class AnalyticsPage {
  AnalyticsPage._();

  /// 앱 진입(스플래시 이전)처럼 직전 화면이 없을 때의 `prev_page`.
  static const String none = 'none';

  static const String splash = 'splash';
  static const String login = 'login';
  static const String onboarding = 'onboarding';
  static const String home = 'home';
  static const String schedule = 'schedule';
  static const String matchDay = 'match_day';
  static const String matchList = 'match_list';
  static const String matchDetail = 'match_detail';
  static const String community = 'community';
  static const String postDetail = 'post_detail';
  static const String postWrite = 'post_write';
  static const String communitySearch = 'community_search';
  static const String notification = 'notification';
  static const String mypage = 'mypage';
  static const String myPlayers = 'my_players';
  static const String notice = 'notice';
  static const String noticeDetail = 'notice_detail';
  static const String playerRating = 'player_rating';
  static const String subscription = 'subscription';
  static const String subscriptionSettings = 'subscription_settings';
  static const String withdraw = 'withdraw';
  static const String accountSetting = 'account_setting';
  static const String profileEdit = 'profile_edit';
  static const String myReview = 'my_review';
  static const String myCommunityActivity = 'my_community_activity';
  static const String mySubscriptionSetting = 'my_subscription_setting';
  static const String matchListSetting = 'match_list_setting';
  static const String calendarSetting = 'calendar_setting';
  static const String guide = 'guide';
  static const String shorts = 'shorts';
  static const String cheerAd = 'cheer_ad';
  static const String adGuide = 'ad_guide';
}

/// `location_section` 값.
class AnalyticsSection {
  AnalyticsSection._();

  /// 하단 네비는 6개 화면 공통이라 섹션을 고정값으로 둔다.
  static const String navigationBottom = 'navigation_bottom';

  // 온보딩 단계
  static const String league = 'league';
  static const String team = 'team';
  static const String player = 'player';
  static const String notification = 'notification';

  // match_detail 탭
  static const String matchData = 'match_data';
  static const String liveEvent = 'live_event';
  static const String playerRating = 'player_rating';

  // subscription_settings
  static const String allList = 'all_list';
}

/// `entry_point` 값. 사용자 의지가 아닌 진입이나 앱 외부 진입을 구분한다.
class AnalyticsEntryPoint {
  AnalyticsEntryPoint._();

  /// 앱 내 일반 이동.
  static const String inApp = 'in_app';

  // match_detail
  static const String push = 'push';
  static const String widget = 'widget';

  // login
  static const String appStart = 'app_start';

  /// 세션 만료로 튕겨 나온 진입. 사용자가 로그인하러 온 게 아니다.
  static const String sessionExpired = 'session_expired';

  /// 비회원 차단(GuestLockOverlay 등)으로 올라온 로그인.
  static const String guestLock = 'guest_lock';
}

/// 알림 권한 응답. 앱 내 '나중에' 는 OS 다이얼로그를 띄우지 않으므로
/// OS 거부와 같은 값으로 묶지 않는다.
class AnalyticsPermissionResult {
  AnalyticsPermissionResult._();

  static const String inAppDeny = 'in_app_deny';
  static const String osGranted = 'os_granted';
  static const String osDenied = 'os_denied';

  /// 설정 앱으로 앱을 벗어나는 이탈 지점.
  static const String osPermanentlyDenied = 'os_permanently_denied';
}

/// 그 밖의 열거형 값.
class AnalyticsValue {
  AnalyticsValue._();

  // login_status
  static const String loggedIn = 'logged_in';
  static const String guest = 'guest';

  // spoiler_prevention
  static const String on = 'on';
  static const String off = 'off';

  // target_type
  static const String team = 'team';
  static const String player = 'player';

  // match_state
  static const String matchBefore = 'before';
  static const String matchLive = 'live';
  static const String matchFinished = 'finished';
}

/// 코드 값 → 전송 값 변환.
///
/// 화면 표시용 문자열을 그대로 보내면 규칙(소문자·언더바)을 깨거나 기기 언어에
/// 따라 값이 갈린다. 변환은 전부 여기를 거친다.
class AnalyticsFormat {
  AnalyticsFormat._();

  /// `2026_10`. 코드의 `monthLabel` 은 화면용 `2026.10` 이라 쓸 수 없다.
  static String month(DateTime month) =>
      '${month.year}_${month.month.toString().padLeft(2, '0')}';

  /// 리그 이름을 값 규칙에 맞춘다: `LCK` → `lck`, `LCK Challengers` →
  /// `lck_challengers`. 리그는 team/player 와 달리 ID 가 없어 이름을 쓴다.
  static String league(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  /// match_list 정렬 index(0=최근순, 1=오래된 순, 2=오늘 이후) → 전송 값.
  static String sortOrder(int index) => switch (index) {
    0 => 'recent',
    2 => 'upcoming',
    _ => 'oldest',
  };

  /// 온보딩 단계 enum 이름을 그대로 쓴다. `step` 값은 코드의 OnboardingStep
  /// 이름(league/team/player/notification)과 같게 유지한다.
  static String onboardingStep(Enum step) => step.name;
}
