import 'community_author.dart';
import 'community_post_image.dart';

/// 팀 게시판 쓰기 잠금 사유.
enum CommunityWriteLockReason {
  /// 내 응원팀이 아닌 팀 게시판.
  notFan;

  static CommunityWriteLockReason? fromApi(String? value) {
    return value == 'NOT_FAN' ? CommunityWriteLockReason.notFan : null;
  }
}

/// 이 게시판에 쓸 수 있는가. 로그인 상태면 전체 게시판에도 실린다.
///
/// **자격([canWrite])과 간격([nextWritableAt])은 별개다.** 자격이 있어도 방금
/// 썼으면 잠깐 기다려야 한다 — 앞은 잠금 바, 뒤는 글쓰기 버튼 카운트다운으로
/// 서로 다르게 그린다.
class CommunityBoardViewer {
  const CommunityBoardViewer({
    required this.canWrite,
    this.reason,
    this.nextWritableAt,
  });

  final bool canWrite;
  final CommunityWriteLockReason? reason;

  /// 작성 간격에 걸려 있으면 다음 작성 가능 시각, 아니면 null.
  /// 간격은 게시판마다 따로 돈다.
  final DateTime? nextWritableAt;

  factory CommunityBoardViewer.fromJson(Map<String, dynamic> json) {
    return CommunityBoardViewer(
      canWrite: json['canWrite'] as bool? ?? false,
      reason: CommunityWriteLockReason.fromApi(json['reason'] as String?),
      nextWritableAt: DateTime.tryParse(
        json['nextWritableAt'] as String? ?? '',
      ),
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
    this.notificationEnabled = true,
  });

  final bool liked;
  final bool scrapped;
  final bool mine;

  /// true면 [CommunityRemotePostDetail.title]/[CommunityRemotePostDetail.body]/
  /// [CommunityRemotePostDetail.images]가 빈 값으로 온다 — "차단한 사용자의
  /// 글입니다" 자리를 그린다.
  final bool blockedAuthor;

  /// 이 글에서 오는 댓글·답글 알림 수신 여부(벨 토글). 기본 켬.
  final bool notificationEnabled;

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
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
    );
  }
}

/// 게시글 목록 요약 한 건.
class CommunityRemotePost {
  const CommunityRemotePost({
    required this.id,
    required this.boardTeamId,
    this.boardTeamCode,
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

  /// 게시판 팀의 코드(예: `GEN`, `HLE`). 전체 게시판이면 null.
  ///
  /// 내 활동 목록(내 글·좋아요·스크랩)은 게시판이 섞여 나와 줄마다 배지가 필요한데,
  /// [boardTeamId]만 있으면 팀 목록(`communityTeams`)을 받아야 이름을 안다. 그 조회가
  /// 실패하면 배지가 통째로 사라지므로 서버가 코드를 같이 내려준다.
  ///
  /// 작성자 응원팀([author].teamCode)과는 다른 값이다 — 다른팀 게시판에도 글은 보인다.
  final String? boardTeamCode;

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
      boardTeamCode: json['boardTeamCode'] as String?,
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
    this.bodyFormat = 'PLAIN',
    required this.images,
    required this.viewer,
  });

  final CommunityRemotePost summary;
  final String body;

  /// PLAIN = 평문, BLOCKS = [body]가 블록 JSON(렌더러가 해석을 가른다).
  final String bodyFormat;

  bool get isBlocks => bodyFormat == 'BLOCKS';

  final List<CommunityPostImage> images;
  final CommunityPostViewer viewer;

  int get id => summary.id;
  int? get boardTeamId => summary.boardTeamId;
  String? get boardTeamCode => summary.boardTeamCode;
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
      bodyFormat: json['bodyFormat'] as String? ?? 'PLAIN',
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
