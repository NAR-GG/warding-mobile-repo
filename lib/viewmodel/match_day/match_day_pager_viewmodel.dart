import 'package:flutter/foundation.dart';

import '../../repository/schedule/schedule_repository.dart';
import 'match_day_viewmodel.dart';

/// [MatchDayScreen] 좌우 스와이프용 3페이지 롤링 윈도우 ViewModel.
///
/// 항상 `[중심-1, 중심, 중심+1]` 세 날짜의 [MatchDayViewModel]을 들고 있다가,
/// [shift]로 윈도우를 한 칸씩 옮긴다. 반대쪽 끝은 dispose 하고 새 끝만 새로 조회해
/// 가운데(현재 보고 있는) 페이지는 항상 이미 로드가 끝난 상태를 유지한다.
class MatchDayPagerViewModel extends ChangeNotifier {
  MatchDayPagerViewModel({
    required DateTime initialDate,
    this.leagues = const ['LCK'],
    this.teamIds,
    ScheduleRepository? repository,
  }) : _repository = repository ?? ScheduleRepository.instance {
    final center = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _dates = [
      center.subtract(const Duration(days: 1)),
      center,
      center.add(const Duration(days: 1)),
    ];
    _pages = _dates.map(_createPage).toList();
  }

  final List<String> leagues;
  final List<int>? teamIds;
  final ScheduleRepository _repository;

  bool _disposed = false;

  late List<DateTime> _dates;
  List<DateTime> get dates => _dates;

  late List<MatchDayViewModel> _pages;
  List<MatchDayViewModel> get pages => _pages;

  /// 카드 스코어 블러(스포방지) on/off. 3페이지가 공유하는 값 — 기본 on.
  bool _spoilerPreventionEnabled = true;
  bool get spoilerPreventionEnabled => _spoilerPreventionEnabled;

  void setSpoilerPreventionEnabled(bool value) {
    if (_spoilerPreventionEnabled == value) return;
    _spoilerPreventionEnabled = value;
    for (final page in _pages) {
      page.setSpoilerPreventionEnabled(value);
    }
    notifyListeners();
  }

  MatchDayViewModel _createPage(DateTime date) {
    final page = MatchDayViewModel(
      date: date,
      leagues: leagues,
      teamIds: teamIds,
      repository: _repository,
    );
    page.setSpoilerPreventionEnabled(_spoilerPreventionEnabled);
    return page;
  }

  /// 윈도우를 한 칸 옮긴다. [direction]이 1이면 다음 날짜 방향, -1이면 이전 날짜 방향.
  void shift(int direction) {
    assert(direction == 1 || direction == -1);
    if (direction == 1) {
      final newDate = _dates.last.add(const Duration(days: 1));
      final newPage = _createPage(newDate);
      _pages.first.dispose();
      _dates = [_dates[1], _dates[2], newDate];
      _pages = [_pages[1], _pages[2], newPage];
    } else {
      final newDate = _dates.first.subtract(const Duration(days: 1));
      final newPage = _createPage(newDate);
      _pages.last.dispose();
      _dates = [newDate, _dates[0], _dates[1]];
      _pages = [newPage, _pages[0], _pages[1]];
    }
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final page in _pages) {
      page.dispose();
    }
    super.dispose();
  }
}
