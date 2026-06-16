import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/game_rating.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/viewmodel/player_rating/player_rating_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

PlayerRatingDetail _detail({
  required String gameId,
  required int participantId,
  int page = 0,
  int totalPages = 1,
  List<Review> reviews = const [],
  MyRating? myRating,
}) =>
    PlayerRatingDetail(
      gameId: gameId,
      rateable: true,
      player: RatingPlayerDetail(
        participantId: participantId,
        playerId: 42,
        playerName: 'Faker',
        playerImageUrl: '',
        teamSide: 'BLUE',
        role: 'MID',
        championName: 'Galio',
        kills: 4,
        deaths: 1,
        assists: 7,
      ),
      averageRating: 4.5,
      ratingCount: 23,
      distribution: const [],
      myRating: myRating,
      reviews: reviews,
      page: page,
      size: 20,
      totalElements: 40,
      totalPages: totalPages,
    );

Review _review(int id) => Review(
      ratingId: id,
      nickname: 'u$id',
      rating: 5,
      mine: false,
    );

const _games = [
  MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
  MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
];

PlayerRatingViewModel _vm(MockRatingRepository repo) => PlayerRatingViewModel(
      gameId: 'g1',
      participantId: 3,
      playerId: 42,
      games: _games,
      currentSet: 1,
      repository: repo,
    );

void main() {
  late MockRatingRepository repo;
  setUp(() => repo = MockRatingRepository());

  test('load(): 상세를 받아 detail·reviews 채움', () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(
              gameId: 'g1',
              participantId: 3,
              reviews: [_review(1), _review(2)],
            ));

    final vm = _vm(repo);
    await vm.load();

    expect(vm.detail, isNotNull);
    expect(vm.reviews, hasLength(2));
    expect(vm.loading, isFalse);
  });

  test('loadMoreReviews(): 다음 페이지를 누적', () async {
    when(() => repo.fetchPlayerRating('g1', 3, page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => _detail(
            gameId: 'g1',
            participantId: 3,
            page: 0,
            totalPages: 2,
            reviews: [_review(1)]));
    when(() => repo.fetchPlayerRating('g1', 3, page: 1, size: any(named: 'size')))
        .thenAnswer((_) async => _detail(
            gameId: 'g1',
            participantId: 3,
            page: 1,
            totalPages: 2,
            reviews: [_review(2)]));

    final vm = _vm(repo);
    await vm.load();
    expect(vm.reviews, hasLength(1));

    await vm.loadMoreReviews();
    expect(vm.reviews.map((r) => r.ratingId), [1, 2]);
  });

  test('selectSet(): 새 세트 평점목록에서 playerId로 participantId 재해석 후 로드',
      () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g1', participantId: 3));
    when(() => repo.fetchGameRatings('g2', teamSide: any(named: 'teamSide')))
        .thenAnswer((_) async => GameRatings(
              gameId: 'g2',
              rateable: true,
              teams: const [],
              players: const [
                RatingPlayer(
                  participantId: 8,
                  playerId: 42,
                  playerName: 'Faker',
                  playerImageUrl: '',
                  teamSide: 'BLUE',
                  role: 'MID',
                  championName: 'Ahri',
                  averageRating: 4,
                  ratingCount: 10,
                  myRating: 0,
                ),
              ],
            ));
    when(() => repo.fetchPlayerRating('g2', 8,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g2', participantId: 8));

    final vm = _vm(repo);
    await vm.load();
    await vm.selectSet(2);

    expect(vm.currentSet, 2);
    expect(vm.detail!.gameId, 'g2');
    verify(() => repo.fetchPlayerRating('g2', 8,
        page: any(named: 'page'), size: any(named: 'size'))).called(1);
  });

  test('saveMyRating(): 저장 후 상세를 다시 로드', () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g1', participantId: 3));
    when(() => repo.putMyRating('g1', 3,
            rating: any(named: 'rating'), comment: any(named: 'comment')))
        .thenAnswer((_) async => const MyRating(ratingId: 9, rating: 5));

    final vm = _vm(repo);
    await vm.load();
    await vm.saveMyRating(5, '굿');

    verify(() => repo.putMyRating('g1', 3, rating: 5, comment: '굿')).called(1);
    verify(() => repo.fetchPlayerRating('g1', 3,
        page: any(named: 'page'), size: any(named: 'size'))).called(2);
  });

  test('deleteMyRating(): 삭제 후 상세를 다시 로드', () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g1', participantId: 3));
    when(() => repo.deleteMyRating('g1', 3)).thenAnswer((_) async {});

    final vm = _vm(repo);
    await vm.load();
    await vm.deleteMyRating();

    verify(() => repo.deleteMyRating('g1', 3)).called(1);
  });
}
