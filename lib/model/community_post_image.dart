/// 게시글 상세에 첨부된 이미지 한 장.
///
/// [id]는 이미지 신고(`CommunityReportTargetType.image`)의 targetId로 쓰인다.
class CommunityPostImage {
  const CommunityPostImage({required this.id, required this.url});

  final int id;
  final String url;

  factory CommunityPostImage.fromJson(Map<String, dynamic> json) {
    return CommunityPostImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
    );
  }
}
