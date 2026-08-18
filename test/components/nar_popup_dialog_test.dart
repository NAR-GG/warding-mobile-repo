import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_button.dart';
import 'package:warding/components/nar_popup_dialog.dart';
import 'package:warding/styles/app_colors.dart';

/// [showNarPopup] 을 띄우는 최소 화면.
Widget _host({
  String? gradientLabel,
  String? title,
  String? message,
  Widget? child,
  List<NarPopupAction> actions = const [],
  void Function(String?)? onClosed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await showNarPopup<String>(
              context: context,
              gradientLabel: gradientLabel,
              title: title,
              message: message,
              actions: actions,
              child: child,
            );
            onClosed?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('헤더·콘텐츠·버튼을 모두 넘기면 함께 그려진다', (tester) async {
    await tester.pumpWidget(
      _host(
        gradientLabel: '와딩 200% 즐기기',
        title: '환영해요!',
        message: '언제든 다시 볼 수 있어요.',
        child: const SizedBox(width: 185, height: 331),
        actions: [
          NarPopupAction(label: '다시 보지 않기', onPressed: () {}),
          NarPopupAction(
            label: '가이드 보기',
            variant: NarButtonVariant.type1,
            onPressed: () {},
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('와딩 200% 즐기기'), findsOneWidget);
    expect(find.text('환영해요!'), findsOneWidget);
    expect(find.text('언제든 다시 볼 수 있어요.'), findsOneWidget);
    expect(find.byType(NarButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('버튼이 눌리면 그 버튼이 정한 값으로 닫힌다', (tester) async {
    String? closed;
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogContext = context;
                closed = await showNarPopup<String>(
                  context: context,
                  title: '제목',
                  actions: [
                    NarPopupAction(
                      label: '확인',
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('confirmed'),
                    ),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(closed, 'confirmed');
  });

  testWidgets('넘기지 않은 영역은 그리지 않는다 — 콘텐츠만 있는 팝업', (tester) async {
    await tester.pumpWidget(
      _host(child: const Text('본문만')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('본문만'), findsOneWidget);
    expect(find.byType(NarButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('뒷배경은 검정 70% 로 깔린다', (tester) async {
    await tester.pumpWidget(_host(title: '제목'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final barrier = tester.widget<ModalBarrier>(
      find.byType(ModalBarrier).last,
    );
    expect(barrier.color, AppColors.narPopupBarrier);
    expect(AppColors.narPopupBarrier, const Color(0xB3000000));
  });

  testWidgets('콘텐츠가 길어도 넘치지 않고 스크롤된다', (tester) async {
    await tester.pumpWidget(
      _host(
        title: '제목',
        // 화면(600)보다 훨씬 큰 콘텐츠.
        child: const SizedBox(height: 2000, child: Text('긴 본문')),
        actions: [NarPopupAction(label: '닫기', onPressed: () {})],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 오버플로는 렌더 예외로 잡힌다.
    expect(tester.takeException(), isNull);
    expect(find.text('제목'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
  });
}
