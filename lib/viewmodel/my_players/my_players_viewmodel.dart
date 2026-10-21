import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/home_models.dart';
import '../../model/player_subscription.dart';
import '../../repository/home/home_sources.dart';
import '../../repository/subscription/subscription_repository.dart';
import '../home/solo_rank_rules.dart';

/// 내 선수 화면의 상태 묶음 (spec: 솔랭 중 / 오늘 경기함 / 소식 없음).
enum MyPlayerStatus { liveSolo, playedToday, quiet }

/// 내 선수 목록 한 줄 — 구독 선수와 그 선수의 오늘 솔랭 상태.
class MyPlayerEntry {
  const MyPlayerEntry({
    required this.player,
    required this.status,
    this.live,
    this.finished,
  });

  final PlayerSubscription player;
  final MyPlayerStatus status;

  /// [MyPlayerStatus.liveSolo] 일 때 진행 중인 게임.
  final HomeLiveSoloPlayer? live;

  /// [MyPlayerStatus.playedToday] 일 때 오늘 가장 최근에 끝난 게임.
  final HomeFinishedSoloPlayer? finished;
}

/// 내 선수(구독 전체) 화면 상태. 보기 전용이다 — 구독 관리·알림 설정은
/// 마이페이지에서 한다(spec 결정).
///
/// 홈과 같은 소스를 쓴다: 구독 목록은 [SubscriptionRepository], 솔랭 상태는
/// [SoloRankSource]. 선수 매칭도 홈처럼 이름(`name` == `playerName`)으로 한다.
///
/// spec 상 로딩·에러 상태는 그리지 않는다. 비회원(JWT 없음)·조회 실패는 구독
/// 0명으로 보고, 다시 불러오다 실패하면 마지막 값을 유지한다
/// (솔랭 실패 시 유지 여부는 spec 미결 — 홈과 같이 잠정으로 유지).
///
/// [worlds] 를 주면 월즈 솔랭 화면이 된다 — 명단이 구독 선수가 아니라 월즈
/// 부트캠프 계정이 등록된 선수 전체이고, 탭([subscribedOnly])과 구독 벨
/// ([setSubscribed])이 생긴다. 분류·필터·접기 규칙은 내 선수와 같다.
class MyPlayersViewModel extends ChangeNotifier {
  MyPlayersViewModel({
    SubscriptionRepository? subscriptions,
    SoloRankSource? soloRank,
    WorldsSoloSource? worlds,
  }) : _subscriptions = subscriptions ?? SubscriptionRepository.instance,
       // 기본은 실제 솔랭 API. 목업은 HOME_MOCKS=true 일 때만.
       _soloRank = soloRank ?? defaultSoloRankSource(),
       _worlds = worlds {
    unawaited(refresh());
  }

  final SubscriptionRepository _subscriptions;
  final SoloRankSource _soloRank;
  final WorldsSoloSource? _worlds;

  /// 월즈 솔랭 화면인지.
  bool get isWorlds => _worlds != null;

  Map<int, WorldsTodayRecord> _today = const {};

  /// 팀 → 리그(서버가 준 칩 순서). 내 선수 화면·옛 서버면 비어 있다.
  Map<String, String> _teamLeagues = const {};

  /// 월즈 선수의 오늘 전적. 오늘 한 판도 없거나 옛 서버면 null.
  WorldsTodayRecord? todayRecord(int playerId) => _today[playerId];

  /// 소식 없음 묶음이 접혀 있을 때 보이는 선수 수.
  static const int quietVisibleCap = 5;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<PlayerSubscription> _players = const [];
  SoloRankSnapshot? _solo;

  // 분류 결과(필터 전). 로드가 끝날 때만 다시 계산한다.
  List<MyPlayerEntry> _allLive = const [];
  List<MyPlayerEntry> _allPlayed = const [];
  List<MyPlayerEntry> _allQuiet = const [];
  List<String> _teamCodes = const [];
  Map<String, String> _teamLogos = const {};

  /// 두 소스를 병렬로 다시 불러온다. 서로 기다리지 않고, 실패한 쪽은
  /// 마지막 값을 그대로 둔다.
  Future<void> refresh() async {
    if (_worlds != null) return _loadWorlds(_worlds);
    await Future.wait([_loadSubscriptions(), _loadSolo()]);
  }

  // 월즈는 명단과 솔랭 상태가 한 응답으로 온다.
  Future<void> _loadWorlds(WorldsSoloSource source) async {
    try {
      final snap = await source.fetch();
      if (_disposed) return;
      _players = snap.players;
      _solo = snap.solo;
      _today = snap.today;
      _teamLeagues = snap.teamLeagues;
      _classify();
      _notify();
    } catch (e) {
      debugPrint('[WorldsSolo] 월즈 솔랭 조회 실패: $e');
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      // 비회원(JWT 없음)이면 authorizedRequest 가 던진다 → 아래 catch.
      final players = await _subscriptions.fetchSubscribedPlayers();
      if (_disposed) return;
      _players = players;
      _classify();
      _notify();
    } catch (e) {
      debugPrint('[MyPlayers] 구독 선수 조회 실패(비회원 포함): $e');
    }
  }

  Future<void> _loadSolo() async {
    try {
      final snap = await _soloRank.fetch();
      if (_disposed) return;
      _solo = snap;
      _classify();
      _notify();
    } catch (e) {
      // spec 미결: 솔랭 조회 실패 시 마지막 값을 유지할지 — 홈과 같이 유지한다.
      debugPrint('[MyPlayers] 솔랭 상태 조회 실패: $e');
    }
  }

  void _classify() {
    // 분류 규칙(이름 매칭, 진행 중 선수는 끝난 경기에서 제외, 선수당 최신 1건)은
    // 홈 솔랭 카드와 공유한다. 구독 선수만 아래에서 찾아 쓰므로 여기서는
    // 구독 필터를 따로 걸지 않는다.
    final solo = SoloRankClassification.of(_solo);
    final liveByName = solo.liveByName;
    final finishedByName = solo.finishedByName;

    final live = <MyPlayerEntry>[];
    final played = <MyPlayerEntry>[];
    final quiet = <MyPlayerEntry>[];
    final teams = <String>[];
    final logos = <String, String>{};
    for (final player in _players) {
      if (player.teamCode.isNotEmpty && !logos.containsKey(player.teamCode)) {
        teams.add(player.teamCode);
        logos[player.teamCode] = player.teamImageUrl;
      }
      final key = SoloRankClassification.soloKey(player.playerName);
      final l = liveByName[key];
      // 진행 중이면 오늘 끝난 기록이 있어도 솔랭 중에만 둔다 — 같은 선수가
      // 두 묶음에 나오지 않게(홈 솔랭 카드와 같은 규칙).
      if (l != null) {
        live.add(
          MyPlayerEntry(
            player: player,
            status: MyPlayerStatus.liveSolo,
            live: l,
          ),
        );
        continue;
      }
      final f = finishedByName[key];
      if (f != null) {
        played.add(
          MyPlayerEntry(
            player: player,
            status: MyPlayerStatus.playedToday,
            finished: f,
          ),
        );
        continue;
      }
      quiet.add(MyPlayerEntry(player: player, status: MyPlayerStatus.quiet));
    }

    // 솔랭 중: 최근에 시작한(경과 짧은) 선수 먼저. 오늘 경기함: 최근에 끝난
    // 선수 먼저. 소식 없음: 구독 목록 순서 그대로.
    live.sort((a, b) => SoloRankClassification.compareLive(a.live!, b.live!));
    played.sort(
      (a, b) =>
          SoloRankClassification.compareFinished(a.finished!, b.finished!),
    );

    _allLive = live;
    _allPlayed = played;
    _allQuiet = quiet;
    // 서버가 준 순서(리그 순 → 리그 안 시드 순). 없는 팀은 뒤에 처음 나온 순서대로.
    // 내 선수 화면은 [_teamLeagues] 가 비어 처음 나온 순서 그대로.
    if (_teamLeagues.isNotEmpty) {
      final seed = _teamLeagues.keys.toList();
      int rank(String t) {
        final i = seed.indexOf(t);
        return i < 0 ? seed.length : i;
      }

      teams.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    _teamCodes = teams;
    _teamLogos = logos;
  }

  /// 구독 선수 수. 비회원·조회 실패는 0명. 월즈 화면에서는 명단 전체 수.
  int get subscribedTotal => _players.length;

  /// 월즈 명단 중 내가 구독한 선수 수("구독 선수" 탭).
  int get subscribedInRoster => _players.where((p) => p.subscribed).length;

  // ---- 월즈: 탭 · 구독 ----
  bool _subscribedOnly = false;

  /// "구독 선수" 탭이면 true, "LCK 전체" 탭이면 false.
  bool get subscribedOnly => _subscribedOnly;

  void setSubscribedOnly(bool value) {
    if (value == _subscribedOnly) return;
    _subscribedOnly = value;
    _notify();
  }

  /// 명단의 한 선수를 구독/해제한다. 화면을 먼저 바꾸고, 실패하면 되돌린다.
  /// [startEnabled]/[endEnabled] 는 구독할 때의 알림 토글(기본: 둘 다 ON).
  Future<void> setSubscribed(
    int playerId,
    bool subscribed, {
    bool startEnabled = true,
    bool endEnabled = true,
  }) async {
    final before = _players;
    _players = [
      for (final p in _players)
        if (p.playerId == playerId)
          p.copyWith(
            subscribed: subscribed,
            startEnabled: startEnabled,
            endEnabled: endEnabled,
          )
        else
          p,
    ];
    _classify();
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
    } catch (e) {
      debugPrint('[WorldsSolo] 구독 변경 실패: $e');
      if (_disposed) return;
      _players = before;
      _classify();
      _notify();
    }
  }

  /// 소속팀 코드 한 번씩(팀 필터 칩). 월즈는 서버가 준 순서, 아니면 처음 나온 순서.
  /// 리그를 골랐으면 그 리그 팀만.
  List<String> get teamCodes {
    final league = _leagueCode;
    if (league == null) return _teamCodes;
    return [
      for (final t in _teamCodes)
        if (_teamLeagues[t] == league) t,
    ];
  }

  /// 팀 칩 로고 URL(응답 값). 없으면 null — 칩이 팀 코드 사전으로 찾는다.
  String? teamLogoUrl(String teamCode) {
    final url = _teamLogos[teamCode];
    return url == null || url.isEmpty ? null : url;
  }

  /// 명단에 있는 리그 — 서버가 준 순서(리그 필터 칩). 서버 목록에 없는 팀은 빠진다.
  List<String> get leagueCodes {
    final present = {for (final t in _teamCodes) _teamLeagues[t]};
    return [
      for (final l in _teamLeagues.values.toSet())
        if (present.contains(l)) l,
    ];
  }

  /// 구독 중인 선수의 알림 토글만 바꾼다. 실패하면 되돌린다.
  Future<void> setAlarms(
    int playerId, {
    required bool startEnabled,
    required bool endEnabled,
  }) async {
    final before = _players;
    _players = [
      for (final p in _players)
        if (p.playerId == playerId)
          p.copyWith(startEnabled: startEnabled, endEnabled: endEnabled)
        else
          p,
    ];
    _classify();
    _notify();
    try {
      await _subscriptions.updatePlayerAlarm(
        playerId,
        startEnabled: startEnabled,
        endEnabled: endEnabled,
      );
    } catch (e) {
      debugPrint('[WorldsSolo] 알림 토글 변경 실패: $e');
      if (_disposed) return;
      _players = before;
      _classify();
      _notify();
    }
  }

  // ---- 필터 ----
  String _query = '';

  /// 검색어. 선수 이름 부분일치(대소문자 무시).
  String get query => _query;

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _notify();
  }

  String? _teamCode;

  /// 팀 필터. null 이면 전체.
  String? get teamCode => _teamCode;

  void setTeamCode(String? code) {
    if (code == _teamCode) return;
    _teamCode = code;
    _notify();
  }

  String? _leagueCode;

  /// 리그 필터(월즈). null 이면 전체.
  String? get leagueCode => _leagueCode;

  /// 리그를 바꾸면 팀 필터는 풀린다 — 다른 리그 팀이 걸린 채 빈 목록이 되지 않게.
  void setLeagueCode(String? code) {
    if (code == _leagueCode) return;
    _leagueCode = code;
    _teamCode = null;
    _notify();
  }

  List<MyPlayerEntry> _filter(List<MyPlayerEntry> list) {
    final q = _query.trim().toLowerCase();
    final team = _teamCode;
    final league = _leagueCode;
    final subscribedOnly = _subscribedOnly;
    if (q.isEmpty && team == null && league == null && !subscribedOnly) {
      return list;
    }
    return [
      for (final e in list)
        if ((!subscribedOnly || e.player.subscribed) &&
            (league == null || _teamLeagues[e.player.teamCode] == league) &&
            (team == null || e.player.teamCode == team) &&
            (q.isEmpty || e.player.playerName.toLowerCase().contains(q)))
          e,
    ];
  }

  List<MyPlayerEntry> get liveSolo => _filter(_allLive);
  List<MyPlayerEntry> get playedToday => _filter(_allPlayed);

  /// 소식 없음 — 필터를 적용한 전체. 화면에는 [quietVisible] 을 그린다.
  List<MyPlayerEntry> get quiet => _filter(_allQuiet);

  // ---- 소식 없음 접기 ----
  bool _quietExpanded = false;

  /// 소식 없음 묶음을 펼쳤는지. 기본은 접힘 — "N명 더 보기" 뒤에 둔다(spec).
  bool get quietExpanded => _quietExpanded;

  void toggleQuietExpanded() {
    _quietExpanded = !_quietExpanded;
    _notify();
  }

  /// 화면에 그릴 소식 없음 선수 — 접혀 있으면 앞 [quietVisibleCap] 명.
  List<MyPlayerEntry> get quietVisible {
    final all = quiet;
    if (_quietExpanded || all.length <= quietVisibleCap) return all;
    return all.sublist(0, quietVisibleCap);
  }

  /// 접혀서 안 보이는 소식 없음 선수 수("N명 더 보기"). 펼쳤으면 0.
  int get quietHiddenCount {
    if (_quietExpanded) return 0;
    final hidden = quiet.length - quietVisibleCap;
    return hidden < 0 ? 0 : hidden;
  }

  /// 접기/펼치기 버튼을 둘지 — 상한을 넘는 소식 없음 선수가 있을 때만.
  bool get quietCollapsible => quiet.length > quietVisibleCap;
}
