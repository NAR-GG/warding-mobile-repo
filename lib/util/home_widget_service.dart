import 'dart:async';
import 'dart:convert';

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

      // iOS 위젯이 앱 없이 오늘 경기를 직접 받아올 때 같은 필터를 쓰도록
      // 공유 저장소에 남긴다 (ios/Shared/TodayMatchesFetcher.swift).
      await _saveWidgetFilters(leagues: leagues, teamIds: teamIds);

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
            // 리그별 조회는 서로 의존하지 않는다. 순서대로 기다리면 선택한
            // 리그 수만큼 왕복이 직렬로 쌓인다 — 함께 띄운다.
            // 개별 리그 실패는 빈 목록으로 접어 기존 동작을 유지한다.
            final perLeague = await Future.wait([
              for (final league in leaguesForDetail)
                ScheduleRepository.instance
                    .fetchMatchesByDate(now, leagues: [league],
                        teamIds: teamIds.isNotEmpty ? teamIds : null)
                    .catchError((_) => <ScheduleMatch>[]),
            ]);
            for (final matches in perLeague) {
              allMatches.addAll(matches);
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

  /// 위젯이 스스로 조회할 때 쓸 리그·팀 필터를 공유 저장소에 남긴다.
  ///
  /// iOS 위젯은 앱을 거치지 않고 직접 오늘 경기를 받아오는데
  /// (`ios/Shared/TodayMatchesFetcher.swift`), 그때 앱 화면과 같은 필터를 써야
  /// 위젯만 다른 경기를 보여주는 일이 없다.
  ///
  /// 온보딩 직후처럼 캘린더 갱신([updateCalendar])이 아직 한 번도 안 돈
  /// 상태에서도 필터가 남아 있도록, 응원팀이 정해지는 지점에서도 부른다
  /// ([updatePreferredTeam]).
  ///
  /// `home_widget` 은 문자열·숫자·불린만 저장하므로 JSON 문자열로 넣는다.
  static Future<void> _saveWidgetFilters({
    required List<String> leagues,
    required List<int> teamIds,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'widget_leagues',
        jsonEncode(leagues),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_team_ids',
        jsonEncode(teamIds),
      );
    } catch (e) {
      debugPrint('[HomeWidget] 위젯 필터 저장 실패: $e');
    }
  }

  /// 오늘 경기 리스트(시간·대진·상태)를 위젯에 전달한다.
  ///
  /// 조회에 실패해도 오늘 날짜로 빈 목록을 저장한다. 그냥 리턴하면 어제
  /// 저장분이 남는데, 위젯은 저장된 `date` 로 오늘 것인지를 판정하므로
  /// (Android `ScheduleWidgetProvider.loadTodayData`) 갱신이 계속 실패하는 동안
  /// "불러오는 중"에서 벗어나지 못한다.
  static Future<void> _updateTodayMatches({
    List<String> leagues = const ['ALL'],
    List<int> teamIds = const [],
  }) async {
    final now = DateTime.now();
    try {
      // ALL이면 상세 API도 league=ALL 하나로 호출한다 (updateCalendar와 동일한 이유).
      final leaguesForDetail = leagues.contains('ALL')
          ? const ['ALL']
          : leagues;
      // 리그별 조회는 서로 의존하지 않으므로 함께 띄운다(위 경로와 동일).
      // 개별 리그 실패는 빈 목록으로 접는다.
      final matches = <ScheduleMatch>[];
      final perLeague = await Future.wait([
        for (final league in leaguesForDetail)
          ScheduleRepository.instance
              .fetchMatchesByDate(now, leagues: [league],
                  teamIds: teamIds.isNotEmpty ? teamIds : null)
              .catchError((_) => <ScheduleMatch>[]),
      ]);
      for (final result in perLeague) {
        matches.addAll(result);
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
      await _saveTodayFromCalendar(now, const []);
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

      // 주소가 살아 있는지만 확인한다. 실제로 그리는 것은 Swift 쪽이라
      // 여기서 받은 바이트는 쓰이지 않으므로, 본문을 안 싣는 HEAD 로 묻는다
      // (GET 이면 응원팀을 바꿀 때마다 로고를 통째로 받고 버리게 된다).
      // HEAD 를 막아 둔 서버도 있어 405·501 이면 통과시킨다 — 주소가 틀린
      // 것과는 다른 응답이다.
      final response = await http.head(Uri.parse(imageUrl));
      const headNotAllowed = {405, 501};
      if (response.statusCode != 200 &&
          !headNotAllowed.contains(response.statusCode)) {
        return;
      }

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
      // 응원팀 ID 도 남긴다 — iOS 위젯이 앱 없이 조회할 때 팀 필터가 켜져
      // 있으면(`team_selected`) 이 값을 쓴다. 온보딩 직후처럼 캘린더 갱신이
      // 아직 안 돈 상태에서도 팀을 알 수 있어야 한다.
      //
      // `widget_team_ids`(실제 적용 필터)와는 다른 키다. 응원팀을 정해 둔 것과
      // 팀 필터를 켠 것은 별개라, 여기서 적용 필터까지 건드리면 필터를 켠 적
      // 없는 사용자에게 팀 경기만 보여주게 된다.
      await HomeWidget.saveWidgetData<int>(
        'preferred_team_id',
        team.id,
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

  /// 위젯 버튼이 공유 저장소에 남긴 요청을 읽어 처리한다.
  ///
  /// 안드로이드 필터 버튼은 딥링크 대신 이 경로를 쓴다 — 앱을 여는 인텐트를
  /// 캘린더와 똑같이 두어 태스크 재사용 동작을 맞추기 위해서다
  /// (`WidgetActionReceiver` 주석 참고).
  static Future<void> consumePendingAction() async {
    try {
      final action =
          await HomeWidget.getWidgetData<String>('pending_widget_action');
      if (action == null || action.isEmpty) return;
      await HomeWidget.saveWidgetData<String>('pending_widget_action', '');
      if (action == 'filter') {
        debugPrint('[HomeWidget] 위젯 요청 처리: $action');
        _handleWidgetUrl('warding://widget/filter', skipDuplicateCheck: true);
      }
    } catch (e) {
      debugPrint('[HomeWidget] 위젯 요청 확인 실패: $e');
    }
  }

  /// 스플래시가 첫 화면 분기 내비게이션을 마친 직후 호출한다.
  /// 그 전에 도착해 보류해 둔 위젯 딥링크가 있으면 그 위에 push 한다.
  static void markSplashReady() {
    _splashReady = true;
    _justPassedSplash = true;
    final pending = _pendingWidgetUrl;
    _pendingWidgetUrl = null;
    // 보류분은 아직 화면을 연 적이 없으므로 중복 필터를 건너뛴다. 채널이
    // 늦게 같은 URL 을 또 넘기면 그때 _lastHandledUrl 로 걸러진다.
    if (pending != null) _handleWidgetUrl(pending, skipDuplicateCheck: true);
    // 위젯 버튼이 저장소에 남긴 요청(안드로이드 필터 버튼)도 함께 소비한다.
    unawaited(consumePendingAction());
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

  /// 스플래시를 막 지난 직후인지. 콜드 스타트에서 같은 딥링크가 두 경로로
  /// 도착하는 구간에서만 true 이고, 한 번 딥링크를 처리하면 내려간다.
  /// 중복 필터를 이 구간으로 한정해, 앱이 떠 있는 동안의 재클릭은 통과시킨다.
  static bool _justPassedSplash = false;

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
    // [_splashReady] 는 static 이라 프로세스가 살아 있는 동안 유지된다. 그런데
    // 위젯 백그라운드 갱신은 UI 없는 엔진에서 도는데, 그 엔진도 main() 을 거쳐
    // 스플래시를 지나므로 플래그가 true 가 되어 버린다. 그 상태에서 딥링크가
    // 통과하면 Navigator 에 실제 화면이 없어 아무 데도 못 간다(필터가 열리지
    // 않던 원인). 화면이 실제로 붙어 있는지도 함께 본다.
    if (!_splashReady || navigatorKey.currentState?.mounted != true) {
      debugPrint('[HomeWidget] 화면 준비 전 — 딥링크 보류: $urlStr');
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
    //
    // 단, 이 중복은 콜드 스타트에서만 생긴다 — 채널이 늦게 전달한 것과
    // 스플래시가 [markSplashReady] 로 소비한 보류분이 겹치는 경우다. 앱이 이미
    // 떠 있는 상태에서 같은 URL 이 또 오는 건 사용자가 위젯 버튼을 다시 누른
    // 것이므로 막으면 안 된다.
    final at = _lastHandledAt;
    final isColdStartWindow = at != null &&
        DateTime.now().difference(at) < _duplicateWindow;
    if (!skipDuplicateCheck &&
        _justPassedSplash &&
        _lastHandledUrl == urlStr &&
        isColdStartWindow) {
      debugPrint('[HomeWidget] 같은 딥링크가 중복 도착해 무시: $urlStr');
      return;
    }
    _lastHandledUrl = urlStr;
    _lastHandledAt = DateTime.now();
    // [_justPassedSplash] 는 여기서 내리지 않는다 — 보류분을 처리한 직후에
    // 채널이 같은 URL 을 또 넘기는 것이 바로 걸러야 할 중복이다. 여기서 내리면
    // 그 두 번째가 새 클릭으로 통과해, 첫 번째가 연 필터 위에 모달 없는 일정
    // 화면이 다시 얹힌다. 플래그는 중복 창이 지나면 [isColdStartWindow] 가
    // false 가 되면서 자연히 무력화된다.

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

    // 필터는 일정 화면이 이미 보이면 화면을 새로 만들지 않고 열라고 알리기만
    // 한다. 라우트를 갈아끼우면 그 전환 도중에 모달을 열게 되어 모달이 곧바로
    // 함께 걷힌다.
    //
    // 문제는 '보이지 않는' 경우다 — 경기 리스트 등 **다른 하단 탭**에 있으면
    // 일정 화면 자체가 스택에 없어 [openScheduleFilterIfVisible] 이 false 를
    // 돌려주는데, 예전엔 여기서 그냥 return 해 버려서 아무 일도 안 일어났다
    // (요청은 [_filterRequestedBeforeReady] 로 남지만, 그걸 소비할 새
    // ScheduleScreen 이 만들어질 계기 자체가 없다 — 하단 탭은 스택에 없던
    // 화면을 되살리지 않는다). 이때는 아래 prev/next 와 같은 경로로 일정
    // 화면을 만들어야 하고, 그 화면의 initState 가 남겨진 요청을 소비해
    // 필터를 연다.
    if (action == 'filter' && openScheduleFilterIfVisible()) {
      return;
    }

    final route = MaterialPageRoute(
      builder: (_) => ScheduleScreen(initialMonth: targetMonth),
    );

    // 일정 화면이 스택에 없을 때만 새로 만든다. 첫 화면이면 교체하고,
    // 아니면 그 위에 얹는다.
    if (nav.canPop()) {
      nav.push(route);
    } else {
      nav.pushReplacement(route);
    }
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
      final json = saved.json;
      if (json != null) {
        leagues = (json['leagues'] as List?)?.cast<String>() ?? ['ALL'];
        teamIds = (json['teamIds'] as List?)?.cast<int>() ?? [];
        teamSelected = (json['teamSelected'] as bool?) ?? false;
      }
    } catch (e) {
      debugPrint('[HomeWidget] 필터 복원 실패: $e');
    }

    try {
      // 위젯이 보고 있는 달을 유지한다.
      //
      // 예전에는 무조건 DateTime.now() 로 받아 덮었는데, 그러면 위젯에서
      // prev/next 로 다른 달을 보다가 앱을 켜는 순간 이번 달로 되돌아갔다
      // (위젯의 월 이동은 앱을 열지 않고 위젯만 갱신하므로, 앱 시작 시 도는
      // 이 갱신이 그 상태를 지워 버렸다).
      final month = await _currentDisplayedMonth();
      // 저장된 필터를 그대로 보낸다('ALL' → 'LCK' 치환 제거). 스플래시가 미리
      // 받아 둔 것과 같은 주소가 되므로 앱을 켤 때 캘린더를 두 번 받지도 않는다.
      final days = await ScheduleRepository.instance.fetchCalendar(
        month,
        leagues: leagues,
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
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 갱신 실패: $e');
      // 캘린더를 못 받아도 오늘 경기만은 따로 시도한다. 여기서 그냥 빠지면
      // 어제 저장분이 남아 위젯이 계속 "불러오는 중"에 머문다.
      try {
        await _updateTodayMatches(leagues: leagues, teamIds: teamIds);
        await HomeWidget.updateWidget(
          androidName: _androidWidgetName,
          iOSName: _iOSWidgetName,
        );
        await HomeWidget.updateWidget(
          androidName: _androidSmallWidgetName,
          iOSName: _iOSWidgetName,
        );
      } catch (e2) {
        debugPrint('[HomeWidget] 오늘 경기 폴백도 실패: $e2');
      }
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
  /// 위젯이 지금 보고 있는 달. 앱을 열 때 그 달로 맞추는 데 쓴다.
  ///
  /// 위젯의 prev/next 는 앱 UI 를 열지 않고 위젯만 갱신하므로, 위젯에서 7월로
  /// 넘긴 뒤 앱을 열면 앱은 이번 달을 보여 서로 어긋난다. 진입 시 이 값으로
  /// 맞춰 준다.
  static Future<DateTime> widgetDisplayedMonth() => _currentDisplayedMonth();

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
      final json = saved.json;
      if (json != null) {
        savedLeagues =
            (json['leagues'] as List?)?.cast<String>() ?? const ['ALL'];
        savedTeamIds = (json['teamIds'] as List?)?.cast<int>() ?? const [];
      }
    } catch (e) {
      debugPrint('[HomeWidget] 저장된 필터 복원 실패: $e');
    }

    final leagues = hasFilter ? savedLeagues : const ['ALL'];
    var teamIds = hasFilter ? savedTeamIds : const <int>[];

    // 응원팀 토글은 자기 팀만 제어한다.
    //
    // 켜면 응원팀을 목록에 더하고, 끄면 응원팀을 목록에서 뺀다. 예전에는 켤
    // 때만 더하고 끌 때는 아무것도 하지 않아서, 앱 필터에 그 팀이 저장돼 있으면
    // (`savedTeamIds`) 토글을 꺼도 필터가 그대로 걸려 있었다.
    final team = await _loadPreferredTeamForWidget();
    if (team != null) {
      teamIds = teamSelected
          ? {...teamIds, team.id}.toList()
          : teamIds.where((id) => id != team.id).toList();
    }

    // 저장된 필터를 그대로 보낸다. 예전엔 'ALL' 을 'LCK' 로 바꿔 보냈는데,
    // 이 위젯은 경기 일정 화면의 필터와 같은 것을 보여주기로 한 것이라
    // 필터가 '전체'인데 위젯만 LCK 만 나오는 상태였다(8월 기준 경기 있는 날
    // 31일 → 22일). 캘린더 API 는 'ALL' 을 그대로 받는다.
    final days = await ScheduleRepository.instance.fetchCalendar(
      month,
      leagues: leagues,
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

  /// 저장된 월(네이티브가 이미 옮겨 둔 값)의 캘린더를 받아 채운다.
  ///
  /// 안드로이드 월 이동은 네이티브가 먼저 월 라벨과 격자를 바꾸고
  /// (`WidgetMonthShiftReceiver`) 이 조회를 요청한다. 여기서 월을 다시 계산하면
  /// 두 번 옮겨지므로, 저장된 값을 그대로 쓴다.
  static Future<void> _handleMonthFetch() async {
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
      teamSelected: teamSelected,
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
        // 안드로이드 월 이동. 네이티브(WidgetMonthShiftReceiver)가 저장된 월을
        // 이미 옮겨 화면을 바꿔 뒀으므로, 여기서는 그 달의 데이터만 받아 채운다.
        case 'month':
          await _handleMonthFetch();
          break;
        // iOS 및 구버전 위젯 경로.
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
