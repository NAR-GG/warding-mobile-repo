import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 알림 피드 최초 로딩 중 표시할 스켈레톤 카드.
/// [NotificationCard] 와 동일한 레이아웃(좌 44×44 아이콘 + 우 제목/본문/시간)에
/// 회색 박스를 깔고 opacity 를 펄스시킨다. [MatchCardSkeleton] 과 동일한 톤.
class NotificationCardSkeleton extends StatefulWidget {
  const NotificationCardSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  State<NotificationCardSkeleton> createState() =>
      _NotificationCardSkeletonState();
}

class _NotificationCardSkeletonState extends State<NotificationCardSkeleton>
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
        return Container(
          width: double.infinity,
          color: AppColors.narBgSecondary,
          padding: EdgeInsets.all(20 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(w: 44 * scale, h: 44 * scale, r: 10), // 아이콘
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    box(w: 140 * scale, h: 16 * scale), // 제목
                    SizedBox(height: 8 * scale),
                    box(h: 13 * scale), // 본문
                    SizedBox(height: 12 * scale),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        box(w: 100 * scale, h: 12 * scale), // 절대 시각
                        box(w: 48 * scale, h: 12 * scale), // 상대 시각
                      ],
                    ),
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
