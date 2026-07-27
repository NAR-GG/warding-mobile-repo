import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_globals.dart';
import '../model/match_calendar_day.dart';
import '../model/schedule_match.dart';
import '../model/team.dart';
import '../repository/auth/auth_service.dart';
import '../repository/onboarding/onboarding_repository.dart';
import '../repository/preference/filter_preference_repository.dart';
import '../repository/preference/team_preference_repository.dart';
import '../repository/schedule/schedule_repository.dart';
import '../screens/schedule/schedule_screen.dart';
import '../util/app_image.dart';

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
          // ALL이면 주요 리그를 각각 호출해서 합침 (상세 API는 리그 1개만 받음)
          final leaguesForDetail = leagues.contains('ALL')
              ? const ['LCK', 'LEC', 'LPL', 'LTA', 'LCP']
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
      final leaguesForDetail = leagues.contains('ALL')
          ? const ['LCK', 'LEC', 'LPL', 'LTA', 'LCP']
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

  /// 위젯 URL 파싱 후 경기일정 화면으로 이동
  static void _handleWidgetUrl(String urlStr) {
    debugPrint('[HomeWidget] 위젯 URL: $urlStr');
    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;

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
      Team? team;
      try {
        final me = await AuthService.instance.fetchMe();
        if (me.favoriteTeamId != null) {
          final teams = await OnboardingRepository.instance.fetchTeams();
          for (final t in teams) {
            if (t.id == me.favoriteTeamId) { team = t; break; }
          }
        }
      } catch (_) {
        team = await TeamPreferenceRepository.instance.loadPreferredTeam();
      }
      await updatePreferredTeam(team);
    } catch (e) {
      debugPrint('[HomeWidget] 응원팀 갱신 실패: $e');
    }
  }
}
