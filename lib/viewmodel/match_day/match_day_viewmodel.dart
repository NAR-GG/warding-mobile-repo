import 'package:flutter/foundation.dart';

import '../../model/schedule_match.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 경기 일정 캘린더에서 특정 날짜를 탭했을 때 여는 '그 날의 경기 리스트' 화면 ViewModel.
///
/// 생성 시 받은 [date]·[league]·[teamId] 로 `/api/mobile/schedules?date=` 를 한 번
/// 조회해 그 날짜의 경기 카드 목록을 들고 있다. 캘린더의 필터(리그·팀)를 그대로
/// 넘겨 캘린더 칩과 동일한 경기 집합을 보여준다.
class MatchDayViewModel extends ChangeNotifier {
  MatchDayViewModel({
    required this.date,
    this.leagues = const ['LCK'],
    this.teamIds,
    ScheduleRepository? repository,
  }) : _repository = repository ?? ScheduleRepository.instance {
    load();
  }

  /// 조회할 날짜 (연·월·일만 사용).
  final DateTime date;

  /// 조회에 적용할 리그 코드 목록 (캘린더 필터와 동일).
  final List<String> leagues;

  /// 조회에 적용할 팀 ID 목록. 비어 있으면 리그 전체.
  final List<int>? teamIds;

  final ScheduleRepository _repository;

  bool _disposed = false;

  /// 해당 날짜의 경기 카드 목록.
  List<ScheduleMatch> _matches = const [];
  List<ScheduleMatch> get matches => _matches;

  /// 조회 진행 중 여부.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 마지막 조회 실패 시 에러. 성공하면 null.
  Object? _error;
  Object? get error => _error;

  /// 해당 날짜의 경기를 조회한다. 재시도용으로 다시 호출할 수 있다.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      _matches = await _repository.fetchMatchesByDate(
        date,
        leagues: leagues,
        teamIds: teamIds,
      );
    } catch (e) {
      _error = e;
      _matches = const [];
      debugPrint('[MatchDay] load 에러: $e');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
