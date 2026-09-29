import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/story_video.dart';
import '../../util/api_client.dart' as http;

/// 쇼츠 목록 한 페이지. [isLast] 가 true 면 다음 페이지가 없다.
class ShortsPage {
  const ShortsPage({required this.items, required this.isLast});

  final List<StoryVideo> items;
  final bool isLast;
}

/// 유튜브 쇼츠 API.
class ShortsRepository {
  ShortsRepository._();
  static final ShortsRepository instance = ShortsRepository._();

  /// [sort]: 'latest' | 'views' | 'likes'.
  ///
  /// [teamCode] 는 그 팀 채널의 쇼츠만 받는다(서버 필터). 서버가 아직 모르는
  /// 동안은 무시되므로 호출하는 쪽도 응답의 `teamCode` 로 한 번 더 거른다.
  Future<List<StoryVideo>> fetchShorts({
    String sort = 'latest',
    int size = 20,
    String? teamCode,
  }) async {
    final page = await fetchShortsPage(
      sort: sort,
      size: size,
      teamCode: teamCode,
    );
    return page.items;
  }

  /// [page] 는 0부터. 전체화면 피드가 다음 페이지를 이어 받을 때 쓴다.
  Future<ShortsPage> fetchShortsPage({
    String sort = 'latest',
    int size = 20,
    int page = 0,
    String? teamCode,
  }) async {
    final response = await http.get(
      Uri.parse(
        ApiConfig.shortsUrl(
          sort: sort,
          size: size,
          page: page,
          teamCode: teamCode,
        ),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('쇼츠 조회 실패 (${response.statusCode})');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = (data['content'] as List<dynamic>? ?? const [])
        .map((e) => StoryVideo.fromJson(e as Map<String, dynamic>))
        .toList();
    return ShortsPage(items: items, isLast: data['last'] as bool? ?? true);
  }
}
