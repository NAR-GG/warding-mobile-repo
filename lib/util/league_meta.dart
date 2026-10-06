import '../model/schedule_filter_options.dart';

/// 서버(`/mobile/schedules/filters`)가 내려준 리그 메타 — 알림 벨·아이콘.
///
/// 리그마다 알림 가능 여부·아이콘이 앱에 하드코딩돼 있으면 백엔드가 새 리그를
/// 지원해도 앱을 배포하기 전엔 사용자에게 안 보인다. 그래서 서버 값을 받아 두고
/// 쓴다. 서버가 메타를 안 주는 구버전이거나 아직 못 받았으면(첫 실행·오프라인)
/// 기존 하드코딩 값으로 폴백한다 — [fallbackAlarmLeagues] 는 그 상태에서만 쓰인다.
///
/// **여기에 리그를 추가하는 것으로 대응을 끝내지 않는다.** 서버가 정하는 게
/// 정상 경로다.
class LeagueMeta {
  LeagueMeta._();

  /// 서버 메타가 없을 때 알림 벨을 띄우는 리그.
  static const Set<String> fallbackAlarmLeagues = {
    'LCK',
    'MSI',
    'EWC',
    'KESPA',
    'ASIAN_GAMES',
    'DEMACIA_CUP',
  };

  /// 서버에서 받은 리그 목록. null 이면 아직 못 받았거나 메타 없는 서버.
  static Map<String, FilterLeague>? _server;

  /// 필터 응답을 반영한다. 메타가 없는 응답이면 무시한다(폴백 유지).
  static void update(ScheduleFilterOptions options) {
    if (!options.hasLeagueMeta) return;
    _server = {for (final l in options.leagues) l.code: l};
  }

  /// 테스트에서 상태를 되돌릴 때 쓴다.
  static void reset() => _server = null;

  /// 알림 벨을 띄우는 리그 코드 전체.
  static Set<String> get alarmLeagues {
    final server = _server;
    if (server == null) return fallbackAlarmLeagues;
    return {
      for (final l in server.values)
        if (l.alarm == true) l.code,
    };
  }

  /// [leagueInfo]('LCK', 'LCK 2026 ...' 처럼 리그 코드로 시작하는 문자열)가
  /// 알림 가능 리그인지.
  ///
  /// **부분 문자열이 아니라 첫 토큰을 정확히 비교한다.** `contains` 로 보면
  /// 코드가 다른 코드의 접두사인 리그(`LCK` vs 가상의 `LCK_CL`)에서 오탐이
  /// 난다 — 알림을 끈 리그에 벨이 뜬다. 지금 백엔드 `ALLOWED_LEAGUES` 에는
  /// 그런 쌍이 없지만, 이 목록은 서버가 늘리는 값이라(앱 배포 없이 리그가
  /// 추가되는 게 이 구조의 목적이다) 미리 막아 둔다.
  static bool alarmEnabled(String leagueInfo) {
    final code = leagueInfo.trim().toUpperCase().split(RegExp(r'\s+')).first;
    return alarmLeagues.contains(code);
  }

  /// [leagueCode] 의 서버 아이콘 URL. 없으면 null(번들 아이콘 폴백).
  static String? iconUrl(String leagueCode) =>
      _server?[leagueCode.toUpperCase()]?.iconUrl;
}
