import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'api_client.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../config/app_globals.dart';
import '../model/calendar_week_start.dart';
import '../model/match_calendar_day.dart';
import '../model/schedule_match.dart';
import '../model/team.dart';
import '../model/user_profile.dart';
import '../repository/auth/auth_service.dart';
import '../repository/onboarding/onboarding_repository.dart';
import '../repository/preference/calendar_week_start_preference_repository.dart';
import '../repository/preference/filter_preference_repository.dart';
import '../repository/preference/team_preference_repository.dart';
import '../repository/schedule/schedule_repository.dart';
import '../util/match_detail_router.dart';
import '../screens/schedule/schedule_screen.dart';
import '../util/app_image.dart';
import '../config/secure_storage.dart';

/// iOS/Android 홈 화면 위젯에 캘린더 데이터를 전달한다.
///
/// `home_widget` 패키지를 통해 UserDefaults(iOS) / SharedPreferences(Android)에
/// JSON 으로 경기 데이터를 저장하고, 위젯 갱신을 트리거한다.
class HomeWidgetService {
  HomeWidgetService._();

  /// iOS App Group ID — Runner.entitlements 와 Widget Extension 양쪽에 등록해야 한다.
  static const String _appGroupId = 'group.com.warding.app';

  /// Android 위젯 클래스 이름 (중/대).
  static const String _androidWidgetName = 'ScheduleWidgetProvider';

  /// Android 소 위젯 클래스 이름.
  static const String _androidSmallWidgetName = 'ScheduleWidgetSmallProvider';

  /// Android 대형 위젯 클래스 이름 (풀 캘린더).
  static const String _androidLargeWidgetName = 'ScheduleWidgetLargeProvider';

  /// iOS WidgetKit 이름 (소/중/대 공용 — WidgetRouter 에서 분기).
  static const String _iOSWidgetName = 'WardingScheduleWidget';

  /// 앱 시작 시 한 번 호출해 App Group 을 설정한다.
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// 현재 월의 캘린더 데이터를 위젯에 전달하고 갱신을 트리거한다.
  static Future<void> updateCalendar({
    required DateTime month,
    required Map<int, List<CalendarMatchBrief>> matchesByDay,
    List<String> leagues = const ['ALL'],
    List<int> teamIds = const [],
  }) async {
    try {
      final monthStr =
          '${month.year}-${month.month.toString().padLeft(2, '0')}';

      final daysJson = <String, dynamic>{};
      for (final entry in matchesByDay.entries) {
        daysJson[entry.key.toString()] = [
          for (final m in entry.value)
            {
              'blue': m.blueTeamCode,
              'red': m.redTeamCode,
              'display': m.displayText,
            },
        ];
      }

      final json = jsonEncode({'month': monthStr, 'days': daysJson});
      await HomeWidget.saveWidgetData<String>('calendar_data', json);

      // 오늘 경기: 상세 API(시간 포함)로 가져와서 위젯에 저장
      final now = DateTime.now();
      if (now.year == month.year && now.month == month.month) {
        final todayBriefs = matchesByDay[now.day] ?? [];
        final calendarMatchIds = todayBriefs.map((m) => m.matchId).toSet();

        if (calendarMatchIds.isNotEmpty) {
          // 캘린더와 동일한 리그/팀 필터로 상세 API 호출 (시간 정보 필요)
          // ALL이면 상세 API도 league=ALL 하나로 호출한다. KESPA 플레이-인 등
          // LCK/LEC/LPL/LTA/LCP 어디에도 속하지 않는 리그의 경기가 있어서,
          // 주요 리그만 개별 호출하면 그런 경기의 시간 정보를 못 가져온다.
          final leaguesForDetail = leagues.contains('ALL')
              ? const ['ALL']
              : leagues;
          try {
            final allMatches = <ScheduleMatch>[];
            for (final league in leaguesForDetail) {
              try {
                final matches = await ScheduleRepository.instance
                    .fetchMatchesByDate(now, leagues: [league],
                        teamIds: teamIds.isNotEmpty ? teamIds : null);
                allMatches.addAll(matches);
              } catch (_) {
                // 개별 리그 실패 무시
              }
            }
            // 캘린더에 있는 경기만 필터링 (캘린더 필터와 동기화)
            final filtered = allMatches
                .where((m) => calendarMatchIds.contains(m.matchId))
                .toList();

            if (filtered.isNotEmpty) {
              await _saveTodayDetailed(now, filtered);
            } else if (allMatches.isNotEmpty) {
              await _saveTodayDetailed(now, allMatches);
            } else {
              await _saveTodayFromCalendar(now, todayBriefs);
            }
          } catch (_) {
            await _saveTodayFromCalendar(now, todayBriefs);
          }
        } else {
          await _updateTodayMatches(leagues: leagues, teamIds: teamIds);
        }
      } else {
        await _updateTodayMatches(leagues: leagues, teamIds: teamIds);
      }

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      // 소 위젯도 갱신
      await HomeWidget.updateWidget(
        androidName: _androidSmallWidgetName,
        iOSName: _iOSWidgetName,
      );
      // 대형 위젯도 갱신
      await HomeWidget.updateWidget(
        androidName: _androidLargeWidgetName,
        iOSName: _iOSWidgetName,
      );
      debugPrint('[HomeWidget] 캘린더 위젯 갱신 완료: $monthStr');
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 위젯 갱신 실패: $e');
    }
  }

  /// 오늘 경기 리스트(시간·대진·상태)를 위젯에 전달한다.
  static Future<void> _updateTodayMatches({
    List<String> leagues = const ['ALL'],
    List<int> teamIds = const [],
  }) async {
    try {
      final now = DateTime.now();
      // ALL이면 상세 API도 league=ALL 하나로 호출한다 (updateCalendar와 동일한 이유).
      final leaguesForDetail = leagues.contains('ALL')
          ? const ['ALL']
          : leagues;
      final matches = <ScheduleMatch>[];
      for (final league in leaguesForDetail) {
        try {
          final result = await ScheduleRepository.instance
              .fetchMatchesByDate(now, leagues: [league],
                  teamIds: teamIds.isNotEmpty ? teamIds : null);
          matches.addAll(result);
        } catch (_) {
          // 개별 리그 실패 무시
        }
      }

      final todayJson = <String, dynamic>{
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'weekday': now.weekday,
        'matches': [
          for (final m in matches)
            {
              'matchId': m.matchId,
              'time': m.scheduledTime,
              'status': m.matchStatus,
              'blueCode': m.teamA.teamCode,
              'redCode': m.teamB.teamCode,
              'display': '${m.teamA.teamCode} VS ${m.teamB.teamCode}',
            },
        ],
      };

      await HomeWidget.saveWidgetData<String>(
        'today_matches',
        jsonEncode(todayJson),
      );
    } catch (e) {
      debugPrint('[HomeWidget] 오늘 경기 갱신 실패: $e');
    }
  }

  /// 상세 API 결과(시간 포함)를 위젯에 저장
  static Future<void> _saveTodayDetailed(
    DateTime now,
    List<ScheduleMatch> matches,
  ) async {
    final todayJson = <String, dynamic>{
      'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'weekday': now.weekday,
      'matches': [
        for (final m in matches)
          {
            'matchId': m.matchId,
            'time': m.scheduledTime,
            'status': m.matchStatus,
            'blueCode': m.teamA.teamCode,
            'redCode': m.teamB.teamCode,
            'display': '${m.teamA.teamCode} VS ${m.teamB.teamCode}',
          },
      ],
    };
    await HomeWidget.saveWidgetData<String>(
      'today_matches',
      jsonEncode(todayJson),
    );
    debugPrint('[HomeWidget] 오늘 경기 상세: ${matches.length}개');
    for (final m in matches) {
      debugPrint('[HomeWidget]   ${m.teamA.teamCode} VS ${m.teamB.teamCode} time="${m.scheduledTime}" status="${m.matchStatus}"');
    }
  }

  /// 캘린더 데이터에서 오늘 경기를 추출해 위젯에 저장 (fetchMatchesByDate 폴백)
  static Future<void> _saveTodayFromCalendar(
    DateTime now,
    List<CalendarMatchBrief> todayMatches,
  ) async {
    final todayJson = <String, dynamic>{
      'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'weekday': now.weekday,
      'matches': [
        for (final m in todayMatches)
          {
            'matchId': m.matchId,
            'time': '',
            'status': 'unstarted',
            'blueCode': m.blueTeamCode,
            'redCode': m.redTeamCode,
            'display': '${m.blueTeamCode} VS ${m.redTeamCode}',
          },
      ],
    };
    await HomeWidget.saveWidgetData<String>(
      'today_matches',
      jsonEncode(todayJson),
    );
    debugPrint('[HomeWidget] 오늘 경기 캘린더 폴백: ${todayMatches.length}개');
  }

  /// 필터/팀 선택 상태를 위젯에 전달한다.
  static Future<void> updateFilterState({
    required bool hasFilter,
    required bool teamSelected,
  }) async {
    try {
      await HomeWidget.saveWidgetData<bool>('has_filter', hasFilter);
      await HomeWidget.saveWidgetData<bool>('team_selected', teamSelected);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidLargeWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('[HomeWidget] 필터 상태 저장 실패: $e');
    }
  }

  /// 캘린더 시작 요일 설정을 위젯에 전달하고 갱신을 트리거한다.
  static Future<void> updateWeekStart(CalendarWeekStart value) async {
    try {
      await HomeWidget.saveWidgetData<String>('week_start', value.storageValue);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidSmallWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidLargeWidgetName,
        iOSName: _iOSWidgetName,
      );
      debugPrint('[HomeWidget] 캘린더 시작 요일 갱신: ${value.storageValue}');
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 시작 요일 갱신 실패: $e');
    }
  }

  /// 응원팀 로고를 App Group 공유 폴더에 저장하고 경로를 위젯에 전달한다.
  static Future<void> updatePreferredTeam(Team? team) async {
    if (team == null) return;
    try {
      final imageUrl = resolveImageUrl(team.imageUrl);
      if (imageUrl == null) return;

      // 이미지 다운로드
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return;

      // App Group 공유 폴더에 저장
      final dir = await HomeWidget.getWidgetData<String>('widget_dir');
      // home_widget은 앱 그룹 UserDefaults만 지원하므로
      // 이미지 URL을 문자열로 저장하고 Swift에서 다운로드하게 한다.
      await HomeWidget.saveWidgetData<String>(
        'team_image_url',
        imageUrl,
      );
      await HomeWidget.saveWidgetData<String>(
        'team_name',
        team.name,
      );
      await HomeWidget.saveWidgetData<String>(
        'team_code',
        team.code,
      );

      // 위젯 갱신 트리거 (잠금화면 포함)
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidSmallWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidLargeWidgetName,
        iOSName: _iOSWidgetName,
      );
      debugPrint('[HomeWidget] 응원팀 저장: ${team.name} (${team.code})');
    } catch (e) {
      debugPrint('[HomeWidget] 응원팀 저장 실패: $e');
    }
  }

  static const _channel = MethodChannel('com.warding.app/widget');

  /// Swift에서 MethodChannel로 전달되는 위젯 액션을 수신한다.
  static void listenWidgetActions() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') {
        final urlStr = call.arguments as String?;
        if (urlStr != null) _handleWidgetUrl(urlStr);
      }
    });
  }

  /// 스플래시가 첫 화면(로그인/홈) 분기 내비게이션을 시작하기 전에 위젯
  /// 딥링크가 도착하면, 스플래시의 자체 내비게이션과 겹쳐 화면이 두 번
  /// 열리는 것처럼 보인다(FCM 콜드 스타트 딥링크와 동일 문제).
  ///
  /// 한 번 true 가 되면 다시 false 로 돌아가지 않는다 — 앱이 살아 있는 동안
  /// 스플래시는 한 번만 지난다. 그래서 이후의 딥링크(백그라운드 복귀 등)는
  /// 이 플래그를 그대로 통과한다.
  static bool _splashReady = false;
  static String? _pendingWidgetUrl;

  /// 스플래시가 첫 화면 분기 내비게이션을 마친 직후 호출한다.
  /// 그 전에 도착해 보류해 둔 위젯 딥링크가 있으면 그 위에 push 한다.
  static void markSplashReady() {
    _splashReady = true;
    final pending = _pendingWidgetUrl;
    _pendingWidgetUrl = null;
    // 보류분은 아직 화면을 연 적이 없으므로 중복 필터를 건너뛴다. 채널이
    // 늦게 같은 URL 을 또 넘기면 그때 _lastHandledUrl 로 걸러진다.
    if (pending != null) _handleWidgetUrl(pending, skipDuplicateCheck: true);
  }

  /// 마지막으로 처리한 URL과 그 시각. 같은 딥링크가 짧은 간격으로 두 번
  /// 들어오는 걸 걸러낸다.
  ///
  /// 콜드 스타트에서는 같은 URL 이 두 경로로 온다 — 네이티브 채널이 늦게
  /// 전달한 것과, 스플래시가 [markSplashReady] 로 소비한 보류분이다. 둘 다
  /// 통과하면 같은 경기 상세가 두 장 쌓인다(Live Activity 카드 탭 증상).
  ///
  /// 사용자가 카드를 연달아 눌러 같은 화면을 다시 여는 건 막지 않도록
  /// 시간 창을 짧게 둔다.
  static String? _lastHandledUrl;
  static DateTime? _lastHandledAt;
  static const _duplicateWindow = Duration(seconds: 3);

  /// 위젯 URL 파싱 후 경기일정 화면으로 이동
  static void _handleWidgetUrl(String urlStr, {bool skipDuplicateCheck = false}) {
    debugPrint('[HomeWidget] 위젯 URL: $urlStr');
    // 콜드 스타트에서는 스플래시가 첫 화면으로 교체를 마칠 때까지 보류한다.
    //
    // navigator 유무로 판단하면 안 된다 — 스플래시도 MaterialApp 아래에 있어
    // 이 시점에 navigator 는 이미 살아 있다. 그래서 예전 조건은 콜드 스타트에서
    // 보류를 못 하고 스플래시만 있는 스택 위로 상세를 바로 push 했다. 그 뒤
    // 스플래시의 pushReplacement 가 자기 자신을 첫 화면으로 바꾸면서 상세가
    // 첫 화면 아래로 깔려, "상세로 갔다가 일정으로 튕기고 뒤로가면 스플래시"가 됐다.
    //
    // [_splashReady] 는 한 번 true 가 되면 되돌아가지 않으므로, 스플래시를
    // 지난 뒤 도착하는 딥링크(백그라운드 복귀 등)는 그대로 통과한다.
    if (!_splashReady) {
      debugPrint('[HomeWidget] 스플래시 진행 중 — 딥링크 보류: $urlStr');
      _pendingWidgetUrl = urlStr;
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;

    // Live Activity 카드 / 다이나믹 아일랜드: warding://match/{matchId}?tab=rating&set=N
    //
    // 경기 상세는 URL 문자열 기준 중복 필터를 타지 않는다. 같은 경기라도
    // 누른 위치에 따라 쿼리가 달라서(카드 본문은 tab 없음, 평점 줄은
    // ?tab=rating&set=N) 문자열로는 중복을 못 걸러내고, 반대로 사용자가 3초
    // 안에 카드 → 평점으로 옮겨 누르면 멀쩡한 탭 전환이 씹힌다.
    // 중복 방지는 [MatchDetailRouter] 가 스택 상태로 처리한다.
    if (uri.host == 'match') {
      _openMatchDetail(uri);
      return;
    }

    // 보류분과 채널 전달이 겹쳐 같은 URL 이 두 번 오면 뒤엣것은 버린다.
    final at = _lastHandledAt;
    if (!skipDuplicateCheck &&
        _lastHandledUrl == urlStr &&
        at != null &&
        DateTime.now().difference(at) < _duplicateWindow) {
      debugPrint('[HomeWidget] 같은 딥링크가 중복 도착해 무시: $urlStr');
      return;
    }
    _lastHandledUrl = urlStr;
    _lastHandledAt = DateTime.now();

    final action = uri.path.replaceAll('/', '');

    // home 액션: 앱만 열기 (메인 페이지)
    if (action == 'home') return;

    final year = int.tryParse(uri.queryParameters['year'] ?? '');
    final month = int.tryParse(uri.queryParameters['month'] ?? '');

    // prev/next: 위젯에 표시된 월 기준으로 이동할 타겟 월 계산
    DateTime? targetMonth;
    if (year != null && month != null) {
      if (action == 'prev') {
        targetMonth = DateTime(year, month - 1);
      } else if (action == 'next') {
        targetMonth = DateTime(year, month + 1);
      } else {
        targetMonth = DateTime(year, month);
      }
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => ScheduleScreen(
          widgetAction: action == 'prev' || action == 'next' ? null : action,
          initialMonth: targetMonth,
        ),
      ),
    );
  }

  /// Live Activity 딥링크로 경기 상세를 연다.
  ///
  /// `warding://match/{matchId}?tab=rating&set=N`
  /// - `tab=rating` 이면 선수 평점 탭(인덱스 2)으로, 없으면 기본 탭으로 연다.
  /// - `set` 이 있으면 해당 세트를 선택한 상태로 진입한다.
  static void _openMatchDetail(Uri uri) {
    final matchId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    debugPrint('[LiveActivity] 딥링크 수신: $uri (matchId=$matchId)');
    if (matchId.isEmpty) return;

    final tab = uri.queryParameters['tab'];
    final tabIndex = switch (tab) {
      'rating' => 2,
      'event' => 1,
      _ => 0,
    };
    final set = int.tryParse(uri.queryParameters['set'] ?? '');

    // 같은 경기 상세가 이미 떠 있으면 새로 쌓지 않고 탭·세트만 갈아끼운다.
    MatchDetailRouter.open(
      matchId: matchId,
      tabIndex: tabIndex,
      setNumber: set,
    );
  }

  /// 백그라운드에서 최신 데이터를 가져와 위젯을 갱신한다.
  /// 캘린더 + 응원팀 + 오늘 경기를 한 번에 갱신한다.
  static Future<void> refreshFromApi() async {
    // 저장된 필터를 먼저 읽어서 캘린더/오늘경기에 적용
    List<String> leagues = const ['ALL'];
    List<int> teamIds = const [];
    bool teamSelected = false;

    try {
      final saved = await FilterPreferenceRepository.instance
          .load(FilterPreferenceRepository.scheduleKey);
      if (saved != null) {
        leagues = (saved['leagues'] as List?)?.cast<String>() ?? ['ALL'];
        teamIds = (saved['teamIds'] as List?)?.cast<int>() ?? [];
        teamSelected = (saved['teamSelected'] as bool?) ?? false;
      }
    } catch (e) {
      debugPrint('[HomeWidget] 필터 복원 실패: $e');
    }

    try {
      final now = DateTime.now();
      final leagueParam = leagues.contains('ALL') ? const ['LCK'] : leagues;
      final days = await ScheduleRepository.instance.fetchCalendar(
        now,
        leagues: leagueParam,
        teamIds: teamIds.isNotEmpty ? teamIds : null,
      );
      final matchesByDay = <int, List<CalendarMatchBrief>>{
        for (final day in days) day.date.day: day.matches,
      };
      await updateCalendar(
        month: now,
        matchesByDay: matchesByDay,
        leagues: leagues,
        teamIds: teamIds,
      );
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 갱신 실패: $e');
    }

    // 필터 상태를 위젯에 전달
    try {
      final hasFilter =
          !(leagues.length == 1 && leagues.first == 'ALL') ||
          teamIds.isNotEmpty;
      await updateFilterState(
        hasFilter: hasFilter,
        teamSelected: teamSelected,
      );
    } catch (e) {
      debugPrint('[HomeWidget] 필터 상태 갱신 실패: $e');
    }

    // 응원팀 정보도 위젯에 전달
    try {
      final team = await _loadPreferredTeamForWidget();
      await updatePreferredTeam(team);
    } catch (e) {
      debugPrint('[HomeWidget] 응원팀 갱신 실패: $e');
    }

    // 캘린더 시작 요일 로컬 설정을 위젯에도 동기화한다 (재설치 등으로
    // 공유 저장소와 로컬 저장소가 어긋나는 경우 대비 — 앱 시작마다 맞춘다).
    try {
      final weekStart = await CalendarWeekStartPreferenceRepository.instance.load();
      await updateWeekStart(weekStart);
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 시작 요일 동기화 실패: $e');
    }
  }

  /// 위젯 갱신 경로 전용 회원 조회 — 토큰 재발급을 시도하지 않는다.
  ///
  /// 홈위젯 백그라운드 콜백은 별도 아이솔레이트에서 돌아 앱 프로세스와
  /// 메모리를 공유하지 않으므로, [AuthService] 의 재발급 단일화
  /// (single-flight) 락이 여기까지 미치지 않는다. 여기서 재발급하면
  /// 포그라운드 앱의 재발급과 경쟁해 토큰이 꼬일 수 있다.
  ///
  /// 그래서 저장된 Access Token 을 그대로 쓰고, 401 등 실패면 null 을
  /// 반환해 이번 위젯 갱신만 조용히 건너뛴다(위젯은 이전 데이터 유지).
  /// 위젯 경로에서는 절대 재발급·로그아웃하지 않는다.
  static Future<UserProfile?> _fetchMeWithoutRefresh() async {
    final String? token;
    try {
      token = await AuthService.instance.jwt;
    } on SecureStorageUnavailableException {
      // 위젯 갱신은 기기 잠금 중에도 돈다 — 못 읽으면 이번 갱신만 건너뛴다.
      debugPrint('[HomeWidget] 토큰 읽기 불가 — 이번 갱신 건너뜀');
      return null;
    }
    if (token == null || token.isEmpty) return null;
    final response = await http.get(
      Uri.parse(ApiConfig.meUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
          '[HomeWidget] 회원 조회 실패 (${response.statusCode}) — 이번 갱신 건너뜀');
      return null;
    }
    return UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 로그인 회원은 서버 `favoriteTeamId` 기준, 실패(비로그인 등) 시 로컬 캐시로
  /// 폴백해 선호 팀을 읽는다. [refreshFromApi]와 백그라운드 팀 필터 토글이 공유한다.
  ///
  /// 서버 조회는 [_fetchMeWithoutRefresh] 를 쓴다 — 위젯 아이솔레이트에서
  /// 토큰 재발급을 시도하면 안 되기 때문이다 (해당 메서드 주석 참고).
  static Future<Team?> _loadPreferredTeamForWidget() async {
    try {
      final me = await _fetchMeWithoutRefresh();
      if (me != null) {
        if (me.favoriteTeamId != null) {
          final teams = await OnboardingRepository.instance.fetchTeams();
          for (final t in teams) {
            if (t.id == me.favoriteTeamId) return t;
          }
        }
        // 로그인 상태인데 응원팀 미설정 — 로컬 캐시로 덮지 않는다.
        return null;
      }
    } catch (_) {
      // 네트워크 오류 등 — 아래 로컬 캐시 폴백으로.
    }
    // 비로그인·토큰 만료(401)·조회 실패 → 로컬 캐시 폴백.
    try {
      return await TeamPreferenceRepository.instance.loadPreferredTeam();
    } on PlatformException {
      // 잠금 상태 백그라운드 갱신 중 Keychain 접근 불가(-25308) —
      // 이번 위젯 갱신에서만 응원팀을 건너뛴다.
      return null;
    }
  }

  /// 위젯에 마지막으로 저장된 캘린더 데이터의 월(연/월)을 읽는다.
  /// 저장값이 없거나 파싱 실패 시 현재 실제 월로 폴백한다.
  static Future<DateTime> _currentDisplayedMonth() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('calendar_data');
      if (raw != null) {
        final monthStr =
            (jsonDecode(raw) as Map<String, dynamic>)['month'] as String?;
        if (monthStr != null) {
          final parts = monthStr.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]));
        }
      }
    } catch (_) {
      // 파싱 실패 시 아래 폴백으로.
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// [month]를 [hasFilter]/[teamSelected] 상태에 맞춰 다시 조회하고
  /// 위젯(캘린더 + 필터 상태)을 갱신한다.
  ///
  /// 리그 필터는 `FilterPreferenceRepository`에 저장된 마지막 조합을 쓰되,
  /// [hasFilter]가 false면 'ALL'로 되돌린다. 팀 필터는 [teamSelected]가
  /// true일 때만 선호 팀 ID를 추가로 합친다. 앱의 실제 저장 필터
  /// (`FilterPreferenceRepository`)는 읽기만 하고 쓰지 않는다 — 위젯 토글은
  /// 위젯에만 적용되는 임시 상태다.
  static Future<void> _refetchAndUpdate({
    required DateTime month,
    required bool hasFilter,
    required bool teamSelected,
  }) async {
    List<String> savedLeagues = const ['ALL'];
    List<int> savedTeamIds = const [];
    try {
      final saved = await FilterPreferenceRepository.instance
          .load(FilterPreferenceRepository.scheduleKey);
      if (saved != null) {
        savedLeagues =
            (saved['leagues'] as List?)?.cast<String>() ?? const ['ALL'];
        savedTeamIds = (saved['teamIds'] as List?)?.cast<int>() ?? const [];
      }
    } catch (e) {
      debugPrint('[HomeWidget] 저장된 필터 복원 실패: $e');
    }

    final leagues = hasFilter ? savedLeagues : const ['ALL'];
    var teamIds = hasFilter ? savedTeamIds : const <int>[];
    if (teamSelected) {
      final team = await _loadPreferredTeamForWidget();
      if (team != null) {
        teamIds = {...teamIds, team.id}.toList();
      }
    }

    final leagueParam = leagues.contains('ALL') ? const ['LCK'] : leagues;
    final days = await ScheduleRepository.instance.fetchCalendar(
      month,
      leagues: leagueParam,
      teamIds: teamIds.isNotEmpty ? teamIds : null,
    );
    final matchesByDay = <int, List<CalendarMatchBrief>>{
      for (final day in days) day.date.day: day.matches,
    };

    await updateCalendar(
      month: month,
      matchesByDay: matchesByDay,
      leagues: leagues,
      teamIds: teamIds,
    );
    await updateFilterState(hasFilter: hasFilter, teamSelected: teamSelected);
  }

  static Future<void> _handleMonthShift(int delta) async {
    final current = await _currentDisplayedMonth();
    final target = DateTime(current.year, current.month + delta);
    final hasFilter = await HomeWidget.getWidgetData<bool>(
          'has_filter',
          defaultValue: false,
        ) ??
        false;
    final teamSelected = await HomeWidget.getWidgetData<bool>(
          'team_selected',
          defaultValue: false,
        ) ??
        false;
    await _refetchAndUpdate(
      month: target,
      hasFilter: hasFilter,
      teamSelected: teamSelected,
    );
  }

  static Future<void> _handleFilterToggle() async {
    final hasFilter = await HomeWidget.getWidgetData<bool>(
          'has_filter',
          defaultValue: false,
        ) ??
        false;
    final teamSelected = await HomeWidget.getWidgetData<bool>(
          'team_selected',
          defaultValue: false,
        ) ??
        false;
    final month = await _currentDisplayedMonth();
    await _refetchAndUpdate(
      month: month,
      hasFilter: !hasFilter,
      teamSelected: teamSelected,
    );
  }

  static Future<void> _handleTeamToggle() async {
    final hasFilter = await HomeWidget.getWidgetData<bool>(
          'has_filter',
          defaultValue: false,
        ) ??
        false;
    final teamSelected = await HomeWidget.getWidgetData<bool>(
          'team_selected',
          defaultValue: false,
        ) ??
        false;
    final month = await _currentDisplayedMonth();
    await _refetchAndUpdate(
      month: month,
      hasFilter: hasFilter,
      teamSelected: !teamSelected,
    );
  }

  /// 위젯 백그라운드 인터랙션 진입점.
  ///
  /// `main.dart`의 `registerInteractivityCallback` 콜백에서 호출된다.
  /// 앱 UI를 열지 않고 URI(`warding://widget/{prev,next,filter,team}`,
  /// 주기 자동 갱신은 `/refresh`)에 따라 위젯만 갱신한다.
  static Future<void> handleBackgroundWidgetAction(Uri? uri) async {
    final action = uri?.path.replaceAll('/', '') ?? 'refresh';
    try {
      switch (action) {
        case 'prev':
          await _handleMonthShift(-1);
          break;
        case 'next':
          await _handleMonthShift(1);
          break;
        case 'filter':
          await _handleFilterToggle();
          break;
        case 'team':
          await _handleTeamToggle();
          break;
        default:
          await refreshFromApi();
      }
    } catch (e) {
      debugPrint('[HomeWidget] 백그라운드 액션 처리 실패($action): $e');
    }
  }
}
