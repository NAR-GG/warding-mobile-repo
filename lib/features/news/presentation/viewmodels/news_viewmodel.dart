import 'package:flutter/foundation.dart';

import 'package:warding/features/news/data/news_source.dart';
import 'package:warding/features/news/domain/news_article.dart';

/// 다른 화면에 끼워 넣는 뉴스 목록의 상태.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class NewsViewModel extends ChangeNotifier {
  NewsViewModel({NewsSource? source}) : _source = source ?? defaultNewsSource();

  final NewsSource _source;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<NewsArticle> _articles = const [];
  List<NewsArticle> get articles => _articles;

  int _gen = 0;

  /// 첫 응답(성공·실패 모두)이 오기 전 true — 뉴스 탭 자리에 스켈레톤을
  /// 그린다. 끝난 뒤 비어 있으면 호출부가 뉴스 탭을 숨긴다.
  bool _firstLoadPending = true;
  bool get loading => _firstLoadPending;

  Future<void> load() async {
    final gen = ++_gen;
    try {
      final articles = await _source.fetchTop();
      if (_disposed || gen != _gen) return;
      _articles = articles;
      _firstLoadPending = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[News] 뉴스 조회 실패: $e');
      if (_disposed || gen != _gen) return;
      _firstLoadPending = false;
      notifyListeners();
    }
  }
}
