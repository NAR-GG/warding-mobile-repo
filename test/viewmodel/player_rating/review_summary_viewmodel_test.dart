import 'package:flutter_test/flutter_test.dart';

import 'package:warding/features/player_rating/data/review_source.dart';
import 'package:warding/features/player_rating/domain/review_item.dart';
import 'package:warding/features/player_rating/presentation/viewmodels/review_summary_viewmodel.dart';

class _FakeSource implements ReviewSource {
  _FakeSource(this.items, {this.throws = false});
  List<ReviewItem> items;
  bool throws;
  int calls = 0;

  @override
  Future<List<ReviewItem>> fetchRecent() async {
    calls++;
    if (throws) throw Exception('500');
    return items;
  }
}

ReviewItem _item(String player) => ReviewItem(
  playerName: player,
  champion: '아리',
  stars: 5,
  comment: '잘했다',
  nickname: '작성자',
  teamCode: 'T1',
  minutesAgo: 10,
);

void main() {
  test('생성만으로는 조회하지 않고 loading 으로 시작한다', () {
    final source = _FakeSource([_item('Faker')]);

    final vm = ReviewSummaryViewModel(source: source);

    expect(source.calls, 0);
    expect(vm.loading, isTrue);
    expect(vm.items, isEmpty);
  });

  test('count 를 넘으면 잘라낸다', () async {
    final vm = ReviewSummaryViewModel(
      source: _FakeSource([for (var i = 0; i < 6; i++) _item('p$i')]),
      count: 4,
    );

    await vm.load();

    expect(vm.items.length, 4);
    expect(vm.loading, isFalse);
  });

  test('실패해도 loading 은 끝낸다 — 끝난 뒤 비면 호출부가 섹션을 숨긴다', () async {
    final vm = ReviewSummaryViewModel(source: _FakeSource([], throws: true));

    await vm.load();

    expect(vm.items, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('빈 소스는 빈 목록 + loading 종료', () async {
    final vm = ReviewSummaryViewModel(source: const EmptyReviewSource());

    await vm.load();

    expect(vm.items, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('재조회가 실패하면 마지막 목록을 유지한다', () async {
    final source = _FakeSource([_item('Faker')]);
    final vm = ReviewSummaryViewModel(source: source);
    await vm.load();

    source.throws = true;
    await vm.load();

    expect(vm.items.single.playerName, 'Faker');
  });
}
