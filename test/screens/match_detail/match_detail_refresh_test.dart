import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/screens/match_detail/match_detail_screen.dart';

import '../../support/fake_rating_repository.dart';

/// 경기 상세 당겨서 새로고침이 화면에서 실제로 걸리는지.
///
/// 뷰모델에 refresh 가 있는 것만으로는 부족하다 — CustomScrollView 의 physics 가
/// 기본값이면 내용이 짧은 탭(경기 전 잠금 안내 등)에서 스크롤 자체가 생기지 않아
/// 당겨도 아무 일이 일어나지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('아래로 당기면 새로고침 인디케이터가 뜬다', (tester) async {
    final match = MockMatchDetailRepository();
    final rating = MockRatingRepository();
    when(() => match.fetchGames(any())).thenAnswer(
      (_) async => (
        const [MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED')],
        null,
      ),
    );
    when(() => match.fetchMatch(any())).thenAnswer((_) async => null);
    when(() => match.fetchChampionPick(any())).thenThrow(Exception('skip'));
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('skip'));
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('skip'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: const MatchDetailScreen(matchId: 'm-1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byType(RefreshProgressIndicator),
      findsOneWidget,
      reason: '당겼는데 인디케이터가 없으면 새로고침이 걸리지 않은 것',
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
