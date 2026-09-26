import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/story_video.dart';
import '../../util/api_client.dart' as http;

/// 유튜브 쇼츠 API.
class ShortsRepository {
  ShortsRepository._();
  static final ShortsRepository instance = ShortsRepository._();

  /// [sort]: 'latest' | 'views' | 'likes'.
  Future<List<StoryVideo>> fetchShorts({String sort = 'latest'}) async {
    final response =
        await http.get(Uri.parse(ApiConfig.shortsUrl(sort: sort)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('쇼츠 조회 실패 (${response.statusCode})');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['content'] as List<dynamic>? ?? const [])
        .map((e) => StoryVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
