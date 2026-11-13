import 'package:flutter_test/flutter_test.dart';

import 'package:warding/features/news/data/news_source.dart';
import 'package:warding/features/news/domain/news_article.dart';
import 'package:warding/features/news/presentation/viewmodels/news_viewmodel.dart';

class _FakeSource implements NewsSource {
  _FakeSource(this.articles, {this.throws = false});
  List<NewsArticle> articles;
  bool throws;
  int calls = 0;

  @override
  Future<List<NewsArticle>> fetchTop() async {
    calls++;
    if (throws) throw Exception('500');
    return articles;
  }
}

NewsArticle _article(String title) =>
    NewsArticle(title: title, office: '언론사', minutesAgo: 10);

void main() {
  test('생성만으로는 조회하지 않고 loading 으로 시작한다', () {
    final source = _FakeSource([_article('기사')]);

    final vm = NewsViewModel(source: source);

    expect(source.calls, 0);
    expect(vm.loading, isTrue);
    expect(vm.articles, isEmpty);
  });

  test('조회 성공하면 목록을 노출하고 loading 을 끝낸다', () async {
    final vm = NewsViewModel(source: _FakeSource([_article('A')]));

    await vm.load();

    expect(vm.articles.single.title, 'A');
    expect(vm.loading, isFalse);
  });

  test('실패해도 loading 은 끝낸다 — 끝난 뒤 비면 호출부가 탭을 숨긴다', () async {
    final vm = NewsViewModel(source: _FakeSource([], throws: true));

    await vm.load();

    expect(vm.articles, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('빈 소스는 빈 목록 + loading 종료', () async {
    final vm = NewsViewModel(source: const EmptyNewsSource());

    await vm.load();

    expect(vm.articles, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('느린 응답이 새 응답을 덮지 않는다', () async {
    // 세대 카운터 확인 — 두 번째 load 가 먼저 끝나도 첫 응답이 덮지 않는다.
    final source = _SlowThenFast();
    final vm = NewsViewModel(source: source);

    final slow = vm.load();
    await vm.load();
    await slow;

    expect(vm.articles.single.title, '빠름');
  });
}

class _SlowThenFast implements NewsSource {
  int _calls = 0;

  @override
  Future<List<NewsArticle>> fetchTop() async {
    _calls++;
    if (_calls == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return [_article('느림')];
    }
    return [_article('빠름')];
  }
}
