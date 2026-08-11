import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/category_tree.dart';

/// 카테고리(리그/시즌/팀) 트리 API.
class CategoryRepository {
  CategoryRepository._();
  static final CategoryRepository instance = CategoryRepository._();

  /// 진행 중인 트리 요청 + 캐시. 연도 안에서는 시즌 도중 거의 안 바뀌는
  /// 데이터인데, 로그도 없이 응답이 0.9~2.7초씩 걸려(2026-08-12 실측) 경기
  /// 리스트 화면에 들어갈 때마다 그대로 맨 앞에 깔려 있었다. 캐시로 매 진입마다
  /// 다시 받지 않게 한다.
  final Map<int, Future<CategoryTree>> _treeInFlight = {};
  final Map<int, (DateTime, CategoryTree)> _treeCache = {};
  static const Duration _treeCacheTtl = Duration(minutes: 10);

  /// `GET /api/categories/tree?year=...` — 해당 연도의 리그/스플릿/팀 트리 조회.
  ///
  /// 같은 연도 요청이 이미 떠 있거나 방금 끝났으면([_treeCacheTtl] 이내) 그
  /// 결과를 재사용한다.
  Future<CategoryTree> fetchTree({required int year}) {
    final cached = _treeCache[year];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _treeCacheTtl) {
      debugPrint('[Category] tree cache hit: $year');
      return Future.value(cached.$2);
    }
    final inFlight = _treeInFlight[year];
    if (inFlight != null) {
      debugPrint('[Category] tree 요청 합류: $year');
      return inFlight;
    }

    final request = _fetchTree(year).then((tree) {
      _treeCache[year] = (DateTime.now(), tree);
      return tree;
    });
    unawaited(request.whenComplete(() {
      if (identical(_treeInFlight[year], request)) {
        _treeInFlight.remove(year);
      }
    }).catchError((_) => const CategoryTree(seasons: [])));
    _treeInFlight[year] = request;
    return request;
  }

  Future<CategoryTree> _fetchTree(int year) async {
    final url = ApiConfig.categoriesTreeUrl(year: year);
    final sw = Stopwatch()..start();
    debugPrint('[Category] GET $url');
    final response = await http.get(Uri.parse(url));
    sw.stop();
    debugPrint('[Category] tree ← ${response.statusCode} '
        '(${sw.elapsedMilliseconds}ms)');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('카테고리 트리 조회 실패 (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CategoryTree.fromJson(body);
  }
}
