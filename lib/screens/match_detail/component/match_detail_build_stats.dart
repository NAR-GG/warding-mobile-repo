import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 빌드 카드 상단의 지표 한 칸 — 라벨 + 값. [child] 를 주면 값 자리를 대체한다
/// (KDA 처럼 색이 섞인 텍스트).
class BuildStatColumn extends StatelessWidget {
  const BuildStatColumn({
    super.key,
    required this.label,
    this.value,
    this.child,
    required this.scale,
  });

  final String label;
  final String? value;
  final Widget? child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12 * scale,
            height: 14 / 12,
            color: AppColors.narText,
          ),
        ),
        SizedBox(height: 3 * scale),
        child ??
            Text(
              value ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 14 * scale,
                height: 17 / 14,
                color: AppColors.narText,
              ),
            ),
      ],
    );
  }
}

/// KDA "a/b/c" — 데스(가운데)만 [AppColors.narTextScore]로 강조한다
/// (Player Stats 의 데스 색상 표기와 동일 규칙).
class BuildSlashTripleText extends StatelessWidget {
  const BuildSlashTripleText({
    super.key,
    required this.a,
    required this.b,
    required this.c,
    required this.scale,
  });

  final String a;
  final String b;
  final String c;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 14 * scale,
      height: 17 / 14,
      color: AppColors.narText,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: a),
          const TextSpan(text: '/'),
          TextSpan(text: b, style: TextStyle(color: AppColors.narTextScore)),
          const TextSpan(text: '/'),
          TextSpan(text: c),
        ],
      ),
    );
  }
}

/// 지표 칸 사이 세로 구분선.
class BuildStatDivider extends StatelessWidget {
  const BuildStatDivider({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 20 * scale, color: AppColors.narLine2);
}
