import 'package:flutter/material.dart';

import '../../../components/nar_skeleton.dart';
import '../../../styles/app_colors.dart';

/// 홈 섹션 스켈레톤 모음. 실제 데이터로 바뀔 때 화면이 튀지 않게 각 섹션의
/// 실제 크기·여백(헤더 아래 간격, 카드 높이)에 맞춘다.

/// 20 여백 안에서 카드 모양(색·테두리·12 라운드)을 만든다. [HomeListBox] 와 같다.
Widget _card(
  double scale, {
  required Widget child,
  double? height,
  bool inset = true,
}) => Container(
  margin: inset ? EdgeInsets.symmetric(horizontal: 20 * scale) : null,
  height: height,
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(
    color: AppColors.narBgTertiary,
    borderRadius: BorderRadius.circular(12 * scale),
    border: Border.all(color: AppColors.narLine),
  ),
  child: child,
);

/// 오늘 경기 — 172 × 110 카드 가로 스트립.
class HomeTodayMatchesSkeleton extends StatelessWidget {
  const HomeTodayMatchesSkeleton({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h, [double r = 4]) =>
        NarSkeletonBox(width: w * scale, height: h * scale, radius: r);

    Widget card() => Container(
      width: 172 * scale,
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        10 * scale,
        12 * scale,
        12 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(52, 16, 8),
          SizedBox(height: 12 * scale),
          Row(
            children: [
              box(24, 24, 12),
              SizedBox(width: 8 * scale),
              box(46, 12),
              const Spacer(),
              box(10, 12),
            ],
          ),
          SizedBox(height: 8 * scale),
          Row(
            children: [
              box(24, 24, 12),
              SizedBox(width: 8 * scale),
              box(46, 12),
              const Spacer(),
              box(10, 12),
            ],
          ),
        ],
      ),
    );

    return NarSkeleton(
      child: SizedBox(
        height: 110 * scale,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          children: [
            card(),
            SizedBox(width: 10 * scale),
            card(),
            SizedBox(width: 10 * scale),
            card(),
          ],
        ),
      ),
    );
  }
}

/// 오늘 끝난 경기 — 솔랭 큰 카드 아래 44 높이 칩 가로 줄.
class HomeFinishedSoloSkeleton extends StatelessWidget {
  const HomeFinishedSoloSkeleton({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget chip() => Container(
      width: 150 * scale,
      height: 44 * scale,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Row(
        children: [
          NarSkeletonBox(width: 28 * scale, height: 28 * scale, radius: 14),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NarSkeletonBox(width: 56 * scale, height: 11 * scale),
                SizedBox(height: 5 * scale),
                NarSkeletonBox(width: 70 * scale, height: 9 * scale),
              ],
            ),
          ),
        ],
      ),
    );

    return NarSkeleton(
      child: SizedBox(
        height: 44 * scale,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          children: [
            chip(),
            SizedBox(width: 8 * scale),
            chip(),
            SizedBox(width: 8 * scale),
            chip(),
          ],
        ),
      ),
    );
  }
}

/// 순위표 — 그룹 헤더 34 + 팀 행 46 × 5 짜리 카드.
class HomeStandingsSkeleton extends StatelessWidget {
  const HomeStandingsSkeleton({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget row() => Container(
      height: 46 * scale,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.narLine)),
      ),
      child: Row(
        children: [
          NarSkeletonBox(width: 14 * scale, height: 12 * scale),
          SizedBox(width: 12 * scale),
          NarSkeletonBox(width: 28 * scale, height: 28 * scale, radius: 14),
          SizedBox(width: 10 * scale),
          NarSkeletonBox(width: 60 * scale, height: 12 * scale),
          const Spacer(),
          NarSkeletonBox(width: 34 * scale, height: 12 * scale),
          SizedBox(width: 18 * scale),
          NarSkeletonBox(width: 22 * scale, height: 12 * scale),
        ],
      ),
    );

    // 순위표 섹션이 이미 좌우 20 여백으로 감싸고 있어 카드는 여백을 더 두지 않는다.
    return NarSkeleton(
      child: _card(
        scale,
        inset: false,
        child: Column(
          children: [
            Container(
              height: 34 * scale,
              padding: EdgeInsets.symmetric(horizontal: 14 * scale),
              alignment: Alignment.centerLeft,
              child: NarSkeletonBox(width: 64 * scale, height: 12 * scale),
            ),
            for (var i = 0; i < 5; i++) row(),
          ],
        ),
      ),
    );
  }
}

/// 커뮤니티·평점 한줄평 — 제목 한 줄 + 보조 한 줄짜리 행 [rows] 개가 든 카드.
class HomeListSkeleton extends StatelessWidget {
  const HomeListSkeleton({super.key, required this.scale, this.rows = 4});

  final double scale;
  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget row() => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 11 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NarSkeletonBox(width: double.infinity, height: 14 * scale),
          SizedBox(height: 8 * scale),
          NarSkeletonBox(width: 120 * scale, height: 11 * scale),
        ],
      ),
    );

    return NarSkeleton(
      child: _card(
        scale,
        child: Column(
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.narLine),
              row(),
            ],
          ],
        ),
      ),
    );
  }
}

/// 뉴스 — 62 × 47 썸네일 + 제목 두 줄 + 보조 한 줄 행 [rows] 개.
class HomeNewsSkeleton extends StatelessWidget {
  const HomeNewsSkeleton({super.key, required this.scale, this.rows = 4});

  final double scale;
  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget row() => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 13 * scale,
        vertical: 11 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NarSkeletonBox(width: 62 * scale, height: 47 * scale, radius: 6),
          SizedBox(width: 11 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NarSkeletonBox(width: double.infinity, height: 14 * scale),
                SizedBox(height: 6 * scale),
                NarSkeletonBox(width: 150 * scale, height: 14 * scale),
                SizedBox(height: 8 * scale),
                NarSkeletonBox(width: 90 * scale, height: 11 * scale),
              ],
            ),
          ),
        ],
      ),
    );

    return NarSkeleton(
      child: _card(
        scale,
        child: Column(
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.narLine),
              row(),
            ],
          ],
        ),
      ),
    );
  }
}
