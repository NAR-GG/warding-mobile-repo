import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_remote_post.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';
import 'community_api_exception.dart';

/// 커뮤니티 게시글·댓글 API (`/api/mobile/community/...`).
///
/// 조회(GET)는 비로그인도 허용한다 — 토큰이 있으면 [_optionalAuthGet]이
/// 자동으로 실어 보내 차단 필터·내 좋아요/스크랩 여부가 붙는다. 쓰기는 전부
/// [AuthService.authorizedRequest]로 인증을 강제한다.
class CommunityRepository {
  CommunityRepository._();
  static final CommunityRepository instance = CommunityRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _optionalAuthGet(String url) async {
    final token = await _auth.jwt;
    if (token == null || token.isEmpty) {
      return http.get(Uri.parse(url));
    }
    return _auth.authorizedRequest(
      (t) => http.get(Uri.parse(url), headers: _headers(t)),
    );
  }

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

  // ── 게시글 ───────────────────────────────────────────────────────

  /// 게시글 목록. [boardTeamId] 생략 = 전체 게시판.
  Future<CommunityRemotePostPage> fetchPosts({
    int? boardTeamId,
    String? cursor,
    int size = 20,
  }) async {
    final response = await _optionalAuthGet(
      ApiConfig.communityPostsUrl(
        boardTeamId: boardTeamId,
        cursor: cursor,
        size: size,
      ),
    );
    _checkOk(response, 'fetchCommunityPosts');
    return CommunityRemotePostPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 게시글 상세.
  Future<CommunityRemotePostDetail> fetchPostDetail(int postId) async {
    final response = await _optionalAuthGet(
      ApiConfig.communityPostUrl(postId),
    );
    _checkOk(response, 'fetchCommunityPostDetail');
    return CommunityRemotePostDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 게시글을 작성하고 새 글 id를 반환한다. [boardTeamId]가 null이면 전체
  /// 게시판(팀 게시판은 서버가 내 응원팀인지 재검사한다).
  Future<int> createPost({
    int? boardTeamId,
    required String title,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCreatePostUrl),
        headers: _headers(token),
        body: jsonEncode({
          'boardTeamId': boardTeamId,
          'title': title,
          'body': body,
          'imageUrls': imageUrls,
        }),
      ),
    );
    _checkOk(response, 'createCommunityPost');
    return ((jsonDecode(response.body) as Map<String, dynamic>)['id'] as num)
        .toInt();
  }

  /// 게시글을 수정한다(작성자만). [imageUrls]는 전체 교체 — null이면 이미지
  /// 변경 없음, `[]`이면 전부 제거.
  Future<void> updatePost(
    int postId, {
    int? boardTeamId,
    required String title,
    required String body,
    List<String>? imageUrls,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.communityPostUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({
          'boardTeamId': boardTeamId,
          'title': title,
          'body': body,
          'imageUrls': imageUrls,
        }),
      ),
    );
    _checkOk(response, 'updateCommunityPost');
  }

  /// 게시글을 삭제한다(작성자만, 소프트 삭제).
  Future<void> deletePost(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.communityPostUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'deleteCommunityPost');
  }

  /// 조회수 +1. 비로그인 포함, 중복 호출도 허용된다.
  Future<void> markPostViewed(int postId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.communityPostViewUrl(postId)),
    );
    _checkOk(response, 'viewCommunityPost');
  }

  /// 추천 토글. 더블탭해도 안전(멱등).
  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityPostLikeUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityPostLike');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      liked: data['liked'] as bool? ?? false,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// 스크랩 토글.
  Future<bool> toggleScrap(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityPostScrapUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityPostScrap');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['scrapped'] as bool? ?? false;
  }
}
