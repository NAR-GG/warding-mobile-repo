import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_my_activity.dart';
import '../../model/community_remote_post.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';
import 'community_api_exception.dart';

/// 마이페이지 "내 활동" API (`/api/mobile/me/community/...`). 전부 인증
/// 필수이고, 삭제·블라인드된 항목은 서버가 이미 걸러서 내려준다.
class CommunityActivityRepository {
  CommunityActivityRepository._();
  static final CommunityActivityRepository instance =
      CommunityActivityRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _get(String url) => _auth.authorizedRequest(
    (token) => http.get(Uri.parse(url), headers: _headers(token)),
  );

  void _checkOk(http.Response response, String eventName) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = CommunityApiException.fromResponse(response);
      SentryLogger.warning(
        module: 'API',
        eventName: eventName,
        reason: 'status_${response.statusCode}',
        extra: {'statusCode': response.statusCode, 'code': exception.code},
      );
      throw exception;
    }
  }

  /// 내 스크랩 목록 (최신순, 커서 = scrapId).
  Future<CommunityScrapPage> fetchScraps({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityScrapsUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityScraps');
    return CommunityScrapPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 내가 쓴 글 목록 (전체·팀 게시판 섞여서, 최신순).
  Future<CommunityRemotePostPage> fetchMyPosts({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityPostsUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityMyPosts');
    return CommunityRemotePostPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 좋아요한 글 목록 (최신순, 커서 = likeId).
  Future<CommunityLikePage> fetchMyLikes({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityLikesUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityMyLikes');
    return CommunityLikePage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 내가 쓴 댓글 목록 (최신순, 커서 = 댓글 id). 원글이 삭제된 댓글은 빠진다.
  Future<CommunityMyCommentPage> fetchMyComments({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityCommentsUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityMyComments');
    return CommunityMyCommentPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
