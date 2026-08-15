import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/match_calendar_day.dart';
import '../../model/schedule_filter_options.dart';
import '../../model/schedule_match.dart';
import '../../util/match_status.dart';

/// 커서 페이지네이션 경기 리스트 한 페이지 결과.
class MatchPage {
  const MatchPage({
    required this.matches,
    required this.nextCursor,
    required this.hasNext,
    this.prevCursor,
    this.hasPrev = false,
  });

  final List<ScheduleMatch> matches;
  final String? nextCursor;
  final bool hasNext;

  /// 이전(과거) 방향으로 한 페이지 더 받기 위한 커서.
  ///
  /// `around` 로 오늘 앞뒤를 함께 받았거나 `before` 로 과거를 이어받은
  /// 응답에 채워진다. 더 과거가 없으면 null.
  final String? prevCursor;

  /// 위쪽(과거)에 더 받을 페이지가 있는지.
  final bool hasPrev;
}

/// 경기 일정 관련 API (`/api/mobile/schedules`).
class ScheduleRepository {
  ScheduleRepository._();
  static final ScheduleRepository instance = ScheduleRepository._();

  /// 라이브 경기가 하나라도 있는지 — 화면과 같은 [isLiveMatchStatus] 기준이다.
  /// 캐시 여부 판단에 쓴다(라이브가 있으면 캐시를 짧게 가져간다).
  bool _hasLiveMatch(List<ScheduleMatch> matches) =>
      matches.any((m) => isLiveMatchStatus(m.matchStatus));

  /// 진행 중인 캘린더 요청. 같은 조회 조건의 요청이 겹치면 결과를 나눠 쓴다.
  ///
  /// 앱 시작 시 캘린더를 부르는 곳이 셋이다 — 스플래시 프리페치,
  /// 홈 위젯 갱신([HomeWidgetService.refreshFromApi]), 그리고 일정 화면
  /// 진입. 이걸 그대로 두면 같은 응답을 세 번 받으려고 회선을 서로 뺏는다.
  /// 먼저 뜬 요청에 나머지가 올라타면 실제 왕복은 한 번으로 끝난다.
  final Map<String, Future<List<MatchCalendarDay>>> _calendarInFlight = {};

  /// 방금 받은 캘린더 응답. [_calendarCacheTtl] 동안만 유효하다.
  final Map<String, (DateTime, List<MatchCalendarDay>)> _calendarCache = {};

  /// 캐시를 신뢰하는 시간.
  ///
  /// 스플래시에서 미리 받은 응답을 곧이어 열리는 일정 화면이 재사용하는 게
  /// 목적이라 짧게 잡는다. 경기 중 스코어가 바뀌는 화면이므로 이보다 길게
  /// 두면 사용자가 옛 데이터를 보게 된다 — 월 이동·필터 변경으로 다시 들어와도
  /// 이 시간이 지났으면 새로 받는다.
  static const Duration _calendarCacheTtl = Duration(seconds: 30);

  /// 캘린더 요청 한 건이 살아 있을 수 있는 최대 시간.
  ///
  /// 백그라운드에 들어가면 OS 가 프로세스를 멈춰 소켓 타임아웃도 같이 얼어붙는다.
  /// 상한을 두지 않으면 그 요청이 영원히 진행 중으로 남아, 뒤따르는 조회가
  /// 계속 거기에 합류하며 스피너가 멈춘 채로 남는다.
  static const Duration _calendarTimeout = Duration(seconds: 15);

  /// 특정 월의 캘린더 마킹 데이터를 조회한다 (인증 불필요).
  ///
  /// 날짜별 경기 수와, 캘린더 칸 칩에 바로 쓸 대진 목록까지 한 번에 받는다.
  /// [month] 는 어느 날짜든 그 연·월만 사용된다.
  ///
  /// 같은 조건의 요청이 이미 떠 있거나 방금 끝났으면 그 결과를 재사용한다.
  /// [forceRefresh] 를 주면 캐시를 건너뛰고 새로 받는다 (당겨서 새로고침 등).
  Future<List<MatchCalendarDay>> fetchCalendar(
    DateTime month, {
    List<String> leagues = const ['LCK'],
    List<int>? teamIds,
    bool forceRefresh = false,
  }) {
    final monthStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final url = ApiConfig.mobileScheduleCalendarUrl(
      month: monthStr,
      leagues: leagues,
      teamIds: teamIds,
    );

    if (!forceRefresh) {
      final cached = _calendarCache[url];
      if (cached != null &&
          DateTime.now().difference(cached.$1) < _calendarCacheTtl) {
        debugPrint('[Schedule] calendar cache hit: $monthStr');
        return Future.value(cached.$2);
      }
      final inFlight = _calendarInFlight[url];
      if (inFlight != null) {
        debugPrint('[Schedule] calendar 요청 합류: $monthStr');
        return inFlight;
      }
    }

    final request = _fetchCalendar(url, monthStr)
        .timeout(_calendarTimeout)
        .then((days) {
      _calendarCache[url] = (DateTime.now(), days);
      return days;
    });
    // 성공·실패 무관하게 진행 중 목록에서 뺀다. 실패한 요청이 남아 있으면
    // 다음 조회가 이미 끝난 실패 future 에 합류해 계속 같은 에러만 받는다.
    // 그 사이 새 요청이 들어와 있으면(같은 url) 그 쪽을 지우지 않도록 확인한다.
    // 정리용 체인 자체의 에러는 여기서 삼킨다 — 원본 에러는 호출자가 받는다.
    unawaited(request.whenComplete(() {
      if (identical(_calendarInFlight[url], request)) {
        _calendarInFlight.remove(url);
      }
    }).catchError((_) => const <MatchCalendarDay>[]));
    _calendarInFlight[url] = request;
    return request;
  }

  Future<List<MatchCalendarDay>> _fetchCalendar(
    String url,
    String monthStr,
  ) async {
    debugPrint('[Schedule] GET $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('[Schedule] calendar ← ${response.statusCode} '
        '(${response.body.length} bytes)');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('경기 캘린더 조회 실패 (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final dates = data['dates'] as List<dynamic>? ?? const [];
    debugPrint('[Schedule] calendar dates: ${dates.length}');
    return dates
        .map((e) => MatchCalendarDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 진행 중인 날짜별 경기 요청 + 캐시. [_calendarInFlight]/[_calendarCache] 와
  /// 같은 이유 — 앱 시작 시 홈 위젯 갱신과 Live Activity 카드 정리 스캔이
  /// '오늘 경기'를 동시에 각자 부른다. 캘린더와 같은 TTL 을 쓴다.
  final Map<String, Future<List<ScheduleMatch>>> _matchesByDateInFlight = {};
  final Map<String, (DateTime, List<ScheduleMatch>)> _matchesByDateCache = {};

  /// 특정 날짜의 경기 리스트 카드를 조회한다 (인증 불필요).
  ///
  /// 같은 조건의 요청이 이미 떠 있거나 방금 끝났으면([_calendarCacheTtl] 이내)
  /// 그 결과를 재사용한다.
  Future<List<ScheduleMatch>> fetchMatchesByDate(
    DateTime date, {
    List<String> leagues = const ['LCK'],
    List<int>? teamIds,
  }) {
    final dateStr = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final url = ApiConfig.mobileSchedulesUrl(
      date: dateStr,
      leagues: leagues,
      teamIds: teamIds,
    );

    final cached = _matchesByDateCache[url];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _calendarCacheTtl) {
      debugPrint('[Schedule] day cache hit: $dateStr');
      return Future.value(cached.$2);
    }
    final inFlight = _matchesByDateInFlight[url];
    if (inFlight != null) {
      debugPrint('[Schedule] day 요청 합류: $dateStr');
      return inFlight;
    }

    final request = _fetchMatchesByDate(url, dateStr)
        .timeout(_calendarTimeout)
        .then((matches) {
      // 진행 중인 경기가 섞여 있으면 캐시하지 않는다 — 스코어가 실시간으로
      // 바뀌는데 캐시하면 재진입 시 [_calendarCacheTtl] 동안 옛 스코어를 보여준다.
      if (!_hasLiveMatch(matches)) {
        _matchesByDateCache[url] = (DateTime.now(), matches);
      }
      return matches;
    });
    unawaited(request.whenComplete(() {
      if (identical(_matchesByDateInFlight[url], request)) {
        _matchesByDateInFlight.remove(url);
      }
    }).catchError((_) => const <ScheduleMatch>[]));
    _matchesByDateInFlight[url] = request;
    return request;
  }

  Future<List<ScheduleMatch>> _fetchMatchesByDate(
    String url,
    String dateStr,
  ) async {
    final response = await http.get(Uri.parse(url));
    debugPrint('[Schedule] day $dateStr ← ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('경기 목록 조회 실패 ($dateStr, ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final matches = data['matches'] as List<dynamic>? ?? const [];
    debugPrint('[Schedule] day $dateStr matches: ${matches.length}');
    return matches
        .map((e) => ScheduleMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 진행 중인 커서 페이지 요청 + 캐시. [_calendarInFlight]/[_calendarCache] 와
  /// 같은 이유다 — 경기 리스트 화면은 진입할 때마다 ViewModel 을 새로 만들어
  /// 자체 캐시가 없다. '오늘까지 당겨오는' 첫 진입 카탄업이 페이지 10개를
  /// 순차로 받는데(커서 체인이라 병렬화 불가), 화면을 나갔다 금방 다시
  /// 들어오면 이 페이지들을 처음부터 그대로 다시 받고 있었다. 커서 체인 자체는
  /// 못 줄이지만, 같은 페이지를 다시 밟을 땐 캐시로 건너뛴다.
  final Map<String, Future<MatchPage>> _matchesInFlight = {};
  final Map<String, (DateTime, MatchPage)> _matchesCache = {};

  /// 경기 리스트를 커서 페이지 단위로 조회한다 (인증 불필요).
  ///
  /// 단일 요청으로 최신 날짜부터 [size] 개씩 받는다. 다음 페이지는 응답의
  /// `nextCursor` 를 [cursor] 로 넘겨 이어 받는다 (첫 페이지는 cursor 생략).
  ///
  /// [from] (`yyyy-MM-dd`) 을 주면 그 날짜 이후 경기만, 과거→미래 오름차순으로
  /// 받는다. '오늘 이후' 필터와, 진입 시 받은 `around` 창을 미래 방향으로
  /// 이어받을 때 쓰는 경로다.
  ///
  /// [around] (`yyyy-MM-dd`) 를 주면 그 날짜를 기준으로 과거 절반 + 미래 절반을
  /// 한 번에 받는다 — 진입 시 '오늘' 그룹에 한 번의 요청으로 닿기 위한 경로다.
  ///
  /// [before] 는 이전 응답의 `prevCursor` 를 그대로 넘겨 그보다 과거를
  /// 이어받는다 (위로 스크롤).
  ///
  /// [around] / [before] / [cursor] 는 서로 배타적이다.
  ///
  /// 같은 조건(같은 커서 포함)의 요청이 이미 떠 있거나 방금 끝났으면
  /// ([_calendarCacheTtl] 이내) 그 결과를 재사용한다.
  Future<MatchPage> fetchMatches({
    String? cursor,
    int size = 20,
    required String league,
    int? teamId,
    int? seasonYear,
    String? split,
    String? from,
    String? around,
    String? before,
  }) {
    final url = ApiConfig.matchesUrl(
      league: league,
      size: size,
      cursor: cursor,
      teamId: teamId,
      seasonYear: seasonYear,
      split: split,
      from: from,
      around: around,
      before: before,
    );

    final cached = _matchesCache[url];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _calendarCacheTtl) {
      debugPrint('[Schedule] matches cache hit');
      return Future.value(cached.$2);
    }
    final inFlight = _matchesInFlight[url];
    if (inFlight != null) {
      debugPrint('[Schedule] matches 요청 합류');
      return inFlight;
    }

    final request = _fetchMatches(url).timeout(_calendarTimeout).then((page) {
      // 진행 중인 경기가 섞여 있으면 캐시하지 않는다 — 스코어가 실시간으로
      // 바뀌는데 캐시하면 재진입 시 [_calendarCacheTtl] 동안 옛 스코어를 보여준다.
      if (!_hasLiveMatch(page.matches)) {
        _matchesCache[url] = (DateTime.now(), page);
      }
      return page;
    });
    unawaited(request.whenComplete(() {
      if (identical(_matchesInFlight[url], request)) {
        _matchesInFlight.remove(url);
      }
    }).catchError((_) {
      return const MatchPage(matches: [], nextCursor: null, hasNext: false);
    }));
    _matchesInFlight[url] = request;
    return request;
  }

  Future<MatchPage> _fetchMatches(String url) async {
    debugPrint('[Schedule] GET $url');
    final response = await http.get(Uri.parse(url));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('경기 목록 조회 실패 (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final matches = (data['matches'] as List<dynamic>? ?? const [])
        .map((e) => ScheduleMatch.fromJson(e as Map<String, dynamic>))
        .toList();
    debugPrint('[Schedule] matches ← ${response.statusCode} '
        '(${matches.length} matches)');
    return MatchPage(
      matches: matches,
      nextCursor: data['nextCursor'] as String?,
      hasNext: data['hasNext'] as bool? ?? false,
      prevCursor: data['prevCursor'] as String?,
      hasPrev: data['hasPrev'] as bool? ?? false,
    );
  }

  /// 필터 모달의 리그·팀 옵션을 조회한다 (인증 불필요).
  /// [league] 소속 팀 목록을 함께 받는다.
  Future<ScheduleFilterOptions> fetchFilterOptions({
    String league = 'LCK',
  }) async {
    final url = ApiConfig.mobileScheduleFiltersUrl(league: league);
    debugPrint('[Schedule] GET $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('[Schedule] filters ← ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('필터 옵션 조회 실패 (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ScheduleFilterOptions.fromJson(data);
  }
}
