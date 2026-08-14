import 'package:flutter/material.dart';

import 'schedule_calendar.dart';
import 'schedule_header.dart';

/// 캘린더 스와이프 진행률에 물린 'yyyy.MM' 월 라벨.
///
/// [progress] 는 캘린더가 매 프레임 밀어 주는 스크롤 진행 상태다. 이 값으로
/// 두 라벨(나가는 달·들어오는 달)을 세로로 밀며 크로스페이드해서, 캘린더
/// 그리드와 정확히 같은 프레임에 같은 진행률로 움직이게 한다.
///
/// 가로로 밀지 않는 이유: 라벨 왼쪽 정렬이 유지돼야 옆의 달력·펼침 아이콘이
/// 흔들리지 않는다. 세로 슬라이드면 폭이 고정된 채 값만 바뀐다.
class CalendarMonthLabel extends StatelessWidget {
  const CalendarMonthLabel({
    super.key,
    required this.progress,
    required this.scale,
  });

  /// 캘린더 스와이프 진행 상태.
  final CalendarScrollProgress progress;

  final double scale;

  /// 'yyyy.MM' 형식으로 만든다. 예: 2026.04.
  static String labelOf(DateTime month) =>
      '${month.year}.${month.month.toString().padLeft(2, '0')}';

  DateTime _monthAt(int delta) =>
      DateTime(progress.month.year, progress.month.month + delta);

  @override
  Widget build(BuildContext context) {
    final style = ScheduleHeader.monthLabelStyle(scale);
    final lineHeight = style.fontSize! * style.height!;

    // 진행률을 '어느 두 달 사이인지'와 '그 사이 몇 %인지(t)'로 쪼갠다.
    final page = progress.page;
    final from = page.floor();
    final t = page - from; // 0.0 ~ 1.0

    // 폭은 항상 'yyyy.MM' 한 벌 크기로 고정한다.
    //
    // 라벨을 두 줄 겹쳐 그리면서 폭을 내용에 맡기면, 스와이프 중 위아래
    // 라벨의 글자 폭 차이(예: 2026.08 → 2026.09 는 같지만 2026.09 → 2026.10
    // 은 다르다)만큼 폭이 프레임마다 달라진다. 그러면 오른쪽에 붙은
    // 달력·펼침 아이콘이 같이 흔들리고 라벨이 깜박이는 것처럼 보인다.
    // 자릿수가 같은 형식이라 어느 달을 재도 폭이 같으므로, 기준 달 하나로
    // 재서 고정한다.
    final width = _measure(labelOf(_monthAt(from)), style);

    return SizedBox(
      width: width,
      height: lineHeight,
      // 넘치는 라벨(위로 나가거나 아래에서 들어오는 줄)을 한 줄 높이로 잘라
      // 헤더 다른 요소를 침범하지 않게 한다.
      child: ClipRect(
        child: Stack(
          // Positioned 자식만 있으면 Stack 이 스스로 크기를 못 정한다.
          // 부모 SizedBox 가 준 크기를 그대로 쓰도록 확장시킨다.
          fit: StackFit.expand,
          children: [
            _slot(
              text: labelOf(_monthAt(from)),
              style: style,
              lineHeight: lineHeight,
              offset: -t,
              opacity: 1 - t,
            ),
            // 정착 상태(t == 0)면 들어오는 라벨은 화면 밖이라 그릴 필요가
            // 없다. 그래도 자식 수와 순서는 유지해 위젯 트리가 흔들리지
            // 않게 SizedBox.shrink 로 자리만 남긴다.
            if (t == 0)
              const SizedBox.shrink()
            else
              _slot(
                text: labelOf(_monthAt(from + 1)),
                style: style,
                lineHeight: lineHeight,
                offset: 1 - t,
                opacity: t,
              ),
          ],
        ),
      ),
    );
  }

  /// [text] 를 [style] 로 그렸을 때의 가로 폭.
  static double _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// 라벨 한 줄. [offset] 은 줄 높이 배수(0 = 제자리, 1 = 한 줄 아래).
  Widget _slot({
    required String text,
    required TextStyle style,
    required double lineHeight,
    required double offset,
    required double opacity,
  }) {
    // left/right 를 함께 잡아 폭을 부모(SizedBox)에 맞춘다. 한쪽만 주면
    // 자식이 가로로 무제한 제약을 받아 레이아웃이 터진다.
    return Positioned(
      left: 0,
      right: 0,
      top: offset * lineHeight,
      height: lineHeight,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      ),
    );
  }
}
