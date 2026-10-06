import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/community_remote_post.dart';
import '../../model/home_models.dart';
import '../../model/notice.dart';
import '../../model/player_subscription.dart';
import '../../model/schedule_match.dart';
import '../../model/team.dart';
import '../../model/standing.dart';
import '../../model/story_video.dart';
import '../../model/worlds_standings.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/community/community_repository.dart';
import '../../repository/home/home_sources.dart';
import '../../repository/notice/notice_repository.dart';
import '../../repository/notification/member_notification_repository.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/preference/notice_preference_repository.dart';
import '../../repository/preference/team_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';
import '../../repository/shorts/shorts_repository.dart';
import '../../repository/standings/standings_repository.dart';
import '../../repository/subscription/subscription_repository.dart';
import '../../repository/team/team_logo_directory.dart';
import '../../util/match_status.dart';
import 'solo_rank_rules.dart';

/// 커뮤니티 섹션 정렬 기준. [hot] 은 칩에서 뺀 상태다([HomeViewModel.availableCommunitySorts]).
enum HomeCommunitySort { latest, hot }

/// 콘텐츠 섹션 탭.
enum HomeContentTab { news, shorts }

/// 쇼츠 탭 필터.
enum HomeShortsFilter { all, team }

/// 월즈 순위표 카드가 보여주는 뷰. 하단 버튼으로 전환한다.
enum WorldsStandingsView { swiss, knockout }

/// 솔랭 카드 상태 (spec "상태" 표).
///
/// - [loading]: 첫 구독 조회가 아직 안 끝났다 — 스켈레톤. 구독 0명과 겉보기가
///   같아(둘 다 아직 화면에 확정된 카드가 없음) 구분하지 않으면 응답이
///   오는 순간 빈 카드 → 실제 카드로 레이아웃이 튄다(CLS).
/// - [noSubscription]: 구독 0명 — 점선 빈 카드.
/// - [noneActive]: 구독은 있는데 진행 중인 선수가 0명 — 한 줄짜리 조용한 상태.
/// - [active]: 진행 중인 선수가 있다 — 큰 카드 스와이프.
enum SoloCardState { loading, noSubscription, noneActive, active }

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
    CommunityRepository? community,
    ShortsRepository? shorts,
    SubscriptionRepository? subscriptions,
    MemberNotificationRepository? memberNotifications,
    SoloRankSource? soloRank,
    ReviewSource? reviews,
    NewsSource? news,
    AuthService? auth,
    OnboardingRepository? onboarding,
    TeamPreferenceRepository? teamPreferences,
  }) : _notices = notices ?? NoticeRepository.instance,
       _noticePreferences =
           noticePreferences ?? NoticePreferenceRepository.instance,
       _schedule = schedule ?? ScheduleRepository.instance,
       _standingsRepo = standings ?? StandingsRepository.instance,
       _community = community ?? CommunityRepository.instance,
       _shortsRepo = shorts ?? ShortsRepository.instance,
       _subscriptions = subscriptions ?? SubscriptionRepository.instance,
       _memberNotifications =
           memberNotifications ?? MemberNotificationRepository.instance,
       // 솔랭·뉴스는 실제 API, 평점은 빈 소스. 목업은 HOME_MOCKS=true 일 때만.
       _soloRank = soloRank ?? defaultSoloRankSource(),
       _reviewSource = reviews ?? defaultReviewSource(),
       _newsSource = news ?? defaultNewsSource(),
       _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance,
       _teamPreferences = teamPreferences ?? TeamPreferenceRepository.instance {
    // 스플래시가 미리 받아 둔 공지가 있으면 첫 프레임부터 그 상태로 그린다
    // ([ScheduleViewModel] 과 같은 이유 — 뒤늦게 끼어들면 아래 섹션을 민다).
    _promotedNotices = _notices.cachedPromoted ?? const [];
    _dismissedNoticeIds = _noticePreferences.cachedValue ?? const {};
    unawaited(refreshAll());
    // 순위표·솔랭·커뮤니티 섹션이 모두 이 싱글톤 캐시로 팀 로고를 그린다.
    // 홈 진입 시점에 한 번 당겨두면 나중에 빌드되는 위젯(라이즈 그룹 등)도
    // 빈 배지로 시작하지 않는다.
    TeamLogoDirectory.instance.ensureLoaded();
    // 솔랭 카드는 진행 중인 게임의 실시간성이 중요한 유일한 섹션이라
    // 5초 폴링을 건다(2026-09-29 결정). 나머지 섹션은 앱 복귀(30초 간격)만
    // 으로 충분하다 — 경기 일정·순위표·커뮤니티 글은 그 정도로 자주 안 바뀐다.
    _startSoloPolling();
  }

  Timer? _soloPollTimer;

  // 솔랭 조회가 5초(폴링 간격)보다 오래 걸리면 다음 틱이 _soloGen 을 먼저
  // 올려 버려, 느린 응답이 돌아와도 gen 불일치로 버려지고 카드가 멈춰
  // 보인다(그 사이 요청만 계속 쌓인다). 이전 조회가 끝나기 전엔 새 틱을
  // 건너뛰어 막는다.
  bool _soloPollInFlight = false;

  void _startSoloPolling() {
    _soloPollTimer?.cancel();
    _soloPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_soloPollInFlight) return;
      _soloPollInFlight = true;
      unawaited(_loadSolo().whenComplete(() => _soloPollInFlight = false));
    });
  }

  /// 앱이 백그라운드로 가면 부른다 — 화면이 안 보이는 동안 5초마다 네트워크를
  /// 쓰지 않게 폴링을 멈춘다. [resumeSoloPolling] 과 짝이다.
  void pauseSoloPolling() => _soloPollTimer?.cancel();

  /// 앱이 다시 포그라운드로 오면 부른다. 폴링을 재개하고, 그 사이 놓친 변화를
  /// 바로 반영하도록 즉시 한 번 조회한다.
  void resumeSoloPolling() {
    _startSoloPolling();
    unawaited(_loadSolo());
  }

  final NoticeRepository _notices;
  final NoticePreferenceRepository _noticePreferences;
  final ScheduleRepository _schedule;
  final StandingsRepository _standingsRepo;
  final CommunityRepository _community;
  final ShortsRepository _shortsRepo;
  final SubscriptionRepository _subscriptions;
  final MemberNotificationRepository _memberNotifications;
  final SoloRankSource _soloRank;
  final ReviewSource _reviewSource;
  final NewsSource _newsSource;
  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final TeamPreferenceRepository _teamPreferences;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _soloPollTimer?.cancel();
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
      _loadPromotedNotice(),
      refreshUnreadNotifications(),
      _loadSubscriptions(),
      _loadSolo(),
      loadTodayMatches(),
      _loadLeagueChips(),
      _loadStandings(),
      _loadCommunityPosts(),
      _loadReviews(),
      _loadNews(),
      _loadShorts(),
    ]);
  }

  // ---- 공지 배너 ----
  List<Notice> _promotedNotices = const [];
  Set<int> _dismissedNoticeIds = const {};

  /// 배너에 노출할 공지 — 닫지 않은 것 중 최신 발행. null 이면 배너 미표시.
  Notice? get promotedNotice {
    for (final notice in _promotedNotices) {
      if (!_dismissedNoticeIds.contains(notice.id)) return notice;
    }
    return null;
  }

  bool get bannerVisible => promotedNotice != null;

  /// 배너 ✕ — 닫은 공지는 일정 화면 배너와 같은 저장소에 기록한다.
  void dismissBanner() {
    final notice = promotedNotice;
    if (notice == null) return;
    _dismissedNoticeIds = {..._dismissedNoticeIds, notice.id};
    _notify();
    unawaited(_noticePreferences.addDismissedId(notice.id));
  }

  Future<void> _loadPromotedNotice() async {
    try {
      final notices = await _notices.fetchPromoted();
      final dismissed = await _noticePreferences.loadDismissedIds();
      if (_disposed) return;
      final before = promotedNotice;
      _promotedNotices = notices;
      // 조회하는 사이 ✕ 로 닫은 id 가 저장값 응답에 아직 없을 수 있다 —
      // 덮어쓰면 닫은 배너가 다시 뜨므로 합친다.
      _dismissedNoticeIds = {...dismissed, ..._dismissedNoticeIds};
      if (promotedNotice?.id != before?.id) _notify();
    } catch (e) {
      debugPrint('[Home] 배너 공지 조회 실패: $e');
    }
  }

  // ---- 상단 알림 배지 ----
  int _unreadNotificationCount = 0;

  /// 헤더 벨 배지용 미읽음 수. 0 이면 배지를 숨긴다.
  ///
  /// 벨이 여는 화면(마이구독)의 피드와 **같은 범위**로 세야 한다 — 거기서
  /// 다 읽었는데 배지가 남으면 유저는 지울 방법이 없다. 그 피드는
  /// `SubscriptionFeedViewModel` 을 group 없이(=전체) 쓰므로 여기도 전체다.
  /// 벨 목적지를 바꾸면 이 범위도 함께 맞춘다.
  int get unreadNotificationCount => _unreadNotificationCount;

  /// 미읽음 수를 다시 센다. 알림 화면에서 돌아올 때도 부른다.
  /// 비회원(JWT 없음)·실패는 0(배지 숨김)으로 조용히 넘어간다.
  Future<void> refreshUnreadNotifications() async {
    var count = 0;
    try {
      final page = await _memberNotifications.fetchNotifications(
        page: 0,
        size: 1,
      );
      count = page.unreadCount;
    } catch (e) {
      debugPrint('[Home] 알림 미읽음 수 조회 실패(비회원 포함): $e');
    }
    if (_disposed || count == _unreadNotificationCount) return;
    _unreadNotificationCount = count;
    _notify();
  }

  // ---- 구독 선수 (솔랭 구독 수·쇼츠 매칭에 함께 쓴다) ----

  /// 실제 구독 선수 목록. null 이면 아직 못 받았거나 비회원·실패 —
  /// 이때 구독 수는 0명으로 본다.
  List<PlayerSubscription>? _subscribedPlayers;

  /// 첫 구독 조회가 아직 끝나지 않았는지. 성공·실패·비회원 어느 쪽으로든
  /// 한 번 끝나면 계속 false다(이후 새로고침은 이 값에 영향 없음) — 앱 복귀
  /// 새로고침마다 스켈레톤이 다시 뜨는 걸 막는다.
  bool _subscriptionsFirstLoadPending = true;

  int _subscriptionsGen = 0;

  Future<void> _loadSubscriptions() async {
    final gen = ++_subscriptionsGen;
    try {
      // 비회원(JWT 없음)이면 authorizedRequest 가 던진다 → 아래 catch.
      final players = await _subscriptions.fetchSubscribedPlayers();
      // 그 사이 더 새 요청이 떴으면 옛 응답은 버린다(아래 로더들도 같다).
      if (_disposed || gen != _subscriptionsGen) return;
      _subscribedPlayers = players;
      _subscriptionsFirstLoadPending = false;
      _recomputeSolo();
      _notify();
    } catch (e) {
      debugPrint('[Home] 구독 선수 조회 실패(비회원 포함): $e');
      if (_disposed || gen != _subscriptionsGen) return;
      _subscriptionsFirstLoadPending = false;
      _notify();
    }
  }

  // ---- 섹션 1: 구독 선수 솔랭 상태 ----
  SoloRankSnapshot? _soloSnapshot;

  List<HomeLiveSoloPlayer> _soloLive = const [];
  List<HomeFinishedSoloPlayer> _soloFinished = const [];

  /// 위쪽 큰 카드 — 지금 진행 중인 선수만. 핀 고정 선수가 먼저, 그 안팎에서는
  /// 가장 최근에 시작한(경과 시간이 짧은) 선수가 먼저.
  List<HomeLiveSoloPlayer> get soloLive => _soloLive;

  /// 아래 줄 — 오늘 끝난 경기. 선수당 최신 1건, 최대 [_maxFinished]명.
  List<HomeFinishedSoloPlayer> get soloFinished => _soloFinished;

  static const int _maxFinished = 8;

  /// 구독 수 — 실제 구독 목록 길이만 센다. 비회원(JWT 없음)이나 조회 실패는
  /// 0명이다(구독 0명이면 점선 빈 카드).
  int get subscribedTotal => _subscribedPlayers?.length ?? 0;

  /// 솔랭 중인 선수가 없을 때 조용한 행에 겹쳐 보여줄 구독 선수 얼굴(최대 4명).
  List<PlayerSubscription> get subscribedFaces =>
      (_subscribedPlayers ?? const <PlayerSubscription>[])
          .take(quietFaceCount)
          .toList();

  static const int quietFaceCount = 4;

  /// "+N명" — 위·아래 어디에도 안 나온 구독 선수 수.
  int get soloHiddenCount {
    final hidden = subscribedTotal - _soloLive.length - _soloFinished.length;
    return hidden < 0 ? 0 : hidden;
  }

  /// 진행 중 0명이어도 오늘 끝난 경기가 있으면 [SoloCardState.active] 다 —
  /// 큰 카드(스와이프)는 [soloLive] 가 비어 있으면 그리지 않고, 끝난 경기
  /// 줄은 그대로 보여준다(2026-09-29 결정, spec.md "상태" 표).
  SoloCardState get soloState {
    if (_subscriptionsFirstLoadPending) return SoloCardState.loading;
    if (subscribedTotal == 0) return SoloCardState.noSubscription;
    if (_soloLive.isEmpty && _soloFinished.isEmpty) {
      return SoloCardState.noneActive;
    }
    return SoloCardState.active;
  }

  /// 핀 고정한 선수 이름. 기기 로컬(메모리)만 — 저장·서버 동기화 없음.
  /// 몇 명까지 허용할지는 spec 미결이라 상한을 두지 않는다.
  Set<String> _pinnedPlayerNames = const {};
  Set<String> get pinnedPlayerNames => _pinnedPlayerNames;

  void togglePin(String name) {
    _pinnedPlayerNames = _pinnedPlayerNames.contains(name)
        ? ({..._pinnedPlayerNames}..remove(name))
        : {..._pinnedPlayerNames, name};
    _recomputeSolo();
    _notify();
  }

  int _soloSwipeIndex = 0;
  int get soloSwipeIndex => _soloSwipeIndex;

  void setSoloSwipeIndex(int index) {
    if (index == _soloSwipeIndex) return;
    _soloSwipeIndex = index;
    _notify();
  }

  int _soloGen = 0;

  /// 내 선수 화면(보기 전용)에서 돌아왔을 때 솔랭 상태를 다시 불러온다.
  /// 홈은 화면 전환(push/pop)으로는 새로고침되지 않고 앱 복귀(30초 간격)
  /// 때만 갱신되므로, 그 사이 선수가 솔랭을 시작·종료해도 내 선수 화면과
  /// 어긋난 채로 남는다 — 벨 알림함(_openNotifications)과 같은 방식으로
  /// 이 화면만 돌아올 때 콕 집어 새로고침한다.
  Future<void> refreshSoloOnReturn() => _loadSolo();

  /// 구독 설정 화면(선수 구독하기)에서 돌아왔을 때 구독 목록과 솔랭 상태를
  /// 함께 다시 불러온다. 구독 수([subscribedTotal])가 바뀌면 솔랭 카드
  /// 상태(빈 카드 ↔ 조용한 행 ↔ 진행 중 카드, [soloState])도 같이 바뀌어야
  /// 하므로 [refreshSoloOnReturn]만으로는 부족하다.
  Future<void> refreshSubscriptionsOnReturn() =>
      Future.wait([_loadSubscriptions(), _loadSolo()]);

  Future<void> _loadSolo() async {
    final gen = ++_soloGen;
    try {
      final snap = await _soloRank.fetch();
      if (_disposed || gen != _soloGen) return;
      _soloSnapshot = snap;
      _recomputeSolo();
      _notify();
    } catch (e) {
      // spec 미결: 폴링 실패 시 마지막 값을 유지할지 — 잠정으로 유지한다.
      debugPrint('[Home] 솔랭 상태 조회 실패: $e');
    }
  }

  void _recomputeSolo() {
    final snap = _soloSnapshot;
    if (snap == null) return;

    // 구독 목록을 받았으면 구독한 선수만 남긴다 — 그래야 숨김 수(구독 수 −
    // 보이는 선수 수)가 맞고 내 선수 화면과 같은 선수를 보여준다. 비회원·실패는
    // 구독 0명이라 어차피 빈 카드다.
    final subscribed = _subscribedPlayers == null
        ? null
        : {
            for (final p in _subscribedPlayers!)
              SoloRankClassification.soloKey(p.playerName),
          };
    final solo = SoloRankClassification.of(snap, subscribed: subscribed);

    // 핀 고정 선수가 먼저, 그 안에서는 공용 규칙(최근 시작 먼저).
    final live = solo.liveByName.values.toList()
      ..sort((a, b) {
        final aPinned = _pinnedPlayerNames.contains(a.name) ? 0 : 1;
        final bPinned = _pinnedPlayerNames.contains(b.name) ? 0 : 1;
        if (aPinned != bPinned) return aPinned - bPinned;
        return SoloRankClassification.compareLive(a, b);
      });
    _soloLive = live;

    // 최대 [_maxFinished]명은 홈 카드만의 표시 상한이다.
    final finished = solo.finishedByName.values.toList()
      ..sort(SoloRankClassification.compareFinished);
    _soloFinished = finished.take(_maxFinished).toList();

    // 진행 중 선수가 줄어 스와이프 위치가 범위를 벗어나면 처음으로 돌린다.
    if (_soloSwipeIndex >= _soloLive.length) _soloSwipeIndex = 0;
  }

  // ---- 섹션 2: 오늘 경기 ----
  List<ScheduleMatch> _todayMatches = const [];

  /// 오늘 경기 — 진행 중인 경기를 앞으로, 그 밖에는 서버 순서 그대로.
  List<ScheduleMatch> get todayMatchesSorted => [
    ..._todayMatches.where((m) => isLiveMatchStatus(m.matchStatus)),
    ..._todayMatches.where((m) => !isLiveMatchStatus(m.matchStatus)),
  ];

  /// 오늘 모든 리그의 경기를 불러온다. 실패하면 마지막 값을 유지한다.
  int _todayGen = 0;

  /// 첫 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다. 이후 새로고침은
  /// 마지막 값을 유지하고 스켈레톤을 다시 띄우지 않는다.
  bool _todayFirstLoadPending = true;
  bool get todayMatchesLoading => _todayFirstLoadPending;

  Future<void> loadTodayMatches() async {
    final gen = ++_todayGen;
    try {
      final matches = await _schedule.fetchMatchesByDate(
        DateTime.now(),
        leagues: const ['ALL'],
      );
      if (_disposed || gen != _todayGen) return;
      _todayMatches = matches;
      _todayFirstLoadPending = false;
      _notify();
    } catch (e) {
      debugPrint('[Home] 오늘 경기 조회 실패: $e');
      if (_disposed || gen != _todayGen) return;
      _todayFirstLoadPending = false;
      _notify();
    }
  }

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
    try {
      final result = await _standingsRepo.fetchStandings(code);
      // `supported: false` 여도 대진이 실려 왔으면 그릴 게 있다 — 리그
      // 테이블이 없다는 뜻이지 보여줄 게 없다는 뜻이 아니다. 예전엔 월즈를
      // 코드로 예외 처리했는데, 이제 응답으로 판단한다.
      final usable = result.supported || result.hasBracket;
      _standingsSupport[code] = (DateTime.now(), usable);
      return usable;
    } catch (e) {
      // 확인 실패로 칩을 숨기지 않는다 — 서버 값을 믿는다.
      debugPrint('[Home] 순위표 지원 확인 실패($code): $e');
      return true;
    }
  }

  Future<void> _loadLeagueChips() async {
    List<HomeLeagueChip> chips;
    // 서버가 준 기본 리그. 메타를 못 받으면 비어 있고, 그때는 기존 기본값을
    // 그대로 둔다.
    String serverDefault = '';
    try {
      final options = await _schedule.fetchFilterOptions();
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
    // 서버 기본값이 고를 수 있는 칩이 아니면 첫 번째 live 칩으로 떨어뜨린다.
    // 사용자가 이미 다른 리그를 골랐으면(_leagueTouched) 건드리지 않는다.
    if (!_leagueTouched) {
      final livable = chips.where((c) => c.live).map((c) => c.code).toList();
      final next = livable.contains(serverDefault)
          ? serverDefault
          : (livable.contains(_selectedLeague)
                ? _selectedLeague
                : (livable.isEmpty ? _selectedLeague : livable.first));
      if (next != _selectedLeague) {
        _selectedLeague = next;
        _worldsStandings = null;
        unawaited(_loadStandings());
      }
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
    // 리그가 바뀌면 이전 리그의 대진은 즉시 버린다 — 새 응답이 오기 전까지
    // 옛 대진이 남아 보이면 안 된다.
    _worldsStandings = null;
    _notify();
    // 리그 코드로 분기하지 않는다. 표인지 대진인지는 `/api/standings` 응답
    // (`reason: BRACKET_ONLY` · `bracket`)이 정한다.
    unawaited(_loadStandings());
  }

  StandingsResult? _standings;

  /// 선택한 리그(LCK 등 리그 테이블 형식)의 순위표. 아직 못 받았으면 null.
  StandingsResult? get standings => _standings;

  /// 첫 순위표 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다.
  bool _standingsFirstLoadPending = true;
  bool get standingsLoading => _standingsFirstLoadPending;

  Future<void> _loadStandings() async {
    final league = _selectedLeague;
    try {
      final result = await _standingsRepo.fetchStandings(league);
      // 그 사이 리그를 바꿨으면 옛 응답은 버린다.
      if (_disposed || league != _selectedLeague) return;
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
      _standingsFirstLoadPending = false;
      _notify();
    } catch (e) {
      debugPrint('[Home] 순위표 조회 실패($league): $e');
      if (_disposed || league != _selectedLeague) return;
      _standingsFirstLoadPending = false;
      _notify();
    }
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
  static const int _communityPostCount = 4;

  // 인기순은 글이 적을 때 늘 같은 글이 보여 칩에서 뺐다(spec 결정) —
  // 지금은 latest 하나뿐이라 토글은 없지만 hot 로직은 남겨 둔다.
  HomeCommunitySort _communitySort = HomeCommunitySort.latest;
  HomeCommunitySort get communitySort => _communitySort;

  /// 정렬을 바꾼다(latest/hot). 그 기준으로 글을 다시 조회한다.
  void setCommunitySort(HomeCommunitySort sort) {
    if (sort == _communitySort) return;
    if (!availableCommunitySorts.contains(sort)) return;
    _communitySort = sort;
    _notify();
    unawaited(_loadCommunityPosts());
  }

  /// 보여줄 정렬 탭. 인기순은 커뮤니티가 활성화될 때까지 뺀다(글이 적어 의미가
  /// 없다).
  List<HomeCommunitySort> get availableCommunitySorts => const [
    HomeCommunitySort.latest,
  ];

  List<CommunityRemotePost> _communityPosts = const [];

  /// 현재 정렬 기준의 커뮤니티 글(최대 4건). 조회 실패 시 마지막 목록 유지.
  List<CommunityRemotePost> get communityPosts => _communityPosts;

  /// 첫 커뮤니티 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다.
  bool _communityFirstLoadPending = true;
  bool get communityLoading => _communityFirstLoadPending;

  Future<void> _loadCommunityPosts() async {
    final sort = _communitySort;
    try {
      final page = await _community.fetchPosts(
        size: _communityPostCount,
        sort: sort.name,
      );
      // 응답이 오는 사이 정렬을 바꿨으면 버린다 — 바뀐 정렬이 다시 조회한다.
      if (_disposed || sort != _communitySort) return;
      _communityPosts = page.posts;
      _communityFirstLoadPending = false;
      _notify();
    } catch (e) {
      debugPrint('[Home] 커뮤니티 글 조회 실패(${sort.name}): $e');
      if (_disposed || sort != _communitySort) return;
      _communityFirstLoadPending = false;
      _notify();
    }
  }

  /// 게시글 상세에서 삭제하고 돌아왔을 때 홈 목록에서도 지운다.
  void removeCommunityPost(int postId) {
    if (!_communityPosts.any((p) => p.id == postId)) return;
    _communityPosts = [
      for (final p in _communityPosts)
        if (p.id != postId) p,
    ];
    _notify();
  }

  /// 게시글 상세에서 좋아요·조회수 등이 바뀌고 돌아왔을 때 홈 목록에도 반영한다.
  void applyCommunityPostUpdate(CommunityRemotePost updated) {
    final index = _communityPosts.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    _communityPosts = [..._communityPosts];
    _communityPosts[index] = updated;
    _notify();
  }

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
  static const int shortsCardCount = 10;

  /// 응원팀 필터는 서버가 아직 팀을 안 거르는 동안에도 카드 10개가 남도록
  /// 넉넉히 받아 클라이언트에서 거른다.
  static const int _shortsTeamFetchSize = 30;

  HomeShortsFilter _shortsFilter = HomeShortsFilter.all;
  HomeShortsFilter get shortsFilter => _shortsFilter;

  /// "내 팀" 필터로 바꾼 직후 응원팀·영상 목록을 다시 받는 동안 true.
  /// 이 플래그가 없으면 필터를 바꾼 첫 프레임에 이전(전체) 목록을 새
  /// 필터로 걸러 빈 리스트가 되고, 아직 응원팀 조회 전이라 "응원팀 미설정"
  /// 안내가 한 프레임 잘못 떴다가 실제 결과로 바뀌는 깜빡임이 있었다.
  bool _shortsLoading = false;
  bool get shortsLoading => _shortsLoading;

  void setShortsFilter(HomeShortsFilter filter) {
    if (filter == _shortsFilter) return;
    _shortsFilter = filter;
    _shortsLoading = true;
    _notify();
    unawaited(_loadShorts());
  }

  /// "내 팀" 기준인 마이페이지 응원팀. 없거나 아직 모르면 null.
  Team? _preferredTeam;
  bool _preferredTeamLoaded = false;

  /// "내 팀" 필터에 쓸 응원팀이 있는지. 없으면 화면이 설정 안내를 보인다.
  bool get hasPreferredTeam => _preferredTeam != null;

  Future<void> _loadPreferredTeam() async {
    if (_preferredTeamLoaded) return;
    try {
      // teamId 를 알기 전에도 팀 목록은 미리 받아둔다 — fetchMe 와 겹쳐서
      // 왕복 한 번을 아낀다.
      final teamsFuture = _onboarding.fetchTeams();
      final me = await _auth.fetchMe();
      final teamId = me.favoriteTeamId;
      final teams = await teamsFuture;
      Team? team;
      if (teamId != null) {
        for (final t in teams) {
          if (t.id == teamId) {
            team = t;
            break;
          }
        }
      }
      _preferredTeam = team;
    } catch (e) {
      // 비로그인 등은 로컬 캐시로 폴백.
      debugPrint('[Home] 응원팀 서버 조회 실패, 로컬 폴백: $e');
      _preferredTeam = await _teamPreferences.loadPreferredTeam();
    }
    _preferredTeamLoaded = true;
  }

  List<StoryVideo> _shorts = const [];

  int _shortsGen = 0;

  Future<void> _loadShorts() async {
    final gen = ++_shortsGen;
    try {
      final onlyTeam = _shortsFilter == HomeShortsFilter.team;
      String? teamCode;
      if (onlyTeam) {
        await _loadPreferredTeam();
        if (_disposed || gen != _shortsGen) return;
        teamCode = _preferredTeam?.code;
        if (teamCode == null) {
          _shorts = const [];
          _shortsLoading = false;
          _notify();
          return;
        }
      }
      final videos = await _shortsRepo.fetchShorts(
        sort: 'latest',
        size: onlyTeam ? _shortsTeamFetchSize : shortsCardCount,
        teamCode: teamCode,
      );
      if (_disposed || gen != _shortsGen) return;
      _shorts = videos;
      _shortsLoading = false;
      _notify();
    } catch (e) {
      debugPrint('[Home] 쇼츠 조회 실패: $e');
      _shortsLoading = false;
      _notify();
    }
  }

  /// 현재 필터를 적용한 쇼츠 — 순수 최신순(서버 순서) 최대 [shortsCardCount] 개.
  ///
  /// "내 팀"은 응원팀 채널의 쇼츠만이다. 응답의 `teamCode` 로 한 번 더 거르니
  /// LCK 공식 채널(팀 코드 없음)은 "전체"에만 나온다.
  List<HomeShortsVideo> get shortsFiltered => [
    for (final v in shortsVideosFiltered) _toShortsVideo(v),
  ];

  /// [shortsFiltered] 와 같은 순서의 원본 영상 — 전체화면 피드가 이어받는다.
  List<StoryVideo> get shortsVideosFiltered {
    final team = _preferredTeam?.code;
    final source = _shortsFilter == HomeShortsFilter.team
        ? _shorts.where((v) => team != null && v.teamCode == team)
        : _shorts;
    return source.take(shortsCardCount).toList();
  }

  /// 홈이 마지막으로 받은 쇼츠 목록의 페이지 크기 — 피드가 다음 페이지부터
  /// 같은 크기로 이어 받는다.
  int get shortsFetchSize => _shortsFilter == HomeShortsFilter.team
      ? _shortsTeamFetchSize
      : shortsCardCount;

  /// 응원팀 코드. 없으면 null. 피드가 "내 팀" 필터를 고를 때 쓴다.
  Future<String?> preferredTeamCode() async {
    await _loadPreferredTeam();
    return _preferredTeam?.code;
  }

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
