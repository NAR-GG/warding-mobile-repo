import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_image_repository.dart';
import 'package:warding/util/api_client.dart' as api;

// Cloudinary 업로드 leg(`request.send()`)는 `BaseRequest.send()`가 내부에서
// 매번 새 `Client()`를 만들어 쓰므로(package:http 1.6.0, base_request.dart:141)
// `setApiClientForTesting`으로 가로챌 수 없다. `ProfileImageRepository`와
// 같은 제약이라 여기서도 서명 발급 단계까지만 단위 테스트한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityImageRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('서명 발급이 실패하면 예외를 던진다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, contains('community-image/signature'));
        expect(request.headers['Authorization'], 'Bearer test-jwt');
        return http.Response.bytes(
          utf8.encode('{"message":"서명 발급 실패"}'),
          500,
        );
      }),
    );

    await expectLater(
      () => repo.upload(File('/nonexistent/path.png')),
      throwsA(isA<Exception>()),
    );
  });
}
