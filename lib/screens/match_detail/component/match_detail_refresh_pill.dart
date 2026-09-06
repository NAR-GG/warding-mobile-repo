import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// 경기 상세 하단 중앙에 떠 있는 "새로고침" 캡슐 버튼.
///
/// 탭하면 [onRefresh] 를 돌리고, 도는 동안은 아이콘 자리에 스피너를 보여준다.
/// 끝나면 라벨이 잠깐 "최신 이벤트 반영 완료!" 로 바뀌었다가 돌아온다 — 당겨서
/// 새로고침처럼 인디케이터가 순식간에 사라지지 않으니 스낵바 대신 라벨로 알린다.
/// `Stack` 의 자식으로 써야 한다(내부에서 [Positioned] 를 그린다).
class MatchDetailRefreshPill extends StatefulWidget {
  const MatchDetailRefreshPill({
    super.key,
    required this.onRefresh,
    this.scale = 1,
    this.bottom = 23,
  });

  /// 실제 새로고침. 예외는 호출부가 삼켜야 한다 — 여기선 끝나기만 기다린다.
  final Future<void> Function() onRefresh;
  final double scale;

  /// 하단 여백(시안 23). [ScrollToTopButton] 과 같은 줄에 놓는다.
  final double bottom;

  @override
  State<MatchDetailRefreshPill> createState() => _MatchDetailRefreshPillState();
}

class _MatchDetailRefreshPillState extends State<MatchDetailRefreshPill> {
  bool _refreshing = false;
  bool _showDone = false;
  Timer? _doneTimer;

  @override
  void dispose() {
    _doneTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_refreshing) return;
    _doneTimer?.cancel();
    setState(() {
      _refreshing = true;
      _showDone = false;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _showDone = true;
        });
        _doneTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showDone = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scale = widget.scale;
    final label = _showDone ? l.latestEventsApplied : l.refresh;

    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.bottom * scale,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 12 * scale,
            ),
            decoration: BoxDecoration(
              // 불투명 대신 다크 반투명 — 뒤 콘텐츠가 살짝 비쳐야 위에 "떠 있는"
              // 느낌이 난다(시안 스크린샷 기준 ~85%).
              color: AppColors.narDark600.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14 * scale),
              boxShadow: [
                BoxShadow(
                  color: AppColors.narDarkOpacity62,
                  blurRadius: 12 * scale,
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 14 * scale,
                      height: 1.2,
                      color: AppColors.narText,
                    ),
                  ),
                ),
                SizedBox(width: 10 * scale),
                SizedBox(
                  width: 18 * scale,
                  height: 18 * scale,
                  child:
                      _refreshing
                          ? Padding(
                            padding: EdgeInsets.all(2 * scale),
                            child: CircularProgressIndicator(
                              strokeWidth: 2 * scale,
                              color: AppColors.narText,
                            ),
                          )
                          : SvgPicture.asset(
                            'assets/icons/reload.svg',
                            width: 18 * scale,
                            height: 18 * scale,
                            colorFilter: const ColorFilter.mode(
                              AppColors.narText,
                              BlendMode.srcIn,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
