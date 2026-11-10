import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/schedule_match.dart';
import 'package:warding/features/schedule/domain/match_calendar_day.dart';
import 'package:warding/features/schedule/domain/match_page.dart';
import 'package:warding/features/schedule/domain/schedule_filter_options.dart';

/// 경기 일정 조회 (인증 불필요).
///
/// 네 조회 모두 **같은 조건의 요청이 겹치면 합류하고, 방금 받은 응답은 짧게
/// 캐시한다.** 앱 시작 시 캘린더를 부르는 곳이 셋(스플래시 프리페치·홈 위젯
/// 갱신·일정 화면)이라 그대로 두면 같은 응답을 세 번 받으려고 회선을 뺏는다.
abstract interface class ScheduleRepository {
  /// 특정 월의 캘린더 마킹 데이터.
  ///
  /// 날짜별 경기 수와 캘린더 칸 칩에 쓸 대진 목록을 함께 받는다. [month] 는
  /// 어느 날짜든 그 연·월만 쓴다. [forceRefresh] 를 주면 캐시를 건너뛴다.
  Future<Either<Failure, List<MatchCalendarDay>>> fetchCalendar(
    DateTime month, {
    List<String> leagues,
    List<int>? teamIds,
    bool forceRefresh,
  });

  /// 특정 날짜의 경기 리스트 카드.
  Future<Either<Failure, List<ScheduleMatch>>> fetchMatchesByDate(
    DateTime date, {
    List<String> leagues,
    List<int>? teamIds,
  });

  /// 커서 페이지네이션 경기 목록.
  Future<Either<Failure, MatchPage>> fetchMatches({
    String? cursor,
    int size,
    required String league,
    int? teamId,
    int? seasonYear,
    String? split,
    String? from,
    String? around,
    String? before,
  });

  /// 필터 선택지(시즌·리그·팀).
  Future<Either<Failure, ScheduleFilterOptions>> fetchFilterOptions({
    String league,
  });
}
