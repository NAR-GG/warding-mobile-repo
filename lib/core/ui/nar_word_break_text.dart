import 'package:flutter/material.dart';

/// 어절 중간에서 끊기지 않게 줄바꿈하는 텍스트.
///
/// Flutter 의 기본 줄바꿈은 한글을 글자 단위로 끊어서, 폭이 조금 모자라면
/// '…쌓입니다' 의 '다' 한 글자만 다음 줄로 내려가 보기 나쁘다. 폭에 맞춰
/// 어절을 채우다 넘칠 때 직접 `\n` 을 넣어, 줄이 바뀔 땐 어절 통째로 넘어간다.
///
/// 한 어절이 폭보다 길면 그 어절만 기본 규칙대로 끊는다(무한 루프 방지).
class NarWordBreakText extends StatelessWidget {
  const NarWordBreakText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // 폭을 모르면(무한대) 손대지 않고 기본 동작에 맡긴다.
        if (!maxWidth.isFinite) {
          return Text(text, style: style, textAlign: textAlign);
        }
        return Text(
          _wrap(
            text,
            style,
            maxWidth,
            MediaQuery.textScalerOf(context),
            Directionality.of(context),
          ),
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }

  /// [maxWidth] 에 맞춰 어절 단위로 `\n` 을 넣은 문자열을 만든다.
  String _wrap(
    String text,
    TextStyle style,
    double maxWidth,
    TextScaler textScaler,
    TextDirection direction,
  ) {
    double widthOf(String s) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final out = StringBuffer();
    // 원문의 줄바꿈은 그대로 두고 줄마다 따로 접는다.
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) out.write('\n');
      final words = lines[i].split(RegExp(r'[ \t]+'))
        ..removeWhere((w) => w.isEmpty);
      var current = '';
      for (final word in words) {
        final candidate = current.isEmpty ? word : '$current $word';
        if (current.isEmpty || widthOf(candidate) <= maxWidth) {
          current = candidate;
          continue;
        }
        // 넘치면 여기서 줄을 바꾸고 이 어절부터 다음 줄을 시작한다.
        out.write('$current\n');
        current = word;
      }
      out.write(current);
    }
    return out.toString();
  }
}
