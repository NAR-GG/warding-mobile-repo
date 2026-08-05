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
/// 액티비티 시작·갱신을 판단한다. 같은 상태로 중복 갱신하지 않는다.
///
/// 카드가 뜬 뒤의 갱신·종료는 서버가 APNs 로 직접 처리한다
/// (세트 시작·종료 시 `update`, 매치 종료 시 `end` + 30분 뒤 dismissal-date).
/// 앱은 카드를 띄우고(서버는 push-to-start 를 쓰지 않는다) 발급된 푸시 토큰을
/// 등록하는 역할만 한다 — [LiveActivityService] 의 `pushToken` 콜백 참고.
class LiveMatchActivityController {
  LiveMatchActivityController({LiveActivityService? service})
      : _service = service ?? LiveActivityService.instance;

  final LiveActivityService _service;

  /// 마지막으로 네이티브에 넘긴 상태의 지문. 같으면 갱신을 건너뛴다.
  String? _lastSignature;

  /// 액티비티가 붙어있는 경기 ID.
  String? _matchId;

  /// 현재 액티비티가 떠 있는지.
  bool get isRunning => _matchId != null;

  /// 경기 상태를 반영한다.
  ///
  /// - LIVE 세트가 있고 액티비티가 없으면 시작
  /// - 이미 떠 있으면 상태만 갱신 (매치 종료는 서버가 처리하므로 제외)
  ///
  /// [autoStart] 가 false 면 이미 떠 있는 액티비티 갱신만 하고 새로 시작하지 않는다.
  Future<void> sync({
    required ScheduleMatch match,
    required List<MatchGame> games,
    bool autoStart = true,
  }) async {
    if (!await _service.isSupported()) return;

    // 아직 시작하지 않은 경기(세트가 없거나 전부 예정)는 표시 대상이 아니다.
    final phase = resolvePhase(games);
    if (phase == null) return;

    final setNumber = resolveSetNumber(games);
    final (scoreA, scoreB) = resolveScore(match, games);

    final state = LiveMatchActivityState(
      phase: phase,
      setNumber: setNumber,
      scoreA: scoreA,
      scoreB: scoreB,
      statusLabel: _statusLabel(phase, setNumber),
      winnerTeamCode: phase == LiveMatchPhase.matchEnded
          ? _resolveWinner(match, scoreA, scoreB)
          : null,
    );

    final signature = '${match.matchId}|${state.phase.wireValue}|'
        '${state.setNumber}|${state.scoreA}|${state.scoreB}';

    if (_matchId == null) {
      // 아직 안 떴는데 경기가 진행 중이 아니면 띄울 이유가 없다.
      if (!autoStart || !_canStart(match, phase)) return;
      // 구독한 팀이 나오거나 알림을 켠 경기일 때만 띄운다.
      if (!await _shouldShow(match)) return;
      if (await _start(match, state)) {
        _matchId = match.matchId;
        _lastSignature = signature;
      }
      return;
    }

    // 다른 경기로 넘어갔으면 기존 액티비티를 내리고 새로 시작한다.
    if (_matchId != match.matchId) {
      await stop();
      if (autoStart && _canStart(match, phase) && await _shouldShow(match)) {
        if (await _start(match, state)) {
          _matchId = match.matchId;
          _lastSignature = signature;
        }
      }
      return;
    }

    if (signature == _lastSignature) return;
    _lastSignature = signature;

    // 카드가 떠 있는 동안의 갱신은 서버가 APNs 로 한다. 여기서 굳이 한 번 더
    // 쏘는 건 경기 상세 화면을 보고 있을 때 반영을 앞당기는 용도다.
    // (서버는 매치 스코어를, 앱은 세트 승자 카운트를 쓰므로 값이 어긋날 수
    //  있어 매치 종료 상태는 서버에 맡기고 여기서 보내지 않는다.)
    if (phase == LiveMatchPhase.matchEnded) return;

    await _service.update(state);
  }

  /// 새로 카드를 띄워도 되는 상태인지.
  ///
  /// 세트 데이터가 LIVE 를 가리키면서, 서버의 경기 상태도 '예정'이 아니어야 한다.
  /// 세트가 LIVE 인데 matchStatus 가 아직 SCHEDULED 로 남아 있는 경기를 걸러
  /// 시작 전 카드 노출을 막는다.
  bool _canStart(ScheduleMatch match, LiveMatchPhase? phase) {
    if (phase != LiveMatchPhase.playing) return false;
    if (isScheduledStatus(match.matchStatus)) {
      debugPrint('[LiveActivity] 서버 상태가 예정이라 표시하지 않음: '
          '${match.matchId} status="${match.matchStatus}"');
      return false;
    }
    return true;
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
    // 서버 상태가 '예정'이면 세트 목록까지 받아볼 필요도 없다.
    if (isScheduledStatus(match.matchStatus)) return false;

    final (games, _) =
        await MatchDetailRepository.instance.fetchGames(matchId);
    if (!_canStart(match, resolvePhase(games))) return false;

    await sync(match: match, games: games);
    return _matchId != null;
  }

  /// 액티비티를 즉시 내린다.
  ///
  /// 매치 종료 시의 정리는 서버가 `end` + dismissal-date 로 처리하므로,
  /// 여기는 사용자가 직접 내리거나 다른 경기로 넘어갈 때만 쓴다.
  Future<void> stop() async {
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
    if (!await _service.ensurePermission()) {
      debugPrint('[LiveActivity] 지원하지 않는 플랫폼이라 표시하지 않음');
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

  /// 세트 목록에서 현재 국면을 판단한다. 아직 시작 전이면 null.
  ///
  /// 세트가 하나도 없거나 전부 `SCHEDULED` 면 경기가 시작되지 않은 것이므로
  /// null 을 돌려준다. (예전에는 이 경우도 [LiveMatchPhase.playing] 으로 봐서
  /// 시작 전 경기에 카드가 떴다.)
  @visibleForTesting
  LiveMatchPhase? resolvePhase(List<MatchGame> games) {
    if (games.any((g) => g.isLive)) return LiveMatchPhase.playing;
    if (games.isNotEmpty && games.every((g) => g.isEnded)) {
      return LiveMatchPhase.matchEnded;
    }
    // 진행 중인 세트는 없지만 끝난 세트가 있으면 세트 간 휴식.
    if (games.any((g) => g.isEnded)) return LiveMatchPhase.setEnded;
    return null;
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

  /// 서버가 내려준 [ScheduleMatch.matchStatus] 가 '아직 시작 전'을 뜻하는지.
  ///
  /// 세트 API 가 늦게 갱신되는 경우를 막는 2차 방어선이다. 값이 비어 있거나
  /// 모르는 값이면 false 를 돌려 세트 데이터 판정에 맡긴다.
  @visibleForTesting
  bool isScheduledStatus(String status) {
    final s = status.toLowerCase();
    return s.contains('schedul') ||
        s.contains('upcoming') ||
        s.contains('not_started') ||
        s.contains('notstarted') ||
        s.contains('pending') ||
        s.contains('ready') ||
        status.contains('예정') ||
        status.contains('대기');
  }

  String? _resolveWinner(ScheduleMatch match, int scoreA, int scoreB) {
    if (scoreA == scoreB) return null;
    return scoreA > scoreB ? match.teamA.teamCode : match.teamB.teamCode;
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
