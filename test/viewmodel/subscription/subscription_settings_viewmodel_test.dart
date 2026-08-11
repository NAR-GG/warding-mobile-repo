import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/viewmodel/subscription/subscription_settings_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

PlayerSubscription _player(int id, {String? name, String role = 'MID'}) =>
    PlayerSubscription(
      playerId: id,
      playerName: name ?? 'P$id',
      playerImageUrl: '',
      role: role,
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

  test('load(): 전체 로스터를 한 번에 받도록 size=200 으로 요청한다', () async {
    when(() => repo.searchAvailablePlayers(query: '', page: 0, size: 200))
        .thenAnswer(
      (_) async => _page(
        content: [for (var i = 0; i < 102; i++) _player(i)],
        page: 0,
        totalPages: 1,
        totalElements: 102,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();

    expect(vm.availablePlayers, hasLength(102));
    expect(vm.hasMorePlayers, isFalse);
    verify(() => repo.searchAvailablePlayers(query: '', page: 0, size: 200))
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

  group('선수 정렬', () {
    test('기본 정렬 모드는 position 이다', () {
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async =>
            _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );
      final vm = SubscriptionSettingsViewModel(repository: repo);
      expect(vm.sortMode, PlayerSortMode.position);
    });

    test('포지션순: TOP→JUNGLE→MID→ADC→SUPPORT, 동일 포지션은 이름 오름차순', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'Zeus', role: 'top'), // 대소문자 무시
            _player(2, name: 'Faker', role: 'MID'),
            _player(3, name: 'Gumayusi', role: 'ADC'),
            _player(4, name: 'Oner', role: 'Jungle'),
            _player(5, name: 'Keria', role: 'SUPPORT'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async =>
            _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();

      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Zeus', 'Oner', 'Faker', 'Gumayusi', 'Keria']);
    });

    test('포지션순: role 이 비어있으면 맨 뒤로 밀린다', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'Faker', role: 'MID'),
            _player(2, name: 'Unranked', role: ''),
            _player(3, name: 'Zeus', role: 'TOP'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async =>
            _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();

      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Zeus', 'Faker', 'Unranked']);
    });

    test('setSortMode(name): 이름 오름차순(대소문자 무시)으로 바뀌고 알린다', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'zeus', role: 'TOP'),
            _player(2, name: 'Faker', role: 'MID'),
            _player(3, name: 'Gumayusi', role: 'ADC'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async =>
            _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();

      var notified = false;
      vm.addListener(() => notified = true);
      vm.setSortMode(PlayerSortMode.name);

      expect(notified, isTrue);
      expect(vm.sortMode, PlayerSortMode.name);
      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Faker', 'Gumayusi', 'zeus']);
    });

    test('togglePlayer(): 구독 추가 후에도 정렬된 위치에 들어간다', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'Faker', role: 'MID'),
            _player(2, name: 'Zeus', role: 'TOP'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async => _page(
          content: [
            _player(1, name: 'Faker', role: 'MID').copyWith(subscribed: true),
            _player(2, name: 'Zeus', role: 'TOP').copyWith(subscribed: true),
            _player(3, name: 'Oner', role: 'JUNGLE'),
          ],
          page: 0,
          totalPages: 1,
          totalElements: 3,
        ),
      );
      when(() => repo.subscribePlayer(3))
          .thenAnswer((_) async => _player(3, name: 'Oner', role: 'JUNGLE'));

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();
      await vm.togglePlayer(3, false);

      // 포지션순: Zeus(TOP) → Oner(JUNGLE) → Faker(MID). 맨 끝에 그냥 붙지 않아야 한다.
      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Zeus', 'Oner', 'Faker']);
    });
  });
}
