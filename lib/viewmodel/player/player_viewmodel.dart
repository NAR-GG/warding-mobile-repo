import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/home_models.dart';
import '../../model/player_detail.dart';
import '../../model/player_subscription.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/home/home_sources.dart';
import '../../repository/match/match_subscription_repository.dart';
import '../../repository/player/player_repository.dart';
import '../../repository/subscription/subscription_repository.dart';
import '../../util/analytics.dart';
import '../../util/analytics_events.dart';
import '../home/solo_cheer_controller.dart';
import '../home/solo_rank_rules.dart';
import '../my_players/my_players_viewmodel.dart';

enum PlayerTab { worlds, solo }

enum PlayerChampionSort { solo, worlds }

/// 선수 페이지 상태. 헤더(상세)·월즈 탭·솔랭 탭을 한 번에 불러온다.
///
/// 응원은 홈과 같은 [SoloCheerController] 를 넘겨받아 카운트를 맞춘다. 넘겨받지
/// 못하면(월즈 솔랭 화면에서 진입) 자기 컨트롤러를 만들고 닫힐 때 정리한다.
class PlayerViewModel extends ChangeNotifier implements PlayerSheetSource {
  PlayerViewModel({
    required this.playerId,
    PlayerSource? source,
    SoloCheerController? cheers,
    SubscriptionRepository? subscriptions,
    MatchSubscriptionRepository? matchSubscriptions,
    Future<bool> Function()? isLoggedIn,
  }) : _source = source ?? defaultPlayerSource(),
       _ownsCheers = cheers == null,
       cheers = cheers ?? SoloCheerController(source: defaultCheerSource()),
       _subscriptions = subscriptions ?? SubscriptionRepository.instance,
       _matchSubscriptions =
           matchSubscriptions ?? MatchSubscriptionRepository.instance,
       _isLoggedIn = isLoggedIn ?? _defaultLoggedIn;

  final int playerId;
  final PlayerSource _source;
  final bool _ownsCheers;
  final SoloCheerController cheers;
  final SubscriptionRepository _subscriptions;
  final MatchSubscriptionRepository _matchSubscriptions;
  final Future<bool> Function() _isLoggedIn;

  static Future<bool> _defaultLoggedIn() async {
    try {
      final jwt = await AuthService.instance.jwt;
      return jwt != null && jwt.isNotEmpty;
    } catch (_) {
      return true; // Keychain 을 못 읽은 건 로그아웃이 아니다.
    }
  }

  bool _disposed = false;

  PlayerDetail? detail;
  PlayerWorlds? worlds;
  PlayerSoloRank? solo;
  bool loading = true;

  /// 상세 조회 실패. [notFound] 면 없는 선수.
  bool failed = false;
  bool notFound = false;

  PlayerTab tab = PlayerTab.worlds;
  PlayerChampionSort championSort = PlayerChampionSort.solo;
  bool championsExpanded = false;
  bool soloGamesExpanded = false;

  /// 다음 경기 알림 구독 여부.
  bool matchAlarmOn = false;

  /// 응원 집계 키 — 홈과 같은 키를 써야 카운트가 맞는다.
  String get cheerKey =>
      SoloRankClassification.soloKey(detail?.playerName ?? '');

  Future<void> load() async {
    failed = false;
    allReviews = null;
    reviewsHasNext = false;
    notFound = false;
    _notify();
    final detailF = _source.fetchDetail(playerId);
    final worldsF = _source.fetchWorlds(playerId);
    final soloF = _source.fetchSoloRank(playerId);
    try {
      detail = await detailF;
    } on PlayerNotFound {
      notFound = true;
      failed = true;
    } catch (e) {
      debugPrint('[Player] 상세 조회 실패: $e');
      failed = true;
    }
    // 탭 데이터는 실패해도 페이지는 연다 — 그 탭만 빈 상태가 된다.
    try {
      worlds = await worldsF;
    } catch (e) {
      debugPrint('[Player] 월즈 탭 조회 실패: $e');
    }
    try {
      solo = await soloF;
    } catch (e) {
      debugPrint('[Player] 솔랭 탭 조회 실패: $e');
    }
    loading = false;
    final d = detail;
    final live = d?.live;
    if (d != null && live != null) {
      cheers.sync(
        cheerKey,
        total: live.cheerTotal,
        mine: live.cheerMine,
        playerId: d.playerId,
      );
    }
    _notify();
    unawaited(_loadMatchAlarm());
  }

  Future<void> _loadMatchAlarm() async {
    final matchId = detail?.nextMatch?.matchId;
    if (matchId == null || matchId.isEmpty || !await _isLoggedIn()) return;
    try {
      final ids = await _matchSubscriptions.subscribedMatchIds();
      matchAlarmOn = ids.contains(matchId);
      _notify();
    } catch (_) {
      // 조회 실패 시 미구독으로 둔다.
    }
  }

  void setTab(PlayerTab value) {
    if (tab == value) return;
    tab = value;
    _notify();
  }

  void setChampionSort(PlayerChampionSort value) {
    if (championSort == value) return;
    championSort = value;
    _notify();
  }

  void expandChampions() {
    championsExpanded = true;
    _notify();
  }

  void expandSoloGames() {
    soloGamesExpanded = true;
    _notify();
  }

  /// 정렬된 솔랭 vs 월즈 챔피언. 판수 많은 순, 같으면 승수 많은 순.
  List<PlayerChampionRecord> get sortedChampions {
    final list = [...?worlds?.champions];
    int games(PlayerChampionRecord c) =>
        championSort == PlayerChampionSort.solo ? c.soloGames : c.worldsGames;
    int wins(PlayerChampionRecord c) =>
        championSort == PlayerChampionSort.solo ? c.soloWins : c.worldsWins;
    list.sort((a, b) {
      final byGames = games(b).compareTo(games(a));
      return byGames != 0 ? byGames : wins(b).compareTo(wins(a));
    });
    return list;
  }

  /// 비회원 여부 — 경기 알림 벨이 시트를 띄우기 전에 확인한다.
  Future<bool> isLoggedIn() => _isLoggedIn();

  MatchSubscriptionRepository get matchSubscriptions => _matchSubscriptions;

  /// 경기 알림 시트 흐름이 끝난 뒤의 구독 여부를 반영한다.
  void setMatchAlarmOn(bool value) {
    if (matchAlarmOn == value) return;
    matchAlarmOn = value;
    _notify();
  }

  // ── 선수 구독 시트([PlayerSheetSource]) ─────────────────────────────

  @override
  MyPlayerEntry? sheetEntry(int playerId) {
    final d = detail;
    if (d == null || d.playerId != playerId) return null;
    final live = d.liveAsHome;
    final last = d.lastGame;
    final ended = last?.endedAt?.toLocal();
    final now = DateTime.now();
    final today =
        ended != null &&
        ended.year == now.year &&
        ended.month == now.month &&
        ended.day == now.day;
    return MyPlayerEntry(
      player: PlayerSubscription(
        playerId: d.playerId,
        playerName: d.playerName,
        playerImageUrl: d.playerImageUrl ?? '',
        role: d.role,
        teamId: 0,
        teamCode: d.teamCode,
        teamName: d.teamName,
        teamImageUrl: d.teamImageUrl ?? '',
        subscribed: d.subscribed,
        startEnabled: d.startEnabled,
        endEnabled: d.endEnabled,
      ),
      status: live != null
          ? MyPlayerStatus.liveSolo
          : today
          ? MyPlayerStatus.playedToday
          : MyPlayerStatus.quiet,
      live: live,
      finished: live == null && today
          ? HomeFinishedSoloPlayer(
              name: d.playerName,
              teamCode: d.teamCode,
              won: last!.win,
              minutesAgo: now.difference(ended).inMinutes.clamp(0, 1 << 30),
              durationMinutes: last.durationSeconds ~/ 60,
            )
          : null,
    );
  }

  @override
  WorldsTodayRecord? todayRecord(int playerId) => null;

  /// 구독/해제 — 화면을 먼저 바꾸고 실패하면 되돌린다(월즈 솔랭과 같은 규칙).
  @override
  Future<void> setSubscribed(
    int playerId,
    bool subscribed, {
    bool startEnabled = true,
    bool endEnabled = true,
  }) async {
    final before = detail;
    if (before == null) return;
    detail = before.copyWith(
      subscribed: subscribed,
      startEnabled: startEnabled,
      endEnabled: endEnabled,
    );
    _notify();
    try {
      if (subscribed) {
        await _subscriptions.subscribePlayer(playerId);
        // 서버 기본값(시작 ON·종료 OFF)과 다를 때만 토글을 맞춘다.
        if (!startEnabled || endEnabled) {
          await _subscriptions.updatePlayerAlarm(
            playerId,
            startEnabled: startEnabled,
            endEnabled: endEnabled,
          );
        }
      } else {
        await _subscriptions.unsubscribePlayer(playerId);
      }
      // API 성공 후에 찍는다(월즈 솔랭과 같은 이벤트·같은 규칙).
      Analytics.track(AnalyticsEvent.subscribeButtonClick, {
        AnalyticsProp.locationPage: AnalyticsPage.playerDetail,
        AnalyticsProp.targetType: AnalyticsValue.player,
        AnalyticsProp.playerId: playerId,
        AnalyticsProp.isOn: subscribed,
        if (subscribed) AnalyticsProp.alarmStart: startEnabled,
        if (subscribed) AnalyticsProp.alarmEnd: endEnabled,
      });
    } catch (e) {
      debugPrint('[Player] 구독 변경 실패: $e');
      detail = before;
      _notify();
    }
  }

  @override
  Future<void> setAlarms(
    int playerId, {
    required bool startEnabled,
    required bool endEnabled,
  }) async {
    final before = detail;
    if (before == null) return;
    detail = before.copyWith(
      startEnabled: startEnabled,
      endEnabled: endEnabled,
    );
    _notify();
    try {
      await _subscriptions.updatePlayerAlarm(
        playerId,
        startEnabled: startEnabled,
        endEnabled: endEnabled,
      );
    } catch (e) {
      debugPrint('[Player] 알림 토글 변경 실패: $e');
      detail = before;
      _notify();
    }
  }

  // ── 한줄평 전체 ───────────────────────────────────────────────

  /// "한줄평 전체 보기" 로 펼친 목록. null 이면 아직 안 펼쳤다(미리보기 3개).
  List<PlayerReview>? allReviews;
  bool reviewsHasNext = false;
  bool reviewsLoading = false;
  int _reviewsPage = 0;

  /// 첫 호출은 0페이지로 펼치고, 그 뒤로는 다음 페이지를 붙인다.
  Future<void> loadMoreReviews() async {
    if (reviewsLoading) return;
    if (allReviews != null && !reviewsHasNext) return;
    reviewsLoading = true;
    _notify();
    try {
      final page = await _source.fetchWorldsReviews(
        playerId,
        page: allReviews == null ? 0 : _reviewsPage + 1,
      );
      _reviewsPage = allReviews == null ? 0 : _reviewsPage + 1;
      allReviews = [...?allReviews, ...page.reviews];
      reviewsHasNext = page.hasNext;
    } catch (e) {
      debugPrint('[Player] 한줄평 조회 실패: $e');
    } finally {
      reviewsLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsCheers) {
      unawaited(cheers.flushAll());
      cheers.dispose();
    }
    super.dispose();
  }
}
