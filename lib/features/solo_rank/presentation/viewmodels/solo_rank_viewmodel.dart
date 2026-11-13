import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/domain/player_subscription.dart';
import 'package:warding/features/solo_rank/data/solo_rank_sources.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_models.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_rules.dart';
import 'package:warding/features/solo_rank/presentation/viewmodels/solo_cheer_controller.dart';
import 'package:warding/features/subscription/presentation/viewmodels/subscribed_players_viewmodel.dart';

/// 솔랭 카드 상태 (spec "상태" 표).
///
/// - [loading]: 첫 구독 조회가 아직 안 끝났다 — 스켈레톤. 구독 0명과 겉보기가
///   같아(둘 다 아직 화면에 확정된 카드가 없음) 구분하지 않으면 응답이
///   오는 순간 빈 카드 → 실제 카드로 레이아웃이 튄다(CLS).
/// - [noSubscription]: 구독 0명 — 점선 빈 카드.
/// - [noneActive]: 구독은 있는데 진행 중인 선수가 0명 — 한 줄짜리 조용한 상태.
/// - [active]: 진행 중인 선수가 있다 — 큰 카드 스와이프.
enum SoloCardState { loading, noSubscription, noneActive, active }

/// 구독 선수의 솔로 랭크 카드 + 월즈 솔랭 상태.
///
/// **구독 목록에 의존한다** — 카드가 보여주는 것이 "구독한 선수의 솔랭"이라
/// 구독 목록 없이는 성립하지 않는다. 그래서 숨기지 않고 생성자로 받는다
/// ([SubscribedPlayersViewModel]). 구독 목록이 바뀌면 분류를 다시 계산한다.
///
/// 홈 화면이 쓰지만 홈에 종속되지 않는다 — 솔랭 카드가 필요한 화면은 어디서든
/// 이것을 구독하면 된다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load]·[loadWorlds] 로
/// 정한다.
class SoloRankViewModel extends ChangeNotifier {
  SoloRankViewModel({
    required this.subscriptions,
    SoloRankSource? source,
    WorldsSoloSource? worlds,
    CheerSource? cheer,
    SoloCheerController? cheerController,
    this.maxFinished = 8,
  }) : _source = source ?? defaultSoloRankSource(),
       _worlds = worlds ?? defaultWorldsSoloSource(),
       cheers =
           cheerController ??
           SoloCheerController(source: cheer ?? defaultCheerSource()) {
    // 구독 목록이 늦게 도착하면 분류를 다시 해야 한다 — 구독한 선수만
    // 남기는 필터가 그 목록에 달려 있다.
    subscriptions.addListener(_onSubscriptionsChanged);
  }

  /// 구독 목록. 소유는 구독 기능이고 여기서는 읽기만 한다.
  final SubscribedPlayersViewModel subscriptions;

  final SoloRankSource _source;
  final WorldsSoloSource _worlds;

  /// 응원 — 낙관적 숫자와 묶음 전송. 카드는 이걸 직접 구독해 탭마다 화면
  /// 전체가 아니라 응원 영역만 다시 그린다.
  final SoloCheerController cheers;

  /// 끝난 경기 줄에 보여줄 최대 인원. 카드를 끼우는 화면이 정한다.
  final int maxFinished;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    subscriptions.removeListener(_onSubscriptionsChanged);
    _pollTimer?.cancel();
    cheers.dispose();
    super.dispose();
  }

  void _onSubscriptionsChanged() {
    _recompute();
    notifyListeners();
  }

  List<PlayerSubscription> get _subscribed =>
      subscriptions.players ?? const <PlayerSubscription>[];

  // ---- 폴링 ----

  Timer? _pollTimer;

  // 솔랭 조회가 5초(폴링 간격)보다 오래 걸리면 다음 틱이 세대를 먼저 올려
  // 버려, 느린 응답이 돌아와도 버려지고 카드가 멈춰 보인다(그 사이 요청만
  // 계속 쌓인다). 이전 조회가 끝나기 전엔 새 틱을 건너뛰어 막는다.
  bool _pollInFlight = false;

  /// 진행 중인 게임의 실시간성이 중요해 5초 폴링을 건다(2026-09-29 결정).
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pollInFlight) return;
      _pollInFlight = true;
      unawaited(
        Future.wait([
          load(),
          loadWorlds(),
        ]).whenComplete(() => _pollInFlight = false),
      );
    });
  }

  /// 화면이 안 보이는 동안 5초마다 네트워크를 쓰지 않게 멈춘다.
  void pausePolling() => _pollTimer?.cancel();

  /// 폴링을 재개하고, 그 사이 놓친 변화를 바로 반영하도록 즉시 한 번 조회한다.
  void resumePolling() {
    startPolling();
    unawaited(load());
    unawaited(loadWorlds());
  }

  // ---- 구독 솔랭 ----

  SoloRankSnapshot? _snapshot;
  int _gen = 0;

  List<LiveSoloPlayer> _live = const [];
  List<FinishedSoloPlayer> _finished = const [];

  /// 위쪽 큰 카드 — 지금 진행 중인 선수만. 핀 고정 선수가 먼저, 그 안팎에서는
  /// 가장 최근에 시작한(경과 시간이 짧은) 선수가 먼저.
  List<LiveSoloPlayer> get live => _live;

  /// 아래 줄 — 오늘 끝난 경기. 선수당 최신 1건, 최대 [maxFinished]명.
  List<FinishedSoloPlayer> get finished => _finished;

  /// 구독 수 — 실제 구독 목록 길이만 센다.
  int get subscribedTotal => subscriptions.total;

  /// 솔랭 중인 선수가 없을 때 조용한 행에 겹쳐 보여줄 구독 선수 얼굴.
  List<PlayerSubscription> get subscribedFaces =>
      _subscribed.take(quietFaceCount).toList();

  static const int quietFaceCount = 4;

  /// "+N명" — 위·아래 어디에도 안 나온 구독 선수 수.
  int get hiddenCount {
    final hidden = subscribedTotal - _live.length - _finished.length;
    return hidden < 0 ? 0 : hidden;
  }

  /// 진행 중 0명이어도 오늘 끝난 경기가 있으면 [SoloCardState.active] 다 —
  /// 큰 카드(스와이프)는 [live] 가 비어 있으면 그리지 않고, 끝난 경기 줄은
  /// 그대로 보여준다(2026-09-29 결정, spec.md "상태" 표).
  SoloCardState get cardState {
    if (subscriptions.loading) return SoloCardState.loading;
    if (subscribedTotal == 0) return SoloCardState.noSubscription;
    if (_live.isEmpty && _finished.isEmpty) return SoloCardState.noneActive;
    return SoloCardState.active;
  }

  /// 핀 고정한 선수 이름. 기기 로컬(메모리)만 — 저장·서버 동기화 없음.
  /// 몇 명까지 허용할지는 spec 미결이라 상한을 두지 않는다.
  Set<String> _pinnedNames = const {};
  Set<String> get pinnedNames => _pinnedNames;

  void togglePin(String name) {
    _pinnedNames = _pinnedNames.contains(name)
        ? ({..._pinnedNames}..remove(name))
        : {..._pinnedNames, name};
    _recompute();
    notifyListeners();
  }

  int _swipeIndex = 0;
  int get swipeIndex => _swipeIndex;

  void setSwipeIndex(int index) {
    if (index == _swipeIndex) return;
    _swipeIndex = index;
    notifyListeners();
  }

  Future<void> load() async {
    final gen = ++_gen;
    try {
      final snap = await _source.fetch();
      if (_disposed || gen != _gen) return;
      _snapshot = snap;
      _recompute();
      notifyListeners();
    } catch (e) {
      // spec 미결: 폴링 실패 시 마지막 값을 유지할지 — 잠정으로 유지한다.
      debugPrint('[SoloRank] 솔랭 상태 조회 실패: $e');
    }
  }

  void _recompute() {
    final snap = _snapshot;
    if (snap == null) return;

    // 구독 목록을 받았으면 구독한 선수만 남긴다 — 그래야 숨김 수(구독 수 −
    // 보이는 선수 수)가 맞고 내 선수 화면과 같은 선수를 보여준다. 비회원·실패는
    // 구독 0명이라 어차피 빈 카드다.
    final players = subscriptions.players;
    final subscribed = players == null
        ? null
        : {
            for (final p in players)
              SoloRankClassification.soloKey(p.playerName),
          };
    final solo = SoloRankClassification.of(snap, subscribed: subscribed);

    // 핀 고정 선수가 먼저, 그 안에서는 공용 규칙(최근 시작 먼저).
    final live = solo.liveByName.values.toList()
      ..sort((a, b) {
        final aPinned = _pinnedNames.contains(a.name) ? 0 : 1;
        final bPinned = _pinnedNames.contains(b.name) ? 0 : 1;
        if (aPinned != bPinned) return aPinned - bPinned;
        return SoloRankClassification.compareLive(a, b);
      });
    _live = live;
    _syncCheers(live);

    final finished = solo.finishedByName.values.toList()
      ..sort(SoloRankClassification.compareFinished);
    _finished = finished.take(maxFinished).toList();

    // 진행 중 선수가 줄어 스와이프 위치가 범위를 벗어나면 처음으로 돌린다.
    if (_swipeIndex >= _live.length) _swipeIndex = 0;
  }

  /// 서버 응원 수를 컨트롤러에 합치고, 카드가 사라진 선수의 미결은 보낸다.
  /// 전송 대상 id 는 솔랭 응답에 있으면 그것, 없으면 구독 목록에서 이름으로 찾는다.
  void _syncCheers(List<LiveSoloPlayer> live) {
    final idByName = {
      for (final p in _subscribed)
        SoloRankClassification.soloKey(p.playerName): p.playerId,
    };
    for (final p in live) {
      final key = SoloRankClassification.soloKey(p.name);
      cheers.sync(
        key,
        total: p.cheerTotal,
        mine: p.cheerMine,
        playerId: p.playerId ?? idByName[key],
      );
    }
    unawaited(
      cheers.flushMissing({
        for (final p in live) SoloRankClassification.soloKey(p.name),
      }),
    );
  }

  /// 앱이 백그라운드로 갈 때 미결 응원을 보낸다.
  Future<void> flushCheers() => cheers.flushAll();

  // ---- 월즈 솔랭 (구독 무관, 월즈 부트캠프 계정이 등록된 선수) ----

  WorldsSoloSnapshot? _worldsSnapshot;
  int _worldsGen = 0;

  Future<void> loadWorlds() async {
    final gen = ++_worldsGen;
    try {
      final snap = await _worlds.fetch();
      if (_disposed || gen != _worldsGen) return;
      _worldsSnapshot = snap;
      notifyListeners();
    } catch (e) {
      // 구독 솔랭과 같이 실패하면 마지막 값을 유지한다.
      debugPrint('[SoloRank] 월즈 솔랭 조회 실패: $e');
    }
  }

  /// 월즈 솔랭을 보여줄지 — 서버 명단이 비면(대회 전·후) 통째로 숨긴다.
  bool get worldsVisible => _worldsSnapshot?.players.isNotEmpty ?? false;

  /// 월즈 명단의 팀 수(진입 줄 "N팀 선수 …"). 팀 없는 선수는 세지 않는다.
  int get worldsTeamCount => {
    for (final p in _worldsSnapshot?.players ?? const <PlayerSubscription>[])
      if (p.teamCode.isNotEmpty) p.teamCode,
  }.length;

  SoloRankClassification get _worldsSolo =>
      SoloRankClassification.of(_worldsSnapshot?.solo);

  /// 지금 솔랭 중인 월즈 선수 전체(구독 포함). 최근 시작 먼저.
  List<LiveSoloPlayer> get worldsLiveAll =>
      _worldsSolo.liveByName.values.toList()
        ..sort(SoloRankClassification.compareLive);

  /// 지금 솔랭 중인 월즈 선수 중 구독하지 않은 선수 — 구독 선수는 위 큰 카드에
  /// 이미 나오므로 월즈 카드에서는 뺀다.
  List<LiveSoloPlayer> get worldsLive {
    final subscribed = {
      for (final p in _subscribed)
        SoloRankClassification.soloKey(p.playerName),
    };
    return [
      for (final p in worldsLiveAll)
        if (!subscribed.contains(SoloRankClassification.soloKey(p.name))) p,
    ];
  }

  /// 월즈 선수가 아무도 솔랭 중이 아닐 때 한 줄에 보여줄 "마지막" 판.
  FinishedSoloPlayer? get worldsLastFinished {
    final finished = _worldsSolo.finishedByName.values.toList()
      ..sort(SoloRankClassification.compareFinished);
    return finished.isEmpty ? null : finished.first;
  }

  /// 내 선수 화면(보기 전용)에서 돌아왔을 때 솔랭 상태를 다시 불러온다.
  Future<void> refreshOnReturn() => Future.wait([load(), loadWorlds()]);

  /// 구독 설정 화면에서 돌아왔을 때 구독 목록과 솔랭 상태를 함께 다시
  /// 불러온다. 구독 수가 바뀌면 [cardState] 도 같이 바뀌어야 하므로
  /// [refreshOnReturn] 만으로는 부족하다.
  Future<void> refreshWithSubscriptions() =>
      Future.wait([subscriptions.load(), load(), loadWorlds()]);
}
