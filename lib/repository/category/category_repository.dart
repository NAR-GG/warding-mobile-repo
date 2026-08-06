import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/category_tree.dart';

/// 카테고리(리그/시즌/팀) 트리 API.
class CategoryRepository {
  CategoryRepository._();
  static final CategoryRepository instance = CategoryRepository._();

  /// `GET /api/categories/tree?year=...` — 해당 연도의 리그/스플릿/팀 트리 조회.
  Future<CategoryTree> fetchTree({required int year}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.categoriesTreeUrl(year: year)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('카테고리 트리 조회 실패 (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CategoryTree.fromJson(body);
  }
}
