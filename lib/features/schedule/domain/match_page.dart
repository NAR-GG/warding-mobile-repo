import 'package:warding/core/domain/schedule_match.dart';

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
