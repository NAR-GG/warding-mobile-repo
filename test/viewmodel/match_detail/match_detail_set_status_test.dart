import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/viewmodel/match_detail/match_detail_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

void main() {
  late MockMatchDetailRepository match;
  late MockRatingRepository rating;

  setUp(() {
    match = MockMatchDetailRepository();
    rating = MockRatingRepository();
    when(() => match.fetchChampionPick(any())).thenThrow(Exception('skip'));
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('skip'));
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('skip'));
  });

  MatchDetailViewModel vmFor(List<MatchGame> games) {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => (games, null));
    return MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
  }

  // 이슈 #73: 1세트 종료 후 2세트 시작 전, 1세트를 보면 "진행중"이 떴다.
  test('종료된 세트를 보고 있으면 isCurrentSetLive == false', () async {
    final vm = vmFor(const [
      MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
      MatchGame(gameId: 'g2', gameOrder: 2, status: 'SCHEDULED'),
    ]);
    await vm.load();
    await vm.selectSet(1); // 종료된 1세트 선택

    expect(vm.currentSetStatus, 'ENDED');
    expect(vm.isCurrentSetLive, isFalse);
  });

  test('진행 중인 세트를 보고 있으면 isCurrentSetLive == true', () async {
    final vm = vmFor(const [
      MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
      MatchGame(gameId: 'g2', gameOrder: 2, status: 'LIVE'),
    ]);
    await vm.load(); // 기본 선택: LIVE 세트(2세트)

    expect(vm.isCurrentSetLive, isTrue);
  });
}
