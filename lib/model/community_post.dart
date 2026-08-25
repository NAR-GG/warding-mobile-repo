import 'community_poll.dart';

/// 커뮤니티 게시글.
///
/// 백엔드 API 가 아직 없어 `fromJson` 은 두지 않는다. 계약이 확정되면 그때
/// 기존 모델(`notice.dart` 등)과 같은 방식으로 붙인다.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.boardId,
    required this.title,
    required this.body,
    required this.authorName,
    required this.authorTeamId,
    required this.timeAgo,
    required this.viewCount,
    required this.commentCount,
    required this.likeCount,
    this.images = const [],
    this.poll,
    this.liked = false,
    this.scrapped = false,
  });

  final int id;

  /// 게시판 식별자. [CommunityBoard.allId] 는 전체 게시판, 그 외에는 팀 id.
  final int boardId;

  final String title;
  final String body;
  final String authorName;

  /// **작성 시점** 응원팀. 작성자가 나중에 팀을 옮겨도 이 값은 그대로 둔다 —
  /// 현재 팀을 조인해 그리면 과거 글의 로고가 전부 새 팀으로 뒤집힌다.
  /// 응원팀 없이 쓴 글은 null.
  final int? authorTeamId;

  final String timeAgo;
  final String viewCount;
  final int commentCount;
  final int likeCount;

  /// 첨부 사진. 더미 단계에서는 `assets/` 로 시작하는 로컬 에셋 경로를 넣고,
  /// 백엔드가 붙으면 같은 자리에 업로드된 URL 이 들어온다
  /// (`CommunityImage` 가 둘을 구분해 그린다).
  final List<String> images;

  /// 붙은 투표. 없으면 null.
  final CommunityPoll? poll;

  final bool liked;
  final bool scrapped;

  CommunityPost copyWith({
    int? likeCount,
    bool? liked,
    bool? scrapped,
    int? commentCount,
    CommunityPoll? poll,
  }) {
    return CommunityPost(
      id: id,
      boardId: boardId,
      title: title,
      body: body,
      authorName: authorName,
      authorTeamId: authorTeamId,
      timeAgo: timeAgo,
      viewCount: viewCount,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      images: images,
      poll: poll ?? this.poll,
      liked: liked ?? this.liked,
      scrapped: scrapped ?? this.scrapped,
    );
  }
}

/// 게시판 하나 — 전체 게시판 또는 팀 게시판.
class CommunityBoard {
  const CommunityBoard({
    required this.id,
    required this.name,
    required this.color,
  });

  /// 전체 게시판의 [id]. 팀 id 와 겹치지 않도록 음수를 쓴다.
  static const int allId = -1;

  final int id;
  final String name;

  /// 팀 대표색. 로고 이미지가 붙기 전까지 원형 플레이스홀더를 이 색으로 그린다.
  final int color;

  bool get isAll => id == allId;
}
