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
class MyPlayersViewModel extends ChangeNotifier {
  MyPlayersViewModel({
    SubscriptionRepository? subscriptions,
    SoloRankSource? soloRank,
  }) : _subscriptions = subscriptions ?? SubscriptionRepository.instance,
       // 기본은 실제 솔랭 API. 목업은 HOME_MOCKS=true 일 때만.
       _soloRank = soloRank ?? defaultSoloRankSource() {
    unawaited(refresh());
  }

  final SubscriptionRepository _subscriptions;
  final SoloRankSource _soloRank;

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

  /// 두 소스를 병렬로 다시 불러온다. 서로 기다리지 않고, 실패한 쪽은
  /// 마지막 값을 그대로 둔다.
  Future<void> refresh() async {
    await Future.wait([_loadSubscriptions(), _loadSolo()]);
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
    final seenTeams = <String>{};
    for (final player in _players) {
      if (player.teamCode.isNotEmpty && seenTeams.add(player.teamCode)) {
        teams.add(player.teamCode);
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
      (a, b) => SoloRankClassification.compareFinished(a.finished!, b.finished!),
    );

    _allLive = live;
    _allPlayed = played;
    _allQuiet = quiet;
    _teamCodes = teams;
  }

  /// 구독 선수 수. 비회원·조회 실패는 0명.
  int get subscribedTotal => _players.length;

  /// 구독 선수 소속팀 코드 — 처음 나온 순서대로 한 번씩(팀 필터 칩).
  List<String> get teamCodes => _teamCodes;

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

  List<MyPlayerEntry> _filter(List<MyPlayerEntry> list) {
    final q = _query.trim().toLowerCase();
    final team = _teamCode;
    if (q.isEmpty && team == null) return list;
    return [
      for (final e in list)
        if ((team == null || e.player.teamCode == team) &&
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
