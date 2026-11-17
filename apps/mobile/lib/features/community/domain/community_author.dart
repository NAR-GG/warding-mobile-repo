/// 커뮤니티 글·댓글 작성자 스냅샷.
///
/// 응답에 `author` 자체가 없으면(회원 하드 삭제) 상위 모델에서
/// `CommunityAuthor?`가 null — "탈퇴한 사용자"로 그린다.
class CommunityAuthor {
  const CommunityAuthor({
    required this.memberId,
    required this.nickname,
    this.profileImageUrl,
    this.teamId,
    this.teamCode,
    this.teamImageUrl,
  });

  final int memberId;
  final String nickname;
  final String? profileImageUrl;

  /// **작성 시점** 응원팀 스냅샷. 작성자가 나중에 팀을 옮겨도 이 값은
  /// 그대로다 — 현재 팀을 조인하면 과거 글의 뱃지가 전부 새 팀으로 뒤집힌다.
  final int? teamId;
  final String? teamCode;
  final String? teamImageUrl;

  factory CommunityAuthor.fromJson(Map<String, dynamic> json) {
    return CommunityAuthor(
      memberId: (json['memberId'] as num?)?.toInt() ?? 0,
      nickname: json['nickname'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      teamId: (json['teamId'] as num?)?.toInt(),
      teamCode: json['teamCode'] as String?,
      teamImageUrl: json['teamImageUrl'] as String?,
    );
  }
}
