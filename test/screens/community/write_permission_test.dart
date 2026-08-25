import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/community_post.dart';
import 'package:warding/screens/community/community_dummy.dart';
import 'package:warding/screens/community/community_permission.dart';
import 'package:warding/screens/community/community_screen.dart';

/// 커뮤니티의 유일한 비자명 로직은 "여기에 글을 쓸 수 있는가" 하나다.
/// 나머지(목록·상세 렌더)는 더미를 그대로 그리는 것뿐이라 테스트하지 않는다.
void main() {
  group('canWriteToBoard', () {
    test('회원은 전체 게시판에 쓸 수 있다', () {
      expect(
        canWriteToBoard(
          loggedIn: true,
          myTeamId: 39,
          boardId: CommunityBoard.allId,
        ),
        isTrue,
      );
    });

    test('회원은 자기 응원팀 게시판에 쓸 수 있다', () {
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: 39, boardId: 39),
        isTrue,
      );
    });

    test('회원도 다른 팀 게시판에는 못 쓴다', () {
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: 39, boardId: 23),
        isFalse,
      );
    });

    test('응원팀 미설정 회원은 전체만 쓰고 팀 게시판은 못 쓴다', () {
      expect(
        canWriteToBoard(
          loggedIn: true,
          myTeamId: null,
          boardId: CommunityBoard.allId,
        ),
        isTrue,
      );
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: null, boardId: 39),
        isFalse,
      );
    });

    test('비회원은 전체 게시판도 못 쓴다', () {
      expect(
        canWriteToBoard(
          loggedIn: false,
          myTeamId: 39,
          boardId: CommunityBoard.allId,
        ),
        isFalse,
      );
      expect(
        canWriteToBoard(loggedIn: false, myTeamId: 39, boardId: 39),
        isFalse,
      );
    });
  });

  group('CommunityScreen', () {
    Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: child,
    );

    testWidgets('전체·우리팀 탭에서는 글쓰기가 열리고, 다른팀 탭에서는 잠금 바가 뜬다', (
      tester,
    ) async {
      // 더미 상수가 '로그인 + T1 응원' 이 아니면 이 시나리오 자체가 성립하지 않는다.
      expect(kDummyLoggedIn, isTrue);
      expect(kDummyMyTeamId, 39); // T1 (실제 팀 id)

      await tester.pumpWidget(wrap(const CommunityScreen()));
      await tester.pumpAndSettle();

      // 전체 탭 — 쓸 수 있다.
      expect(find.text('글쓰기'), findsOneWidget);

      await tester.tap(find.text('우리팀'));
      await tester.pumpAndSettle();
      expect(find.text('글쓰기'), findsOneWidget);

      // 다른팀 탭은 읽기 전용이라 글쓰기가 사라지고 이유가 뜬다.
      await tester.tap(find.text('다른팀'));
      await tester.pumpAndSettle();
      expect(find.text('글쓰기'), findsNothing);
      expect(find.text('Gen.G 팬만 글을 쓸 수 있어요.'), findsOneWidget);
      expect(find.text('전체로 가기'), findsOneWidget);
    });

    testWidgets('다른팀 탭에는 내 응원팀 칩이 없다', (tester) async {
      await tester.pumpWidget(wrap(const CommunityScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다른팀'));
      await tester.pumpAndSettle();

      // 내 팀(T1)은 '우리팀' 탭이 전담하므로 여기 레일에 다시 나오면 안 된다.
      expect(find.text('T1'), findsNothing);
      expect(find.text('Gen.G'), findsOneWidget);
    });

    testWidgets('잠금 바의 전체로 가기를 누르면 전체 탭으로 돌아온다', (tester) async {
      await tester.pumpWidget(wrap(const CommunityScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다른팀'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('전체로 가기'));
      await tester.pumpAndSettle();

      expect(find.text('글쓰기'), findsOneWidget);
    });

    testWidgets('좌우로 밀어 탭을 옮길 수 있다', (tester) async {
      await tester.pumpWidget(wrap(const CommunityScreen()));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();

      // 전체 → 우리팀. 우리팀도 쓸 수 있으므로 글쓰기는 그대로다.
      expect(find.text('글쓰기'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();

      // 우리팀 → 다른팀. 여기서는 잠긴다.
      expect(find.text('글쓰기'), findsNothing);
      expect(find.text('전체로 가기'), findsOneWidget);
    });
  });
}
