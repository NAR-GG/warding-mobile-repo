import 'dart:async';

import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 경기 상세 — 챔피언픽 탭 스크롤 중 오른쪽에 떴다 사라지는 목차(TOC).
///
/// [sectionKeys]/[labels]로 받은 4개 섹션(Champion Pick/Player Stats/
/// Team Summary/Objectives) 헤더가 pinned 탭바([pinnedBarKey]) 아래를
/// 지날 때마다 활성 점이 바뀐다(스크럴스파이). 활성 점 옆에는 그 섹션
/// 이름을 보여주는 칩이 뜬다. 점을 탭하거나 점 칼럼을 위아래로 드래그하면
/// 해당 섹션으로 바로 스크롤된다. 스크롤이 멎으면 서서히 사라진다.
class MatchDetailToc extends StatefulWidget {
  const MatchDetailToc({
    super.key,
    required this.active,
    required this.scrollController,
    required this.pinnedBarKey,
    required this.sectionKeys,
    required this.labels,
    this.scale = 1,
  });

  /// 챔피언픽 탭일 때만 true. false 면 항상 숨어 있는다.
  final bool active;
  final ScrollController scrollController;
  final GlobalKey pinnedBarKey;
  final List<GlobalKey> sectionKeys;
  final List<String> labels;
  final double scale;

  @override
  State<MatchDetailToc> createState() => _MatchDetailTocState();
}

class _MatchDetailTocState extends State<MatchDetailToc>
    with SingleTickerProviderStateMixin {
  int _activeIndex = 0;
  bool _visible = false;
  bool _frameScheduled = false;
  Timer? _hideTimer;

  final GlobalKey _markersKey = GlobalKey();
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _pulse = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.3), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant MatchDetailToc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    if (!widget.active && oldWidget.active) {
      _hideTimer?.cancel();
      if (_visible) setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _hideTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.active || _frameScheduled) return;
    _frameScheduled = true;
    // 스크롤 offset 이 바뀐 직후엔 슬리버 레이아웃이 아직 다음 프레임에
    // 반영되므로, 위치를 재는 건 프레임이 끝난 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      _recomputeActiveSection();
      if (!_visible) setState(() => _visible = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  void _recomputeActiveSection() {
    final barBox =
        widget.pinnedBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (barBox == null || !barBox.attached) return;
    final thresholdY =
        barBox.localToGlobal(Offset.zero).dy + barBox.size.height;

    var next = 0;
    for (var i = 0; i < widget.sectionKeys.length; i++) {
      final box =
          widget.sectionKeys[i].currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= thresholdY + 1) next = i;
    }

    // 마지막 섹션(Objectives) 콘텐츠가 남은 뷰포트보다 짧으면, 끝까지
    // 스크롤해도 그 헤더가 pinned 탭바 밑을 못 지나친다 — 더 내릴 스크롤
    // 여백 자체가 없기 때문이다. 그러면 위 루프가 영영 마지막 섹션을
    // activate 하지 못하고 그 앞 섹션에 멈춰 있는다. 스크롤이 끝까지
    // 내려갔으면 마지막 섹션을 무조건 활성으로 본다.
    final position = widget.scrollController.position;
    if (position.hasContentDimensions &&
        position.pixels >= position.maxScrollExtent - 1) {
      next = widget.sectionKeys.length - 1;
    }

    if (next != _activeIndex) {
      setState(() => _activeIndex = next);
      _pulseController.forward(from: 0);
    }
  }

  /// [localY] (점 칼럼 기준 로컬 좌표) 에 해당하는 섹션으로 바로 스크롤한다.
  void _jumpTo(int index) {
    final ctx = widget.sectionKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  int? _indexAtLocalY(double localY) {
    final box = _markersKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final h = box.size.height;
    if (h <= 0) return null;
    final ratio = (localY / h).clamp(0.0, 0.999);
    return (ratio * widget.labels.length).floor().clamp(
      0,
      widget.labels.length - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    // Positioned 는 Stack 의 직계 자식이어야 하므로(그래야 StackParentData 를
    // 붙일 수 있다) IgnorePointer 를 밖이 아니라 안쪽에 둔다.
    //
    // left 를 안 주고 right 만 주면 이 서브트리는 폭 제약이 없어(unbounded)
    // 칩 텍스트가 화면 왼쪽 밖으로 나가도 아무도 막지 않는다 — 그 상태에서
    // Stack 의 기본 clipBehavior(hardEdge) 가 화면 경계에서 그냥 잘라버려
    // 텍스트가 잘린 것처럼 보였다. left:0 을 줘서 실제 화면 폭만큼 진짜
    // 제약을 주고, 그 폭을 LayoutBuilder 로 재서 칩에 안전하게 넘긴다.
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 9 * scale,
      child: IgnorePointer(
        ignoring: !widget.active || !_visible,
        child: Center(
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              opacity: widget.active && _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: LayoutBuilder(
                builder:
                    (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        final i = _indexAtLocalY(d.localPosition.dy);
                        if (i != null) _jumpTo(i);
                      },
                      onVerticalDragUpdate: (d) {
                        final i = _indexAtLocalY(d.localPosition.dy);
                        if (i != null && i != _activeIndex) _jumpTo(i);
                      },
                      child: Column(
                        key: _markersKey,
                        mainAxisSize: MainAxisSize.min,
                        // 칩이 붙는 활성 행은 폭이 넓고 비활성 행은 점만 있어 좁다.
                        // 기본(center) 정렬이면 좁은 행의 점이 넓은 행 쪽으로 밀려
                        // 액티브 점과 다른 자리에 뜬다 — 오른쪽으로 정렬해 점들이
                        // 항상 같은 세로선에 붙게 한다.
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < widget.labels.length; i++) ...[
                            if (i > 0) SizedBox(height: 8 * scale),
                            _TocRow(
                              label: widget.labels[i],
                              isActive: i == _activeIndex,
                              pulse: _pulse,
                              scale: scale,
                              maxChipWidth: constraints.maxWidth,
                            ),
                          ],
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.label,
    required this.isActive,
    required this.pulse,
    required this.scale,
    required this.maxChipWidth,
  });

  final String label;
  final bool isActive;
  final Animation<double> pulse;
  final double scale;

  /// 이 TOC 칼럼에 실제로 주어진 화면 폭. 칩이 이 폭을 넘으면 잘리지 않고
  /// 말줄임(ellipsis)으로 대신 줄어들게 하는 상한이다.
  final double maxChipWidth;

  @override
  Widget build(BuildContext context) {
    // 마커가 원(11) → 캡슐(11×25)로 커질 때 이 마커 슬롯 자체의 높이가
    // 따라 커지면, Column 안 다른 행들이 그 순간 위아래로 밀려서 "덜컹"
    // 거린다(실측 확인됨 — 활성 행이 바뀔 때마다 다른 행이 순간 이동했었다).
    // 마커 슬롯 높이만 마커의 최대 크기(25)로 고정해 두고, 마커 자체 모양은
    // AnimatedContainer 로 그 안에서 부드럽게 바뀌게 한다 — 마커 쪽 레이아웃은
    // 절대 흔들리지 않는다.
    //
    // 이 슬롯 높이(25)를 행 전체(Row 를 감싼 SizedBox)에도 똑같이 씌우면,
    // 칩 쪽 필요 높이(패딩 5+5 + 텍스트 line-height 14*1.55 ≈ 31.7)가 더 커서
    // 칩 텍스트 아래가 잘린다. 그래서 행 전체를 고정 높이로 감싸지 않고
    // 마커 슬롯만 SizedBox 로 고정한다 — 칩은 자기 필요 높이만큼 자연스럽게
    // 커지고, Row 의 crossAxisAlignment.center 가 마커와 칩을 세로 중앙
    // 정렬해 준다.
    final marker = SizedBox(
      height: 25 * scale,
      child: Center(
        child: ScaleTransition(
          scale: isActive ? pulse : const AlwaysStoppedAnimation(1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 11 * scale,
            height: isActive ? 25 * scale : 11 * scale,
            decoration: BoxDecoration(
              color:
                  isActive ? const Color(0xFFFCFDFE) : const Color(0x99FCFDFE),
              // shape:circle 대신 borderRadius 로 통일해야 AnimatedContainer 가
              // 두 상태 사이를 매끄럽게 보간한다(circle↔rect 는 안 섞인다).
              // 11×11 일 때 반지름 5.5 면 정원이 된다.
              borderRadius: BorderRadius.circular(
                isActive ? 6 * scale : 5.5 * scale,
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          // 기본 layoutBuilder 는 크로스페이드 동안 이전 칩과 새 칩을
          // Stack 으로 겹쳐 그려서, 라벨 길이가 다르면(예: "Objectives"
          // → "Champion Pick") 그 짧은 순간 실제보다 더 넓게 차지한다.
          // 이 폭이 화면 왼쪽 밖으로 나가면 텍스트가 잘려 보인다.
          // 이전 칩을 무시하고 새 칩 크기만 쓰게 해서 없앤다.
          layoutBuilder:
              (currentChild, previousChildren) =>
                  currentChild ?? const SizedBox.shrink(),
          child:
              isActive
                  ? Padding(
                    key: ValueKey(label),
                    padding: EdgeInsets.only(right: 4 * scale),
                    child: _TocChip(
                      label: label,
                      scale: scale,
                      // 마커(11) + 이 padding(4) + 약간의 여유만큼 뺀 나머지가
                      // 칩이 실제로 쓸 수 있는 최대 폭이다.
                      maxWidth: (maxChipWidth - 11 * scale - 4 * scale - 8)
                          .clamp(0, double.infinity),
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
        marker,
      ],
    );
  }
}

class _TocChip extends StatelessWidget {
  const _TocChip({
    required this.label,
    required this.scale,
    required this.maxWidth,
  });

  final String label;
  final double scale;

  /// 이 칩이 실제로 쓸 수 있는 최대 폭. 라벨이 이보다 넓으면 화면 밖으로
  /// 잘리는 대신 말줄임(…)으로 대신 줄인다.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Container 에 alignment 를 주면 부모가 준 폭 제약을 꽉 채우려 든다
    // (Team Summary 의 diff 배지에서 겪은 것과 같은 문제). alignment 없이
    // padding+child 로만 크기를 잡아 텍스트+패딩만큼만 차지하게 한다.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 5 * scale,
        ),
        decoration: BoxDecoration(
          color: const Color(0xCCFCFDFE),
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            fontSize: 14 * scale,
            height: 1.55,
            color: AppColors.narBgContent,
          ),
        ),
      ),
    );
  }
}
