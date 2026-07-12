import 'package:flutter/material.dart';

import '../../../components/nar_chip.dart';

/// 마이 구독 날짜 점프 칩. 선택 상태에 따라 모양이 달라진다.
///
/// - 미선택: 기본 '날짜' 드롭다운 칩 (회색 테두리).
/// - 선택됨: 활성 칩 — 선택한 날짜 + circle-x(탭 시 선택 해제).
///
/// 필터가 아니라 캘린더에서 고른 날짜의 피드 헤더로 스크롤하는 용도라,
/// 선택 해제해도 리스트 자체는 바뀌지 않는다.
class DateFilterChip extends StatelessWidget {
  const DateFilterChip({
    super.key,
    required this.selectedDate,
    required this.scale,
    this.onTap,
    this.onClear,
  });

  /// 캘린더에서 고른 날짜. null 이면 미선택.
  final DateTime? selectedDate;

  final double scale;

  /// 칩 본문 탭 콜백 (캘린더 바텀시트 열기).
  final VoidCallback? onTap;

  /// circle-x 탭 콜백 (선택 해제).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final date = selectedDate;
    if (date == null) {
      return NarChip.dropdown(label: '날짜', scale: scale, onTap: onTap);
    }

    return NarChip.active(
      label: '${date.month}월 ${date.day}일',
      trailing: NarChipTrailing.remove,
      scale: scale,
      onTap: onTap,
      onRemove: onClear,
    );
  }
}
