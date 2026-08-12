import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 무한 스크롤 추가 로드 중 표시할 스켈레톤 카드.
/// [MatchCard] 와 동일한 레이아웃·치수에 회색 박스를 깔고 opacity 를 펄스시킨다.
class MatchCardSkeleton extends StatefulWidget {
  const MatchCardSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  State<MatchCardSkeleton> createState() => _MatchCardSkeletonState();
}

class _MatchCardSkeletonState extends State<MatchCardSkeleton>
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final opacity = 0.3 + (_ctrl.value * 0.3); // 0.3 ↔ 0.6 펄스
        Widget box({double? w, required double h, double r = 4}) => Opacity(
          opacity: opacity,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: AppColors.narLine2,
              borderRadius: BorderRadius.circular(r),
            ),
          ),
        );
        // 실제 카드([MatchCard])의 팀 컬럼과 같은 폭 80 고정.
        Widget teamColumn() => SizedBox(
          width: 80 * scale,
          child: Column(
            children: [
              box(w: 50 * scale, h: 50 * scale, r: 8), // 로고
              SizedBox(height: 4 * scale),
              box(w: 36 * scale, h: 16 * scale), // 팀명
            ],
          ),
        );
        // 카드와 같은 padding 10px 16px 24px — 로딩→실데이터 전환 시 점프 방지.
        return Padding(
          padding: EdgeInsets.only(
            top: 10 * scale,
            left: 16 * scale,
            right: 16 * scale,
            bottom: 24 * scale,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  box(w: 59 * scale, h: 24 * scale, r: 8), // 시간 칩
                  SizedBox(width: 8 * scale),
                  Expanded(child: box(h: 14 * scale)), // 라벨
                  SizedBox(width: 8 * scale),
                  box(w: 18 * scale, h: 18 * scale), // chevron
                ],
              ),
              SizedBox(height: 20 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    teamColumn(),
                    box(w: 60 * scale, h: 28 * scale), // 스코어
                    teamColumn(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
