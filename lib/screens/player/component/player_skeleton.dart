import 'package:flutter/material.dart';

import '../../../components/nar_card.dart';
import '../../../components/nar_skeleton.dart';
import '../../../components/nar_stat_box.dart';

/// 선수 페이지 첫 로딩 스켈레톤.
///
/// 실제 화면과 같은 순서·높이로 둬서 데이터가 들어올 때 레이아웃이 튀지 않게 한다
/// (큰 카드 → 다음 경기 → 지표 3칸 → 탭 → 섹션 제목 + 카드).
class PlayerSkeleton extends StatelessWidget {
  const PlayerSkeleton({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h, [double r = 4]) =>
        NarSkeletonBox(width: w * scale, height: h * scale, radius: r);

    return NarSkeleton(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          12 * scale,
          20 * scale,
          40 * scale,
        ),
        children: [
          // 큰 카드(솔랭 중) / 프로필 줄(쉬는 중) 자리 — 실제 카드와 같은 100 높이.
          NarCard(
            scale: scale,
            padding: EdgeInsets.fromLTRB(
              16 * scale,
              14 * scale,
              16 * scale,
              12 * scale,
            ),
            child: SizedBox(
              height: 100 * scale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      box(20, 20, 10),
                      SizedBox(width: 6 * scale),
                      box(90, 13),
                    ],
                  ),
                  const Spacer(),
                  box(70, 12),
                  SizedBox(height: 6 * scale),
                  Row(
                    children: [
                      box(20, 20, 6),
                      SizedBox(width: 6 * scale),
                      box(160, 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12 * scale),
          // 지표 3칸.
          NarStatRow(
            scale: scale,
            boxes: [
              for (var i = 0; i < 3; i++)
                NarStatBox(
                  label: '',
                  scale: scale,
                  value: Padding(
                    padding: EdgeInsets.only(top: 2 * scale),
                    child: box(40, 17),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20 * scale),
          // 탭 줄.
          Row(
            children: [
              box(60, 20),
              SizedBox(width: 24 * scale),
              box(60, 20),
            ],
          ),
          SizedBox(height: 28 * scale),
          // 섹션 제목 + 카드.
          box(120, 17),
          SizedBox(height: 12 * scale),
          NarCard(
            scale: scale,
            padding: EdgeInsets.all(14 * scale),
            child: Column(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) SizedBox(height: 16 * scale),
                  Row(
                    children: [
                      box(34, 34, 6),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            box(140, 13),
                            SizedBox(height: 6 * scale),
                            box(90, 12),
                          ],
                        ),
                      ),
                      box(36, 24),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
