import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_spoiler_toggle.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/schedule/component/schedule_header.dart';

/// 경기일정 헤더 레이아웃 회귀 테스트.
///
/// 월 라벨은 왼쪽 끝, 스포방지·필터는 **오른쪽 끝**에 붙어야 한다. 한때 월
/// 라벨을 [Flexible] 로 둬서 남는 폭을 전부 가져갔고, 그 바람에 스포방지와
/// 필터가 라벨 바로 옆에 붙어 가운데쯤에 떠 있었다.
///
/// 동시에 좁은 폭에서 overflow 가 나면 안 된다 — 라벨 길이가 상태·언어마다
/// 달라서(스포방지 ON/OFF, Spoiler Prevention ON) 폭이 빠듯하다.
void main() {
  /// [MediaQuery] 의 폭과 실제 배치 폭을 **같이** 맞춘다.
  ///
  /// 헤더는 `MediaQuery` 폭으로 scale 을 정하고 그 scale 로 내부 수치를
  /// 곱한다. 둘이 어긋나면(예: MediaQuery 800, 배치 390) scale 은 430
  /// 기준인데 배치는 390 이라 실기기에 없는 조합이 나온다.
  Widget wrap(Widget child, {required Size size, Locale locale = const Locale('ko')}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        // MediaQuery 만 바꾸면 scale 만 달라지고 실제 배치 폭은 테스트
        // 캔버스(800) 그대로다. 기기 폭을 재현하려면 폭도 함께 묶어야 한다.
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: size.width, child: child),
          ),
        ),
      ),
    );
  }

  Widget header({bool spoiler = true}) => ScheduleHeader(
    monthLabel: '2026.10',
    spoilerPreventionEnabled: () => spoiler,
    onSpoilerChanged: (_) {},
    onFilterTap: () {},
    onMonthTap: () {},
  );

  testWidgets('스포방지·필터가 오른쪽 끝에 붙는다', (tester) async {
    const size = Size(390, 844);
    await tester.pumpWidget(wrap(header(), size: size));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 월 라벨이 잘리지 않아야 한다 — '2026.10' 이 '2026…' 으로 줄면
    // 다른 달로 읽힌다. 글자가 요구하는 폭을 실제로 받았는지 본다.
    final labelText = tester.widget<Text>(find.text('2026.10'));
    final painter = TextPainter(
      text: TextSpan(text: labelText.data, style: labelText.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final intrinsic = painter.width;
    painter.dispose();
    expect(
      tester.getSize(find.text('2026.10')).width,
      greaterThanOrEqualTo(intrinsic - 0.5),
      reason: '월 라벨이 ellipsis 로 줄어들면 안 된다',
    );

    final monthRight = tester.getRect(find.text('2026.10')).right;
    final toggleLeft = tester.getRect(find.byType(NarSpoilerToggle)).left;

    // 헤더 좌우 패딩 20*scale 을 감안한 오른쪽 경계.
    final scale = size.width.clamp(320.0, 430.0) / 375;
    final contentRight = size.width - 20 * scale;

    // 토글은 월 라벨 **글자** 바로 옆이 아니라 오른쪽 영역에 있어야 한다.
    // (라벨 위젯 자체는 Expanded 라 남는 폭을 차지하지만, 그 안의 글자는
    // 왼쪽 정렬이라 글자 끝과 토글 사이가 실제로 벌어진다.)
    // 둘이 서로 겹치거나 붙어 버리지 않았는지만 본다. 간격의 정확한 값은
    // 월 라벨이 자기 폭을 다 쓰고 남은 만큼이라 폭·언어에 따라 달라진다.
    expect(
      toggleLeft - monthRight,
      greaterThan(0),
      reason: '월 라벨 글자와 스포방지가 겹치면 안 된다',
    );

    // 오른쪽 묶음의 마지막(필터 버튼 44 원형)이 콘텐츠 오른쪽 끝에 닿아야 한다.
    // 응원팀 아이콘은 이 테스트에서 안 넘겼으므로 필터가 마지막이다.
    final filterRight = tester
        .getRect(
          find.ancestor(
            of: find.byType(SvgPicture),
            matching: find.byType(Container),
          ).last,
        )
        .right;
    expect(
      filterRight,
      closeTo(contentRight, 1),
      reason: '필터 버튼이 헤더 오른쪽 끝(좌우 패딩 안쪽)에 붙어야 한다',
    );
  });

  // 가장 좁은 폭 + 라벨이 가장 긴 조합(영문 OFF)에서도 넘치면 안 된다.
  for (final size in const [Size(320.0, 568.0), Size(375.0, 812.0)]) {
    for (final locale in const [Locale('ko'), Locale('en')]) {
      for (final spoiler in const [true, false]) {
        testWidgets(
          '폭 ${size.width} ${locale.languageCode} spoiler=$spoiler 에서 overflow 가 없다',
          (tester) async {
            await tester.pumpWidget(
              wrap(header(spoiler: spoiler), size: size, locale: locale),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: '폭 ${size.width} 에서 RenderFlex overflow 가 나면 안 된다',
            );
          },
        );
      }
    }
  }
}
