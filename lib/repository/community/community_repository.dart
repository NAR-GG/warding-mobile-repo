import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_poll.dart';
import '../../model/community_post_block.dart';
import '../../model/community_remote_comment.dart';
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
    int? cursor,
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
    String bodyFormat = 'PLAIN',
    List<String> imageUrls = const [],
    ({String question, List<String> options})? poll,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCreatePostUrl),
        headers: _headers(token),
        body: jsonEncode({
          'boardTeamId': boardTeamId,
          'title': title,
          'body': body,
          'bodyFormat': bodyFormat,
          'imageUrls': imageUrls,
          if (poll != null)
            'poll': {'question': poll.question, 'options': poll.options},
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
    String bodyFormat = 'PLAIN',
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
          'bodyFormat': bodyFormat,
          'imageUrls': imageUrls,
        }),
      ),
    );
    _checkOk(response, 'updateCommunityPost');
  }

  /// 투표(단일 선택, 변경 불가). 성공 시 투표 후 상태를 반환한다.
  /// 이미 투표했으면 서버가 409(COMMUNITY_ALREADY_VOTED)를 준다.
  Future<CommunityPoll> votePoll(int postId, int optionId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityPollVoteUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({'optionId': optionId}),
      ),
    );
    _checkOk(response, 'voteCommunityPoll');
    return CommunityPoll.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 링크 프리뷰(OG 스냅샷). 서버가 못 긁으면 title 이하 null 로 온다.
  Future<CommunityLinkPreview> fetchLinkPreview(String url) async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.communityLinkPreviewUrl(url)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'fetchCommunityLinkPreview');
    return CommunityLinkPreview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
  ///
  /// 화면 표시와 무관한 집계 핑이라 실패해도 조용히 무시한다(spec §6.1:
  /// "optional, 응답 무시") — [NoticeRepository.markViewed]와 동일한 패턴.
  Future<void> markPostViewed(int postId) async {
    try {
      final token = await _auth.jwt;
      final response = (token == null || token.isEmpty)
          ? await http.post(Uri.parse(ApiConfig.communityPostViewUrl(postId)))
          : await http.post(
              Uri.parse(ApiConfig.communityPostViewUrl(postId)),
              headers: {'Authorization': 'Bearer $token'},
            );
      debugPrint('[Community] 조회수 $postId ← ${response.statusCode}');
    } catch (e) {
      debugPrint('[Community] 조회수 $postId 실패: $e');
    }
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

  /// 이 글 알림 켬/끔 토글. 반환 = 토글 후 수신 여부.
  Future<bool> togglePostNotification(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityPostNotificationUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityPostNotification');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['enabled'] as bool? ?? true;
  }

  // ── 댓글 ────────────────────────────────────────────────────────

  /// 댓글 목록(오래된 순). 1단 스레드 조립은 호출부(뷰모델) 몫이다.
  Future<CommunityRemoteCommentPage> fetchComments(
    int postId, {
    int? cursor,
    int size = 50,
  }) async {
    final response = await _optionalAuthGet(
      ApiConfig.communityCommentsUrl(postId, cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityComments');
    return CommunityRemoteCommentPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 댓글을 작성하고 새 댓글 id를 반환한다. 답글이면 [replyToCommentId]에
  /// **대상 댓글 id를 그대로** 넘긴다 — 답글의 답글이어도 마찬가지다. parent
  /// 올려붙이기와 멘션 대상은 서버가 계산하므로 앱이 parentId를 직접
  /// 계산하지 않는다.
  Future<int> createComment(
    int postId, {
    required String body,
    int? replyToCommentId,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCreateCommentUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({
          'body': body,
          if (replyToCommentId != null) 'replyToCommentId': replyToCommentId,
        }),
      ),
    );
    _checkOk(response, 'createCommunityComment');
    return ((jsonDecode(response.body) as Map<String, dynamic>)['id'] as num)
        .toInt();
  }

  /// 댓글 본문을 수정한다(작성자만). 멘션·답글 관계는 서버가 안 바꾼다.
  Future<void> updateComment(int commentId, {required String body}) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.communityCommentUrl(commentId)),
        headers: _headers(token),
        body: jsonEncode({'body': body}),
      ),
    );
    _checkOk(response, 'updateCommunityComment');
  }

  /// 댓글을 삭제한다(작성자만, 소프트 삭제).
  Future<void> deleteComment(int commentId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.communityCommentUrl(commentId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'deleteCommunityComment');
  }

  /// 댓글 추천 토글.
  Future<({bool liked, int likeCount})> toggleCommentLike(
    int commentId,
  ) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCommentLikeUrl(commentId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityCommentLike');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      liked: data['liked'] as bool? ?? false,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    );
  }
}
