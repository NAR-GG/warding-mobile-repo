import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/match_calendar_day.dart';
import '../../model/schedule_filter_options.dart';
import '../../model/schedule_match.dart';

/// 경기 일정 관련 API (`/api/mobile/schedules`).
class ScheduleRepository {
  ScheduleRepository._();
  static final ScheduleRepository instance = ScheduleRepository._();

  /// 특정 월의 캘린더 마킹 데이터를 조회한다 (인증 불필요).
  ///
  /// 날짜별 경기 수와, 캘린더 칸 칩에 바로 쓸 대진 목록까지 한 번에 받는다.
  /// [month] 는 어느 날짜든 그 연·월만 사용된다.
  Future<List<MatchCalendarDay>> fetchCalendar(
    DateTime month, {
    String league = 'LCK',
    int? teamId,
  }) async {
    final monthStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final url = ApiConfig.mobileScheduleCalendarUrl(
      month: monthStr,
      league: league,
      teamId: teamId,
    );
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

  /// 특정 날짜의 경기 리스트 카드를 조회한다 (인증 불필요).
  Future<List<ScheduleMatch>> fetchMatchesByDate(
    DateTime date, {
    String league = 'LCK',
    int? teamId,
  }) async {
    final dateStr = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final url = ApiConfig.mobileSchedulesUrl(
      date: dateStr,
      league: league,
      teamId: teamId,
    );
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
