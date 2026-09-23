import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/community_remote_post.dart';
import '../../model/home_models.dart';
import '../../model/notice.dart';
import '../../model/player_subscription.dart';
import '../../model/schedule_match.dart';
import '../../model/standing.dart';
import '../../model/story_video.dart';
import '../../repository/community/community_repository.dart';
import '../../repository/home/home_sources.dart';
import '../../repository/notice/notice_repository.dart';
import '../../repository/preference/notice_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';
import '../../repository/shorts/shorts_repository.dart';
import '../../repository/standings/standings_repository.dart';
import '../../repository/subscription/subscription_repository.dart';
import '../../util/match_status.dart';

/// 커뮤니티 섹션 정렬 기준.
enum HomeCommunitySort { latest, hot, review }

/// 콘텐츠 섹션 탭.
enum HomeContentTab { news, shorts }

/// 쇼츠 탭 필터.
enum HomeShortsFilter { all, player, team }

/// 솔랭 카드 상태 (spec "상태" 표).
///
/// - [noSubscription]: 구독 0명 — 점선 빈 카드.
/// - [noneActive]: 구독은 있는데 진행 중인 선수가 0명 — 한 줄짜리 조용한 상태.
/// - [active]: 진행 중인 선수가 있다 — 큰 카드 스와이프.
enum SoloCardState { noSubscription, noneActive, active }

/// 홈 화면 상태.
///
/// 섹션마다 따로 불러온다(`/api/mobile/home` 한 번에 받기는 spec 미결).
/// 실데이터가 있는 섹션(공지·오늘 경기·순위·커뮤니티 글·쇼츠·구독 수)은
/// repository 로, 백엔드에 아직 없는 섹션(솔랭 상태·평점 한줄평·뉴스)은
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
    SoloRankSource? soloRank,
    ReviewSource? reviews,
    NewsSource? news,
  }) : _notices = notices ?? NoticeRepository.instance,
       _noticePreferences =
           noticePreferences ?? NoticePreferenceRepository.instance,
       _schedule = schedule ?? ScheduleRepository.instance,
       _standingsRepo = standings ?? StandingsRepository.instance,
       _community = community ?? CommunityRepository.instance,
       _shortsRepo = shorts ?? ShortsRepository.instance,
       _subscriptions = subscriptions ?? SubscriptionRepository.instance,
       _soloRank = soloRank ?? const MockSoloRankSource(),
       _reviewSource = reviews ?? const MockReviewSource(),
       _newsSource = news ?? const MockNewsSource() {
    // 스플래시가 미리 받아 둔 공지가 있으면 첫 프레임부터 그 상태로 그린다
    // ([ScheduleViewModel] 과 같은 이유 — 뒤늦게 끼어들면 아래 섹션을 민다).
    _promotedNotices = _notices.cachedPromoted ?? const [];
    _dismissedNoticeIds = _noticePreferences.cachedValue ?? const {};
    unawaited(refreshAll());
  }

  final NoticeRepository _notices;
  final NoticePreferenceRepository _noticePreferences;
  final ScheduleRepository _schedule;
  final StandingsRepository _standingsRepo;
  final CommunityRepository _community;
  final ShortsRepository _shortsRepo;
  final SubscriptionRepository _subscriptions;
  final SoloRankSource _soloRank;
  final ReviewSource _reviewSource;
  final NewsSource _newsSource;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 모든 섹션을 다시 불러온다. 섹션끼리는 서로 기다리지 않는다 — 한 섹션이
  /// 실패해도 나머지는 그대로 채워진다.
  Future<void> refreshAll() async {
    await Future.wait([
      _loadPromotedNotice(),
      _loadSubscriptions(),
      _loadSolo(),
      loadTodayMatches(),
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
      _dismissedNoticeIds = dismissed;
      if (promotedNotice?.id != before?.id) _notify();
    } catch (e) {
      debugPrint('[Home] 배너 공지 조회 실패: $e');
    }
  }

  // ---- 구독 선수 (솔랭 구독 수·쇼츠 매칭에 함께 쓴다) ----

  /// 실제 구독 선수 목록. null 이면 아직 못 받았거나 비회원·실패 —
  /// 이때 구독 수는 솔랭 소스 값으로 대신한다.
  List<PlayerSubscription>? _subscribedPlayers;

  Future<void> _loadSubscriptions() async {
    try {
      // 비회원(JWT 없음)이면 authorizedRequest 가 던진다 → 아래 catch.
      final players = await _subscriptions.fetchSubscribedPlayers();
      if (_disposed) return;
      _subscribedPlayers = players;
      _recomputeSolo();
      _notify();
    } catch (e) {
      debugPrint('[Home] 구독 선수 조회 실패(비회원 포함): $e');
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

  /// 구독 수. 실제 구독 목록을 우선 쓰고, 못 받았으면 솔랭 소스 값을 쓴다.
  int get subscribedTotal =>
      _subscribedPlayers?.length ?? _soloSnapshot?.subscribedTotal ?? 0;

  /// "+N명" — 위·아래 어디에도 안 나온 구독 선수 수.
  int get soloHiddenCount {
    final hidden = subscribedTotal - _soloLive.length - _soloFinished.length;
    return hidden < 0 ? 0 : hidden;
  }

  SoloCardState get soloState {
    if (subscribedTotal == 0) return SoloCardState.noSubscription;
    if (_soloLive.isEmpty) return SoloCardState.noneActive;
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

  Future<void> _loadSolo() async {
    try {
      final snap = await _soloRank.fetch();
      if (_disposed) return;
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

    final live = [...snap.live];
    live.sort((a, b) {
      final aPinned = _pinnedPlayerNames.contains(a.name) ? 0 : 1;
      final bPinned = _pinnedPlayerNames.contains(b.name) ? 0 : 1;
      if (aPinned != bPinned) return aPinned - bPinned;
      return a.elapsedSeconds.compareTo(b.elapsedSeconds);
    });
    _soloLive = live;

    // 지금 진행 중인 선수는 아래 줄에서 뺀다 — 위 큰 카드에 이미 있어서, 남기면
    // 같은 선수가 두 번 나오고 숨김 수도 두 번 빠진다(spec 결정).
    // 그다음 선수당 가장 최근(minutesAgo 최소) 1건만 남긴다.
    final liveNames = {for (final p in snap.live) p.name};
    final latest = <String, HomeFinishedSoloPlayer>{};
    for (final p in snap.finished) {
      if (liveNames.contains(p.name)) continue;
      final prev = latest[p.name];
      if (prev == null || p.minutesAgo < prev.minutesAgo) latest[p.name] = p;
    }
    final finished = latest.values.toList()
      ..sort((a, b) => a.minutesAgo.compareTo(b.minutesAgo));
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
  Future<void> loadTodayMatches() async {
    try {
      final matches = await _schedule.fetchMatchesByDate(
        DateTime.now(),
        leagues: const ['ALL'],
      );
      if (_disposed) return;
      _todayMatches = matches;
      _notify();
    } catch (e) {
      debugPrint('[Home] 오늘 경기 조회 실패: $e');
    }
  }

  // ---- 섹션 3: 순위표 ----
  // 월즈는 리그 테이블과 다른 화면(스위스 전적·토너먼트 대진)이 필요해 이번
  // 스코프에서는 제외한다 — 칩만 노출하고 LPL/LEC/LCS 처럼 탭 비활성 상태로 둔다.
  static const List<HomeLeagueChip> _leagueChips = [
    HomeLeagueChip(code: 'LCK', label: 'LCK', live: true),
    HomeLeagueChip(code: 'LPL', label: 'LPL', live: false),
    HomeLeagueChip(code: 'LEC', label: 'LEC', live: false),
    HomeLeagueChip(code: 'LCS', label: 'LCS', live: false),
    HomeLeagueChip(code: '월즈', label: '월즈', live: false),
  ];

  List<HomeLeagueChip> get leagueChips => _leagueChips;

  String _selectedLeague = 'LCK';
  String get selectedLeague => _selectedLeague;

  void selectLeague(String code) {
    final selectable = _leagueChips.any((c) => c.code == code && c.live);
    if (!selectable || code == _selectedLeague) return;
    _selectedLeague = code;
    _notify();
    unawaited(_loadStandings());
  }

  StandingsResult? _standings;

  /// 선택한 리그의 순위표. 아직 못 받았으면 null.
  StandingsResult? get standings => _standings;

  Future<void> _loadStandings() async {
    final league = _selectedLeague;
    try {
      final result = await _standingsRepo.fetchStandings(league);
      // 그 사이 리그를 바꿨으면 옛 응답은 버린다.
      if (_disposed || league != _selectedLeague) return;
      _standings = result;
      _notify();
    } catch (e) {
      debugPrint('[Home] 순위표 조회 실패($league): $e');
    }
  }

  bool _standingsExpanded = false;
  bool get standingsExpanded => _standingsExpanded;

  void toggleStandingsExpanded() {
    _standingsExpanded = !_standingsExpanded;
    _notify();
  }

  // ---- 섹션 4: 커뮤니티 ----
  static const int _communityPostCount = 4;

  // 기본은 최신순 — 글이 적을 때 인기순이면 늘 같은 글이 보인다(spec 결정).
  HomeCommunitySort _communitySort = HomeCommunitySort.latest;
  HomeCommunitySort get communitySort => _communitySort;

  /// 정렬을 바꾼다. 글 정렬(latest/hot)이면 그 기준으로 다시 조회하고,
  /// 평점 탭([HomeCommunitySort.review])은 [reviews] 를 보여줄 뿐 조회하지 않는다.
  void setCommunitySort(HomeCommunitySort sort) {
    if (sort == _communitySort) return;
    _communitySort = sort;
    _notify();
    if (sort != HomeCommunitySort.review) unawaited(_loadCommunityPosts());
  }

  List<CommunityRemotePost> _communityPosts = const [];

  /// 현재 정렬 기준의 커뮤니티 글(최대 4건). 조회 실패 시 마지막 목록 유지.
  List<CommunityRemotePost> get communityPosts => _communityPosts;

  Future<void> _loadCommunityPosts() async {
    final sort = _communitySort;
    if (sort == HomeCommunitySort.review) return;
    try {
      final page = await _community.fetchPosts(
        size: _communityPostCount,
        sort: sort.name,
      );
      // 응답이 오는 사이 정렬을 바꿨으면 버린다 — 바뀐 정렬이 다시 조회한다.
      if (_disposed || sort != _communitySort) return;
      _communityPosts = page.posts;
      _notify();
    } catch (e) {
      debugPrint('[Home] 커뮤니티 글 조회 실패(${sort.name}): $e');
    }
  }

  List<HomeReviewItem> _reviews = const [];

  /// 평점 한줄평(한줄평이 달린 것만 — [ReviewSource] 계약).
  List<HomeReviewItem> get reviews => _reviews;

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewSource.fetchRecent();
      if (_disposed) return;
      _reviews = reviews;
      _notify();
    } catch (e) {
      debugPrint('[Home] 평점 한줄평 조회 실패: $e');
    }
  }

  // ---- 섹션 5: 콘텐츠 (뉴스 / 쇼츠) ----
  // 기본 탭은 뉴스 — 쇼츠는 호불호가 갈리고 뉴스를 보는 사람이 더 많다(spec 결정).
  HomeContentTab _contentTab = HomeContentTab.news;
  HomeContentTab get contentTab => _contentTab;

  void setContentTab(HomeContentTab tab) {
    if (tab == _contentTab) return;
    _contentTab = tab;
    _notify();
  }

  List<HomeNewsArticle> _news = const [];
  List<HomeNewsArticle> get news => _news;

  Future<void> _loadNews() async {
    try {
      final articles = await _newsSource.fetchTop();
      if (_disposed) return;
      _news = articles;
      _notify();
    } catch (e) {
      debugPrint('[Home] 뉴스 조회 실패: $e');
    }
  }

  HomeShortsFilter _shortsFilter = HomeShortsFilter.all;
  HomeShortsFilter get shortsFilter => _shortsFilter;

  void setShortsFilter(HomeShortsFilter filter) {
    if (filter == _shortsFilter) return;
    _shortsFilter = filter;
    _notify();
  }

  List<StoryVideo> _shorts = const [];

  Future<void> _loadShorts() async {
    try {
      final videos = await _shortsRepo.fetchShorts(sort: 'latest');
      if (_disposed) return;
      _shorts = videos;
      _notify();
    } catch (e) {
      debugPrint('[Home] 쇼츠 조회 실패: $e');
    }
  }

  /// 현재 필터를 적용한 쇼츠.
  ///
  /// 쇼츠 응답에는 팀·선수 필드가 없고 `channelName`·`title` 만 있어서,
  /// 구독 선수 이름과 소속팀 코드·이름을 문자열로 찾아 매칭한다.
  /// 선수 한글 활동명("페이커")은 아직 서버에 없어(spec) 영문 이름만 찾는다.
  ///
  /// "내 팀"은 구독 선수들의 소속팀 합집합으로 본다 — 따로 고른 응원팀으로 볼지는
  /// spec 미결이라 잠정안이다.
  ///
  /// 전체 필터는 내 선수 → 내 팀 → 나머지 순이다(같은 등급 안에서는 서버 순서).
  List<HomeShortsVideo> get shortsFiltered {
    final players = _subscribedPlayers ?? const <PlayerSubscription>[];
    final myTeams = <String, String>{
      for (final p in players)
        if (p.teamCode.isNotEmpty) p.teamCode: p.teamName,
    };

    final videos = [
      for (final v in _shorts) _toShortsVideo(v, players, myTeams),
    ];
    bool isMyTeam(HomeShortsVideo v) => myTeams.containsKey(v.teamCode);

    switch (_shortsFilter) {
      case HomeShortsFilter.player:
        return videos.where((v) => v.matchedPlayer != null).toList();
      case HomeShortsFilter.team:
        return videos.where(isMyTeam).toList();
      case HomeShortsFilter.all:
        return [
          ...videos.where((v) => v.matchedPlayer != null),
          ...videos.where((v) => v.matchedPlayer == null && isMyTeam(v)),
          ...videos.where((v) => v.matchedPlayer == null && !isMyTeam(v)),
        ];
    }
  }

  HomeShortsVideo _toShortsVideo(
    StoryVideo video,
    List<PlayerSubscription> players,
    Map<String, String> myTeams,
  ) {
    final haystack = '${video.title} ${video.channelName}';

    PlayerSubscription? player;
    for (final p in players) {
      if (_containsWord(haystack, p.playerName)) {
        player = p;
        break;
      }
    }

    var teamCode = player?.teamCode ?? '';
    if (player == null) {
      for (final entry in myTeams.entries) {
        if (_containsWord(haystack, entry.key) ||
            _containsText(haystack, entry.value)) {
          teamCode = entry.key;
          break;
        }
      }
    }

    return HomeShortsVideo(
      title: video.title,
      teamCode: teamCode,
      views: video.viewCount,
      matchedPlayer: player?.playerName,
    );
  }

  /// [word] 가 영문·숫자 경계로 떨어진 낱말로 들어 있는지(대소문자 무시).
  /// "T1"·"KT" 같은 짧은 코드가 다른 영단어 안에 섞여 잘못 잡히지 않게 한다.
  /// 한글과 붙어 있는 건("T1전") 경계로 본다.
  static bool _containsWord(String text, String word) {
    if (word.trim().isEmpty) return false;
    return RegExp(
      '(^|[^A-Za-z0-9])${RegExp.escape(word)}(\$|[^A-Za-z0-9])',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _containsText(String text, String part) =>
      part.trim().isNotEmpty && text.toLowerCase().contains(part.toLowerCase());
}
