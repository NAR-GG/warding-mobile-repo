/// 신고 대상 종류.
enum CommunityReportTargetType {
  post,
  comment,
  image;

  String get apiValue => switch (this) {
    CommunityReportTargetType.post => 'POST',
    CommunityReportTargetType.comment => 'COMMENT',
    CommunityReportTargetType.image => 'IMAGE',
  };
}

/// 신고 사유. [etc]는 상세 사유(`detail`, ≤200자)가 필수다.
enum CommunityReportReason {
  abuse,
  obscene,
  ad,
  fraud,
  spam,
  etc;

  String get apiValue => switch (this) {
    CommunityReportReason.abuse => 'ABUSE',
    CommunityReportReason.obscene => 'OBSCENE',
    CommunityReportReason.ad => 'AD',
    CommunityReportReason.fraud => 'FRAUD',
    CommunityReportReason.spam => 'SPAM',
    CommunityReportReason.etc => 'ETC',
  };
}
