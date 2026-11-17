import 'package:warding/core/util/server_time.dart';
import 'dart:convert';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/features/news/data/news_source.dart';
import 'package:warding/features/news/domain/news_article.dart';

class ApiNewsSource implements NewsSource {
  ApiNewsSource({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  Future<List<NewsArticle>> fetchTop() async {
    final response = await http.get(Uri.parse(ApiConfig.homeNewsUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('홈 뉴스 조회 실패 (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    final now = _now();
    return [
      for (final e in data)
        NewsArticle(
          title: (e as Map<String, dynamic>)['title'] as String? ?? '',
          office: e['officeName'] as String? ?? '',
          minutesAgo: minutesSince(parseServerTime(e['createdAt']), now),
          thumbnailUrl: e['thumbnail'] as String?,
          postUrl: e['postUrl'] as String?,
        ),
    ];
  }
}
