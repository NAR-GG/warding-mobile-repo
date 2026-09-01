import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 커뮤니티 목록 최초 로딩 중 표시할 스켈레톤 카드.
/// [PostListItem] 과 같은 padding·구분선으로 실데이터 전환 시 목록이
/// 튀지 않게 한다.
class PostListItemSkeleton extends StatefulWidget {
  const PostListItemSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  State<PostListItemSkeleton> createState() => _PostListItemSkeletonState();
}

class _PostListItemSkeletonState extends State<PostListItemSkeleton>
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
            // MatchCardSkeleton 과 같은 이유로 Opacity 대신 색의 알파를 쓴다 —
            // 목록 한 화면에 여러 장 깔릴 때 오프스크린 레이어 비용을 아낀다.
            color: AppColors.narLine2.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(r),
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 18 * scale,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.narLine, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 2줄(16/height 1.4 → 줄당 22.4).
              box(w: double.infinity, h: 22 * scale),
              SizedBox(height: 6 * scale),
              box(w: 160 * scale, h: 22 * scale),
              SizedBox(height: 10 * scale),
              // 본문 미리보기 2줄(14/height 1.5 → 줄당 21).
              box(w: double.infinity, h: 21 * scale),
              SizedBox(height: 4 * scale),
              box(w: 220 * scale, h: 21 * scale),
              SizedBox(height: 14 * scale),
              // 메타 줄: 시간 + 작성자.
              Row(
                children: [
                  box(w: 40 * scale, h: 16 * scale),
                  SizedBox(width: 9 * scale),
                  box(w: 70 * scale, h: 16 * scale),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
