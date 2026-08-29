import 'community_author.dart';

/// 댓글 상태. VISIBLE이 아니면 [CommunityRemoteComment.body]/
/// [CommunityRemoteComment.author]가 null로 온다(행은 유지된다 — 자리 보존).
enum CommunityCommentStatus {
  visible,
  deleted,
  blocked,
  hidden;

  static CommunityCommentStatus fromApi(String? value) {
    switch (value) {
      case 'DELETED':
        return CommunityCommentStatus.deleted;
      case 'BLOCKED':
        return CommunityCommentStatus.blocked;
      case 'HIDDEN':
        return CommunityCommentStatus.hidden;
      case 'VISIBLE':
      default:
        return CommunityCommentStatus.visible;
    }
  }
}

/// 커뮤니티 댓글 한 건. 답글은 1단까지만 접는다 — [parentId]는 항상
/// 최상위 댓글을 가리킨다(답글의 답글도 같은 층에 쌓인다).
class CommunityRemoteComment {
  const CommunityRemoteComment({
    required this.id,
    required this.parentId,
    required this.status,
    required this.body,
    required this.author,
    required this.likeCount,
    required this.liked,
    required this.mine,
    required this.createdAt,
    this.mentionNickname,
  });

  final int id;
  final int? parentId;
  final CommunityCommentStatus status;

  /// status가 VISIBLE이 아니면 null.
  final String? body;

  /// status가 VISIBLE이 아니면 null.
  final CommunityAuthor? author;

  /// 답글이 특정 사용자에게 향할 때 본문 앞에 붙는 `@닉네임`.
  final String? mentionNickname;

  final int likeCount;
  final bool liked;
  final bool mine;
  final DateTime? createdAt;

  factory CommunityRemoteComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    return CommunityRemoteComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentId: (json['parentId'] as num?)?.toInt(),
      status: CommunityCommentStatus.fromApi(json['status'] as String?),
      body: json['body'] as String?,
      author: author == null
          ? null
          : CommunityAuthor.fromJson(author as Map<String, dynamic>),
      mentionNickname: json['mentionNickname'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] as bool? ?? false,
      mine: json['mine'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// 댓글 목록 페이지 응답(오래된 순).
class CommunityRemoteCommentPage {
  const CommunityRemoteCommentPage({required this.comments, this.nextCursor});

  final List<CommunityRemoteComment> comments;
  final int? nextCursor;

  factory CommunityRemoteCommentPage.fromJson(Map<String, dynamic> json) {
    return CommunityRemoteCommentPage(
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map(
            (e) => CommunityRemoteComment.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}
