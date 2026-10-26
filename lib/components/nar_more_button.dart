import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 공용 "더 보기" 줄 버튼. 라벨 + chevron, 부모 폭을 채운다.
///
/// - 기본([NarMoreButton.new]): 목록 아래에 떼어 놓는 독립 버튼.
///   narBgTertiary 배경 + narLine 테두리, 높이 38, radius 10, 위 여백 10.
///   (예: 선수 페이지 "전체 8개 보기", "15판 더 보기")
/// - 카드 안([NarMoreButton.inCard]): 카드 마지막 줄로 붙이는 버튼.
///   배경·테두리 없이 상단 구분선만, 높이 40, 여백 없음.
///   (예: 홈 순위표 "전체 보기"·"접기")
///
/// [expanded] 가 true 면 chevron 이 위를 향한다(접기).
class NarMoreButton extends StatelessWidget {
  const NarMoreButton({
    super.key,
    required this.label,
    required this.onTap,
    this.expanded = false,
    this.scale = 1,
  }) : _inCard = false;

  /// 카드 마지막 줄용 — 상단 구분선만 두고 배경·테두리는 없다.
  const NarMoreButton.inCard({
    super.key,
    required this.label,
    required this.onTap,
    this.expanded = false,
    this.scale = 1,
  }) : _inCard = true;

  final String label;
  final VoidCallback onTap;

  /// true 면 chevron 이 위를 향한다 — "접기" 상태.
  final bool expanded;
  final double scale;

  /// 카드 안에 붙는 형태인지.
  final bool _inCard;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: (_inCard ? 40 : 38) * scale,
        margin: _inCard ? null : EdgeInsets.only(top: 10 * scale),
        alignment: Alignment.center,
        decoration: _inCard
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.narLine)),
              )
            : BoxDecoration(
                color: AppColors.narBgTertiary,
                borderRadius: BorderRadius.circular(10 * scale),
                border: Border.all(color: AppColors.narLine),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                // 카드 안은 홈 시안대로 14/400, 독립 버튼은 13/600.
                fontWeight: _inCard ? FontWeight.w400 : FontWeight.w600,
                fontSize: (_inCard ? 14 : 13) * scale,
                color: AppColors.narText2,
              ),
            ),
            SizedBox(width: (_inCard ? 4 : 3) * scale),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16 * scale,
              color: AppColors.narText2,
            ),
          ],
        ),
      ),
    );
  }
}
