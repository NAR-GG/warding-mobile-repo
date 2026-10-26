import 'package:flutter/material.dart';

import '../styles/app_colors.dart';
import 'nar_card.dart';

/// 공용 지표 상자 — 작은 회색 라벨 + 큰 값. 카드 틀([NarCard]) 안에 담는다.
///
/// 선수 페이지 "구독자 · 최근 7일 응원 · 월즈 팬 평점" 줄, 내 선수 월즈 시트의
/// 오늘 전적처럼 "라벨 위, 숫자 아래" 지표를 나란히 둘 때 쓴다.
/// 값은 숫자 색을 섞어 쓰는 경우가 많아 [value] 로 위젯째 받는다.
class NarStatBox extends StatelessWidget {
  const NarStatBox({
    super.key,
    required this.label,
    required this.value,
    required this.scale,
    this.labelSize = 11,
    this.padding,
  });

  final String label;
  final Widget value;
  final double scale;

  /// 라벨 크기(기본 11 — 선수 페이지). 내 선수 시트는 13.
  final double labelSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return NarCard(
      scale: scale,
      padding:
          padding ??
          EdgeInsets.fromLTRB(12 * scale, 10 * scale, 8 * scale, 10 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: labelSize * scale,
              color: AppColors.narText2,
            ),
          ),
          SizedBox(height: 4 * scale),
          value,
        ],
      ),
    );
  }
}

/// [NarStatBox] 를 같은 폭으로 나란히 두는 줄.
class NarStatRow extends StatelessWidget {
  const NarStatRow({
    super.key,
    required this.boxes,
    required this.scale,
    this.gap = 8,
  });

  final List<NarStatBox> boxes;
  final double scale;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // stretch 를 쓰면 높이가 안 정해진 부모(ListView 등)에서 무한 높이가 된다.
    // 상자들 높이를 맞추는 건 IntrinsicHeight 로 부모가 정한다.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < boxes.length; i++) ...[
          if (i > 0) SizedBox(width: gap * scale),
          Expanded(child: boxes[i]),
        ],
      ],
    );
  }
}
