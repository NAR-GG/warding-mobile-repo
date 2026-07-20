// test/viewmodel/onboarding/onboarding_viewmodel_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/onboarding_selection.dart';
import 'package:warding/model/team.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/onboarding/onboarding_repository.dart';
import 'package:warding/repository/preference/onboarding_preference_repository.dart';
import 'package:warding/repository/preference/team_preference_repository.dart';
import 'package:warding/viewmodel/onboarding/onboarding_viewmodel.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockTeamPreferenceRepository extends Mock
    implements TeamPreferenceRepository {}

class MockOnboardingPreferenceRepository extends Mock
    implements OnboardingPreferenceRepository {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOnboardingRepository repo;
  late MockTeamPreferenceRepository teamPrefs;
  late MockOnboardingPreferenceRepository onboardingPrefs;
  late MockAuthService auth;

  // goNext() 가 알림 단계 진입 시 permission_handler 네이티브 채널로 현재
  // 권한 상태를 묻는다. 테스트 환경엔 네이티브 구현이 없으니 직접 목킹한다.
  // 기본값 0(denied) — 기존 테스트들의 '명시적으로 markNotificationDone
  // 호출' 흐름을 그대로 유지하기 위해서다.
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  var mockedPermissionStatus = 0;
  void setMockedPermissionStatus(int status) => mockedPermissionStatus = status;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(permissionChannel, (call) async {
    if (call.method == 'checkPermissionStatus') return mockedPermissionStatus;
    return null;
  });

  setUpAll(() {
    registerFallbackValue(const OnboardingSelection(teamId: 0));
    registerFallbackValue(<int>[]);
    registerFallbackValue(const Team(id: 0, name: '', code: '', imageUrl: ''));
  });

  setUp(() {
    mockedPermissionStatus = 0;
    repo = MockOnboardingRepository();
    teamPrefs = MockTeamPreferenceRepository();
    onboardingPrefs = MockOnboardingPreferenceRepository();
    auth = MockAuthService();

    when(() => repo.fetchLeagues()).thenAnswer((_) async => const []);
    when(() => repo.fetchTeams()).thenAnswer(
        (_) async => const [Team(id: 1, name: 'T1', code: 'T1', imageUrl: '')]);
    when(() => repo.fetchPlayers(
          year: any(named: 'year'),
          teamId: any(named: 'teamId'),
        )).thenAnswer((_) async => const []);
    when(() => teamPrefs.savePreferredTeam(any())).thenAnswer((_) async {});
    when(() => teamPrefs.clearPreferredTeam()).thenAnswer((_) async {});
    when(() => onboardingPrefs.saveSelection(any())).thenAnswer((_) async {});
    when(() => onboardingPrefs.clear()).thenAnswer((_) async {});
  });

  OnboardingViewModel build() => OnboardingViewModel(
        repository: repo,
        onFinish: () {},
        teamPreferences: teamPrefs,
        onboardingPreferences: onboardingPrefs,
        authService: auth,
      );

  // 온보딩 마지막 단계까지 진행시켜 _savePreferences 가 실행되게 한다.
  Future<void> completeFlow(OnboardingViewModel vm) async {
    vm.selectLeague('LCK');
    await vm.goNext(); // league -> team
    vm.selectTeam(1);
    await vm.goNext(); // team -> player (loadPlayers)
    vm.togglePlayer(5);
    await vm.goNext(); // player -> notification
    vm.markNotificationDone();
    await vm.goNext(); // notification -> finish (_savePreferences)
  }

  test('비회원이면 selection을 로컬 저장한다', () async {
    when(() => auth.jwt).thenAnswer((_) async => null);

    final vm = build();
    await completeFlow(vm);

    final sel = verify(() => onboardingPrefs.saveSelection(captureAny()))
        .captured
        .single as OnboardingSelection;
    expect(sel.leagueName, 'LCK');
    expect(sel.teamId, 1);
    expect(sel.playerIds, [5]);
    verifyNever(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        ));
    verify(() => teamPrefs.savePreferredTeam(any())).called(1);
  });

  test('회원이면 서버 저장하고 로컬 selection을 지운다', () async {
    when(() => auth.jwt).thenAnswer((_) async => 'jwt-token');
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenAnswer((_) async {});

    final vm = build();
    await completeFlow(vm);

    verify(() => repo.completeOnboarding(
          favoriteLeagueName: 'LCK',
          favoriteTeamId: 1,
          favoritePlayerIds: [5],
          jwt: 'jwt-token',
        )).called(1);
    verify(() => onboardingPrefs.clear()).called(1);
    verifyNever(() => onboardingPrefs.saveSelection(any()));
    verify(() => teamPrefs.savePreferredTeam(any())).called(1);
  });

  test('회원이고 서버 저장 실패하면 로컬 selection을 지우지 않는다', () async {
    when(() => auth.jwt).thenAnswer((_) async => 'jwt-token');
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenThrow(Exception('network'));

    final vm = build();
    await completeFlow(vm);

    verifyNever(() => onboardingPrefs.clear());
    verifyNever(() => onboardingPrefs.saveSelection(any()));
  });

  test('skip()은 로컬 selection을 지운다', () async {
    final vm = build();
    await vm.skip();
    verify(() => onboardingPrefs.clear()).called(1);
  });

  test('알림 권한이 이미 허용돼 있으면 알림 단계를 건너뛰고 곧장 완료한다', () async {
    setMockedPermissionStatus(1); // granted
    when(() => auth.jwt).thenAnswer((_) async => null);

    final vm = build();
    vm.selectLeague('LCK');
    await vm.goNext(); // league -> team
    vm.selectTeam(1);
    await vm.goNext(); // team -> player
    vm.togglePlayer(5);
    await vm.goNext(); // player -> notification(이미 허용) -> 곧장 완료

    expect(vm.notificationDone, isTrue);
    verify(() => onboardingPrefs.saveSelection(any())).called(1);
    verify(() => teamPrefs.savePreferredTeam(any())).called(1);
  });
}
