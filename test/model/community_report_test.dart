import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_report.dart';

void main() {
  test('CommunityReportTargetType.apiValue는 서버 문자열과 일치한다', () {
    expect(CommunityReportTargetType.post.apiValue, 'POST');
    expect(CommunityReportTargetType.comment.apiValue, 'COMMENT');
    expect(CommunityReportTargetType.image.apiValue, 'IMAGE');
  });

  test('CommunityReportReason.apiValue는 서버 문자열과 일치한다', () {
    expect(CommunityReportReason.abuse.apiValue, 'ABUSE');
    expect(CommunityReportReason.obscene.apiValue, 'OBSCENE');
    expect(CommunityReportReason.ad.apiValue, 'AD');
    expect(CommunityReportReason.fraud.apiValue, 'FRAUD');
    expect(CommunityReportReason.spam.apiValue, 'SPAM');
    expect(CommunityReportReason.etc.apiValue, 'ETC');
  });
}
