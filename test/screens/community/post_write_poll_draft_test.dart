import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/repository/community/community_draft_repository.dart';
import 'package:warding/screens/community/post_write_screen.dart';

/// 투표 컴포저 상태(질문/선택지/복수선택/결과공개)도 임시저장 대상이어야 한다 —
/// 저장 시 함께 담기고, 드래프트를 불러오면 컴포저에 그대로 복원돼야 한다.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpWriteScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PostWriteScreen(boardTeamId: null),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillPoll(WidgetTester tester) async {
    await tester.tap(find.text('투표'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '투표 질문을 입력하세요'),
      '누가 이길까요?',
    );
    await tester.enterText(find.widgetWithText(TextField, '선택지 1'), 'A팀');
    await tester.enterText(find.widgetWithText(TextField, '선택지 2'), 'B팀');
    await tester.pump();
  }

  testWidgets('투표를 켜고 임시저장하면 투표 설정도 함께 저장된다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '투표 글');
    await tester.pump();
    await fillPoll(tester);

    await tester.tap(find.text('임시'));
    await tester.pumpAndSettle();

    final drafts = await CommunityDraftRepository().loadAll();
    expect(drafts, hasLength(1));
    expect(drafts.single.pollEnabled, isTrue);
    expect(drafts.single.pollQuestion, '누가 이길까요?');
    expect(drafts.single.pollOptions, ['A팀', 'B팀']);
  });

  testWidgets('투표만 켜고(본문 없이) 임시저장해도 저장된다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '투표만 있는 글');
    await tester.pump();
    await tester.tap(find.text('투표'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('임시'));
    await tester.pumpAndSettle();

    final drafts = await CommunityDraftRepository().loadAll();
    expect(drafts, hasLength(1));
    expect(drafts.single.pollEnabled, isTrue);
  });

  testWidgets('투표가 담긴 드래프트는 목록에서 투표 배지가 붙는다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '투표 글');
    await tester.pump();
    await fillPoll(tester);
    await tester.tap(find.text('임시'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '다른 글');
    await tester.pump();

    // 시트를 열기 전(툴바 버튼 + 컴포저 제목으로 이미 "투표" 텍스트가 있다)
    // 대비 목록 배지 하나만큼 늘어나는지로 검증한다.
    final before = find.text('투표').evaluate().length;
    await tester.tap(find.text('저장1'));
    await tester.pumpAndSettle();

    expect(find.text('투표').evaluate().length, before + 1);
  });

  testWidgets('저장n 목록에서 불러오면 투표 컴포저가 그대로 복원된다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '투표 글');
    await tester.pump();
    await fillPoll(tester);
    await tester.tap(find.text('임시'));
    await tester.pumpAndSettle();

    // 저장된 값과 다르게 덮어써서 — 로드가 실제로 원래 저장값으로 되돌리는지 검증한다.
    // (poll 컴포저를 안 건드리면 이 테스트는 저장/복원 로직 없이도 통과해버린다.)
    await tester.enterText(find.byType(TextField).first, '다른 글');
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '누가 이길까요?',
      ),
      '다른 질문',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'A팀',
      ),
      'X',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'B팀',
      ),
      'Y',
    );
    await tester.pump();

    await tester.tap(find.text('저장1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('투표 글')); // 드래프트 목록의 행
    await tester.pumpAndSettle();
    await tester.tap(find.text('불러오기')); // 덮어쓰기 확인
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '누가 이길까요?',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'A팀',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'B팀',
      ),
      findsOneWidget,
    );
  });
}
