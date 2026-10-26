import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 공용 카드 틀 — narBgTertiary 배경 + narLine 테두리 + radius 12.
///
/// 목록을 담을 때는 [NarCard.list] 로 자식 사이에 1px 구분선을 자동으로 끼운다
/// (자식이 비면 아무것도 그리지 않는다).
class NarCard extends StatelessWidget {
  const NarCard({
    super.key,
    required Widget child,
    required this.scale,
    this.padding,
    this.margin,
  }) : _child = child,
       _children = null;

  /// 행 사이에 구분선을 넣는 목록 카드. 자식이 비면 빈 위젯을 돌려준다.
  const NarCard.list({
    super.key,
    required List<Widget> children,
    required this.scale,
    this.padding,
    this.margin,
  }) : _children = children,
       _child = null;

  final Widget? _child;
  final List<Widget>? _children;
  final double scale;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final rows = _children;
    if (rows != null && rows.isEmpty) return const SizedBox.shrink();

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: rows == null
          ? _child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.narLine),
                  rows[i],
                ],
              ],
            ),
    );
  }
}
