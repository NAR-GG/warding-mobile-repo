import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 선수 평점 탭 최초 로딩 중 표시할 스켈레톤.
/// [MatchDetailPlayerRatingSection] 과 동일한 레이아웃(요약 + 팀별 5행)에
/// 회색 박스를 깔고 opacity 를 펄스시킨다. [MatchCardSkeleton] 과 동일한 톤.
class MatchDetailPlayerRatingSkeleton extends StatefulWidget {
  const MatchDetailPlayerRatingSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  State<MatchDetailPlayerRatingSkeleton> createState() =>
      _MatchDetailPlayerRatingSkeletonState();
}

class _MatchDetailPlayerRatingSkeletonState
    extends State<MatchDetailPlayerRatingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return ColoredBox(
      color: AppColors.narBgContent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final opacity = 0.3 + (_ctrl.value * 0.3); // 0.3 ↔ 0.6 펄스
          Widget box({double? w, required double h, double r = 4}) => Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              // 펄스는 Opacity 위젯 대신 색의 알파로 낸다 — 결과는 같은데
              // Opacity 는 박스마다 오프스크린 레이어를 떠서, 한 화면에
              // 스켈레톤이 여러 장 깔리면 그 비용이 장수만큼 곱해진다.
              color: AppColors.narLine2.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(r),
            ),
          );
          Widget teamSection() => Padding(
            padding: EdgeInsets.symmetric(vertical: 16 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                  child: box(w: 90 * scale, h: 19 * scale), // 'DNS(BLUE)' 헤딩
                ),
                SizedBox(height: 16 * scale),
                for (var i = 0; i < 5; i++)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 10 * scale),
                    padding: EdgeInsets.all(10 * scale),
                    color: i.isEven ? AppColors.narBgSecondary : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        box(w: 38 * scale, h: 38 * scale, r: 8), // 선수 사진
                        SizedBox(width: 6 * scale),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            box(w: 60 * scale, h: 14 * scale), // 선수명
                            SizedBox(height: 4 * scale),
                            box(w: 32 * scale, h: 12 * scale), // 포지션
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            box(w: 76 * scale, h: 14 * scale), // 별점
                            SizedBox(height: 2 * scale),
                            box(w: 56 * scale, h: 14 * scale), // '4.5 (23명)'
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 전체 선수 평점 요약.
              Padding(
                padding: EdgeInsets.all(16 * scale),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    box(w: 100 * scale, h: 16 * scale),
                    box(w: 100 * scale, h: 16 * scale),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.narLine),
              teamSection(),
              teamSection(),
            ],
          );
        },
      ),
    );
  }
}
