import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/onboarding_selection.dart';

void main() {
  test('toJson/fromJson 라운드트립', () {
    const sel = OnboardingSelection(
      leagueName: 'LCK',
      teamId: 1,
      playerIds: [10, 20],
    );
    final restored = OnboardingSelection.fromJson(
      jsonDecode(jsonEncode(sel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.leagueName, 'LCK');
    expect(restored.teamId, 1);
    expect(restored.playerIds, [10, 20]);
  });

  test('leagueName 없이도(기본 playerIds) 복원된다', () {
    const sel = OnboardingSelection(teamId: 2);
    final restored = OnboardingSelection.fromJson(
      jsonDecode(jsonEncode(sel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.leagueName, isNull);
    expect(restored.teamId, 2);
    expect(restored.playerIds, isEmpty);
  });
}
