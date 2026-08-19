import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/screens/match_list/component/match_card.dart';

import '../../support/l10n_test_setup.dart';

/// 스포방지 오버레이의 흐림 처리.
///
/// 흐림은 시안 요구사항이라 없애면 안 되지만, 예전 구현([BackdropFilter])은
/// 뒤 레이어 전체를 샘플링해서 뷰포트에 뜬 카드 수만큼 비용이 곱해졌다.
/// 지금은 흐려야 할 대상(0:0 더미)에만 [ImageFiltered] 를 건다. 둘 다
/// 화면상 결과는 같아 보이므로, 어느 쪽을 쓰는지 테스트로 못박아 둔다.
void main() {
  Widget card({required bool spoilerPreventionEnabled}) => MatchCard(
        matchId: 'match-1',
        time: '18:00',
        label: '2026 LCK Spring',
        homeName: 'T1',
        awayName: 'GEN',
        homeScore: 2,
        awayScore: 1,
        leagueInfo: 'LCK',
        spoilerPreventionEnabled: spoilerPreventionEnabled,
      );

  testWidgets('스포방지 ON 이면 흐림이 걸린다 — 단, BackdropFilter 로는 아니다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        card(spoilerPreventionEnabled: true),
        size: const Size(390, 844),
      ),
    );

    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(
      find.byType(BackdropFilter),
      findsNothing,
      reason: '카드마다 뒤 레이어를 샘플링하면 스크롤 프레임이 무너진다',
    );
  });

  testWidgets('스포방지 OFF 면 흐림 자체가 없다', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithL10n(
        card(spoilerPreventionEnabled: false),
        size: const Size(390, 844),
      ),
    );

    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('가장 좁은 화면(320)에서도 오버레이가 가로로 넘치지 않는다', (
    WidgetTester tester,
  ) async {
    // 더미 스코어는 시안 크기 그대로면 칸(116)보다 넓어진다. 예전엔 오버레이의
    // ClipRRect 가 가려 줬지만 흐림이 더미 쪽으로 내려온 뒤로는 여기서 직접
    // 묶어야 한다 — 놓치면 노란 줄무늬 overflow 가 카드에 그대로 뜬다.
    await tester.pumpWidget(
      wrapWithL10n(
        card(spoilerPreventionEnabled: true),
        size: const Size(320, 844),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
