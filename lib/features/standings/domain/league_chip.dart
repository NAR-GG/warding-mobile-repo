// 순위표 리그 칩 모델. 순위표 섹션만 쓴다.

/// 순위표 리그 칩 하나. [live] 가 false 면 아직 데이터가 없는 리그(탭 불가).
class HomeLeagueChip {
  const HomeLeagueChip({
    required this.code,
    required this.label,
    required this.live,
  });

  final String code;
  final String label;
  final bool live;
}
