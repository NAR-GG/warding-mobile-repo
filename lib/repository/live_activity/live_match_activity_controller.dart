import 'package:flutter/foundation.dart';

import '../../model/team_notification_subscription.dart';
import '../match/match_detail_repository.dart';
import '../match/match_subscription_repository.dart';
import '../schedule/schedule_repository.dart';
import '../subscription/subscription_repository.dart';
import 'live_activity_service.dart';

/// 잠금화면에 잘못 남은 Live Activity 카드를 정리하는 컨트롤러.
///
/// 카드의 생성·갱신·종료는 서버가 APNs(push-to-start + update 토큰)로 직접
/// 처리한다. 앱은 더 이상 카드를 띄우지 않는다 — 토큰 등록에 JWT 가 필요해
/// 비회원 카드는 서버가 갱신하지 못하고 고착되기만 하므로, 비회원(과 그에
/// 의존하던 iOS 17.2 미만)의 로컬 표시 경로는 지원을 접었다(2026-08).
///
/// 서버 정리(스윕)는 update 토큰이 등록된 카드만 닫을 수 있다. 토큰 등록에
/// 실패한 채 떠 있는 카드(백그라운드 wake 실패, JWT 만료 등)는 이 경로로만
/// 사라진다.
class LiveMatchActivityController {
  LiveMatchActivityController({LiveActivityService? service})
      : _service = service ?? LiveActivityService.instance;

  final LiveActivityService _service;

  /// 진행 중인 구독 경기가 없는데 카드가 남아 있으면 정리한다.
  ///
  /// 앱 시작·포그라운드 복귀 시 호출한다. 진행 중(세트 간 휴식 포함)인
  /// 경기가 하나라도 있으면 그 카드는 서버가 관리하므로 건드리지 않는다.
  ///
  /// 알림을 켠 경기 ID 목록을 먼저 보고, 그다음 구독 팀이 나오는 경기(오늘·어제)를
  /// 훑는다. 앞쪽이 후보가 훨씬 적어 대부분 거기서 끝난다.
  Future<void> dismissStaleCards() async {
    if (!await _service.isSupported()) return;

    try {
      // 경기 단위 구독은 인증이 필요해 비회원·로그인 전에는 조회가 실패한다.
      // 그때는 후보가 없는 것으로 보고 팀 구독 경로만 본다.
      final subscribedIds = await _subscribedMatchIds() ?? const <String>{};
      if (await _anyOngoing(subscribedIds)) return;

      // 날짜별 경기 목록은 인증이 필요 없다. 이쪽 조회까지 실패했다면 후보를
      // 다 보지 못한 것이라, 진행 중인 카드를 잘못 내리지 않도록 멈춘다.
      final todays = await _todayMatchIdsOfSubscribedTeams();
      if (todays == null) return;
      // 알림 구독 경기와 겹치는 건 1단계에서 이미 확인했으니 다시 묻지 않는다.
      final remaining = todays.where((id) => !subscribedIds.contains(id));
      if (await _anyOngoing(remaining)) return;

      debugPrint('[LiveActivity] 진행 중인 경기가 없어 남은 카드를 정리');
      await _service.endAll();
    } catch (e) {
      debugPrint('[LiveActivity] 카드 정리 스캔 실패: $e');
    }
  }

  /// [matchIds] 중 하나라도 아직 카드를 유지해야 하는 상태인지, 병렬로 확인한다.
  ///
  /// 예전엔 순차 `for`-루프로 하나씩 물어봐서 경기가 많은 날은(최근 실측
  /// 20개 기준 약 6초) 앱을 열 때마다 매치 상세·세트 API가 줄줄이 걸렸다.
  /// 동시에 쏘고 기다리는 시간을 가장 느린 응답 하나로 줄인다.
  Future<bool> _anyOngoing(Iterable<String> matchIds) async {
    if (matchIds.isEmpty) return false;
    final ongoing = await Future.wait(matchIds.map(_isOngoing));
    return ongoing.any((v) => v);
  }

  /// 해당 경기가 아직 카드를 유지해야 하는 상태인지. 서버 `matchStatus` 하나만 본다.
  ///
  /// 예전엔 세트 목록(`/matches/{id}/games`)에서 국면을 추론했는데, 그 API 는 아직
  /// 치르지 않은 세트를 아예 내려주지 않는다 — 세트 상태는 라이브 스토어의 gameId 로
  /// 만들어지고 시작 전 세트는 gameId 가 없다. 그래서 **세트 사이에는 목록이 항상
  /// "전부 ENDED"** 였고, 경기 종료로 오판해 진행 중인 경기의 카드를 [endAll] 로
  /// 즉시 지웠다(실측: bo3 2:0 으로 끝난 경기 응답이 2세트뿐, SCHEDULED 세트는
  /// 애초에 존재하지 않는다 → `setEnded` 분기는 도달 불가였다).
  ///
  /// 서버 상태가 늦게 `completed` 로 바뀌면 카드가 조금 더 남는다. 그건 서버의 매치
  /// 종료 푸시와 orphan 스윕(5분)이 만회한다. 반대로 잘못 지우면 앱이 해제를 서버에
  /// 알리지 않으므로 서버는 카드가 살아있다고 믿고 그 경기 내내 재생성하지 못한다 —
  /// 늦게 닫는 건 만회되고 잘못 닫는 건 복구 불가라, 의심스러우면 두는 쪽이 싸다.
  Future<bool> _isOngoing(String matchId) async {
    final match = await MatchDetailRepository.instance.fetchMatch(matchId);
    if (match == null) return false;
    return !isScheduledStatus(match.matchStatus) &&
        !isFinishedStatus(match.matchStatus);
  }

  /// 알림을 켠 경기 ID 목록. 조회에 실패하면 null.
  ///
  /// 경기 리스트에서 직접 신청한 것만 담긴다(팀 구독 경기는 포함되지 않는다).
  /// 빈 목록(대상 없음)과 실패를 구분해야 조회 실패를 '진행 중인 경기
  /// 없음'으로 오해하고 멀쩡한 카드를 내리지 않는다.
  Future<Set<String>?> _subscribedMatchIds() async {
    try {
      return await MatchSubscriptionRepository.instance.subscribedMatchIds();
    } catch (e) {
      debugPrint('[LiveActivity] 경기 구독 목록 조회 실패: $e');
      return null;
    }
  }

  /// 구독(또는 응원) 팀이 나오는 경기의 ID 목록(오늘 + 어제). 조회에 실패하면 null.
  ///
  /// 어제까지 보는 이유: 자정을 넘긴 경기(늦게 시작한 장기 bo5)는 오늘 목록에 없어서
  /// 후보에서 빠지고, 그러면 "진행 중인 경기 없음" 으로 판정돼 살아있는 카드를 지웠다.
  Future<List<String>?> _todayMatchIdsOfSubscribedTeams() async {
    final codes = {
      for (final s in await _loadTeamSubs())
        if (s.subscribed || s.favoriteTeam) s.teamCode,
    };
    if (codes.isEmpty) return const [];

    try {
      final now = DateTime.now();
      final days = await Future.wait([
        ScheduleRepository.instance.fetchMatchesByDate(now, leagues: const ['ALL']),
        ScheduleRepository.instance.fetchMatchesByDate(
            now.subtract(const Duration(days: 1)),
            leagues: const ['ALL']),
      ]);
      return [
        for (final matches in days)
          for (final m in matches)
            if (codes.contains(m.teamA.teamCode) ||
                codes.contains(m.teamB.teamCode))
              m.matchId,
      ];
    } catch (e) {
      debugPrint('[LiveActivity] 경기 목록 조회 실패: $e');
      return null;
    }
  }

  /// 팀 알림 구독 목록 캐시. 매 스캔마다 API 를 때리지 않도록 짧게 재사용한다.
  List<TeamNotificationSubscription>? _teamSubs;
  DateTime? _teamSubsAt;
  static const _teamSubsTtl = Duration(minutes: 10);

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

  /// 서버가 내려준 matchStatus 가 '아직 시작 전'을 뜻하는지.
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

  /// 서버가 내려준 matchStatus 가 '경기 종료'를 뜻하는지.
  ///
  /// 실제 서버는 `completed` 를 내려준다. 나머지 값은 서버 구현이 바뀌어도 걸리도록
  /// 함께 둔 것이다. 모르는 값이면 false — 진행 중으로 보고 카드를 남긴다.
  @visibleForTesting
  bool isFinishedStatus(String status) {
    final s = status.toLowerCase();
    return s.contains('complet') ||
        s.contains('finish') ||
        s.contains('ended') ||
        status.contains('종료') ||
        status.contains('완료');
  }
}

/// 앱 전역에서 하나만 쓰는 컨트롤러 인스턴스.
final liveMatchActivityController = LiveMatchActivityController();
