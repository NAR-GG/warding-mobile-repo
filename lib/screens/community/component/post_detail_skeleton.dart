import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 글 상세 최초 로딩 중 표시할 스켈레톤. [PostDetailScreen._body] 의
/// 아바타·작성자줄·제목·본문 자리와, 그 아래 댓글 목록([CommentTile]) 자리를
/// 같은 치수로 잡아 실데이터 전환 시 화면이 튀지 않게 한다. 댓글 개수는
/// 글이 로드되기 전엔 알 수 없어 임의로 3줄만 자리를 잡는다.
class PostDetailSkeleton extends StatefulWidget {
  const PostDetailSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  State<PostDetailSkeleton> createState() => _PostDetailSkeletonState();
}

class _PostDetailSkeletonState extends State<PostDetailSkeleton>
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
            color: AppColors.narLine2.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(r),
          ),
        );
        Widget circle(double d) => Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: AppColors.narLine2.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );

        // 댓글 한 줄([CommentTile] 과 같은 치수) — 아바타 28 + padding
        // 20/10/10 + 작성자줄 + 본문 1줄 + 메타줄.
        Widget commentRow() => Padding(
          padding: EdgeInsets.only(
            left: 20 * scale,
            right: 20 * scale,
            top: 10 * scale,
            bottom: 10 * scale,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              circle(28 * scale),
              SizedBox(width: 9 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(w: 70 * scale, h: 15 * scale),
                    SizedBox(height: 5 * scale),
                    box(w: double.infinity, h: 19 * scale),
                    SizedBox(height: 8 * scale),
                    box(w: 50 * scale, h: 14 * scale),
                  ],
                ),
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                14 * scale,
                20 * scale,
                16 * scale,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.narLine, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프로필 아바타(34) + 작성자줄(팀 로고 14 + 이름) + 시간.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      circle(34 * scale),
                      SizedBox(width: 9 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            box(w: 90 * scale, h: 16 * scale),
                            SizedBox(height: 4 * scale),
                            box(w: 60 * scale, h: 14 * scale),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14 * scale),
                  // 제목(18/height 1.4 → 줄당 25.2).
                  box(w: double.infinity, h: 25 * scale),
                  SizedBox(height: 8 * scale),
                  // 본문 3줄(14/height 1.65 → 줄당 23.1).
                  box(w: double.infinity, h: 23 * scale),
                  SizedBox(height: 6 * scale),
                  box(w: double.infinity, h: 23 * scale),
                  SizedBox(height: 6 * scale),
                  box(w: 180 * scale, h: 23 * scale),
                ],
              ),
            ),
            // "댓글 N개" 자리.
            Padding(
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                14 * scale,
                20 * scale,
                2 * scale,
              ),
              child: box(w: 70 * scale, h: 19 * scale),
            ),
            commentRow(),
            commentRow(),
            commentRow(),
          ],
        );
      },
    );
  }
}
