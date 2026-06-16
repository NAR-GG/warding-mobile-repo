import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/game_rating.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/viewmodel/match_detail/match_detail_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

GameRatings _ratings(String gameId) => GameRatings(
      gameId: gameId,
      rateable: true,
      teams: const [],
      players: const [],
    );

void main() {
  late MockMatchDetailRepository match;
  late MockRatingRepository rating;

  setUp(() {
    match = MockMatchDetailRepository();
    rating = MockRatingRepository();
    when(() => match.fetchChampionPick(any())).thenThrow(Exception('skip'));
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('skip'));
  });

  test('load(): 현재 세트 gameId로 평점을 로드해 ratings에 채운다', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
          MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenAnswer((inv) async => _ratings(inv.positionalArguments.first as String));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();

    expect(vm.ratings, isNotNull);
    expect(vm.ratings!.gameId, 'g2');
    expect(vm.loadingRatings, isFalse);
    expect(vm.ratingsError, isNull);
  });

  test('reloadRatings(): 현재 세트 평점을 다시 가져온다', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenAnswer((inv) async => _ratings(inv.positionalArguments.first as String));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();
    await vm.reloadRatings();

    expect(vm.ratings!.gameId, 'g1');
    // 최초 load + reloadRatings = 2회 호출
    verify(() => rating.fetchGameRatings('g1', teamSide: any(named: 'teamSide')))
        .called(2);
  });

  test('selectSet(): 세트 전환 시 평점을 비우고 새 세트로 다시 로드', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
          MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenAnswer((inv) async => _ratings(inv.positionalArguments.first as String));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();
    await vm.selectSet(1);

    expect(vm.ratings!.gameId, 'g1');
  });

  test('평점 로드 실패 시 ratingsError 세팅', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('boom'));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();

    expect(vm.ratings, isNull);
    expect(vm.ratingsError, isNotNull);
    expect(vm.loadingRatings, isFalse);
  });
}
