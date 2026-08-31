import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_detail_header.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/community_remote_post.dart';
import 'package:warding/repository/community/community_draft_repository.dart';
import 'package:warding/screens/community/post_write_screen.dart';

/// 뒤로가기 아이콘 — 작성 중인 내용이 있으면 임시저장 확인 팝업을 띄우고,
/// 선택(취소/나가기/임시저장)에 따라 다르게 동작해야 한다.
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PostWriteScreen(boardTeamId: null),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> triggerBack(WidgetTester tester) async {
    final header = tester.widget<NarDetailHeader>(
      find.byType(NarDetailHeader),
    );
    header.onBack!();
    await tester.pumpAndSettle();
  }

  testWidgets('아무것도 안 썼으면 확인 없이 바로 나간다', (tester) async {
    await pumpWriteScreen(tester);

    await triggerBack(tester);

    expect(find.byType(PostWriteScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('내용이 있으면 임시저장 확인 팝업이 뜬다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();

    await triggerBack(tester);

    expect(find.text('임시저장하시겠어요?'), findsOneWidget);
    expect(find.byType(PostWriteScreen), findsOneWidget);
  });

  testWidgets('취소를 누르면 화면에 남고 아무 것도 저장되지 않는다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();
    await triggerBack(tester);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.byType(PostWriteScreen), findsOneWidget);
    expect(find.text('제목'), findsOneWidget);
    expect(await CommunityDraftRepository().loadAll(), isEmpty);
  });

  testWidgets('나가기를 누르면 저장하지 않고 나간다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();
    await triggerBack(tester);

    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();

    expect(find.byType(PostWriteScreen), findsNothing);
    expect(await CommunityDraftRepository().loadAll(), isEmpty);
  });

  testWidgets('임시저장을 누르면 저장하고 나간다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();
    await triggerBack(tester);

    await tester.tap(find.text('임시저장'));
    await tester.pumpAndSettle();

    expect(find.byType(PostWriteScreen), findsNothing);
    final drafts = await CommunityDraftRepository().loadAll();
    expect(drafts, hasLength(1));
    expect(drafts.single.title, '제목');
  });

  testWidgets('임시저장 직후 더 안 건드리고 뒤로가면 팝업 없이 바로 나간다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();

    await tester.tap(find.text('임시')); // 헤더의 "임시" 버튼으로 저장
    await tester.pumpAndSettle();

    await triggerBack(tester);

    expect(find.text('임시저장하시겠어요?'), findsNothing);
    expect(find.byType(PostWriteScreen), findsNothing);
  });

  testWidgets('임시저장 후 내용을 더 바꾸면 뒤로갈 때 다시 팝업이 뜬다', (tester) async {
    await pumpWriteScreen(tester);
    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();
    await tester.tap(find.text('임시'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '제목 수정');
    await tester.pump();
    await triggerBack(tester);

    expect(find.text('임시저장하시겠어요?'), findsOneWidget);
  });

  testWidgets('수정 화면을 아무것도 안 바꾸고 뒤로가면 팝업 없이 바로 나간다', (tester) async {
    final edit = CommunityRemotePostDetail.fromJson({
      'id': 1,
      'title': '원본 제목',
      'body': '원본 본문',
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PostWriteScreen(boardTeamId: null, edit: edit),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await triggerBack(tester);

    expect(find.text('임시저장하시겠어요?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
