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

  /// 액티비티가 붙어있는 경기 ID.
  String? _matchId;

  /// 현재 액티비티가 떠 있는지.
  bool get isRunning => _matchId != null;

  /// 경기가 진행 중이면 카드를 띄운다.
  ///
  /// 카드가 뜬 뒤의 갱신·종료는 전부 서버가 APNs 로 처리하므로, 이 메서드는
  /// '띄우기'만 한다. 앱이 같이 갱신하면 스코어 기준이 달라(서버는 매치
  /// 스코어, 앱은 세트 승자 카운트) 표시가 오락가락한다.
  ///
  /// [autoStart] 가 false 면 새로 시작하지 않는다.
  Future<void> sync({
    required ScheduleMatch match,
    required List<MatchGame> games,
    bool autoStart = true,
  }) async {
    if (!autoStart) return;
    // 이미 이 경기 카드가 떠 있으면 할 일이 없다.
    if (_matchId == match.matchId) return;
    if (!await _service.isSupported()) return;

    // 아직 시작하지 않은 경기(세트가 없거나 전부 예정)는 표시 대상이 아니다.
    final phase = resolvePhase(games);
    if (!_canStart(match, phase)) return;

    // 구독한 팀이 나오거나 알림을 켠 경기일 때만 띄운다.
    if (!await _shouldShow(match)) return;

    // 다른 경기 카드가 떠 있으면 내리고 새로 띄운다.
    if (_matchId != null) await stop();

    final setNumber = resolveSetNumber(games);
    final (scoreA, scoreB) = resolveScore(match, games);

    final state = LiveMatchActivityState(
      phase: phase!,
      setNumber: setNumber,
      scoreA: scoreA,
      scoreB: scoreB,
      statusLabel: _statusLabel(phase, setNumber),
    );

    if (await _start(match, state)) {
      _matchId = match.matchId;
      debugPrint('[LiveActivity] 카드 표시: ${match.matchId} '
          '${match.teamA.teamCode} vs ${match.teamB.teamCode} '
          'status="${match.matchStatus}" set=$setNumber');
    }
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
  /// 이미 이 컨트롤러가 띄운 카드가 있으면 아무것도 하지 않는다.
  ///
  /// 알림을 켠 경기 ID 목록을 먼저 보고, 그다음 구독 팀이 나오는 오늘 경기를
  /// 훑는다. 앞쪽이 후보가 훨씬 적어 대부분 거기서 끝난다.
  ///
  /// 띄울 경기를 하나도 못 찾으면 남아 있는 카드를 정리한다([_dismissStale]).
  Future<void> scanForLiveMatch() async {
    if (_matchId != null) return;
    if (!await _service.isSupported()) return;

    try {
      final subscribed = await _subscribedMatchIds();
      for (final matchId in subscribed ?? const <String>{}) {
        if (await _startIfLive(matchId)) return;
      }
      final todays = await _todayMatchIdsOfSubscribedTeams();
      for (final matchId in todays ?? const <String>[]) {
        if (await _startIfLive(matchId)) return;
      }

      // 조회가 실패했으면 후보를 다 보지 못한 것이라 정리하지 않는다.
      if (subscribed == null || todays == null) return;
      await _dismissStale();
    } catch (e) {
      debugPrint('[LiveActivity] 진행 중 경기 스캔 실패: $e');
    }
  }

  /// 앱이 띄운 적 없는데 잠금화면에 남아 있는 카드를 정리한다.
  ///
  /// 카드는 iOS 시스템이 들고 있어 앱을 껐다 켜도 살아남지만, 이 컨트롤러는
  /// 전역 싱글턴이라 재시작하면 [_matchId] 가 null 로 돌아온다. 그래서 앱은
  /// "내가 띄운 카드가 없다"고 보고 그 카드를 영영 건드리지 못한다.
  ///
  /// 서버는 자기가 아는 카드만 `end` 로 닫으므로, 잘못 떠서 서버에 토큰이
  /// 등록되지 않은 카드는 이 경로로만 사라진다.
  ///
  /// [scanForLiveMatch] 가 띄울 경기를 못 찾은 뒤에만 부른다 — 진행 중인
  /// 경기가 있으면 그 경로에서 이미 반환했다. 카드가 없으면 네이티브
  /// `endAll` 이 빈 목록을 돌아 아무 일도 하지 않는다.
  Future<void> _dismissStale() async {
    debugPrint('[LiveActivity] 진행 중인 경기가 없어 남은 카드를 정리');
    await _service.endAll();
  }

  /// 알림을 켠 경기 ID 목록. 조회에 실패하면 null.
  ///
  /// 경기 리스트에서 직접 신청한 것만 담긴다(팀 구독 경기는 포함되지 않는다).
  /// 빈 목록(대상 없음)과 실패를 구분해야 [_dismissStale] 이 조회 실패를
  /// '진행 중인 경기 없음'으로 오해하고 멀쩡한 카드를 내리지 않는다.
  Future<Set<String>?> _subscribedMatchIds() async {
    try {
      return await MatchSubscriptionRepository.instance.subscribedMatchIds();
    } catch (e) {
      debugPrint('[LiveActivity] 경기 구독 목록 조회 실패: $e');
      return null;
    }
  }

  /// 구독(또는 응원) 팀이 나오는 오늘 경기의 ID 목록. 조회에 실패하면 null.
  ///
  /// 경기 단위 알림을 켜지 않았어도 팀만 구독했으면 카드를 띄워야 해서
  /// 필요한 경로다.
  Future<List<String>?> _todayMatchIdsOfSubscribedTeams() async {
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
      return null;
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

  /// 떠 있는 카드를 즉시 내린다.
  ///
  /// 매치 종료 시의 정리는 서버가 `end` + dismissal-date 로 처리하므로,
  /// 여기는 다른 경기로 넘어가거나 잘못 뜬 카드를 치울 때만 쓴다.
  /// 최종 스코어를 남길 필요가 없어 상태를 새로 만들지 않고 바로 내린다.
  Future<void> stop() async {
    await _service.endAll();
    _matchId = null;
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
  ///
  /// 실제 서버(`GET /api/mobile/matches/{id}`)는 시작 전 경기에 `unstarted`
  /// 를 내려준다. 나머지 값은 서버 구현이 바뀌어도 걸리도록 함께 둔 것이다.
  @visibleForTesting
  bool isScheduledStatus(String status) {
    final s = status.toLowerCase();
    return s.contains('unstarted') ||
        s.contains('schedul') ||
        s.contains('upcoming') ||
        s.contains('not_started') ||
        s.contains('notstarted') ||
        s.contains('pending') ||
        s.contains('ready') ||
        status.contains('예정') ||
        status.contains('대기');
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
