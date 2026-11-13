import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/domain/player_subscription.dart';
import 'package:warding/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:warding/features/subscription/presentation/viewmodels/subscribed_players_viewmodel.dart';

class _MockRepo extends Mock implements SubscriptionRepository {}

class _MockAuth extends Mock implements AuthService {}

PlayerSubscription _player(String name) => PlayerSubscription(
  playerId: name.hashCode,
  playerName: name,
  playerImageUrl: '',
  role: 'MID',
  teamId: 1,
  teamCode: 'T1',
  teamName: 'T1',
  teamImageUrl: '',
  subscribed: true,
  startEnabled: true,
  endEnabled: true,
);

void main() {
  late _MockRepo repo;
  late _MockAuth auth;
  late SubscribedPlayersViewModel vm;

  setUp(() {
    repo = _MockRepo();
    auth = _MockAuth();
    vm = SubscribedPlayersViewModel(repository: repo, auth: auth);
  });

  test('생성만으로는 조회하지 않고 loading 으로 시작한다', () {
    verifyNever(() => repo.fetchSubscribedPlayers());
    expect(vm.loading, isTrue);
    expect(vm.players, isNull);
    expect(vm.total, 0);
  });

  test('조회 성공하면 목록과 수를 노출한다', () async {
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => Right([_player('Faker'), _player('Chovy')]));

    await vm.load();

    expect(vm.total, 2);
    expect(vm.loading, isFalse);
  });

  test('비회원·실패는 0명으로 두고 loading 만 끝낸다', () async {
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => const Left(UnauthorizedFailure()));
    when(() => auth.jwt).thenAnswer((_) async => null);

    await vm.load();

    expect(vm.total, 0);
    expect(vm.loading, isFalse);
  });

  test('로그아웃하면 이전 계정의 구독 선수를 버린다', () async {
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => Right([_player('Faker')]));
    await vm.load();
    expect(vm.total, 1);

    // 이후 실패 + JWT 없음 = 로그아웃
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => const Left(UnauthorizedFailure()));
    when(() => auth.jwt).thenAnswer((_) async => null);
    await vm.load();

    expect(vm.players, isNull);
    expect(vm.total, 0);
  });

  test('로그아웃이 아닌 실패는 마지막 목록을 유지한다', () async {
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => Right([_player('Faker')]));
    await vm.load();

    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => const Left(ServerFailure()));
    when(() => auth.jwt).thenAnswer((_) async => 'token');
    await vm.load();

    expect(vm.total, 1);
  });

  test('Keychain 을 못 읽은 것은 로그아웃으로 보지 않는다', () async {
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => Right([_player('Faker')]));
    await vm.load();

    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => const Left(ServerFailure()));
    when(() => auth.jwt).thenThrow(Exception('-25308'));
    await vm.load();

    expect(vm.total, 1);
  });
}
