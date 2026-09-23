import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/home/home_sources.dart';

void main() {
  test('MockSoloRankSource: 진행 중과 끝난 경기를 따로 준다', () async {
    final snap = await MockSoloRankSource().fetch();
    expect(snap.live, isNotEmpty);
    expect(snap.finished, isNotEmpty);
    expect(snap.subscribedTotal, greaterThanOrEqualTo(snap.live.length));
  });

  test('MockReviewSource: 한줄평이 빈 항목은 없다', () async {
    final reviews = await MockReviewSource().fetchRecent();
    expect(reviews, isNotEmpty);
    expect(reviews.every((r) => r.comment.trim().isNotEmpty), isTrue);
    expect(reviews.every((r) => r.stars >= 1 && r.stars <= 5), isTrue);
    expect(reviews.every((r) => r.comment.length <= 150), isTrue);
  });

  test('MockNewsSource: 기사를 준다', () async {
    expect(await MockNewsSource().fetchTop(), isNotEmpty);
  });
}
