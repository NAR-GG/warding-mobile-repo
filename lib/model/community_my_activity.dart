import 'community_remote_post.dart';

/// 내 스크랩 한 건.
class CommunityScrapItem {
  const CommunityScrapItem({required this.scrapId, required this.post});

  final int scrapId;
  final CommunityRemotePost post;

  factory CommunityScrapItem.fromJson(Map<String, dynamic> json) {
    return CommunityScrapItem(
      scrapId: (json['scrapId'] as num?)?.toInt() ?? 0,
      post: CommunityRemotePost.fromJson(json['post'] as Map<String, dynamic>),
    );
  }
}

/// 내 스크랩 페이지 응답 (최신순, 커서 = scrapId).
class CommunityScrapPage {
  const CommunityScrapPage({required this.items, this.nextCursor});

  final List<CommunityScrapItem> items;
  final int? nextCursor;

  factory CommunityScrapPage.fromJson(Map<String, dynamic> json) {
    return CommunityScrapPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CommunityScrapItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}

/// 좋아요한 글 한 건.
class CommunityLikeItem {
  const CommunityLikeItem({required this.likeId, required this.post});

  final int likeId;
  final CommunityRemotePost post;

  factory CommunityLikeItem.fromJson(Map<String, dynamic> json) {
    return CommunityLikeItem(
      likeId: (json['likeId'] as num?)?.toInt() ?? 0,
      post: CommunityRemotePost.fromJson(json['post'] as Map<String, dynamic>),
    );
  }
}

/// 좋아요한 글 페이지 응답 (최신순, 커서 = likeId).
class CommunityLikePage {
  const CommunityLikePage({required this.items, this.nextCursor});

  final List<CommunityLikeItem> items;
  final int? nextCursor;

  factory CommunityLikePage.fromJson(Map<String, dynamic> json) {
    return CommunityLikePage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CommunityLikeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}

/// 내가 쓴 댓글 한 건. 원글이 삭제되면 목록에서 빠지므로 [postId]는
/// 항상 유효한 이동 대상이다.
class CommunityMyComment {
  const CommunityMyComment({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.body,
    required this.likeCount,
    required this.createdAt,
    this.boardTeamId,
    this.boardTeamCode,
  });

  final int id;
  final int postId;
  final String postTitle;
  final String body;
  final int likeCount;
  final DateTime? createdAt;

  /// **원글이 속한 게시판**. null이면 전체 게시판이다.
  ///
  /// 내가 댓글을 단 글은 다른팀 게시판일 수도 있어서, 이 값은 내 응원팀과 무관하다.
  final int? boardTeamId;

  /// 게시판 팀의 코드(예: `GEN`). 전체 게시판이면 null.
  /// 팀 목록 조회 없이 배지를 그리려고 서버가 같이 내려준다.
  final String? boardTeamCode;

  factory CommunityMyComment.fromJson(Map<String, dynamic> json) {
    return CommunityMyComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      postTitle: json['postTitle'] as String? ?? '',
      body: json['body'] as String? ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      boardTeamId: (json['boardTeamId'] as num?)?.toInt(),
      boardTeamCode: json['boardTeamCode'] as String?,
    );
  }
}

/// 내가 쓴 댓글 페이지 응답 (최신순, 커서 = 댓글 id).
class CommunityMyCommentPage {
  const CommunityMyCommentPage({required this.comments, this.nextCursor});

  final List<CommunityMyComment> comments;
  final int? nextCursor;

  factory CommunityMyCommentPage.fromJson(Map<String, dynamic> json) {
    return CommunityMyCommentPage(
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map((e) => CommunityMyComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}
