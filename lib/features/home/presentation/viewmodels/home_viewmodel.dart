import 'package:warding/features/solo_rank/data/solo_rank_sources.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_models.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/features/community/domain/community_remote_post.dart';
import 'package:warding/features/home/domain/home_models.dart';
import 'package:warding/features/news/data/news_source.dart';
import 'package:warding/features/news/domain/news_article.dart';
import 'package:warding/features/news/presentation/viewmodels/news_viewmodel.dart';
import 'package:warding/features/player_rating/data/review_source.dart';
import 'package:warding/features/player_rating/domain/review_item.dart';
import 'package:warding/features/player_rating/presentation/viewmodels/review_summary_viewmodel.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/domain/player_subscription.dart';
import 'package:warding/domain/schedule_match.dart';
import 'package:warding/features/standings/domain/standing.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';
import 'package:warding/features/standings/domain/worlds_standings.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/features/community/data/community_repository.dart';
import 'package:warding/features/community/presentation/viewmodels/community_summary_viewmodel.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';
import 'package:warding/features/notice/presentation/viewmodels/notice_banner_viewmodel.dart';
import 'package:warding/domain/repositories/member_notification_repository.dart';
import 'package:warding/features/notification/presentation/viewmodels/notification_badge_viewmodel.dart';
import 'package:warding/features/home/domain/usecases/get_preferred_team.dart';
import 'package:warding/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:warding/core/infrastructure/preference/notice_preference_repository.dart';
import 'package:warding/core/infrastructure/preference/team_preference_repository.dart';
import 'package:warding/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:warding/features/schedule/presentation/viewmodels/today_matches_viewmodel.dart';
import 'package:warding/features/shorts/domain/repositories/shorts_repository.dart';
import 'package:warding/features/shorts/presentation/viewmodels/shorts_summary_viewmodel.dart';
import 'package:warding/features/standings/domain/repositories/standings_repository.dart';
import 'package:warding/features/standings/domain/league_chip.dart';
import 'package:warding/features/standings/presentation/viewmodels/standings_viewmodel.dart';
import 'package:warding/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:warding/core/infrastructure/team/team_logo_directory.dart';
import 'package:warding/features/solo_rank/presentation/viewmodels/solo_cheer_controller.dart';
import 'package:warding/features/solo_rank/presentation/viewmodels/solo_rank_viewmodel.dart';
import 'package:warding/features/subscription/presentation/viewmodels/subscribed_players_viewmodel.dart';

/// 커뮤니티 섹션 정렬 기준. 정의는 커뮤니티 기능이 갖는다
/// ([CommunitySummarySort]) — 홈 말고도 쓸 수 있어야 해서다.
typedef HomeCommunitySort = CommunitySummarySort;

/// 콘텐츠 섹션 탭.
enum HomeContentTab { news, shorts }

/// 쇼츠 탭 필터. 정의는 쇼츠 기능이 갖는다 ([ShortsSummaryFilter]).
typedef HomeShortsFilter = ShortsSummaryFilter;

/// 대진 카드가 보여주는 뷰. 정의는 순위표 기능이 갖는다.
typedef WorldsStandingsView = StandingsView;

/// 홈 화면 상태.
///
/// 섹션마다 따로 불러온다(`/api/mobile/home` 한 번에 받기는 spec 미결).
/// 실데이터가 있는 섹션(공지·오늘 경기·순위·커뮤니티 글·쇼츠·구독 수)은
/// repository 로, 홈 전용 매핑이 필요한 섹션(솔랭 상태·평점 한줄평·뉴스)은
/// [SoloRankSource]/[ReviewSource]/[NewsSource] 로 받는다.
///
/// spec 상 로딩·에러 상태는 그리지 않으므로 그런 getter 를 두지 않는다.
/// 각 섹션 로더는 실패를 `debugPrint` 로만 남기고 마지막 값을 그대로 둔다.
/// (솔랭 폴링 실패 시 마지막 값을 유지할지는 spec 미결 — 잠정으로 유지한다.)
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    NoticeRepository? notices,
    NoticePreferenceRepository? noticePreferences,
    ScheduleRepository? schedule,
    StandingsRepository? standings,
    CommunityRepository? communityRepository,
    ShortsRepository? shortsRepository,
    SubscriptionRepository? subscriptions,
    MemberNotificationRepository? memberNotifications,
    SoloRankSource? soloRank,
    WorldsSoloSource? worlds,
    CheerSource? cheer,
    ReviewSource? reviews,
    NewsSource? news,
    AuthService? auth,
    OnboardingRepository? onboarding,
    TeamPreferenceRepository? teamPreferences,
    GetPreferredTeam? getPreferredTeam,
    CommunitySummaryViewModel? communitySummary,
    NoticeBannerViewModel? noticeBannerViewModel,
    NotificationBadgeViewModel? notificationBadgeViewModel,
    TodayMatchesViewModel? todayMatchesViewModel,
    SubscribedPlayersViewModel? subscribedPlayersViewModel,
    SoloRankViewModel? soloRankViewModel,
    ShortsSummaryViewModel? shortsSummary,
    StandingsViewModel? standingsViewModel,
    ReviewSummaryViewModel? reviewSummaryViewModel,
    NewsViewModel? newsViewModel,
  }) : // 솔랭·뉴스는 실제 API, 평점은 빈 소스. 목업은 HOME_MOCKS=true 일 때만.
       // 응원팀을 정하는 규칙은 UseCase 가 갖는다 — repository 3개를 조합하고
       // 폴백 순서가 규칙이라서다. 세 파라미터는 그 UseCase 로 넘긴다(테스트가
       // 개별 fake 를 주입하던 경로를 그대로 유지한다).
       _getPreferredTeam =
           getPreferredTeam ??
           GetPreferredTeam(
             auth: auth,
             onboarding: onboarding,
             teamPreferences: teamPreferences,
           ),
       community =
           communitySummary ??
           CommunitySummaryViewModel(repository: communityRepository),
       noticeBanner =
           noticeBannerViewModel ??
           NoticeBannerViewModel(
             repository: notices,
             preferences: noticePreferences,
           ),
       notificationBadge =
           notificationBadgeViewModel ??
           NotificationBadgeViewModel(repository: memberNotifications),
       todayMatches =
           todayMatchesViewModel ?? TodayMatchesViewModel(repository: schedule),
       subscribedPlayers =
           subscribedPlayersViewModel ??
           SubscribedPlayersViewModel(repository: subscriptions, auth: auth),
       standings_ =
           standingsViewModel ??
           StandingsViewModel(repository: standings, schedule: schedule),
       reviewSummary =
           reviewSummaryViewModel ?? ReviewSummaryViewModel(source: reviews),
       newsVm = newsViewModel ?? NewsViewModel(source: news) {
    // 솔랭 VM 은 **위에서 만든 구독 VM 과 같은 인스턴스**를 받아야 한다 —
    // initializer 에서 양쪽을 만들면 두 벌이 생겨, refreshAll 이 로드한 쪽과
    // 솔랭이 보는 쪽이 달라진다(카드가 loading 에서 안 벗어난다).
    solo =
        soloRankViewModel ??
        SoloRankViewModel(
          subscriptions: subscribedPlayers,
          source: soloRank,
          worlds: worlds,
          cheer: cheer,
        );
    // 쇼츠는 응원팀을 알아야 "내 팀" 필터가 된다. 그 결정 규칙은 쇼츠 기능
    // 소유가 아니라 UseCase 가 가지므로 콜백으로 넘긴다.
    shorts =
        shortsSummary ??
        ShortsSummaryViewModel(
          repository: shortsRepository,
          resolveTeamCode: () async => (await _getPreferredTeam())?.code,
          cardCount: shortsCardCount,
        );
    // 섹션 ViewModel 의 통지를 홈 통지로 올린다 — 홈 위젯들이 HomeViewModel
    // 하나만 구독하는 기존 구조를 유지한다. 섹션을 독립 구독하는 화면은
    // 그 ViewModel 을 직접 쓰면 된다.
    community.addListener(_notify);
    noticeBanner.addListener(_notify);
    notificationBadge.addListener(_notify);
    todayMatches.addListener(_notify);
    subscribedPlayers.addListener(_notify);
    solo.addListener(_notify);
    shorts.addListener(_notify);
    standings_.addListener(_notify);
    reviewSummary.addListener(_notify);
    newsVm.addListener(_notify);
    // 스플래시가 미리 받아 둔 공지가 있으면 첫 프레임부터 그 상태로 그린다
    // ([ScheduleViewModel] 과 같은 이유 — 뒤늦게 끼어들면 아래 섹션을 민다).
    unawaited(refreshAll());
    // 순위표·솔랭·커뮤니티 섹션이 모두 이 싱글톤 캐시로 팀 로고를 그린다.
    // 홈 진입 시점에 한 번 당겨두면 나중에 빌드되는 위젯(라이즈 그룹 등)도
    // 빈 배지로 시작하지 않는다.
    TeamLogoDirectory.instance.ensureLoaded();
    // 솔랭 카드는 진행 중인 게임의 실시간성이 중요한 유일한 섹션이라
    // 5초 폴링을 건다(2026-09-29 결정). 나머지 섹션은 앱 복귀(30초 간격)만
    // 으로 충분하다 — 경기 일정·순위표·커뮤니티 글은 그 정도로 자주 안 바뀐다.
    solo.startPolling();
  }


  final GetPreferredTeam _getPreferredTeam;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    community.removeListener(_notify);
    community.dispose();
    noticeBanner.removeListener(_notify);
    noticeBanner.dispose();
    notificationBadge.removeListener(_notify);
    notificationBadge.dispose();
    todayMatches.removeListener(_notify);
    todayMatches.dispose();
    // 남은 응원을 먼저 보낸다 — solo.dispose() 가 컨트롤러를 닫는다.
    unawaited(solo.flushCheers());
    solo.removeListener(_notify);
    solo.dispose();
    subscribedPlayers.removeListener(_notify);
    subscribedPlayers.dispose();
    shorts.removeListener(_notify);
    shorts.dispose();
    standings_.removeListener(_notify);
    standings_.dispose();
    reviewSummary.removeListener(_notify);
    reviewSummary.dispose();
    newsVm.removeListener(_notify);
    newsVm.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 앱 복귀 새로고침의 최소 간격 — 잠깐 다녀온 복귀마다 전 섹션을 다시
  /// 부르지 않게 한다.
  static const Duration resumeRefreshInterval = Duration(seconds: 30);

  DateTime? _lastRefreshAt;

  /// 앱이 포그라운드로 돌아왔을 때 부른다. 마지막 [refreshAll] 이
  /// [minInterval] 안이면 건너뛴다.
  Future<void> refreshOnResume({
    Duration minInterval = resumeRefreshInterval,
  }) async {
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < minInterval) return;
    await refreshAll();
  }

  /// 모든 섹션을 다시 불러온다. 섹션끼리는 서로 기다리지 않는다 — 한 섹션이
  /// 실패해도 나머지는 그대로 채워진다.
  ///
  /// 복귀 새로고침과 겹칠 수 있어, 섹션 로더마다 세대 번호를 두어 늦게 도착한
  /// 옛 응답이 새 응답을 덮지 않게 한다.
  Future<void> refreshAll() async {
    _lastRefreshAt = DateTime.now();
    await Future.wait([
      noticeBanner.load(),
      community.load(),
      notificationBadge.refresh(),
      subscribedPlayers.load(),
      solo.load(),
      solo.loadWorlds(),
      todayMatches.load(),
      standings_.loadLeagueChips(),
      standings_.loadStandings(),
      reviewSummary.load(),
      newsVm.load(),
      shorts.load(),
    ]);
  }

  // ---- 공지 배너 ----
  //
  // 로직은 `features/notice` 가 갖는다 — 배너가 필요한 화면은 어디서든
  // [NoticeBannerViewModel] 을 구독하면 된다.
  final NoticeBannerViewModel noticeBanner;

  Notice? get promotedNotice => noticeBanner.notice;
  bool get bannerVisible => noticeBanner.visible;

  /// 배너 ✕ — 닫은 공지는 일정 화면 배너와 같은 저장소에 기록한다.
  void dismissBanner() => noticeBanner.dismiss();

  // ---- 상단 알림 배지 ----
  //
  // 로직은 `features/notification` 이 갖는다 — 벨 배지가 필요한 화면은
  // 어디서든 [NotificationBadgeViewModel] 을 구독하면 된다.
  final NotificationBadgeViewModel notificationBadge;

  /// 헤더 벨 배지용 미읽음 수. 0 이면 배지를 숨긴다.
  int get unreadNotificationCount => notificationBadge.unreadCount;

  /// 미읽음 수를 다시 센다. 알림 화면에서 돌아올 때도 부른다.
  Future<void> refreshUnreadNotifications() => notificationBadge.refresh();

  // ---- 구독 선수 · 솔랭 · 월즈 솔랭 ----
  //
  // 로직은 `features/subscription`·`features/solo_rank` 가 갖는다.
  // 솔랭 VM 은 구독 VM 을 생성자로 받는다 — 카드가 보여주는 것이 "구독한
  // 선수의 솔랭"이라 그 의존은 숨길 게 아니라 드러내는 것이 맞다.
  final SubscribedPlayersViewModel subscribedPlayers;
  late final SoloRankViewModel solo;

  /// 응원 컨트롤러 — 카드가 직접 구독해 탭마다 홈 전체가 아니라 응원 영역만
  /// 다시 그린다.
  SoloCheerController get cheers => solo.cheers;

  int get subscribedTotal => solo.subscribedTotal;
  List<PlayerSubscription> get subscribedFaces => solo.subscribedFaces;
  static const int quietFaceCount = SoloRankViewModel.quietFaceCount;

  List<LiveSoloPlayer> get soloLive => solo.live;
  List<FinishedSoloPlayer> get soloFinished => solo.finished;
  int get soloHiddenCount => solo.hiddenCount;
  SoloCardState get soloState => solo.cardState;

  Set<String> get pinnedPlayerNames => solo.pinnedNames;
  void togglePin(String name) => solo.togglePin(name);

  int get soloSwipeIndex => solo.swipeIndex;
  void setSoloSwipeIndex(int index) => solo.setSwipeIndex(index);

  /// 앱이 백그라운드로 갈 때 미결 응원을 보낸다.
  Future<void> flushCheers() => solo.flushCheers();

  /// 내 선수 화면(보기 전용)에서 돌아왔을 때 솔랭 상태를 다시 불러온다.
  ///
  /// 홈은 화면 전환(push/pop)으로는 새로고침되지 않고 앱 복귀(30초 간격)
  /// 때만 갱신되므로, 그 사이 선수가 솔랭을 시작·종료해도 내 선수 화면과
  /// 어긋난 채로 남는다 — 벨 알림함과 같은 방식으로 이 화면만 돌아올 때
  /// 콕 집어 새로고침한다.
  Future<void> refreshSoloOnReturn() => solo.refreshOnReturn();

  /// 구독 설정 화면(선수 구독하기)에서 돌아왔을 때 구독 목록과 솔랭 상태를
  /// 함께 다시 불러온다.
  Future<void> refreshSubscriptionsOnReturn() =>
      solo.refreshWithSubscriptions();

  bool get worldsVisible => solo.worldsVisible;
  int get worldsTeamCount => solo.worldsTeamCount;
  List<LiveSoloPlayer> get worldsLiveAll => solo.worldsLiveAll;
  List<LiveSoloPlayer> get worldsLive => solo.worldsLive;
  FinishedSoloPlayer? get worldsLastFinished => solo.worldsLastFinished;

  // 폴링 — 솔랭 카드만 실시간성이 필요하다.
  void pauseSoloPolling() => solo.pausePolling();
  void resumeSoloPolling() => solo.resumePolling();

  // ---- 섹션 2: 오늘 경기 ----
  //
  // 로직은 `features/schedule` 이 갖는다 — 오늘 경기 요약이 필요한 화면은
  // 어디서든 [TodayMatchesViewModel] 을 구독하면 된다.
  final TodayMatchesViewModel todayMatches;

  /// 오늘 경기 — 진행 중인 경기를 앞으로, 그 밖에는 서버 순서 그대로.
  List<ScheduleMatch> get todayMatchesSorted => todayMatches.sorted;
  bool get todayMatchesLoading => todayMatches.loading;

  /// 오늘 모든 리그의 경기를 불러온다. 실패하면 마지막 값을 유지한다.
  Future<void> loadTodayMatches() => todayMatches.load();

  // ---- 섹션 3: 순위표 ----
  //
  // 로직은 `features/standings` 가 갖는다 — 리그 칩·표/대진 전환 규칙이
  // 한 덩어리라 홈 밖에서도 그대로 쓸 수 있어야 한다.
  final StandingsViewModel standings_;

  List<LeagueChip> get leagueChips => standings_.leagueChips;
  String get selectedLeague => standings_.selectedLeague;
  void selectLeague(String code) => standings_.selectLeague(code);

  StandingsResult? get standings => standings_.standings;
  bool get standingsLoading => standings_.standingsLoading;
  WorldsStandings? get worldsStandings => standings_.worldsStandings;
  bool get standingsIsBracket => standings_.standingsIsBracket;

  WorldsStandingsView get worldsView => standings_.worldsView;
  void toggleWorldsView() => standings_.toggleWorldsView();
  bool get worldsHasBothViews => standings_.worldsHasBothViews;
  WorldsStandingsView get effectiveWorldsView => standings_.effectiveWorldsView;

  bool get standingsExpanded => standings_.standingsExpanded;
  void toggleStandingsExpanded() => standings_.toggleStandingsExpanded();

  // ---- 섹션 4: 커뮤니티 ----
  //
  // 로직은 `features/community` 가 갖는다 — 홈 전용이 아니라 커뮤니티 요약이
  // 필요한 화면은 어디서든 [CommunitySummaryViewModel] 을 구독하면 된다.
  // 아래 getter 들은 기존 위젯·테스트가 쓰던 이름을 그대로 유지하는 위임이다.
  final CommunitySummaryViewModel community;

  HomeCommunitySort get communitySort => community.sort;
  void setCommunitySort(HomeCommunitySort sort) => community.setSort(sort);
  List<HomeCommunitySort> get availableCommunitySorts =>
      community.availableSorts;
  List<CommunityRemotePost> get communityPosts => community.posts;
  bool get communityLoading => community.loading;

  /// 게시글 상세에서 삭제하고 돌아왔을 때 홈 목록에서도 지운다.
  void removeCommunityPost(int postId) => community.removePost(postId);

  /// 게시글 상세에서 좋아요·조회수 등이 바뀌고 돌아왔을 때 홈 목록에도 반영한다.
  void applyCommunityPostUpdate(CommunityRemotePost updated) =>
      community.applyPostUpdate(updated);

  // 평점 한줄평 — 로직은 `features/player_rating` 이 갖는다.
  final ReviewSummaryViewModel reviewSummary;

  /// 평점 한줄평. 비어 있으면 평점 섹션 전체를 숨긴다([HomeReviewSection]).
  List<ReviewItem> get reviews => reviewSummary.items;
  bool get reviewsLoading => reviewSummary.loading;

  // ---- 섹션 5: 콘텐츠 (뉴스 / 쇼츠) ----
  // 기본 탭은 뉴스 — 쇼츠는 호불호가 갈리고 뉴스를 보는 사람이 더 많다(spec 결정).
  // 단 뉴스가 없으면(릴리즈 빈 소스 등) 뉴스 탭을 숨기고 쇼츠가 실제 탭이 된다.
  HomeContentTab _contentTab = HomeContentTab.news;

  /// 실제로 보이는 탭 — 고른 탭이 없어졌으면 남은 탭으로 맞춘다.
  HomeContentTab get contentTab => availableContentTabs.contains(_contentTab)
      ? _contentTab
      : availableContentTabs.first;

  /// 보여줄 콘텐츠 탭. 뉴스가 비면 쇼츠만.
  /// 뉴스 첫 응답을 기다리는 동안은 뉴스 탭을 둔다(스켈레톤) — 그래야 비었을 때
  /// 쇼츠로 넘어가는 한 번의 전환만 생긴다.
  List<HomeContentTab> get availableContentTabs =>
      newsVm.articles.isEmpty && !newsVm.loading
      ? const [HomeContentTab.shorts]
      : HomeContentTab.values;

  void setContentTab(HomeContentTab tab) {
    if (tab == contentTab) return;
    if (!availableContentTabs.contains(tab)) return;
    _contentTab = tab;
    _notify();
  }

  // 뉴스 — 로직은 `features/news` 가 갖는다.
  final NewsViewModel newsVm;

  List<NewsArticle> get news => newsVm.articles;
  bool get newsLoading => newsVm.loading;

  /// 홈 쇼츠 카드 수. 이어서 보는 건 전체화면 피드(후속)가 맡는다.
  // 쇼츠 — 로직은 `features/shorts` 가 갖는다. 전체화면 피드와 같은 기능이고
  // 피드가 이 목록을 initialVideos 로 이어받는다.
  late final ShortsSummaryViewModel shorts;

  static const int shortsCardCount = 10;

  HomeShortsFilter get shortsFilter => shorts.filter;
  bool get shortsLoading => shorts.loading;
  void setShortsFilter(HomeShortsFilter filter) => shorts.setFilter(filter);

  /// "내 팀" 필터에 쓸 응원팀이 있는지. 없으면 화면이 설정 안내를 보인다.
  bool get hasPreferredTeam => shorts.hasTeam;

  /// 현재 필터를 적용한 쇼츠 — 순수 최신순(서버 순서) 최대 [shortsCardCount] 개.
  List<HomeShortsVideo> get shortsFiltered => [
    for (final v in shortsVideosFiltered) _toShortsVideo(v),
  ];

  /// [shortsFiltered] 와 같은 순서의 원본 영상 — 전체화면 피드가 이어받는다.
  List<StoryVideo> get shortsVideosFiltered => shorts.videos;

  /// 홈이 마지막으로 받은 쇼츠 목록의 페이지 크기 — 피드가 다음 페이지부터
  /// 같은 크기로 이어 받는다.
  int get shortsFetchSize => shorts.fetchSize;

  /// 응원팀 코드. 없으면 null. 피드가 "내 팀" 필터를 고를 때 쓴다.
  Future<String?> preferredTeamCode() => shorts.teamCode();

  HomeShortsVideo _toShortsVideo(StoryVideo video) {
    return HomeShortsVideo(
      title: video.title,
      teamCode: video.teamCode,
      views: video.viewCount,
      youtubeVideoId: video.youtubeVideoId,
      url: video.videoUrl.isNotEmpty
          ? video.videoUrl
          : video.youtubeVideoId.isNotEmpty
          ? 'https://www.youtube.com/shorts/${video.youtubeVideoId}'
          : '',
      thumbnailUrl: video.thumbnailUrl,
    );
  }

}
