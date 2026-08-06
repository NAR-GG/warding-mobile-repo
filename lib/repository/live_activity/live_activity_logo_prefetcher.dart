import 'package:flutter/foundation.dart';

import '../../model/schedule_filter_options.dart';
import '../schedule/schedule_repository.dart';
import 'live_activity_service.dart';

/// 서버가 만들 카드에 쓸 팀 로고를 미리 App Group 에 캐싱한다.
///
/// push-to-start 로 서버가 카드를 만들면 앱은 실행되지 않는다. 위젯 확장은
/// 렌더 시점에 네트워크를 못 쓰므로, 그 전에 앱이 디스크에 저장해 둔 파일만
/// 쓸 수 있다. 파일명은 서버와 맞춘 `<팀코드>.png` 규칙을 따른다.
///
/// 저장 위치는 `Library/Caches` 가 아닌 App Group 컨테이너라 iOS 가 임의로
/// 지우지 않는다. 그래서 한 번 받으면 앱을 지울 때까지 남는다.
class LiveActivityLogoPrefetcher {
  LiveActivityLogoPrefetcher({
    LiveActivityService? service,
    ScheduleRepository? scheduleRepository,
  })  : _service = service ?? LiveActivityService.instance,
        _schedule = scheduleRepository ?? ScheduleRepository.instance;

  final LiveActivityService _service;
  final ScheduleRepository _schedule;

  /// 앱을 켤 때 미리 받아둘 기본 리그.
  static const String defaultLeague = 'LCK';

  /// 이번 앱 실행에서 이미 처리한 팀 코드. 같은 팀을 여러 훅에서 중복으로
  /// 훑지 않도록 걸러낸다(앱 시작 → 리그 전환에서 겹치는 팀이 많다).
  ///
  /// 디스크 캐시는 실행 간에도 유지되므로 이건 채널 왕복을 아끼는 용도다.
  final Set<String> _done = {};

  /// 프리페치가 겹쳐 돌지 않게 잡는 잠금.
  ///
  /// 훅이 셋(앱 시작·리그 전환·알림 켜기)이라 동시에 불릴 수 있는데, 겹치면
  /// [_done] 에 표시되기 전의 같은 팀을 양쪽이 함께 내려받는다.
  Future<void>? _running;

  /// [teams] 의 로고를 필요한 것만 내려받아 캐싱한다.
  ///
  /// 이미 같은 URL 로 저장된 파일이 있으면 네트워크를 타지 않는다.
  /// 실패해도 조용히 넘어간다 — 로고가 없으면 위젯이 팀 코드로 폴백한다.
  Future<void> prefetch(Iterable<LogoTarget> teams) async {
    final targets = teams.toList(growable: false);
    if (targets.isEmpty) return;

    // 앞선 프리페치가 돌고 있으면 끝난 뒤에 이어서 한다.
    final previous = _running;
    final task = _prefetch(targets, after: previous);
    _running = task;
    try {
      await task;
    } finally {
      if (identical(_running, task)) _running = null;
    }
  }

  Future<void> _prefetch(
    List<LogoTarget> teams, {
    Future<void>? after,
  }) async {
    if (after != null) await after;
    if (!await _service.isSupported()) return;

    var fetched = 0;

    for (final team in teams) {
      if (team.code.isEmpty || team.imageUrl.isEmpty) continue;
      if (!_done.add(team.code)) continue;

      final fileName = '${team.code}.png';

      // 파일이 그대로 있고 URL 도 안 바뀌었으면 건너뛴다.
      if (await _service.hasLogo(fileName, url: team.imageUrl)) continue;

      final base64 = await _service.fetchLogoBase64(team.imageUrl);
      // 실패하면 다음 기회에 다시 시도하도록 처리 표시를 되돌린다.
      if (base64 == null) {
        _done.remove(team.code);
        continue;
      }

      if (await _service.cacheLogo(base64, fileName, url: team.imageUrl)) {
        fetched++;
      } else {
        _done.remove(team.code);
      }
    }

    if (fetched > 0) {
      debugPrint('[LiveActivity] 로고 프리페치 $fetched건 저장');
    }
  }

  /// 필터 응답의 팀 목록을 그대로 프리페치한다.
  ///
  /// 리그 필터를 바꿀 때 이미 받아온 응답을 재사용하는 경로다.
  Future<void> prefetchTeams(Iterable<FilterTeam> teams) {
    return prefetch([
      for (final t in teams)
        LogoTarget(code: t.teamCode, imageUrl: t.teamImageUrl),
    ]);
  }

  /// [league] 소속 팀 로고를 미리 받아둔다. 조회에 실패하면 조용히 넘어간다.
  ///
  /// 앱 시작 훅이 쓰는 경로다 — 이미 저장된 팀은 네트워크를 타지 않으므로
  /// 두 번째 실행부터는 존재 확인만 하고 끝난다.
  Future<void> prefetchLeague([String league = defaultLeague]) async {
    if (!await _service.isSupported()) return;
    try {
      final options = await _schedule.fetchFilterOptions(league: league);
      await prefetchTeams(options.teams);
    } catch (e) {
      debugPrint('[LiveActivity] 로고 프리페치용 팀 목록 조회 실패($league): $e');
    }
  }
}

/// 프리페치 대상 팀 — 코드와 로고 URL 한 쌍.
///
/// 필터·경기 카드 등 팀 정보를 들고 있는 모델이 서로 달라 최소 형태로 받는다.
class LogoTarget {
  const LogoTarget({required this.code, required this.imageUrl});

  /// 팀 코드. 파일명(`<코드>.png`)이 되므로 서버 계약과 같은 값이어야 한다.
  final String code;

  /// 팀 로고 원본 URL.
  final String imageUrl;
}

/// 앱 전역에서 하나만 쓰는 프리페처.
///
/// 처리한 팀 코드 캐시([LiveActivityLogoPrefetcher._done])를 공유해야
/// 훅마다 같은 팀을 다시 훑지 않는다.
final liveActivityLogoPrefetcher = LiveActivityLogoPrefetcher();
