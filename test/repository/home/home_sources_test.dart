import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/home/home_api_sources.dart';
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

  // 목업은 HOME_MOCKS 게이트 뒤에 있다 — 플래그가 꺼진 기본 빌드는 솔랭·뉴스는 실제
  // API 소스, 평점은 빈 소스(백엔드 #542 배포 전)라 가짜 데이터가 나가지 않는다.
  group('HOME_MOCKS 게이트', () {
    test('dart-define 이 없으면 꺼져 있다', () {
      expect(kHomeMocks, isFalse);
    });

    test('플래그가 꺼지면 솔랭·뉴스는 API 소스, 평점은 빈 소스', () async {
      expect(defaultSoloRankSource(mocks: false), isA<ApiSoloRankSource>());
      expect(defaultNewsSource(mocks: false), isA<ApiNewsSource>());
      final reviews = defaultReviewSource(mocks: false);
      expect(reviews, isA<EmptyReviewSource>());
      expect(await reviews.fetchRecent(), isEmpty);
    });

    test('플래그가 켜지면 목업 소스', () {
      expect(defaultSoloRankSource(mocks: true), isA<MockSoloRankSource>());
      expect(defaultReviewSource(mocks: true), isA<MockReviewSource>());
      expect(defaultNewsSource(mocks: true), isA<MockNewsSource>());
    });
  });
}
