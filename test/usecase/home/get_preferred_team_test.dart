import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/core/infrastructure/preference/team_preference_repository.dart';
import 'package:warding/domain/team.dart';
import 'package:warding/domain/user_profile.dart';
import 'package:warding/features/home/domain/usecases/get_preferred_team.dart';
import 'package:warding/features/onboarding/domain/repositories/onboarding_repository.dart';

class _MockAuth extends Mock implements AuthService {}

class _MockOnboarding extends Mock implements OnboardingRepository {}

class _MockTeamPrefs extends Mock implements TeamPreferenceRepository {}

const _t1 = Team(id: 1, name: 'T1', code: 'T1', imageUrl: 'https://x/t1.png');
const _gen = Team(id: 2, name: 'Gen.G', code: 'GEN', imageUrl: 'https://x/g.png');

UserProfile _me({int? favoriteTeamId}) =>
    UserProfile(id: 10, nickname: '테스터', favoriteTeamId: favoriteTeamId);

void main() {
  late _MockAuth auth;
  late _MockOnboarding onboarding;
  late _MockTeamPrefs prefs;
  late GetPreferredTeam usecase;

  setUp(() {
    auth = _MockAuth();
    onboarding = _MockOnboarding();
    prefs = _MockTeamPrefs();
    usecase = GetPreferredTeam(
      auth: auth,
      onboarding: onboarding,
      teamPreferences: prefs,
    );
  });

  test('로그인 + 응원팀 설정 → 서버 favoriteTeamId 에 해당하는 팀', () async {
    when(() => auth.fetchMe()).thenAnswer((_) async => _me(favoriteTeamId: 2));
    when(() => onboarding.fetchTeams())
        .thenAnswer((_) async => const Right([_t1, _gen]));

    expect(await usecase(), _gen);
    // 서버가 정답일 때는 로컬 캐시를 보지 않는다.
    verifyNever(() => prefs.loadPreferredTeam());
  });

  test('로그인했지만 응원팀 미설정 → null (로컬 캐시로 덮지 않는다)', () async {
    when(() => auth.fetchMe()).thenAnswer((_) async => _me());
    when(() => onboarding.fetchTeams())
        .thenAnswer((_) async => const Right([_t1, _gen]));
    // 캐시에 값이 있어도 그걸 쓰면 안 된다 — 사용자가 응원팀을 지운 경우
    // 캐시로 되살리면 지울 방법이 없어진다.
    when(() => prefs.loadPreferredTeam()).thenAnswer((_) async => _t1);

    expect(await usecase(), isNull);
    verifyNever(() => prefs.loadPreferredTeam());
  });

  test('서버 조회 실패(비로그인 등) → 로컬 캐시로 폴백', () async {
    when(() => auth.fetchMe()).thenThrow(Exception('401'));
    when(() => prefs.loadPreferredTeam()).thenAnswer((_) async => _t1);

    expect(await usecase(), _t1);
  });

  test('팀 목록 조회가 실패하면 응원팀을 못 찾은 것으로 본다', () async {
    when(() => auth.fetchMe()).thenAnswer((_) async => _me(favoriteTeamId: 2));
    when(() => onboarding.fetchTeams())
        .thenAnswer((_) async => const Left(ServerFailure()));

    expect(await usecase(), isNull);
  });

  test('서버 teamId 가 목록에 없으면 null', () async {
    when(() => auth.fetchMe()).thenAnswer((_) async => _me(favoriteTeamId: 99));
    when(() => onboarding.fetchTeams())
        .thenAnswer((_) async => const Right([_t1, _gen]));

    expect(await usecase(), isNull);
  });
}
