import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 스크롤이 긴 화면 우측 하단에 떠 있는 '맨 위로' 버튼.
///
/// [scrollController] 를 관찰해 일정 거리([showAfter]) 이상 스크롤됐을 때만
/// 나타나고, 탭하면 맨 위로 부드럽게 스크롤한다. `Stack` 의 자식으로 써야 한다
/// (내부에서 [Positioned] 를 직접 그린다).
class ScrollToTopButton extends StatefulWidget {
  const ScrollToTopButton({
    super.key,
    required this.scrollController,
    this.scale = 1,
    this.right = 23,
    this.bottom = 23,
    this.showAfter = 300,
    this.reverse = false,
    this.onTap,
  });

  final ScrollController scrollController;
  final double scale;

  /// 대상 ListView 가 reverse:true 면 같이 true 로. 화면 '맨 위'가
  /// maxScrollExtent 쪽이 되므로 표시 조건과 스크롤 목적지를 뒤집는다.
  final bool reverse;

  /// 외부에서 탭 동작을 직접 제어할 때 사용한다.
  final VoidCallback? onTap;

  /// 우측/하단 여백 (시안 기준 23/23). 화면에 겹치는 요소(하단 네비 등)가
  /// 있으면 화면에서 더 큰 값을 넘겨 그 위로 띄운다.
  final double right;
  final double bottom;

  /// 이 거리(스크롤 오프셋) 이상 내려가야 버튼이 나타난다.
  final double showAfter;

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  /// 화면 시작점(맨 위)에서 얼마나 스크롤했는지.
  /// reverse 여부와 상관없이 pixels 가 곧 스크롤 거리다.
  double _distanceFromTop(ScrollPosition position) => position.pixels;

  void _onScroll() {
    final controller = widget.scrollController;
    final show = controller.hasClients &&
        _distanceFromTop(controller.position) > widget.showAfter;
    if (show != _visible) setState(() => _visible = show);
  }

  void _scrollToTop() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (!widget.scrollController.hasClients) return;
    if (widget.reverse) {
      // reverse 리스트: 현재 위치에서 2000px 위로 이동.
      final target = (widget.scrollController.position.pixels + 2000)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);
      widget.scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: widget.right * widget.scale,
      bottom: widget.bottom * widget.scale,
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _scrollToTop,
            child: SvgPicture.asset(
              'assets/icons/arrow-up.svg',
              width: 34 * widget.scale,
              height: 34 * widget.scale,
            ),
          ),
        ),
      ),
    );
  }
}
