import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/live_match_activity.dart';
import '../../model/match_game.dart';
import '../../model/schedule_match.dart';
import '../../model/team_notification_subscription.dart';
import '../match/match_detail_repository.dart';
import '../match/match_subscription_repository.dart';
import '../preference/team_preference_repository.dart';
import '../schedule/schedule_repository.dart';
import '../subscription/subscription_repository.dart';
import 'live_activity_service.dart';

/// 경기 데이터([ScheduleMatch] + 세트 목록)를 Live Activity 상태로 옮겨주는 컨트롤러.
///
/// [MatchDetailViewModel] 은 화면 상태만 담당하고, 여기서 그 데이터를 읽어
/// 액티비티 시작·갱신·종료를 판단한다. 같은 상태로 중복 갱신하지 않는다.
class LiveMatchActivityController {
  LiveMatchActivityController({LiveActivityService? service})
      : _service = service ?? LiveActivityService.instance;

  final LiveActivityService _service;

  /// 마지막으로 네이티브에 넘긴 상태의 지문. 같으면 갱신을 건너뛴다.
  String? _lastSignature;

  /// 액티비티가 붙어있는 경기 ID.
  String? _matchId;

  /// 현재 세트가 시작된 시각. LIVE 세트가 바뀔 때만 다시 잡는다.
  DateTime? _setStartedAt;

  /// [_setStartedAt] 기준점이 어느 세트의 것인지. 세트가 바뀌면 다시 잡는다.
  int? _timedSet;

  /// 경기 종료 후 카드를 자동으로 내리는 타이머.
  Timer? _dismissTimer;

  /// 카드가 떠 있는 동안 스코어를 주기적으로 갱신하는 타이머.
  Timer? _pollTimer;

  /// 갱신 주기. 세트 스코어는 자주 바뀌지 않아 30초면 충분하다.
  static const _pollInterval = Duration(seconds: 30);

  /// 경기 종료 카드를 유지하는 시간. 평점을 남길 여유를 준다.
  static const _autoDismissAfter = Duration(minutes: 30);

  /// 현재 액티비티가 떠 있는지.
  bool get isRunning => _matchId != null;

  /// 경기 상태를 반영한다.
  ///
  /// - LIVE 세트가 있고 액티비티가 없으면 시작
  /// - 이미 떠 있으면 상태만 갱신
  /// - 경기가 끝났으면 종료 상태로 갱신
  ///
  /// [autoStart] 가 false 면 이미 떠 있는 액티비티 갱신만 하고 새로 시작하지 않는다.
  Future<void> sync({
    required ScheduleMatch match,
    required List<MatchGame> games,
    bool autoStart = true,
  }) async {
    if (!await _service.isSupported()) return;

    // 이미 추적 중인 경기인데 세트 응답이 비어 오면 일시적인 응답 누락일
    // 가능성이 크다. 그대로 반영하면 진행 중인 세트가 "SET END"로 잘못
    // 표시되니, 상태를 내리지 말고 이번 갱신은 건너뛴다.
    if (_matchId == match.matchId && games.isEmpty) return;

    final phase = resolvePhase(games);
    final setNumber = resolveSetNumber(games);
    final (scoreA, scoreB) = resolveScore(match, games);

    // 진행 중인 세트가 바뀌면 경과 시간 기준점을 새로 잡는다.
    // (세트가 끝나고 다음 세트가 시작되면 타이머가 0부터 다시 흘러야 한다.)
    if (phase == LiveMatchPhase.playing) {
      if (_timedSet != setNumber) {
        _timedSet = setNumber;
        _setStartedAt = DateTime.now();
      }
      _setStartedAt ??= DateTime.now();
    }

    final state = LiveMatchActivityState(
      phase: phase,
      setNumber: setNumber,
      scoreA: scoreA,
      scoreB: scoreB,
      setStartedAt: phase == LiveMatchPhase.playing ? _setStartedAt : null,
      frozenTime: phase == LiveMatchPhase.playing ? null : _frozenElapsed(),
      statusLabel: _statusLabel(phase, setNumber),
      winnerTeamCode: phase == LiveMatchPhase.matchEnded
          ? _resolveWinner(match, scoreA, scoreB)
          : null,
    );

    final signature = '${match.matchId}|${state.phase.wireValue}|'
        '${state.setNumber}|${state.scoreA}|${state.scoreB}';

    if (_matchId == null) {
      // 아직 안 떴는데 경기가 진행 중이 아니면 띄울 이유가 없다.
      if (!autoStart || phase != LiveMatchPhase.playing) return;
      // 구독한 팀이 나오거나 알림을 켠 경기일 때만 띄운다.
      if (!await _shouldShow(match)) return;
      final started = await _start(match, state);
      if (started) {
        _matchId = match.matchId;
        _lastSignature = signature;
        _startPolling(match);
      }
      return;
    }

    // 다른 경기로 넘어갔으면 기존 액티비티를 내리고 새로 시작한다.
    if (_matchId != match.matchId) {
      await stop();
      if (autoStart &&
          phase == LiveMatchPhase.playing &&
          await _shouldShow(match)) {
        _setStartedAt = DateTime.now();
        if (await _start(match, state)) {
          _matchId = match.matchId;
          _lastSignature = signature;
          _startPolling(match);
        }
      }
      return;
    }

    if (signature == _lastSignature) return;
    _lastSignature = signature;

    await _service.update(state);

    // 경기가 끝나면 최종 스코어를 잠깐 보여준 뒤 카드를 내린다.
    // (사용자가 '평점 남기기' 를 누를 시간을 준다.)
    if (phase == LiveMatchPhase.matchEnded) {
      _scheduleAutoDismiss();
    }
  }

  /// 진행 중인 구독 경기를 찾아 카드를 띄운다.
  ///
  /// 앱 시작·포그라운드 복귀 시 호출한다. 푸시만으로는 카드를 띄울 수 없는
  /// 경우(세트 시작 알림을 꺼 둔 구독자 등)를 메우는 경로다.
  /// 이미 카드가 떠 있으면 아무것도 하지 않는다.
  ///
  /// 알림을 켠 경기 ID 목록을 먼저 보고, 그다음 구독 팀이 나오는 오늘 경기를
  /// 훑는다. 앞쪽이 후보가 훨씬 적어 대부분 거기서 끝난다.
  Future<void> scanForLiveMatch() async {
    if (_matchId != null) return;
    if (!await _service.isSupported()) return;

    try {
      for (final matchId in await _subscribedMatchIds()) {
        if (await _startIfLive(matchId)) return;
      }
      for (final matchId in await _todayMatchIdsOfSubscribedTeams()) {
        if (await _startIfLive(matchId)) return;
      }
    } catch (e) {
      debugPrint('[LiveActivity] 진행 중 경기 스캔 실패: $e');
    }
  }

  /// 알림을 켠 경기 ID 목록. 실패하면 빈 집합.
  ///
  /// 경기 리스트에서 직접 신청한 것만 담긴다(팀 구독 경기는 포함되지 않는다).
  Future<Set<String>> _subscribedMatchIds() async {
    try {
      return await MatchSubscriptionRepository.instance.subscribedMatchIds();
    } catch (e) {
      debugPrint('[LiveActivity] 경기 구독 목록 조회 실패: $e');
      return const {};
    }
  }

  /// 구독(또는 응원) 팀이 나오는 오늘 경기의 ID 목록.
  ///
  /// 경기 단위 알림을 켜지 않았어도 팀만 구독했으면 카드를 띄워야 해서
  /// 필요한 경로다.
  Future<List<String>> _todayMatchIdsOfSubscribedTeams() async {
    final codes = {
      for (final s in await _loadTeamSubs())
        if (s.subscribed || s.favoriteTeam) s.teamCode,
    };
    if (codes.isEmpty) return const [];

    try {
      final matches = await ScheduleRepository.instance
          .fetchMatchesByDate(DateTime.now(), leagues: const ['ALL']);
      return [
        for (final m in matches)
          if (codes.contains(m.teamA.teamCode) ||
              codes.contains(m.teamB.teamCode))
            m.matchId,
      ];
    } catch (e) {
      debugPrint('[LiveActivity] 오늘 경기 조회 실패: $e');
      return const [];
    }
  }

  /// 해당 경기가 진행 중이면 카드를 띄운다. 띄웠으면 true.
  Future<bool> _startIfLive(String matchId) async {
    final match = await MatchDetailRepository.instance.fetchMatch(matchId);
    if (match == null) return false;

    final (games, _) =
        await MatchDetailRepository.instance.fetchGames(matchId);
    if (resolvePhase(games) != LiveMatchPhase.playing) return false;

    await sync(match: match, games: games);
    return _matchId != null;
  }

  /// 경기 종료 카드를 일정 시간 뒤 자동으로 내린다.
  ///
  /// iOS 는 액티비티를 최대 8시간 유지하고 그 뒤 스스로 정리하지만,
  /// 종료된 경기 카드가 몇 시간씩 잠금화면에 남으면 방해가 된다.
  void _scheduleAutoDismiss() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_autoDismissAfter, () {
      stop();
    });
  }

  /// 카드가 떠 있는 동안 세트 목록을 주기적으로 다시 받아 상태를 갱신한다.
  ///
  /// 경기 상세 화면을 벗어나도 잠금화면 카드가 계속 살아 있어야 하므로,
  /// 화면이 아니라 컨트롤러가 직접 폴링한다. 앱이 백그라운드로 내려가면
  /// iOS 가 타이머를 멈추고, 포그라운드 복귀 시 다시 돈다.
  void _startPolling(ScheduleMatch match) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (_matchId != match.matchId) return;
      try {
        final (games, _) =
            await MatchDetailRepository.instance.fetchGames(match.matchId);
        await sync(match: match, games: games, autoStart: false);
      } catch (e) {
        debugPrint('[LiveActivity] 폴링 실패: $e');
      }
    });
  }

  /// 액티비티를 즉시 내린다.
  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _timedSet = null;
    if (_matchId == null) {
      await _service.endAll();
      return;
    }
    await _service.end(
      LiveMatchActivityState(
        phase: LiveMatchPhase.matchEnded,
        setNumber: 1,
        scoreA: 0,
        scoreB: 0,
        statusLabel: '경기 종료',
      ),
    );
    _matchId = null;
    _lastSignature = null;
    _setStartedAt = null;
  }

  // ── 표시 자격 / 응원 팀 ──────────────────────

  /// 팀 알림 구독 목록 캐시. 매 sync 마다 API 를 때리지 않도록 짧게 재사용한다.
  List<TeamNotificationSubscription>? _teamSubs;
  DateTime? _teamSubsAt;
  static const _teamSubsTtl = Duration(minutes: 10);

  /// 이 경기에 Live Activity 를 띄울 자격이 있는지.
  ///
  /// - 양 팀 중 하나가 구독(또는 응원) 중인 팀이거나
  /// - 이 경기의 알림을 켜 뒀으면 띄운다.
  ///
  /// 팀 구독의 세부 알림 옵션(세트 시작/종료·라이브 이벤트)은 푸시용이므로
  /// 여기서는 보지 않는다. 구독만 했으면 띄운다.
  Future<bool> _shouldShow(ScheduleMatch match) async {
    // 1) 경기 알림을 켠 경기인지.
    try {
      final ids = await MatchSubscriptionRepository.instance
          .subscribedMatchIds();
      if (ids.contains(match.matchId)) return true;
    } catch (e) {
      debugPrint('[LiveActivity] 경기 구독 조회 실패: $e');
    }

    // 2) 구독(또는 응원)하는 팀이 나오는 경기인지.
    final subs = await _loadTeamSubs();
    for (final s in subs) {
      if (!s.subscribed && !s.favoriteTeam) continue;
      if (s.teamCode == match.teamA.teamCode ||
          s.teamCode == match.teamB.teamCode) {
        return true;
      }
    }

    debugPrint('[LiveActivity] 구독/알림 대상이 아니라 표시하지 않음: '
        '${match.teamA.teamCode} vs ${match.teamB.teamCode}');
    return false;
  }

  /// 이 경기에서 사용자가 응원하는 팀의 코드. 없으면 null.
  ///
  /// 서버의 팀 알림 목록(`favoriteTeam`)을 우선 보고, 실패하면 로컬에
  /// 캐싱해 둔 선호 팀으로 폴백한다(비회원·오프라인 대응).
  Future<String?> _favoriteTeamCode(ScheduleMatch match) async {
    final subs = await _loadTeamSubs();
    for (final s in subs) {
      if (!s.favoriteTeam) continue;
      if (s.teamCode == match.teamA.teamCode ||
          s.teamCode == match.teamB.teamCode) {
        return s.teamCode;
      }
    }

    try {
      final team = await TeamPreferenceRepository.instance.loadPreferredTeam();
      final code = team?.code;
      if (code == match.teamA.teamCode || code == match.teamB.teamCode) {
        return code;
      }
    } catch (e) {
      debugPrint('[LiveActivity] 로컬 선호 팀 조회 실패: $e');
    }
    return null;
  }

  /// 팀 알림 구독 목록을 TTL 캐시와 함께 조회한다. 실패하면 빈 목록.
  Future<List<TeamNotificationSubscription>> _loadTeamSubs() async {
    final cachedAt = _teamSubsAt;
    final cached = _teamSubs;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _teamSubsTtl) {
      return cached;
    }
    try {
      final list =
          await SubscriptionRepository.instance.fetchTeamNotifications();
      _teamSubs = list;
      _teamSubsAt = DateTime.now();
      return list;
    } catch (e) {
      debugPrint('[LiveActivity] 팀 구독 조회 실패: $e');
      return cached ?? const [];
    }
  }

  // ── 상태 해석 ───────────────────────────────

  Future<bool> _start(
    ScheduleMatch match,
    LiveMatchActivityState state,
  ) async {
    // Android 는 알림 권한이 없으면 카드가 뜨지 않는다. 시작 직전에 확보한다.
    if (!await _service.ensurePermission()) {
      debugPrint('[LiveActivity] 알림 권한이 없어 표시하지 않음');
      return false;
    }

    // 로고는 액티비티 시작 시 한 번만 받아 App Group 에 캐싱한다.
    final logoA = await _service.fetchLogoBase64(match.teamA.teamImageUrl);
    final logoB = await _service.fetchLogoBase64(match.teamB.teamImageUrl);

    // 응원 팀이 이 경기에 나오면 그 팀 로고에 하트를 붙인다.
    final favoriteCode = await _favoriteTeamCode(match);

    return _service.start(
      config: LiveMatchActivityConfig(
        matchId: match.matchId,
        teamAName: match.teamA.teamName,
        teamACode: match.teamA.teamCode,
        teamBName: match.teamB.teamName,
        teamBCode: match.teamB.teamCode,
        leagueName: match.leagueInfo,
        teamALogoBase64: logoA,
        teamBLogoBase64: logoB,
        favoriteTeamCode: favoriteCode,
      ),
      state: state,
    );
  }

  /// 세트 목록에서 현재 국면을 판단한다.
  @visibleForTesting
  LiveMatchPhase resolvePhase(List<MatchGame> games) {
    if (games.any((g) => g.isLive)) return LiveMatchPhase.playing;
    // 세트 데이터가 전혀 없으면(과거 경기, 잘못된 matchId 등) 진행 중이라고
    // 볼 근거가 없다. 아래 SCHEDULED-전용 폴백과 구분해야 한다
    // — 그건 "세트는 있는데 아직 LIVE 로 안 바뀐 시작 직전" 케이스다.
    if (games.isEmpty) return LiveMatchPhase.setEnded;
    if (games.every((g) => g.isEnded)) return LiveMatchPhase.matchEnded;
    // 진행 중인 세트는 없지만 끝난 세트가 있으면 세트 간 휴식.
    if (games.any((g) => g.isEnded)) return LiveMatchPhase.setEnded;
    return LiveMatchPhase.playing;
  }

  /// 표시할 세트 번호 — LIVE 세트가 있으면 그것, 없으면 마지막 종료 세트.
  @visibleForTesting
  int resolveSetNumber(List<MatchGame> games) {
    for (final g in games) {
      if (g.isLive) return g.gameOrder;
    }
    var last = 1;
    for (final g in games) {
      if (g.isEnded && g.gameOrder > last) last = g.gameOrder;
    }
    return last;
  }

  /// 세트 승리 수로 스코어를 센다.
  @visibleForTesting
  (int, int) resolveScore(ScheduleMatch match, List<MatchGame> games) {
    var a = 0;
    var b = 0;
    for (final g in games) {
      final winner = g.winnerTeamCode;
      if (winner == null) continue;
      if (winner == match.teamA.teamCode) {
        a++;
      } else if (winner == match.teamB.teamCode) {
        b++;
      }
    }
    return (a, b);
  }

  String? _resolveWinner(ScheduleMatch match, int scoreA, int scoreB) {
    if (scoreA == scoreB) return null;
    return scoreA > scoreB ? match.teamA.teamCode : match.teamB.teamCode;
  }

  /// 세트가 끝난 시점의 경과 시간 문자열.
  String? _frozenElapsed() {
    final started = _setStartedAt;
    if (started == null) return null;
    final d = DateTime.now().difference(started);
    return '${d.inMinutes.toString().padLeft(2, '0')}:'
        '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _statusLabel(LiveMatchPhase phase, int setNumber) {
    switch (phase) {
      case LiveMatchPhase.playing:
        return '';
      case LiveMatchPhase.setEnded:
        return '다음 세트 준비 중';
      case LiveMatchPhase.matchEnded:
        return '경기 종료';
    }
  }
}

/// 앱 전역에서 하나만 쓰는 컨트롤러 인스턴스.
///
/// Live Activity 는 동시에 하나만 유지하므로 싱글턴으로 둔다.
final liveMatchActivityController = LiveMatchActivityController();
