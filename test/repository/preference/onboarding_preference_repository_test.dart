import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/onboarding_selection.dart';
import 'package:warding/repository/preference/onboarding_preference_repository.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late OnboardingPreferenceRepository repo;

  setUp(() {
    storage = MockSecureStorage();
    repo = OnboardingPreferenceRepository(storage: storage);
  });

  test('saveSelection: onboarding_selection 키로 JSON을 write 한다', () async {
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});

    await repo.saveSelection(
      const OnboardingSelection(leagueName: 'LCK', teamId: 1, playerIds: [10]),
    );

    final value = verify(() => storage.write(
          key: 'onboarding_selection',
          value: captureAny(named: 'value'),
        )).captured.single as String;
    final json = jsonDecode(value) as Map<String, dynamic>;
    expect(json['teamId'], 1);
    expect(json['leagueName'], 'LCK');
    expect(json['playerIds'], [10]);
  });

  test('loadSelection: 저장값을 복원한다', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode(
        const OnboardingSelection(teamId: 3, playerIds: [7]).toJson(),
      ),
    );

    final sel = await repo.loadSelection();
    expect(sel, isNotNull);
    expect(sel!.teamId, 3);
    expect(sel.playerIds, [7]);
  });

  test('loadSelection: 값이 없으면 null', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    expect(await repo.loadSelection(), isNull);
  });

  test('loadSelection: 손상된 값이면 null', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'not-json');
    expect(await repo.loadSelection(), isNull);
  });

  test('clear: onboarding_selection 키를 delete 한다', () async {
    when(() => storage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    await repo.clear();
    verify(() => storage.delete(key: 'onboarding_selection')).called(1);
  });
}
