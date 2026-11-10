import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/core/domain/failure.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';
import 'package:warding/features/my_review/presentation/viewmodels/my_review_viewmodel.dart';

class _MockRepo extends Mock implements MyReviewRepository {}

MyReviewItem _item(int id, DateTime created) => MyReviewItem(
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

MyReviewPage _page(
  List<MyReviewItem> items, {
  int page = 0,
  int totalElements = 1,
  int totalPages = 1,
}) =>
    MyReviewPage(
      ratings: items,
      page: page,
      totalElements: totalElements,
      totalPages: totalPages,
    );

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  MyReviewViewModel build() => MyReviewViewModel(repository: repo);

  test('load(): 항목·누적 건수 채움', () async {
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size'))).thenAnswer(
      (_) async => Right(
        _page([_item(1, DateTime(2026, 4, 20))], totalElements: 3),
      ),
    );

    final vm = build();
    await vm.load();

    expect(vm.items, hasLength(1));
    expect(vm.totalElements, 3);
    expect(vm.loading, isFalse);
    expect(vm.error, isNull);
  });

  test('grouped: createdAt 기준 YYYY.MM.DD 로 묶고 삽입 순서를 유지한다', () async {
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size'))).thenAnswer(
      (_) async => Right(_page([
        _item(1, DateTime(2026, 4, 20, 10)),
        _item(2, DateTime(2026, 4, 19, 9)),
        _item(3, DateTime(2026, 4, 20, 8)),
      ], totalElements: 3)),
    );

    final vm = build();
    await vm.load();

    expect(vm.grouped.keys.toList(), ['2026.04.20', '2026.04.19']);
    expect(vm.grouped['2026.04.20'], hasLength(2));
  });

  test('loadMore(): 다음 페이지를 누적한다', () async {
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size'))).thenAnswer((invocation) async {
      final p = invocation.namedArguments[const Symbol('page')] as int;
      return Right(
        _page(
          [_item(p + 1, DateTime(2026, 4, 20 - p))],
          page: p,
          totalElements: 2,
          totalPages: 2,
        ),
      );
    });

    final vm = build();
    await vm.load();
    expect(vm.hasMore, isTrue);

    await vm.loadMore();

    expect(vm.items, hasLength(2));
    expect(vm.hasMore, isFalse);
  });

  test('load() 실패하면 error 문구가 채워지고 목록은 비어 있다', () async {
    // repository 가 Exception 을 던지는 대신 Left 를 돌려준다. ViewModel 에
    // try/catch 가 없어도 실패 분기가 컴파일 단계에서 강제된다.
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    final vm = build();
    await vm.load();

    expect(vm.error, isNotNull);
    expect(vm.items, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('loadMore() 실패는 화면 전체를 에러로 덮지 않는다', () async {
    var call = 0;
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size'))).thenAnswer((_) async {
      call++;
      if (call == 1) {
        return Right(
          _page([_item(1, DateTime(2026, 4, 20))],
              totalElements: 2, totalPages: 2),
        );
      }
      return const Left(ServerFailure(statusCode: 500));
    });

    final vm = build();
    await vm.load();
    await vm.loadMore();

    // 이미 보고 있는 목록은 유효하므로 그대로 남는다.
    expect(vm.items, hasLength(1));
    expect(vm.error, isNull);
    expect(vm.loadingMore, isFalse);
  });

  test('deleteRating(): 성공하면 항목 제거 + 누적 건수 감소', () async {
    final item = _item(1, DateTime(2026, 4, 20));
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size'))).thenAnswer(
      (_) async => Right(_page([item], totalElements: 3)),
    );
    when(() => repo.deleteMyRating(gameId: any(named: 'gameId'), participantId: any(named: 'participantId')))
        .thenAnswer((_) async => const Right(unit));

    final vm = build();
    await vm.load();

    final ok = await vm.deleteRating(item);

    expect(ok, isTrue);
    expect(vm.items, isEmpty);
    expect(vm.totalElements, 2);
  });

  test('deleteRating(): 실패하면 false 를 주고 목록을 건드리지 않는다', () async {
    final item = _item(1, DateTime(2026, 4, 20));
    when(() => repo.fetchMyRatings(page: any(named: 'page'), size: any(named: 'size'))).thenAnswer(
      (_) async => Right(_page([item], totalElements: 3)),
    );
    when(() => repo.deleteMyRating(gameId: any(named: 'gameId'), participantId: any(named: 'participantId')))
        .thenAnswer((_) async => const Left(UnauthorizedFailure()));

    final vm = build();
    await vm.load();

    final ok = await vm.deleteRating(item);

    expect(ok, isFalse);
    expect(vm.items, hasLength(1));
    expect(vm.totalElements, 3);
  });
}
