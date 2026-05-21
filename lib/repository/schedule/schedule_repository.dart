import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/match_calendar_day.dart';
import '../../model/schedule_match.dart';

/// 경기 일정 관련 API.
class ScheduleRepository {
  ScheduleRepository._();
  static final ScheduleRepository instance = ScheduleRepository._();

  /// 특정 월에 경기가 있는 날짜 목록을 조회한다 (달력 마킹용). 인증 불필요.
  ///
  /// [month] 는 어느 날짜든 그 연·월만 사용된다.
  Future<List<MatchCalendarDay>> fetchCalendar(DateTime month) async {
    final monthStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final url = ApiConfig.scheduleCalendarUrl(monthStr);
    debugPrint('[Schedule] GET $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('[Schedule] calendar ← ${response.statusCode} '
        '(${response.body.length} bytes)');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('경기 캘린더 조회 실패 (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final dates = data['dates'] as List<dynamic>;
    debugPrint('[Schedule] calendar dates: ${dates.length}');
    return dates
        .map((e) => MatchCalendarDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 특정 날짜의 경기 목록을 조회한다. 인증 불필요.
  Future<List<ScheduleMatch>> fetchMatchesByDate(DateTime date) async {
    final dateStr = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final url = ApiConfig.scheduleByDateUrl(dateStr);
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
}
