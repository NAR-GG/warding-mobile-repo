// test/repository/onboarding/onboarding_sync_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/onboarding_selection.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/onboarding/onboarding_repository.dart';
import 'package:warding/repository/onboarding/onboarding_sync_service.dart';
import 'package:warding/repository/preference/onboarding_preference_repository.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockOnboardingPreferenceRepository extends Mock
    implements OnboardingPreferenceRepository {}

void main() {
  late MockOnboardingRepository repo;
  late MockOnboardingPreferenceRepository prefs;
  late OnboardingSyncService service;

  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    repo = MockOnboardingRepository();
    prefs = MockOnboardingPreferenceRepository();
    service = OnboardingSyncService(repository: repo, preferences: prefs);
    when(() => prefs.clear()).thenAnswer((_) async {});
  });

  void stubComplete() {
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenAnswer((_) async {});
  }

  test('서버가 onboarded면 로컬을 지우고 true', () async {
    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'j', isOnboarded: true),
    );
    expect(result, isTrue);
    verify(() => prefs.clear()).called(1);
    verifyNever(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        ));
  });

  test('미onboarded + 로컬 selection 있으면 전송하고 지우고 true', () async {
    when(() => prefs.loadSelection()).thenAnswer(
      (_) async =>
          const OnboardingSelection(leagueName: 'LCK', teamId: 1, playerIds: [5]),
    );
    stubComplete();

    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'jwt-token', isOnboarded: false),
    );

    expect(result, isTrue);
    verify(() => repo.completeOnboarding(
          favoriteLeagueName: 'LCK',
          favoriteTeamId: 1,
          favoritePlayerIds: [5],
          jwt: 'jwt-token',
        )).called(1);
    verify(() => prefs.clear()).called(1);
  });

  test('미onboarded + 로컬 selection 없으면 false (전송 안 함)', () async {
    when(() => prefs.loadSelection()).thenAnswer((_) async => null);

    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'j', isOnboarded: false),
    );

    expect(result, isFalse);
    verifyNever(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        ));
  });

  test('전송 실패하면 로컬을 지우지 않고 false', () async {
    when(() => prefs.loadSelection()).thenAnswer(
      (_) async => const OnboardingSelection(teamId: 1),
    );
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenThrow(Exception('network'));

    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'j', isOnboarded: false),
    );

    expect(result, isFalse);
    verifyNever(() => prefs.clear());
  });
}
