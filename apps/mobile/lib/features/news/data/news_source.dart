import 'package:warding/core/config/home_mocks.dart';
import 'package:warding/features/news/data/api_news_source.dart';
import 'package:warding/features/news/domain/news_article.dart';

// 뉴스 소스. 홈 콘텐츠 섹션의 뉴스 탭이 쓴다.
abstract class NewsSource {
  Future<List<NewsArticle>> fetchTop();
}

/// 홈 목업 스위치. 켜져 있으면 솔랭·평점·뉴스의 기본 소스가 목업이다. 꺼져 있으면
NewsSource defaultNewsSource({bool mocks = kHomeMocks}) =>
    mocks ? const MockNewsSource() : ApiNewsSource();

/// 빈 솔랭 소스 — 솔랭 백엔드가 없을 때 릴리즈 빌드의 기본값. 구독이 있으면
class MockNewsSource implements NewsSource {
  const MockNewsSource();

  static const List<NewsArticle> articles = [
    NewsArticle(title: 'T1, 플레이오프 진출 확정', office: 'OSEN', minutesAgo: 40),
    NewsArticle(title: '젠지, 정규시즌 1위 마감', office: '스포츠조선', minutesAgo: 120),
    NewsArticle(title: '한화생명, 로스터 변경 발표', office: '인벤', minutesAgo: 200),
    NewsArticle(
      title: 'LCK 2026 서머 일정 공개',
      office: '데일리e스포츠',
      minutesAgo: 340,
    ),
    NewsArticle(title: 'kt, 신인 서포터 영입', office: '포모스', minutesAgo: 600),
  ];

  @override
  Future<List<NewsArticle>> fetchTop() async => articles;
}

/// 빈 뉴스 소스. 테스트가 "뉴스가 없는 상태"(뉴스 탭 숨김)를 만들 때 쓴다.
class EmptyNewsSource implements NewsSource {
  const EmptyNewsSource();
  @override
  Future<List<NewsArticle>> fetchTop() async => const [];
}
