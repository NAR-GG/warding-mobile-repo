import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/search_select_box.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/viewmodel/match_list/match_list_viewmodel.dart';

/// 경기 리스트 필터의 시즌 선택지가 **화면에 실제로** 올해를 포함하는지 본다.
///
/// ViewModel 단위 테스트(`match_list_viewmodel_test.dart`)는 목록 계산만
/// 확인한다. 여기서는 그 목록이 실제 위젯(`SearchSelectBox`)까지 전달돼
/// 사용자가 고를 수 있는 상태인지를 확인한다 — 예전처럼 목록이 상수로 박혀
/// 있으면 해가 바뀌는 순간 올해가 선택지에서 빠지는데, 그 상태에서도
/// ViewModel 테스트만으로는 화면 연결이 끊긴 걸 못 잡는다.
void main() {
  Future<void> pumpSeasonBox(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchSelectBox(
            options: MatchListViewModel.fallbackSeasons,
            value: MatchListViewModel.fallbackSeasons.last,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('시즌 박스에 올해가 선택돼 있다', (tester) async {
    await pumpSeasonBox(tester);

    expect(find.text('${DateTime.now().year}'), findsOneWidget);
  });

  testWidgets('선택지를 펼치면 올해·작년이 모두 보인다', (tester) async {
    await pumpSeasonBox(tester);

    await tester.tap(find.byType(SearchSelectBox));
    await tester.pumpAndSettle();

    final thisYear = DateTime.now().year;
    expect(find.text('$thisYear'), findsWidgets);
    expect(find.text('${thisYear - 1}'), findsWidgets);
  });
}
