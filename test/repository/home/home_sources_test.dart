import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/home/home_sources.dart';

void main() {
  test('MockSoloRankSource: 진행 중과 끝난 경기를 따로 준다', () async {
    final snap = await MockSoloRankSource().fetch();
    expect(snap.live, isNotEmpty);
    expect(snap.finished, isNotEmpty);
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

  // 목업은 HOME_MOCKS 게이트 뒤에 있다 — 플래그가 꺼진 빌드(릴리즈 기본값)의
  // 기본 소스는 빈 소스라 가짜 솔랭·뉴스·평점이 실사용자에게 나가지 않는다.
  group('HOME_MOCKS 게이트', () {
    test('dart-define 이 없으면 kDebugMode 를 따른다', () {
      expect(kHomeMocks, kDebugMode);
    });

    test('플래그가 꺼지면 기본 소스는 모두 빈 소스', () async {
      final solo = defaultSoloRankSource(mocks: false);
      final reviews = defaultReviewSource(mocks: false);
      final news = defaultNewsSource(mocks: false);
      expect(solo, isA<EmptySoloRankSource>());
      expect(reviews, isA<EmptyReviewSource>());
      expect(news, isA<EmptyNewsSource>());

      final snap = await solo.fetch();
      expect(snap.live, isEmpty);
      expect(snap.finished, isEmpty);
      expect(await reviews.fetchRecent(), isEmpty);
      expect(await news.fetchTop(), isEmpty);
    });

    test('플래그가 켜지면 목업 소스', () {
      expect(defaultSoloRankSource(mocks: true), isA<MockSoloRankSource>());
      expect(defaultReviewSource(mocks: true), isA<MockReviewSource>());
      expect(defaultNewsSource(mocks: true), isA<MockNewsSource>());
    });
  });
}
