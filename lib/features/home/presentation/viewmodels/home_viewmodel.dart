import 'package:warding/core/config/home_mocks.dart';
import 'package:warding/features/solo_rank/data/solo_rank_sources.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_models.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/core/error/failure_exception.dart';
import 'package:warding/features/community/domain/community_remote_post.dart';
import 'package:warding/features/home/domain/home_models.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/domain/player_subscription.dart';
import 'package:warding/domain/schedule_match.dart';
import 'package:warding/features/home/domain/standing.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';
import 'package:warding/features/home/domain/worlds_standings.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/features/community/data/community_repository.dart';
import 'package:warding/features/community/presentation/viewmodels/community_summary_viewmodel.dart';
import 'package:warding/features/home/data/home_sources.dart';
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
import 'package:warding/core/di_container.dart';
import 'package:warding/features/shorts/domain/repositories/shorts_repository.dart';
import 'package:warding/features/shorts/presentation/viewmodels/shorts_summary_viewmodel.dart';
import 'package:warding/features/home/domain/repositories/standings_repository.dart';
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

/// 월즈 순위표 카드가 보여주는 뷰. 하단 버튼으로 전환한다.
enum WorldsStandingsView { swiss, knockout }

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
  }) : _schedule = schedule ?? di<ScheduleRepository>(),
       _standingsRepo = standings ?? di<StandingsRepository>(),
       // 솔랭·뉴스는 실제 API, 평점은 빈 소스. 목업은 HOME_MOCKS=true 일 때만.
       _reviewSource = reviews ?? defaultReviewSource(),
       _newsSource = news ?? defaultNewsSource(),
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
           SubscribedPlayersViewModel(repository: subscriptions, auth: auth) {
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

  final ScheduleRepository _schedule;
  final StandingsRepository _standingsRepo;

  final ReviewSource _reviewSource;
  final NewsSource _newsSource;
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
      _loadLeagueChips(),
      _loadStandings(),
      _loadReviews(),
      _loadNews(),
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

  List<HomeLiveSoloPlayer> get soloLive => solo.live;
  List<HomeFinishedSoloPlayer> get soloFinished => solo.finished;
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
  List<HomeLiveSoloPlayer> get worldsLiveAll => solo.worldsLiveAll;
  List<HomeLiveSoloPlayer> get worldsLive => solo.worldsLive;
  HomeFinishedSoloPlayer? get worldsLastFinished => solo.worldsLastFinished;

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
  // 표인지 대진인지는 **응답이 정한다** — `/api/standings` 의
  // `reason: "BRACKET_ONLY"` 면 대진 카드([WorldsStandings] — 스위스 전적
  // 버킷 + 토너먼트), 아니면 리그 테이블이다. 예전엔 `selectedLeague ==
  // 'WORLDS'` 하드코딩이라 월즈 말고는 어느 리그도 대진을 못 그렸다.
  //
  // 아래 폴백의 월즈 `live: false` 는 출시 보류 결정(사용자 요청)이라 그대로
  // 둔다 — 포맷 분기와는 별개다. 코드값은 [ApiConfig]의 리그 코드 체계와
  // 맞춰 'WORLDS'를 쓰고 라벨만 한글.
  //
  // 칩 목록은 서버(`/mobile/schedules/filters` 의 `standings`)가 정한다 —
  // null=칩 없음 / false=점선 / true=선택 가능([_loadLeagueChips]). 앱에 박아
  // 두면 백엔드가 순위표를 연 리그가 앱 배포 전엔 안 보인다. 서버가 메타를 안
  // 주거나 못 받으면 [_fallbackLeagueChips] 로 폴백한다.
  static const List<HomeLeagueChip> _fallbackLeagueChips = [
    HomeLeagueChip(code: 'LCK', label: 'LCK', live: true),
    HomeLeagueChip(code: 'LPL', label: 'LPL', live: false),
    HomeLeagueChip(code: 'LEC', label: 'LEC', live: false),
    HomeLeagueChip(code: 'LCS', label: 'LCS', live: false),
    HomeLeagueChip(code: 'WORLDS', label: '월즈', live: false),
  ];

  /// 서버 응답을 받기 전에는 기본 리그 칩 하나만 둔다 — 폴백 5개를 먼저 그렸다가
  /// 서버가 지운 칩이 사라지는 깜빡임을 피한다.
  List<HomeLeagueChip> _leagueChips = const [
    HomeLeagueChip(code: 'LCK', label: 'LCK', live: true),
  ];

  List<HomeLeagueChip> get leagueChips => _leagueChips;

  /// 칩 라벨 **폴백** — 서버 `name` 이 비었을 때만 쓴다. 월즈만 한글,
  /// 나머지는 리그 코드 그대로. 서버가 표시명을 주면 그쪽이 이긴다.
  static String _chipLabel(String code) => code == 'WORLDS' ? '월즈' : code;

  /// 서버가 `standings: true` 를 준 리그가 실제로 순위표를 주는지(`supported`)
  /// 확인한 결과와 시각. 등록만 되고 데이터가 없는 리그(예: DEMACIA_CUP
  /// `UNAVAILABLE`)는 칩을 켜 줘도 표가 비어, 점선으로 처리한다.
  final Map<String, (DateTime, bool)> _standingsSupport = {};
  static const Duration _standingsSupportTtl = Duration(minutes: 10);

  Future<bool> _isStandingsSupported(String code) async {
    final cached = _standingsSupport[code];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _standingsSupportTtl) {
      return cached.$2;
    }
    final outcome = await _standingsRepo.fetchStandings(code);
    return outcome.match(
      (failure) {
        // 확인 실패로 칩을 숨기지 않는다 — 서버 값을 믿는다.
        debugPrint('[Home] 순위표 지원 확인 실패($code): $failure');
        return true;
      },
      (result) {
        // `supported: false` 여도 대진이 실려 왔으면 그릴 게 있다 — 리그
        // 테이블이 없다는 뜻이지 보여줄 게 없다는 뜻이 아니다. 예전엔 월즈를
        // 코드로 예외 처리했는데, 이제 응답으로 판단한다.
        final usable = result.supported || result.hasBracket;
        _standingsSupport[code] = (DateTime.now(), usable);
        return usable;
      },
    );
  }

  Future<void> _loadLeagueChips() async {
    List<HomeLeagueChip> chips;
    // 서버가 준 기본 리그. 메타를 못 받으면 비어 있고, 그때는 기존 기본값을
    // 그대로 둔다.
    String serverDefault = '';
    try {
      final options = (await _schedule.fetchFilterOptions())
          .getOrElse((f) => throw FailureException(f));
      serverDefault = options.defaultLeague;
      if (!options.hasLeagueMeta) {
        chips = _fallbackLeagueChips;
      } else {
        // 순서는 서버가 준 그대로다 — 앱에서 다시 정렬하지 않는다. 예전엔
        // LCK·LPL·LEC·LCS·월즈를 앞으로 당기는 고정 순서를 뒀는데, 그러면
        // 백엔드가 순서를 바꿔도 앱 배포 전엔 반영되지 않는다.
        final served = [
          for (final l in options.leagues)
            if (l.code != 'ALL' && l.standings != null) l,
        ];
        chips = await Future.wait([
          for (final l in served)
            () async {
              final live =
                  l.standings == true && await _isStandingsSupported(l.code);
              return HomeLeagueChip(
                code: l.code,
                // 서버가 준 표시명을 쓴다. 비어 있을 때만 앱 라벨로 폴백 —
                // 예전엔 서버 `name` 을 버리고 코드로만 라벨을 만들어서,
                // 백엔드가 표시명을 바꿔도 앱 배포 전엔 반영되지 않았다.
                label: l.name.isNotEmpty ? l.name : _chipLabel(l.code),
                live: live,
              );
            }(),
        ]);
      }
    } catch (e) {
      debugPrint('[Home] 리그 칩 조회 실패(하드코딩 폴백): $e');
      chips = _fallbackLeagueChips;
    }
    if (_disposed) return;
    _leagueChips = chips;

    // 기본 선택도 서버가 정한다(`defaultLeague`). 앱은 'LCK' 를 박아 뒀는데,
    // 서버가 그 리그를 안 주거나(칩 없음) 데이터가 없으면(점선) **선택된 칩이
    // 목록에 없는 상태**가 된다 — 순위표 자리가 빈 채로 열린다.
    //
    // 지켜야 할 불변식: **선택된 리그는 항상 고를 수 있는 칩이어야 한다.**
    // 그래서 사용자가 고른 리그라도(_leagueTouched) 그게 더 이상 live 가
    // 아니면 그대로 둘 수 없다 — 그 경우에도 떨어뜨린다. 반대로 사용자가 고른
    // 리그가 아직 live 면 서버 기본값으로 되돌리지 않는다.
    final livable = chips.where((c) => c.live).map((c) => c.code).toList();
    final keepsCurrent = livable.contains(_selectedLeague);
    final String next;
    if (_leagueTouched && keepsCurrent) {
      next = _selectedLeague; // 사용자 선택이 아직 유효하다
    } else if (livable.contains(serverDefault)) {
      next = serverDefault;
    } else if (keepsCurrent) {
      next = _selectedLeague;
    } else if (livable.isNotEmpty) {
      next = livable.first;
    } else {
      next = _selectedLeague; // 고를 수 있는 칩이 하나도 없다 — 그대로 둔다
    }
    if (next != _selectedLeague) {
      _selectedLeague = next;
      _clearStandings();
      unawaited(_loadStandings());
    }
    _notify();
  }

  /// 사용자가 칩을 직접 골랐는지. 칩 목록이 늦게 도착해도 그 선택을 덮지
  /// 않으려고 둔다(홈 진입 직후 칩을 누르면 두 흐름이 겹친다).
  bool _leagueTouched = false;

  String _selectedLeague = 'LCK';
  String get selectedLeague => _selectedLeague;

  void selectLeague(String code) {
    final selectable = _leagueChips.any((c) => c.code == code && c.live);
    if (!selectable || code == _selectedLeague) return;
    _selectedLeague = code;
    _leagueTouched = true;
    _clearStandings();
    _notify();
    // 리그 코드로 분기하지 않는다. 표인지 대진인지는 `/api/standings` 응답
    // (`reason: BRACKET_ONLY` · `bracket`)이 정한다.
    unawaited(_loadStandings());
  }

  /// 리그가 바뀔 때 이전 리그의 순위표·대진을 즉시 버리고 스켈레톤으로
  /// 되돌린다. 안 비우면 새 응답이 오기 전까지 **새 칩 아래 옛 리그의 표가**
  /// 그대로 남고, 새 조회가 실패하면 계속 남는다. 대진만 비우고 표는 안
  /// 비우던 비대칭을 없앤다.
  void _clearStandings() {
    _standings = null;
    _worldsStandings = null;
    _standingsFirstLoadPending = true;
  }

  StandingsResult? _standings;

  /// 선택한 리그(LCK 등 리그 테이블 형식)의 순위표. 아직 못 받았으면 null.
  StandingsResult? get standings => _standings;

  /// 첫 순위표 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다.
  bool _standingsFirstLoadPending = true;
  bool get standingsLoading => _standingsFirstLoadPending;

  Future<void> _loadStandings() async {
    final league = _selectedLeague;
    final outcome = await _standingsRepo.fetchStandings(league);
    // 그 사이 리그를 바꿨으면 옛 응답은 버린다.
    if (_disposed || league != _selectedLeague) return;

    outcome.match(
      (failure) => debugPrint('[Home] 순위표 조회 실패($league): $failure'),
      (result) {
        _standings = result;
        // 대진은 응답에 실려 왔을 때만 그린다. 안 실려 오면 리그 테이블이다.
        _worldsStandings = result.hasBracket
            ? result.bracket!.toWorldsStandings()
            : null;
        // 백엔드에 아직 대진 API 가 없어, 목업 빌드에서만 대진 UI 를 미리 본다
        // (`--dart-define=HOME_MOCKS=true`). 릴리즈에는 영향이 없다.
        if (_worldsStandings == null && kHomeMocks && !result.supported) {
          unawaited(_loadBracketMock(league));
        }
      },
    );
    // 성공·실패 모두 첫 로드는 끝난 것으로 본다(스켈레톤을 치운다).
    _standingsFirstLoadPending = false;
    _notify();
  }

  WorldsStandings? _worldsStandings;

  /// 대진 데이터(스위스 전적 + 토너먼트). 리그 테이블 형식이면 null.
  ///
  /// 이름이 `worlds` 인 건 월즈용으로 먼저 만들었기 때문이고, 지금은 응답이
  /// `bracket` 을 주는 어느 리그든 여기에 담긴다.
  WorldsStandings? get worldsStandings => _worldsStandings;

  /// 대진 UI 미리보기용 목업. `HOME_MOCKS=true` 빌드에서만 값이 온다.
  Future<void> _loadBracketMock(String league) async {
    try {
      final result = await _standingsRepo.fetchWorldsStandings();
      if (_disposed || league != _selectedLeague) return;
      _worldsStandings = result;
      _notify();
    } catch (e) {
      debugPrint('[Home] 대진 목업 조회 실패($league): $e');
    }
  }

  /// 리그 테이블 대신 대진 카드를 그려야 하는지 — **대진 데이터가 실제로
  /// 있을 때만** true 다. 리그 코드도, `reason` 도 보지 않는다.
  bool get standingsIsBracket => _worldsStandings != null;

  WorldsStandingsView _worldsView = WorldsStandingsView.swiss;
  WorldsStandingsView get worldsView => _worldsView;

  /// 대진 카드 하단 버튼으로 스위스 전적 ↔ 토너먼트 대진을 전환한다.
  void toggleWorldsView() {
    _worldsView = _worldsView == WorldsStandingsView.swiss
        ? WorldsStandingsView.knockout
        : WorldsStandingsView.swiss;
    _notify();
  }

  /// 지금 리그에 스위스·녹아웃이 **둘 다** 있는지. 한쪽만 있으면 전환 버튼을
  /// 숨기고 있는 쪽을 그린다 — 그룹 스테이지 없이 녹아웃만 하는 대회
  /// (ASIAN_GAMES 등)에서 빈 화면으로 전환되는 걸 막는다.
  bool get worldsHasBothViews {
    final d = _worldsStandings;
    return d != null && d.bracket.isNotEmpty && d.knockout.isNotEmpty;
  }

  /// 데이터가 있는 쪽을 고른 실제 표시 뷰.
  WorldsStandingsView get effectiveWorldsView {
    final d = _worldsStandings;
    if (d == null) return _worldsView;
    if (d.bracket.isEmpty) return WorldsStandingsView.knockout;
    if (d.knockout.isEmpty) return WorldsStandingsView.swiss;
    return _worldsView;
  }

  bool _standingsExpanded = false;
  bool get standingsExpanded => _standingsExpanded;

  void toggleStandingsExpanded() {
    _standingsExpanded = !_standingsExpanded;
    _notify();
  }

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

  static const int _reviewCount = 4;

  List<HomeReviewItem> _reviews = const [];

  /// 평점 한줄평(한줄평이 달린 것만 — [ReviewSource] 계약) 최대
  /// [_reviewCount]건. 비어 있으면 평점 섹션 전체를 숨긴다([HomeReviewSection]).
  List<HomeReviewItem> get reviews => _reviews.take(_reviewCount).toList();

  int _reviewsGen = 0;

  /// 첫 한줄평 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다. 끝난 뒤
  /// 비어 있으면 섹션 전체를 숨긴다.
  bool _reviewsFirstLoadPending = true;
  bool get reviewsLoading => _reviewsFirstLoadPending;

  Future<void> _loadReviews() async {
    final gen = ++_reviewsGen;
    try {
      final reviews = await _reviewSource.fetchRecent();
      if (_disposed || gen != _reviewsGen) return;
      _reviews = reviews;
      _reviewsFirstLoadPending = false;
      _notify();
    } catch (e) {
      debugPrint('[Home] 평점 한줄평 조회 실패: $e');
      if (_disposed || gen != _reviewsGen) return;
      _reviewsFirstLoadPending = false;
      _notify();
    }
  }

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
      _news.isEmpty && !_newsFirstLoadPending
      ? const [HomeContentTab.shorts]
      : HomeContentTab.values;

  void setContentTab(HomeContentTab tab) {
    if (tab == contentTab) return;
    if (!availableContentTabs.contains(tab)) return;
    _contentTab = tab;
    _notify();
  }

  List<HomeNewsArticle> _news = const [];
  List<HomeNewsArticle> get news => _news;

  int _newsGen = 0;

  /// 첫 뉴스 응답(성공·실패 모두)이 오기 전 true — 뉴스 탭 자리에 스켈레톤을
  /// 그린다. 끝난 뒤 비어 있으면 뉴스 탭을 숨기고 쇼츠가 실제 탭이 된다.
  bool _newsFirstLoadPending = true;
  bool get newsLoading => _newsFirstLoadPending;

  Future<void> _loadNews() async {
    final gen = ++_newsGen;
    try {
      final articles = await _newsSource.fetchTop();
      if (_disposed || gen != _newsGen) return;
      _news = articles;
      _newsFirstLoadPending = false;
      _notify();
    } catch (e) {
      debugPrint('[Home] 뉴스 조회 실패: $e');
      if (_disposed || gen != _newsGen) return;
      _newsFirstLoadPending = false;
      _notify();
    }
  }

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
