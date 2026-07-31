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
    MatchDetailRepository? repository,
    RatingRepository? ratingRepository,
  })  : _matchInfo = initialMatch,
        _activeTab = initialTabIndex,
        _repository = repository ?? MatchDetailRepository.instance,
        _ratingRepository = ratingRepository ?? RatingRepository.instance;

  final String matchId;

  /// Screen 이 주입한 초기 경기 정보 (경기 목록에서 진입할 때).
  /// 마이구독처럼 matchId 만 가지고 진입하면 null 이므로 _loadGames 에서 별도 로드한다.
  final ScheduleMatch? initialMatch;

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

  // ── 라이브 이벤트 ──────────────────────────
  MatchLiveEvents? _liveEventsData;
  List<MatchLiveEvent> get liveEvents => _liveEventsData?.events ?? const [];

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

  @override
  void dispose() {
    _disposed = true;
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
  Future<void> load() async {
    await _loadGames();
    await _loadCurrentSet();
  }

  Future<void> _loadGames() async {
    _loadingGames = true;
    _safeNotify();
    // games 로드와 matchInfo 로드를 분리해 fetchGames 실패 시에도 matchInfo 로드를 시도한다.
    try {
      final (games, matchInfoFromGames) = await _repository.fetchGames(matchId);
      _games = games;
      // 진입 시 기본 세트: LIVE → 최신 ENDED → 1세트.
      _currentSet = _computeInitialSet(games);

      // games 응답에 팀 정보가 없고 initialMatch도 없으면 별도 API 시도.
      if (_matchInfo == null) {
        _matchInfo = matchInfoFromGames;
        if (_matchInfo == null) {
          final info = await _repository.fetchMatch(matchId);
          if (info != null) _matchInfo = info;
        }
      }
    } catch (e) {
      debugPrint('[MatchDetailVM] load games failed: $e');
      // fetchGames 실패 시에도 matchInfo 로드는 이어서 시도한다.
      if (_matchInfo == null) {
        try {
          final info = await _repository.fetchMatch(matchId);
          if (info != null) _matchInfo = info;
        } catch (_) {}
      }
    }
    _loadingGames = false;
    _safeNotify();
  }

  /// 진입 시 기본 선택 세트를 정한다.
  /// 1) status=="LIVE" 인 세트
  /// 2) 없으면 status=="ENDED" 중 gameOrder 가 가장 큰 세트
  /// 3) 그래도 없으면 1세트(목록이 있으면 첫 세트)
  int _computeInitialSet(List<MatchGame> games) {
    if (games.isEmpty) return 1;
    for (final g in games) {
      if (g.isLive) return g.gameOrder;
    }
    int? latestEnded;
    for (final g in games) {
      if (g.isEnded &&
          (latestEnded == null || g.gameOrder > latestEnded)) {
        latestEnded = g.gameOrder;
      }
    }
    if (latestEnded != null) return latestEnded;
    return games.first.gameOrder;
  }

  /// 세트 변경. 활성 탭의 데이터만 즉시 다시 로드한다(나머지는 지연 로딩 재적용).
  Future<void> selectSet(int setNumber) async {
    if (setNumber == _currentSet) return;
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

  /// 진입 시(또는 세트 변경 후) 현재 활성 탭의 데이터만 로드한다.
  Future<void> _loadCurrentSet() => _ensureTabLoaded(_activeTab);

  /// 탭 전환. 이미 로드했던 탭이면 재요청하지 않는다.
  void setActiveTab(int index) {
    if (_activeTab == index) return;
    _activeTab = index;
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
    } catch (e) {
      debugPrint('[MatchDetailVM] champion pick failed: $e');
      _championError = appStrings?.championPickLoadFailed ?? 'Failed to load champion picks';
      _championPick = null;
    } finally {
      _loadingChampion = false;
      _safeNotify();
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
      _eventsError = appStrings?.liveEventLoadFailed ?? 'Failed to load live events';
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
      _ratingsError = appStrings?.playerRatingLoadFailed2 ?? 'Failed to load player ratings';
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
