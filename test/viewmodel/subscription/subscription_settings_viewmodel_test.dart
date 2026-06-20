import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/viewmodel/subscription/subscription_settings_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

PlayerSubscription _player(int id) => PlayerSubscription(
      playerId: id,
      playerName: 'P$id',
      playerImageUrl: '',
      role: 'MID',
      teamId: 1,
      teamCode: 'T1',
      teamName: 'Team1',
      teamImageUrl: '',
      subscribed: false,
    );

PlayerPage _page({
  required List<PlayerSubscription> content,
  required int page,
  required int totalPages,
  required int totalElements,
}) =>
    PlayerPage(
      content: content,
      page: page,
      size: 20,
      totalElements: totalElements,
      totalPages: totalPages,
    );

void main() {
  late MockSubscriptionRepository repo;

  setUp(() {
    repo = MockSubscriptionRepository();
    when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => const []);
    when(() => repo.fetchAvailableTeams()).thenAnswer((_) async => const []);
  });

  test('load(): 첫 페이지 선수와 전체 인원을 채운다', () async {
    when(() => repo.searchAvailablePlayers(
        query: '', page: 0, size: any(named: 'size'))).thenAnswer(
      (_) async => _page(
        content: [_player(1)],
        page: 0,
        totalPages: 3,
        totalElements: 42,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();

    expect(vm.availablePlayers, hasLength(1));
    expect(vm.availablePlayersTotal, 42);
    expect(vm.hasMorePlayers, isTrue);
  });

  test('load(): 전체 로스터를 한 번에 받도록 size=100 으로 요청한다', () async {
    when(() => repo.searchAvailablePlayers(query: '', page: 0, size: 100))
        .thenAnswer(
      (_) async => _page(
        content: [for (var i = 0; i < 64; i++) _player(i)],
        page: 0,
        totalPages: 1,
        totalElements: 64,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();

    expect(vm.availablePlayers, hasLength(64));
    expect(vm.hasMorePlayers, isFalse);
    verify(() => repo.searchAvailablePlayers(query: '', page: 0, size: 100))
        .called(greaterThanOrEqualTo(1));
  });

  test('loadMorePlayers(): 다음 페이지를 누적한다', () async {
    when(() => repo.searchAvailablePlayers(
        query: '', page: 0, size: any(named: 'size'))).thenAnswer(
      (_) async => _page(
        content: [_player(1)],
        page: 0,
        totalPages: 2,
        totalElements: 2,
      ),
    );
    when(() => repo.searchAvailablePlayers(
        query: '', page: 1, size: any(named: 'size'))).thenAnswer(
      (_) async => _page(
        content: [_player(2)],
        page: 1,
        totalPages: 2,
        totalElements: 2,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();
    await vm.loadMorePlayers();

    expect(vm.availablePlayers.map((p) => p.playerId), [1, 2]);
    expect(vm.hasMorePlayers, isFalse);
  });

  test('loadMorePlayers(): 마지막 페이지면 더 부르지 않는다', () async {
    when(() => repo.searchAvailablePlayers(
        query: '', page: 0, size: any(named: 'size'))).thenAnswer(
      (_) async => _page(
        content: [_player(1)],
        page: 0,
        totalPages: 1,
        totalElements: 1,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();
    await vm.loadMorePlayers();

    expect(vm.hasMorePlayers, isFalse);
    verifyNever(() => repo.searchAvailablePlayers(
        query: '', page: 1, size: any(named: 'size')));
  });

  test('searchPlayers(): 페이지네이션을 리셋하고 새 결과로 교체한다', () async {
    when(() => repo.searchAvailablePlayers(
        query: '', page: 0, size: any(named: 'size'))).thenAnswer(
      (_) async => _page(
        content: [_player(1)],
        page: 0,
        totalPages: 2,
        totalElements: 30,
      ),
    );
    when(() => repo.searchAvailablePlayers(
        query: 'Faker', page: 0, size: any(named: 'size'))).thenAnswer(
      (_) async => _page(
        content: [_player(99)],
        page: 0,
        totalPages: 1,
        totalElements: 1,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();
    await vm.searchPlayers('Faker');

    expect(vm.availablePlayers.map((p) => p.playerId), [99]);
    expect(vm.availablePlayersTotal, 1);
    expect(vm.hasMorePlayers, isFalse);
  });
}
