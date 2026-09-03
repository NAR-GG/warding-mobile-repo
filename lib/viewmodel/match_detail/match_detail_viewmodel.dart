import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/game_rating.dart';
import '../../model/match_champion_pick.dart';
import '../../model/match_game.dart';
import '../../model/match_live_event.dart';
import '../../model/schedule_match.dart';
import '../../repository/match/match_detail_repository.dart';
import '../../repository/rating/rating_repository.dart';

/// 경기 상세 화면(챔피언 픽 · 라이브 이벤트 탭) 상태·로직.
///
/// matchId 로 세트(게임) 목록을 받아 현재 세트의 gameId 를 해석하고,
/// 해당 세트의 챔피언 픽·라이브 이벤트를 로드한다. BuildContext 에 의존하지 않는다.
class MatchDetailViewModel extends ChangeNotifier {
  MatchDetailViewModel({
    required this.matchId,
    this.initialMatch,
    int initialTabIndex = 0,
    this.initialSet,
    MatchDetailRepository? repository,
    RatingRepository? ratingRepository,
  }) : _matchInfo = initialMatch,
       _activeTab = initialTabIndex,
       _repository = repository ?? MatchDetailRepository.instance,
       _ratingRepository = ratingRepository ?? RatingRepository.instance;

  final String matchId;

  /// Screen 이 주입한 초기 경기 정보 (경기 목록에서 진입할 때).
  /// 마이구독처럼 matchId 만 가지고 진입하면 null 이므로 _loadGames 에서 별도 로드한다.
  final ScheduleMatch? initialMatch;

  /// 진입 시 선택할 세트 번호. Live Activity '평점 남기기' 처럼 특정 세트를
  /// 지정해 들어올 때 쓴다. null 이면 [_computeInitialSet] 으로 자동 판단한다.
  final int? initialSet;

  ScheduleMatch? _matchInfo;

  /// 스코어 카드에 쓸 경기 정보. null 이면 플레이스홀더 렌더링.
  ScheduleMatch? get matchInfo => _matchInfo;

  final MatchDetailRepository _repository;
  final RatingRepository _ratingRepository;

  /// 세트 목록 (gameOrder 오름차순).
  List<MatchGame> _games = const [];
  List<MatchGame> get games => _games;

  /// 현재 선택된 세트 번호(1부터). 기본 1세트.
  int _currentSet = 1;
  int get currentSet => _currentSet;

  /// 현재 세트의 gameId. 미해석이면 null.
  String? get currentGameId {
    for (final g in _games) {
      if (g.gameOrder == _currentSet) return g.gameId;
    }
    return null;
  }

  /// 현재 선택된 세트의 진행 상태("LIVE"|"ENDED"|"SCHEDULED"). 미해석이면 SCHEDULED.
  String get currentSetStatus {
    for (final g in _games) {
      if (g.gameOrder == _currentSet) return g.status;
    }
    return MatchGameStatus.scheduled;
  }

  /// 현재 선택된 세트가 진행 중인지. 경기 전체가 LIVE여도 종료된 세트를
  /// 보고 있으면 false (예: 1세트 종료 후 2세트 시작 전 1세트 선택).
  bool get isCurrentSetLive => currentSetStatus == MatchGameStatus.live;

  /// 현재 선택된 세트를 이긴 팀의 teamCode. 미해석이거나 진행 전이면 null.
  String? get currentSetWinnerTeamCode {
    for (final g in _games) {
      if (g.gameOrder == _currentSet) return g.winnerTeamCode;
    }
    return null;
  }

  /// 현재 선택된 세트의 다시보기 VOD URL. 없으면 null.
  String? get currentSetVodUrl {
    for (final g in _games) {
      if (g.gameOrder == _currentSet) return g.vodUrl;
    }
    return null;
  }

  // ── 챔피언 픽 ──────────────────────────────
  MatchChampionPick? _championPick;
  MatchChampionPick? get championPick => _championPick;
  bool _loadingChampion = false;
  bool get loadingChampion => _loadingChampion;
  String? _championError;
  String? get championError => _championError;

  // 와드 설치·파괴는 팀 합산 summary 자체엔 없지만(항상 0), 각
  // ChampionPick(선수별)에는 champions API가 직접 내려준다 —
  // ChampionTeam.summaryWithWards 가 5명분을 더해 채운다.
  TeamStatsSummary? get blueTeamSummary =>
      _championPick?.blueTeam.summaryWithWards;
  TeamStatsSummary? get redTeamSummary =>
      _championPick?.redTeam.summaryWithWards;

  // ── 라이브 이벤트 ──────────────────────────
  MatchLiveEvents? _liveEventsData;

  /// 실제 이벤트 목록 + (조건이 맞으면) 맨 앞에 합성한 넥서스 처치 이벤트.
  ///
  /// 리스트는 최신순이라 맨 앞 = 화면에서 가장 위 = 시간상 가장 나중에
  /// 일어난 일이다. 넥서스 처치는 그 세트의 마지막 이벤트이므로 맨 앞에 둔다.
  List<MatchLiveEvent> get liveEvents {
    final base = _liveEventsData?.events ?? const [];
    final nexus = _synthesizedNexusEvent(base);
    if (nexus == null) return base;
    return [nexus, ...base];
  }

  /// 세트가 ENDED 이고 승자가 확정됐고, [_matchInfo] 로 승자의 사이드(Blue/Red)를
  /// 판별할 수 있을 때만 넥서스 이벤트를 만든다. 아래 중 하나라도 아니면 null:
  /// - 세트가 아직 LIVE/SCHEDULED
  /// - 라이브 이벤트 조회 자체가 실패함([_liveEventsData] 가 null) — 이 경우
  ///   합성해 넣으면 [liveEvents] 가 비어있지 않게 되어 화면의 에러 UI가 가려진다.
  /// - winnerTeamCode 가 없거나, [_matchInfo] 의 teamA/teamB 어느 teamCode 와도
  ///   안 맞음 (팀 사이드를 모르면 어느 로고를 써야 할지 알 수 없어 스킵한다).
  MatchLiveEvent? _synthesizedNexusEvent(List<MatchLiveEvent> base) {
    final liveEventsData = _liveEventsData;
    if (liveEventsData == null) return null;
    if (base.any((e) => e.type == LiveEventType.nexus)) return null;
    if (currentSetStatus != MatchGameStatus.ended) return null;
    final winnerCode = currentSetWinnerTeamCode;
    if (winnerCode == null || winnerCode.isEmpty) return null;
    final info = _matchInfo;
    if (info == null) return null;

    final String winnerTeamName;
    if (winnerCode == info.teamA.teamCode) {
      winnerTeamName = info.teamA.teamName;
    } else if (winnerCode == info.teamB.teamCode) {
      winnerTeamName = info.teamB.teamName;
    } else {
      return null;
    }

    // 사이드는 그 세트 API(blueTeamName/redTeamName)로 먼저 판별한다 — 팀
    // 로고도 같은 응답(_liveEventsData)에서 오므로, 이름과 사이드가 항상
    // 같은 출처에서 나와야 진영이 세트마다 바뀌어도(LCK 흔함) 로고가
    // 정확히 맞는다. 그 값이 없을 때만 매치 단위 teamA=Blue/teamB=Red
    // 관례로 폴백한다.
    final String teamSide;
    if (liveEventsData.blueTeamName == winnerTeamName) {
      teamSide = 'Blue';
    } else if (liveEventsData.redTeamName == winnerTeamName) {
      teamSide = 'Red';
    } else if (winnerCode == info.teamA.teamCode) {
      teamSide = 'Blue';
    } else {
      teamSide = 'Red';
    }

    // 실제 마지막(=가장 최근, 리스트 맨 앞) 이벤트 시각을 근사치로 재사용한다.
    // 넥서스 처치의 정확한 게임 내 시각은 현재 API에 없다.
    final latest = base.isNotEmpty ? base.first : null;
    return MatchLiveEvent(
      type: LiveEventType.nexus,
      gameTime: latest?.gameTime ?? '',
      gameTimeSeconds: latest?.gameTimeSeconds ?? 0,
      teamSide: teamSide,
      teamName: winnerTeamName,
    );
  }

  /// 오브젝트 이벤트 출처 팀 로고용 — 응답 최상위의 양 팀 로고 URL.
  String? get blueTeamImageUrl => _liveEventsData?.blueTeamImageUrl;
  String? get redTeamImageUrl => _liveEventsData?.redTeamImageUrl;
  bool _loadingEvents = false;
  bool get loadingEvents => _loadingEvents;
  String? _eventsError;
  String? get eventsError => _eventsError;

  // ── 선수 평점 ──────────────────────────────
  GameRatings? _ratings;
  GameRatings? get ratings => _ratings;
  bool _loadingRatings = false;
  bool get loadingRatings => _loadingRatings;
  String? _ratingsError;
  String? get ratingsError => _ratingsError;

  // ── 탭 지연 로딩 ────────────────────────────
  // 세 탭(챔피언 픽·라이브 이벤트·선수 평점)을 진입 즉시 한꺼번에 로드하면
  // 화면에 보이지도 않는 탭의 요청이 활성 탭 로딩과 대역폭을 다퉈 체감 속도가
  // 떨어진다. 활성 탭 데이터만 즉시 로드하고, 나머지는 실제로 그 탭으로
  // 전환할 때(= [setActiveTab]) 처음 한 번만 로드한다. 세트를 바꾸면
  // [selectSet] 이 요청 여부를 초기화해 다시 전환 시 새 세트로 로드한다.
  int _activeTab;
  int get activeTab => _activeTab;
  bool _championRequested = false;
  bool _eventsRequested = false;
  bool _ratingsRequested = false;

  bool _disposed = false;

  /// 챔피언 픽 탭이 활성 상태이고 세트가 LIVE 인 동안 5초마다
  /// 스코어보드(KDA·CS·골드·아이템·룬)를 다시 받아온다.
  static const _championPollInterval = Duration(seconds: 5);
  Timer? _championPollTimer;

  /// 지금 5초 폴링이 돌고 있는지. 경기 데이터 탭에 "실시간 갱신 중"
  /// 표기를 띄울지 판단하는 데 쓴다.
  bool get isChampionPollingActive => _championPollTimer != null;

  @override
  void dispose() {
    _disposed = true;
    _championPollTimer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// 세트 목록(games) 조회 중 여부.
  /// 이 목록이 오기 전엔 [currentSetStatus] 가 기본값(SCHEDULED)으로 잡혀
  /// 실제로는 이미 시작·종료된 경기인데도 탭들이 잠금 안내를 잠깐 보여줄 수 있다.
  /// 화면은 이 플래그가 true 인 동안 잠금 안내 대신 스켈레톤을 보여줘야 한다.
  bool _loadingGames = false;
  bool get loadingGames => _loadingGames;

  /// 화면 진입 시 호출. 세트 목록 → 현재 세트 데이터 로드.
  ///
  /// 스코어 카드용 경기 정보([matchInfo])는 탭 데이터와 무관하므로 기다리지
  /// 않는다 — 도착하는 대로 [_safeNotify] 로 화면에 반영된다.
  Future<void> load() async {
    // 세트 목록과 경기 정보는 서로를 필요로 하지 않으므로 같이 띄운다.
    // 예전엔 games 를 받아본 뒤에야 '팀 정보가 없네' 하고 match 를 불러
    // 두 번의 왕복이 그대로 더해졌다.
    //
    // 경기 정보를 이미 들고 진입했으면(경기 목록에서 카드 탭) 요청 자체를
    // 띄우지 않는다 — 마이구독·딥링크처럼 matchId 만 있을 때만 필요하다.
    // games 응답 최상위에 팀 정보가 실려 오기도 하는데, 그때는 이 요청 결과를
    // 버린다. 헛요청 한 번이 순차 왕복보다 싸고, 실려 오는지는 미리 알 수 없다.
    final matchInfoDone = _matchInfo == null
        ? _loadMatchInfo()
        : Future<void>.value();

    await _loadGames();
    // 탭 데이터(gameId 필요)는 세트 목록만 있으면 시작할 수 있다.
    await _loadCurrentSet();
    // 화면이 완전히 채워지는 시점을 load() 완료로 삼는다 — 여기까지 오면
    // 대개 이미 끝나 있다.
    await matchInfoDone;
  }

  /// 스코어 카드에 쓸 경기 정보를 따로 받아둔다. 실패해도 화면은 나머지
  /// 데이터로 렌더링되므로 조용히 넘어간다.
  Future<void> _loadMatchInfo() async {
    try {
      final info = await _repository.fetchMatch(matchId);
      // 그 사이 games 응답이 팀 정보를 채웠으면 그쪽을 그대로 둔다.
      if (_matchInfo == null && info != null) {
        _matchInfo = info;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('[MatchDetailVM] load match failed: $e');
    }
  }

  Future<void> _loadGames() async {
    _loadingGames = true;
    _safeNotify();
    try {
      final (games, matchInfoFromGames) = await _repository.fetchGames(matchId);
      _games = games;
      // 진입 시 기본 세트: LIVE → 최신 ENDED → 1세트.
      _currentSet = _computeInitialSet(games);
      // games 응답에 팀 정보가 실려 왔으면 그걸 먼저 쓴다.
      _matchInfo ??= matchInfoFromGames;
    } catch (e) {
      debugPrint('[MatchDetailVM] load games failed: $e');
    }
    _loadingGames = false;
    _safeNotify();
  }

  /// 진입 시 기본 선택 세트를 정한다.
  /// 1) status=="LIVE" 인 세트
  /// 2) 없으면 status=="ENDED" 중 gameOrder 가 가장 큰 세트
  /// 3) 그래도 없으면 1세트(목록이 있으면 첫 세트)
  int _computeInitialSet(List<MatchGame> games) {
    // 딥링크 등으로 세트를 지정해 들어왔으면 그 세트를 우선한다.
    // (목록에 없는 번호면 자동 판단으로 넘어간다.)
    final requested = initialSet;
    if (requested != null &&
        (games.isEmpty || games.any((g) => g.gameOrder == requested))) {
      return requested;
    }
    if (games.isEmpty) return 1;
    for (final g in games) {
      if (g.isLive) return g.gameOrder;
    }
    int? latestEnded;
    for (final g in games) {
      if (g.isEnded && (latestEnded == null || g.gameOrder > latestEnded)) {
        latestEnded = g.gameOrder;
      }
    }
    if (latestEnded != null) return latestEnded;
    return games.first.gameOrder;
  }

  /// 이미 열려 있는 상세에 딥링크(Live Activity·다이나믹 아일랜드·푸시)가
  /// 다시 들어왔을 때 탭·세트를 갈아끼운다. 화면을 새로 만들지 않으므로
  /// 로딩 깜빡임이나 스크롤 위치 손실이 없다.
  ///
  /// [setNumber] 가 아직 없는 세트(로드 전이거나 범위 밖)면 무시하고 탭만 바꾼다.
  void applyDeepLink({required int tabIndex, int? setNumber}) {
    if (setNumber != null &&
        setNumber != _currentSet &&
        _games.any((g) => g.gameOrder == setNumber)) {
      // [selectSet] 은 활성 탭 기준으로 다시 로드하므로 탭을 먼저 바꿔 둔다.
      _activeTab = tabIndex;
      selectSet(setNumber);
    } else {
      setActiveTab(tabIndex);
    }
    _safeNotify();
  }

  /// 세트 변경. 활성 탭의 데이터만 즉시 다시 로드한다(나머지는 지연 로딩 재적용).
  Future<void> selectSet(int setNumber) async {
    if (setNumber == _currentSet) return;
    _stopChampionPolling();
    _currentSet = setNumber;
    // 이전 세트 데이터 비우고 요청 여부도 초기화 — 다른 탭은 다시 전환할 때 로드.
    _championPick = null;
    _liveEventsData = null;
    _ratings = null;
    _championRequested = false;
    _eventsRequested = false;
    _ratingsRequested = false;
    _safeNotify();
    await _loadCurrentSet();
  }

  /// 당겨서 새로고침. 지금 보고 있는 세트·탭을 그대로 두고 데이터만 다시 받는다.
  ///
  /// [load] 를 다시 부르지 않는 이유가 두 가지다.
  /// - [_loadGames] 가 [_computeInitialSet] 으로 세트를 다시 고른다. 3세트를
  ///   보다가 당기면 LIVE 세트로 튕겨 나간다.
  /// - [_loadMatchInfo] 는 `_matchInfo == null` 일 때만 받는다. 진행 중 경기의
  ///   스코어가 바뀌어도 갱신되지 않는다 — 새로고침에서 가장 보고 싶은 값인데도.
  ///
  /// 그래서 여기서는 경기 정보·세트 목록을 강제로 다시 받고, 탭 데이터는
  /// 요청 플래그를 지워 활성 탭만 새로 받는다(나머지 탭은 전환할 때 받는다 —
  /// 지연 로딩 규칙 그대로다).
  Future<void> refresh() async {
    _stopChampionPolling();
    _championPick = null;
    _liveEventsData = null;
    _ratings = null;
    _championRequested = false;
    _eventsRequested = false;
    _ratingsRequested = false;
    _championError = null;
    _safeNotify();

    // 스코어·세트 목록은 서로를 필요로 하지 않으므로 같이 띄운다.
    await Future.wait([_refreshMatchInfo(), _refreshGames()]);
    if (_disposed) return;
    await _loadCurrentSet();
  }

  /// 스코어 카드용 경기 정보를 무조건 다시 받는다([_loadMatchInfo] 는 값이
  /// 없을 때만 받으므로 새로고침에는 쓸 수 없다).
  Future<void> _refreshMatchInfo() async {
    try {
      final info = await _repository.fetchMatch(matchId);
      if (info != null) {
        _matchInfo = info;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('[MatchDetailVM] refresh match failed: $e');
    }
  }

  /// 세트 목록을 다시 받되 **보고 있던 세트는 유지**한다.
  /// 그 세트가 사라졌을 때만(드묾) 기본 선택 규칙으로 되돌린다.
  Future<void> _refreshGames() async {
    _loadingGames = true;
    _safeNotify();
    try {
      final (games, matchInfoFromGames) = await _repository.fetchGames(matchId);
      _games = games;
      if (games.isNotEmpty && !games.any((g) => g.gameOrder == _currentSet)) {
        _currentSet = _computeInitialSet(games);
      }
      // 위 _refreshMatchInfo 가 받아 온 값이 더 정확하므로 덮어쓰지 않는다.
      _matchInfo ??= matchInfoFromGames;
    } catch (e) {
      debugPrint('[MatchDetailVM] refresh games failed: $e');
    }
    _loadingGames = false;
    _safeNotify();
  }

  /// 진입 시(또는 세트 변경 후) 현재 활성 탭의 데이터만 로드한다.
  Future<void> _loadCurrentSet() => _ensureTabLoaded(_activeTab);

  /// 탭 전환. 이미 로드했던 탭이면 재요청하지 않는다.
  void setActiveTab(int index) {
    if (_activeTab == index) return;
    _activeTab = index;
    if (index == 0) {
      _restartChampionPollingIfNeeded();
    } else {
      _stopChampionPolling();
    }
    _ensureTabLoaded(index);
  }

  Future<void> _ensureTabLoaded(int index) {
    switch (index) {
      case 0:
        return ensureChampionPickLoaded();
      case 1:
        return ensureLiveEventsLoaded();
      case 2:
        return ensureRatingsLoaded();
      default:
        return Future.value();
    }
  }

  /// 챔피언 픽 탭 데이터를 아직 요청한 적 없으면 로드한다.
  /// 세트가 SCHEDULED(경기 전)면 화면이 잠금 안내만 보여주므로 요청하지 않는다.
  Future<void> ensureChampionPickLoaded() {
    if (_championRequested || currentSetStatus == MatchGameStatus.scheduled) {
      return Future.value();
    }
    _championRequested = true;
    return _loadChampionPick();
  }

  /// 라이브 이벤트 탭 데이터를 아직 요청한 적 없으면 로드한다.
  /// 세트가 SCHEDULED(경기 전)면 화면이 잠금 안내만 보여주므로 요청하지 않는다.
  Future<void> ensureLiveEventsLoaded() {
    if (_eventsRequested || currentSetStatus == MatchGameStatus.scheduled) {
      return Future.value();
    }
    _eventsRequested = true;
    return _loadLiveEvents();
  }

  /// 선수 평점 탭 데이터를 아직 요청한 적 없으면 로드한다.
  /// 세트가 ENDED(종료)가 아니면 화면이 잠금 안내만 보여주므로 요청하지 않는다.
  Future<void> ensureRatingsLoaded() {
    if (_ratingsRequested || currentSetStatus != MatchGameStatus.ended) {
      return Future.value();
    }
    _ratingsRequested = true;
    return _loadRatings();
  }

  Future<void> _loadChampionPick() async {
    final gameId = currentGameId;
    _loadingChampion = true;
    _championError = null;
    _safeNotify();
    try {
      if (gameId == null || gameId.isEmpty) {
        throw Exception(appStrings?.setInfoNotFound ?? 'Set info not found');
      }
      _championPick = await _repository.fetchChampionPick(gameId);
      _restartChampionPollingIfNeeded();
    } catch (e) {
      debugPrint('[MatchDetailVM] champion pick failed: $e');
      _championError =
          appStrings?.championPickLoadFailed ?? 'Failed to load champion picks';
      _championPick = null;
    } finally {
      _loadingChampion = false;
      _safeNotify();
    }
  }

  /// 챔피언 픽 탭이 활성 상태이고 현재 세트가 LIVE 일 때만 폴링을 (재)시작한다.
  /// 조건을 안 만족하면 기존 타이머를 정리하고 끝낸다. [isChampionPollingActive]
  /// 가 바뀔 수 있어(예: 탭 전환) UI 가 "실시간 갱신 중" 표기를 즉시
  /// 반영하도록 알린다.
  void _restartChampionPollingIfNeeded() {
    final wasActive = isChampionPollingActive;
    _stopChampionPolling(notify: false);
    if (_activeTab == 0 && isCurrentSetLive) {
      _championPollTimer = Timer.periodic(_championPollInterval, (_) {
        _pollChampionPick();
      });
    }
    if (wasActive != isChampionPollingActive) _safeNotify();
  }

  void _stopChampionPolling({bool notify = true}) {
    final wasActive = isChampionPollingActive;
    _championPollTimer?.cancel();
    _championPollTimer = null;
    if (notify && wasActive) _safeNotify();
  }

  /// 폴링 틱에서 호출 — 로딩 인디케이터를 켜지 않고 조용히 갱신한다.
  /// 세트가 더 이상 LIVE 가 아니게 되면(경기 종료) 스스로 폴링을 멈춘다.
  Future<void> _pollChampionPick() async {
    if (_disposed || _activeTab != 0 || !isCurrentSetLive) {
      _stopChampionPolling();
      return;
    }
    final gameId = currentGameId;
    if (gameId == null || gameId.isEmpty) return;
    try {
      final updated = await _repository.fetchChampionPick(gameId);
      if (_disposed) return;
      _championPick = updated;
      _safeNotify();
    } catch (e) {
      debugPrint('[MatchDetailVM] champion pick poll failed: $e');
    }
  }

  Future<void> _loadLiveEvents() async {
    final gameId = currentGameId;
    _loadingEvents = true;
    _eventsError = null;
    _safeNotify();
    try {
      if (gameId == null || gameId.isEmpty) {
        throw Exception(appStrings?.setInfoNotFound ?? 'Set info not found');
      }
      _liveEventsData = await _repository.fetchLiveEvents(gameId);
    } catch (e) {
      debugPrint('[MatchDetailVM] live events failed: $e');
      _eventsError =
          appStrings?.liveEventLoadFailed ?? 'Failed to load live events';
      _liveEventsData = null;
    } finally {
      _loadingEvents = false;
      _safeNotify();
    }
  }

  Future<void> _loadRatings() async {
    final gameId = currentGameId;
    _loadingRatings = true;
    _ratingsError = null;
    _safeNotify();
    try {
      if (gameId == null || gameId.isEmpty) {
        _ratings = null;
      } else {
        _ratings = await _ratingRepository.fetchGameRatings(gameId);
      }
    } catch (e) {
      debugPrint('[MatchDetailVM] load ratings failed: $e');
      _ratingsError =
          appStrings?.playerRatingLoadFailed2 ??
          'Failed to load player ratings';
      _ratings = null;
    } finally {
      _loadingRatings = false;
      _safeNotify();
    }
  }

  /// 라이브 이벤트 리로드 버튼용. 현재 세트의 이벤트만 다시 가져온다.
  Future<void> reloadLiveEvents() {
    _eventsRequested = true;
    return _loadLiveEvents();
  }

  /// 선수 평점 상세에서 평가 작성/수정/삭제 후 돌아왔을 때 현재 세트의
  /// 평점(평균·내 평점)을 다시 가져온다.
  Future<void> reloadRatings() {
    _ratingsRequested = true;
    return _loadRatings();
  }
}
