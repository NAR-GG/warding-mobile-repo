import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';

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

  /// Android 위젯 클래스 정규화 이름 (중/대).
  static const String _androidWidgetName =
      'com.warding.app.ScheduleWidgetProvider';

  /// Android 소 위젯 클래스 정규화 이름.
  static const String _androidSmallWidgetName =
      'com.warding.app.ScheduleWidgetSmallProvider';

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

      // 오늘 경기 상세도 함께 가져와 저장
      await _updateTodayMatches();

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      // 소 위젯도 갱신
      await HomeWidget.updateWidget(
        androidName: _androidSmallWidgetName,
        iOSName: _iOSWidgetName,
      );
      debugPrint('[HomeWidget] 캘린더 위젯 갱신 완료: $monthStr');
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 위젯 갱신 실패: $e');
    }
  }

  /// 오늘 경기 리스트(시간·대진·상태)를 위젯에 전달한다.
  static Future<void> _updateTodayMatches() async {
    try {
      final now = DateTime.now();
      final matches =
          await ScheduleRepository.instance.fetchMatchesByDate(now);

      final todayJson = <String, dynamic>{
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'weekday': now.weekday, // 1=Mon ... 7=Sun
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
      debugPrint('[HomeWidget] 응원팀 저장: ${team.name}');
    } catch (e) {
      debugPrint('[HomeWidget] 응원팀 저장 실패: $e');
    }
  }

  /// 위젯 딥링크 처리: warding://widget/prev, next, filter
  static void handleWidgetDeepLink(Uri uri) {
    final path = uri.host == 'widget' ? uri.path : uri.host;
    final action = path.replaceAll('/', '');
    debugPrint('[HomeWidget] 딥링크: $uri → action=$action');

    // 경기일정 화면으로 이동
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (action) {
    case 'prev':
    case 'next':
    case 'filter':
      // 경기일정 화면을 열면서 action 전달
      nav.push(
        MaterialPageRoute(
          builder: (_) => ScheduleScreen(widgetAction: action),
        ),
      );
    }
  }

  /// 백그라운드에서 최신 데이터를 가져와 위젯을 갱신한다.
  /// 캘린더 + 응원팀 + 오늘 경기를 한 번에 갱신한다.
  static Future<void> refreshFromApi() async {
    try {
      final now = DateTime.now();
      final days = await ScheduleRepository.instance.fetchCalendar(now);
      final matchesByDay = <int, List<CalendarMatchBrief>>{
        for (final day in days) day.date.day: day.matches,
      };
      await updateCalendar(month: now, matchesByDay: matchesByDay);
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 갱신 실패: $e');
    }

    // 저장된 필터 상태를 위젯에 전달
    try {
      final saved = await FilterPreferenceRepository.instance
          .load(FilterPreferenceRepository.scheduleKey);
      if (saved != null) {
        final leagues = (saved['leagues'] as List?)?.cast<String>() ?? ['ALL'];
        final teamIds = (saved['teamIds'] as List?)?.cast<int>() ?? [];
        final teamSelected = (saved['teamSelected'] as bool?) ?? false;
        final hasFilter =
            !(leagues.length == 1 && leagues.first == 'ALL') ||
            teamIds.isNotEmpty;
        await updateFilterState(
          hasFilter: hasFilter,
          teamSelected: teamSelected,
        );
      }
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
