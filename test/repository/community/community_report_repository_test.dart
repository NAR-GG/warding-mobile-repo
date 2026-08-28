import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/model/community_report.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_api_exception.dart';
import 'package:warding/repository/community/community_report_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityReportRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('report는 targetType·reason을 API 문자열로 보낸다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/community/reports');
        expect(request.body, contains('"targetType":"IMAGE"'));
        expect(request.body, contains('"reason":"ETC"'));
        expect(request.body, contains('"detail":"기타 사유"'));
        return http.Response('', 204);
      }),
    );

    await repo.report(
      targetType: CommunityReportTargetType.image,
      targetId: 3,
      reason: CommunityReportReason.etc,
      detail: '기타 사유',
    );
  });

  test('중복 신고는 409 CommunityApiException을 던진다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('{"code":"COMMUNITY_ALREADY_REPORTED","message":"이미 신고했습니다."}'),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      () => repo.report(
        targetType: CommunityReportTargetType.post,
        targetId: 42,
        reason: CommunityReportReason.spam,
      ),
      throwsA(
        isA<CommunityApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });

  test('block은 POST /blocks에 memberId를 보낸다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/community/blocks');
        expect(request.body, contains('"memberId":7'));
        return http.Response('', 204);
      }),
    );

    await repo.block(7);
  });

  test('unblock은 DELETE /blocks/{memberId}로 호출한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/mobile/community/blocks/7');
        return http.Response('', 204);
      }),
    );

    await repo.unblock(7);
  });
}
