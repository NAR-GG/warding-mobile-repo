import 'package:flutter/foundation.dart';

import '../../model/game_rating.dart';
import '../../model/match_champion_pick.dart';
import '../../model/match_game.dart';
import '../../model/match_live_event.dart';
import '../../repository/match/match_detail_repository.dart';
import '../../repository/rating/rating_repository.dart';

/// 경기 상세 화면(챔피언 픽 · 라이브 이벤트 탭) 상태·로직.
///
/// matchId 로 세트(게임) 목록을 받아 현재 세트의 gameId 를 해석하고,
/// 해당 세트의 챔피언 픽·라이브 이벤트를 로드한다. BuildContext 에 의존하지 않는다.
class MatchDetailViewModel extends ChangeNotifier {
  MatchDetailViewModel({
    required this.matchId,
    MatchDetailRepository? repository,
    RatingRepository? ratingRepository,
  })  : _repository = repository ?? MatchDetailRepository.instance,
        _ratingRepository = ratingRepository ?? RatingRepository.instance;

  final String matchId;
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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// 화면 진입 시 호출. 세트 목록 → 현재 세트 데이터 로드.
  Future<void> load() async {
    await _loadGames();
    await _loadCurrentSet();
  }

  Future<void> _loadGames() async {
    try {
      final games = await _repository.fetchGames(matchId);
      _games = games;
      // 진입 시 기본 세트: LIVE → 최신 ENDED → 1세트.
      _currentSet = _computeInitialSet(games);
      _safeNotify();
    } catch (e) {
      debugPrint('[MatchDetailVM] load games failed: $e');
      // 세트 목록 실패 시에도 세트별 로드에서 개별 에러를 노출한다.
    }
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

  /// 세트 변경. 해당 세트의 챔피언 픽·라이브 이벤트를 다시 로드한다.
  Future<void> selectSet(int setNumber) async {
    if (setNumber == _currentSet) return;
    _currentSet = setNumber;
    // 이전 세트 데이터 비우고 로딩 표시.
    _championPick = null;
    _liveEventsData = null;
    _ratings = null;
    _safeNotify();
    await _loadCurrentSet();
  }

  Future<void> _loadCurrentSet() async {
    await Future.wait([
      _loadChampionPick(),
      _loadLiveEvents(),
      _loadRatings(),
    ]);
  }

  Future<void> _loadChampionPick() async {
    final gameId = currentGameId;
    _loadingChampion = true;
    _championError = null;
    _safeNotify();
    try {
      if (gameId == null || gameId.isEmpty) {
        throw Exception('세트 정보를 찾을 수 없어요');
      }
      _championPick = await _repository.fetchChampionPick(gameId);
    } catch (e) {
      debugPrint('[MatchDetailVM] champion pick failed: $e');
      _championError = '챔피언 픽을 불러오지 못했어요';
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
        throw Exception('세트 정보를 찾을 수 없어요');
      }
      _liveEventsData = await _repository.fetchLiveEvents(gameId);
    } catch (e) {
      debugPrint('[MatchDetailVM] live events failed: $e');
      _eventsError = '라이브 이벤트를 불러오지 못했어요';
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
      _ratingsError = '선수 평점을 불러오지 못했어요';
      _ratings = null;
    } finally {
      _loadingRatings = false;
      _safeNotify();
    }
  }

  /// 라이브 이벤트 리로드 버튼용. 현재 세트의 이벤트만 다시 가져온다.
  Future<void> reloadLiveEvents() => _loadLiveEvents();

  /// 선수 평점 상세에서 평가 작성/수정/삭제 후 돌아왔을 때 현재 세트의
  /// 평점(평균·내 평점)을 다시 가져온다.
  Future<void> reloadRatings() => _loadRatings();
}
