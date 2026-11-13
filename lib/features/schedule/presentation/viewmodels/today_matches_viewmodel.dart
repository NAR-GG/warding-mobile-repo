import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/core/error/failure_exception.dart';
import 'package:warding/core/util/match_status.dart';
import 'package:warding/domain/schedule_match.dart';
import 'package:warding/features/schedule/domain/repositories/schedule_repository.dart';

/// 다른 화면에 끼워 넣는 "오늘 경기" 요약 목록의 상태.
///
/// 일정 화면은 [ScheduleViewModel] 이다 — 그쪽은 달력·리그 필터·월 이동을 하고,
/// 이쪽은 오늘 하루의 전체 리그만 받는다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class TodayMatchesViewModel extends ChangeNotifier {
  TodayMatchesViewModel({ScheduleRepository? repository})
    : _repository = repository ?? di<ScheduleRepository>();

  final ScheduleRepository _repository;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<ScheduleMatch> _matches = const [];

  /// 오늘 경기 — 진행 중인 경기를 앞으로, 그 밖에는 서버 순서 그대로.
  List<ScheduleMatch> get sorted => [
    ..._matches.where((m) => isLiveMatchStatus(m.matchStatus)),
    ..._matches.where((m) => !isLiveMatchStatus(m.matchStatus)),
  ];

  /// 세대 카운터 — 느린 응답이 새 응답을 덮지 않게 한다.
  int _gen = 0;

  /// 첫 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다. 이후 새로고침은
  /// 마지막 값을 유지하고 스켈레톤을 다시 띄우지 않는다.
  bool _firstLoadPending = true;
  bool get loading => _firstLoadPending;

  /// 오늘 모든 리그의 경기를 불러온다. 실패하면 마지막 값을 유지한다.
  Future<void> load() async {
    final gen = ++_gen;
    try {
      final matches = (await _repository.fetchMatchesByDate(
        DateTime.now(),
        leagues: const ['ALL'],
      ))
          .getOrElse((f) => throw FailureException(f));
      if (_disposed || gen != _gen) return;
      _matches = matches;
      _firstLoadPending = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[TodayMatches] 오늘 경기 조회 실패: $e');
      if (_disposed || gen != _gen) return;
      _firstLoadPending = false;
      notifyListeners();
    }
  }
}
