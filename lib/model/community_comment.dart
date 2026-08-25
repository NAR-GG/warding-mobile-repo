/// 커뮤니티 댓글.
///
/// 답글은 1단까지만 접는다. 답글에 다시 답글을 달면 더 들여쓰지 않고 같은
/// 층에 쌓이며, 본문 앞에 `@닉네임` 멘션이 붙는다([mention]).
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.parentId,
    required this.authorName,
    required this.authorTeamId,
    required this.body,
    required this.timeAgo,
    required this.likeCount,
    this.mention,
    this.liked = false,
  });

  final int id;

  /// null 이면 최상위 댓글, 값이 있으면 그 댓글에 달린 답글.
  final int? parentId;

  final String authorName;

  /// 작성 시점 응원팀. [CommunityPost.authorTeamId] 와 같은 규칙.
  final int? authorTeamId;

  final String body;

  /// 답글이 특정 사용자에게 향할 때 본문 앞에 붙는 `@닉네임`.
  final String? mention;

  final String timeAgo;
  final int likeCount;
  final bool liked;

  CommunityComment copyWith({int? likeCount, bool? liked}) {
    return CommunityComment(
      id: id,
      parentId: parentId,
      authorName: authorName,
      authorTeamId: authorTeamId,
      body: body,
      timeAgo: timeAgo,
      mention: mention,
      likeCount: likeCount ?? this.likeCount,
      liked: liked ?? this.liked,
    );
  }
}
