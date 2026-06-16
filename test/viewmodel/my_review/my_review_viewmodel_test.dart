import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/my_rating_list.dart';
import 'package:warding/viewmodel/my_review/my_review_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

MyRatingItem _item(int id, DateTime created) => MyRatingItem(
      ratingId: id,
      gameId: 'g$id',
      participantId: id,
      playerId: id,
      playerName: 'P$id',
      playerImageUrl: '',
      teamSide: 'BLUE',
      role: 'MID',
      championName: 'C',
      rating: 5,
      createdAt: created,
    );

void main() {
  late MockRatingRepository repo;
  setUp(() => repo = MockRatingRepository());

  test('load(): 항목·누적 건수 채움', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(1, DateTime(2026, 4, 20))],
              page: 0,
              size: 20,
              totalElements: 3,
              totalPages: 1,
            ));

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();

    expect(vm.items, hasLength(1));
    expect(vm.totalElements, 3);
    expect(vm.loading, isFalse);
  });

  test('grouped: createdAt 기준 YYYY.MM.DD 로 묶고 최신 날짜 우선', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [
                _item(1, DateTime(2026, 4, 20, 10)),
                _item(2, DateTime(2026, 4, 19, 9)),
                _item(3, DateTime(2026, 4, 20, 8)),
              ],
              page: 0,
              size: 20,
              totalElements: 3,
              totalPages: 1,
            ));

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();

    final keys = vm.grouped.keys.toList();
    expect(keys, ['2026.04.20', '2026.04.19']);
    expect(vm.grouped['2026.04.20'], hasLength(2));
  });

  test('loadMore(): 다음 페이지 누적', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(1, DateTime(2026, 4, 20))],
              page: 0,
              size: 20,
              totalElements: 2,
              totalPages: 2,
            ));
    when(() => repo.fetchMyRatings(page: 1, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(2, DateTime(2026, 4, 19))],
              page: 1,
              size: 20,
              totalElements: 2,
              totalPages: 2,
            ));

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();
    await vm.loadMore();

    expect(vm.items.map((i) => i.ratingId), [1, 2]);
  });

  test('deleteRating(): 항목 제거 + 누적 건수 감소', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(1, DateTime(2026, 4, 20))],
              page: 0,
              size: 20,
              totalElements: 1,
              totalPages: 1,
            ));
    when(() => repo.deleteMyRating('g1', 1)).thenAnswer((_) async {});

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();
    await vm.deleteRating(vm.items.first);

    expect(vm.items, isEmpty);
    expect(vm.totalElements, 0);
    verify(() => repo.deleteMyRating('g1', 1)).called(1);
  });
}
