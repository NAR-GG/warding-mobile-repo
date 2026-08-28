import 'community_author.dart';
import 'community_post_image.dart';

/// 팀 게시판 쓰기 잠금 사유.
enum CommunityWriteLockReason {
  /// 내 응원팀이 아닌 팀 게시판.
  notFan,

  /// 응원팀을 바꾼 지 30일이 안 지남.
  cooldown;

  static CommunityWriteLockReason? fromApi(String? value) {
    switch (value) {
      case 'NOT_FAN':
        return CommunityWriteLockReason.notFan;
      case 'COOLDOWN':
        return CommunityWriteLockReason.cooldown;
      default:
        return null;
    }
  }
}

/// 팀 게시판 쓰기 잠금 바. 팀 게시판 + 로그인일 때만 목록 응답에 실린다.
class CommunityBoardViewer {
  const CommunityBoardViewer({
    required this.canWrite,
    this.reason,
    this.writableFrom,
  });

  final bool canWrite;
  final CommunityWriteLockReason? reason;

  /// [reason]이 cooldown일 때 다시 쓸 수 있게 되는 시각.
  final DateTime? writableFrom;

  factory CommunityBoardViewer.fromJson(Map<String, dynamic> json) {
    return CommunityBoardViewer(
      canWrite: json['canWrite'] as bool? ?? false,
      reason: CommunityWriteLockReason.fromApi(json['reason'] as String?),
      writableFrom: DateTime.tryParse(json['writableFrom'] as String? ?? ''),
    );
  }
}

/// 게시글 상세 조회자 관점 상태.
class CommunityPostViewer {
  const CommunityPostViewer({
    required this.liked,
    required this.scrapped,
    required this.mine,
    required this.blockedAuthor,
  });

  final bool liked;
  final bool scrapped;
  final bool mine;

  /// true면 [CommunityRemotePostDetail.title]/[CommunityRemotePostDetail.body]/
  /// [CommunityRemotePostDetail.images]가 빈 값으로 온다 — "차단한 사용자의
  /// 글입니다" 자리를 그린다.
  final bool blockedAuthor;

  static const _empty = CommunityPostViewer(
    liked: false,
    scrapped: false,
    mine: false,
    blockedAuthor: false,
  );

  factory CommunityPostViewer.fromJson(Map<String, dynamic> json) {
    return CommunityPostViewer(
      liked: json['liked'] as bool? ?? false,
      scrapped: json['scrapped'] as bool? ?? false,
      mine: json['mine'] as bool? ?? false,
      blockedAuthor: json['blockedAuthor'] as bool? ?? false,
    );
  }
}

/// 게시글 목록 요약 한 건.
class CommunityRemotePost {
  const CommunityRemotePost({
    required this.id,
    required this.boardTeamId,
    required this.title,
    required this.bodyPreview,
    required this.author,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.edited,
    required this.createdAt,
    this.thumbnailUrl,
    this.imageCount = 0,
  });

  final int id;

  /// null이면 전체 게시판 글.
  final int? boardTeamId;

  final String title;
  final String bodyPreview;

  /// 응답에 `author`가 없으면(탈퇴 회원) null.
  final CommunityAuthor? author;

  final int viewCount;
  final int likeCount;
  final int commentCount;

  /// 수정됨 표시 기준. `updatedAt`으로 판단하지 않는다.
  final bool edited;

  final DateTime? createdAt;
  final String? thumbnailUrl;
  final int imageCount;

  factory CommunityRemotePost.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    return CommunityRemotePost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      boardTeamId: (json['boardTeamId'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      bodyPreview: json['bodyPreview'] as String? ?? '',
      author: author == null
          ? null
          : CommunityAuthor.fromJson(author as Map<String, dynamic>),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      edited: json['edited'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 게시글 상세 — 목록 요약 필드 + 본문·이미지·조회자 상태.
class CommunityRemotePostDetail {
  const CommunityRemotePostDetail({
    required this.summary,
    required this.body,
    required this.images,
    required this.viewer,
  });

  final CommunityRemotePost summary;
  final String body;
  final List<CommunityPostImage> images;
  final CommunityPostViewer viewer;

  int get id => summary.id;
  int? get boardTeamId => summary.boardTeamId;
  String get title => summary.title;
  CommunityAuthor? get author => summary.author;
  int get viewCount => summary.viewCount;
  int get likeCount => summary.likeCount;
  int get commentCount => summary.commentCount;
  bool get edited => summary.edited;
  DateTime? get createdAt => summary.createdAt;

  factory CommunityRemotePostDetail.fromJson(Map<String, dynamic> json) {
    return CommunityRemotePostDetail(
      summary: CommunityRemotePost.fromJson(json),
      body: json['body'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((e) => CommunityPostImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      viewer: json['viewer'] == null
          ? CommunityPostViewer._empty
          : CommunityPostViewer.fromJson(
              json['viewer'] as Map<String, dynamic>,
            ),
    );
  }
}

/// 게시글 목록 페이지 응답.
class CommunityRemotePostPage {
  const CommunityRemotePostPage({
    required this.posts,
    this.nextCursor,
    this.boardViewer,
  });

  final List<CommunityRemotePost> posts;
  final int? nextCursor;

  /// 팀 게시판 + 로그인일 때만 채워진다.
  final CommunityBoardViewer? boardViewer;

  factory CommunityRemotePostPage.fromJson(Map<String, dynamic> json) {
    return CommunityRemotePostPage(
      posts: (json['posts'] as List<dynamic>? ?? const [])
          .map((e) => CommunityRemotePost.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
      boardViewer: json['boardViewer'] == null
          ? null
          : CommunityBoardViewer.fromJson(
              json['boardViewer'] as Map<String, dynamic>,
            ),
    );
  }
}
