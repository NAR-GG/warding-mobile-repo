import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/player_detail.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/home/home_sources.dart';
import '../../repository/match/match_subscription_repository.dart';
import '../../repository/player/player_repository.dart';
import '../../repository/subscription/subscription_repository.dart';
import '../home/solo_cheer_controller.dart';
import '../home/solo_rank_rules.dart';

enum PlayerTab { worlds, solo }

enum PlayerChampionSort { solo, worlds }

/// 선수 페이지 상태. 헤더(상세)·월즈 탭·솔랭 탭을 한 번에 불러온다.
///
/// 응원은 홈과 같은 [SoloCheerController] 를 넘겨받아 카운트를 맞춘다. 넘겨받지
/// 못하면(월즈 솔랭 화면에서 진입) 자기 컨트롤러를 만들고 닫힐 때 정리한다.
class PlayerViewModel extends ChangeNotifier {
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

  /// 선수 구독 토글. 비회원이면 false — 화면이 로그인으로 보낸다.
  Future<bool> toggleSubscribed() async {
    final d = detail;
    if (d == null) return true;
    if (!await _isLoggedIn()) return false;
    final next = !d.subscribed;
    detail = d.copyWith(subscribed: next);
    _notify();
    try {
      if (next) {
        await _subscriptions.subscribePlayer(playerId);
      } else {
        await _subscriptions.unsubscribePlayer(playerId);
      }
    } catch (e) {
      debugPrint('[Player] 구독 변경 실패: $e');
      detail = detail?.copyWith(subscribed: !next);
      _notify();
    }
    return true;
  }

  /// 비회원 여부 — 경기 알림 벨이 시트를 띄우기 전에 확인한다.
  Future<bool> isLoggedIn() => _isLoggedIn();

  /// 경기 알림 해제. 실패하면 되돌리고 false.
  Future<bool> unsubscribeMatch() async {
    final matchId = detail?.nextMatch?.matchId;
    if (matchId == null) return false;
    matchAlarmOn = false;
    _notify();
    try {
      await _matchSubscriptions.unsubscribeMatch(matchId);
      return true;
    } catch (_) {
      matchAlarmOn = true;
      _notify();
      return false;
    }
  }

  /// 경기 알림 등록. 실패하면 되돌리고 false.
  Future<bool> subscribeMatch(
    Future<void> Function(String matchId) send,
  ) async {
    final matchId = detail?.nextMatch?.matchId;
    if (matchId == null) return false;
    matchAlarmOn = true;
    _notify();
    try {
      await send(matchId);
      return true;
    } catch (_) {
      matchAlarmOn = false;
      _notify();
      return false;
    }
  }

  MatchSubscriptionRepository get matchSubscriptions => _matchSubscriptions;

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
