import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 무한 스크롤 추가 로드 중 표시할 스켈레톤 카드.
/// [MatchCard] 와 동일한 레이아웃·치수에 회색 박스를 깔고 opacity 를 펄스시킨다.
///
/// 실제 카드로 바뀔 때 목록이 튀지 않도록 높이를 카드와 맞춘다:
/// 위 10 + 헤더 24 + 간격 20 + 스코어 블록 77 + 아래 24 = 155 (+ 구분선 1).
class MatchCardSkeleton extends StatefulWidget {
  const MatchCardSkeleton({
    super.key,
    this.scale = 1,
    this.showTopBorder = true,
    this.showAlarmBell = true,
  });

  final double scale;

  /// 위쪽 1px 구분선을 그릴지. 실제 카드([MatchCard.showTopBorder])와 같은 규칙.
  final bool showTopBorder;

  /// 헤더 좌측 알림 벨 자리를 비워둘지. 실제 카드는 LCK·MSI·EWC·KeSPA 경기에만
  /// 벨을 그리는데, 로딩 중에는 어떤 리그가 올지 몰라 기본값으로 자리를 잡아둔다.
  final bool showAlarmBell;

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
        // 실제 카드([MatchCard]의 _TeamColumn)와 같은 폭 80 고정.
        // 로고 50 + 간격 4 + 팀명(16/19) = 73.
        Widget teamColumn() => SizedBox(
          width: 80 * scale,
          child: Column(
            children: [
              box(w: 50 * scale, h: 50 * scale, r: 8), // 로고
              SizedBox(height: 4 * scale),
              box(w: 36 * scale, h: 19 * scale), // 팀명 (16px/height 19/16)
            ],
          ),
        );
        return Container(
          // 카드와 같은 배경 — 로딩 중에도 카드 면이 이어져 보인다.
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            border:
                widget.showTopBorder
                    ? const Border(
                      top: BorderSide(color: AppColors.narLine2, width: 1),
                    )
                    : null,
          ),
          // 카드와 같은 padding 10px 16px 24px — 로딩→실데이터 전환 시 점프 방지.
          padding: EdgeInsets.only(
            top: 10 * scale,
            left: 16 * scale,
            right: 16 * scale,
            bottom: 24 * scale,
          ),
          child: Column(
            children: [
              // 헤더: (벨 24) + 시간 칩 24 + 라벨 + chevron 18. 높이는 칩 기준 24.
              SizedBox(
                height: 24 * scale,
                child: Row(
                  children: [
                    if (widget.showAlarmBell) ...[
                      box(w: 24 * scale, h: 24 * scale, r: 6), // 알림 벨
                      SizedBox(width: 8 * scale),
                    ],
                    box(w: 54 * scale, h: 24 * scale, r: 8), // 시간 칩(NarBadge)
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: box(w: 96 * scale, h: 14 * scale), // 라벨
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    box(w: 18 * scale, h: 18 * scale), // chevron
                  ],
                ),
              ),
              SizedBox(height: 20 * scale),
              // 시안 'box': 헤더보다 좌우 16 안쪽, 팀 컬럼 80 고정 + space-between.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    teamColumn(),
                    // 스코어 자리는 스포방지 오버레이(_SpoilerOverlay)가 잡는
                    // 116×77 고정 영역이다. 팀 컬럼(73)보다 커서 이 값이 행 높이를
                    // 정하므로, 여기가 어긋나면 실데이터 전환 때 목록이 튄다.
                    box(w: 116 * scale, h: 77 * scale, r: 14),
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
