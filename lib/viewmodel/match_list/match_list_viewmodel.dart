import 'package:flutter/foundation.dart';

/// 경기 리스트 화면의 상태·로직.
class MatchListViewModel extends ChangeNotifier {
  /// 선택 가능한 시즌 목록.
  static const List<String> seasons = ['2025', '2026'];

  /// 현재 선택된 시즌. 기본값은 가장 최근 시즌.
  String _selectedSeason = seasons.last;
  String get selectedSeason => _selectedSeason;

  /// 시즌을 선택한다. 같은 값이면 통지하지 않는다.
  void selectSeason(String season) {
    if (_selectedSeason == season) return;
    _selectedSeason = season;
    notifyListeners();
  }
}
