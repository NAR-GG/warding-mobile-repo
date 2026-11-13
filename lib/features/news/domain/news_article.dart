// 뉴스 기사 모델.

/// 콘텐츠 · 뉴스 탭 한 건.
class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.office,
    required this.minutesAgo,
    this.thumbnailUrl,
    this.postUrl,
  });

  final String title;
  final String office;
  final int minutesAgo;

  /// 기사 썸네일 URL. 없으면 빈 자리를 그린다.
  final String? thumbnailUrl;

  /// 기사 원문 URL. 없으면 탭해도 이동하지 않는다.
  final String? postUrl;
}

