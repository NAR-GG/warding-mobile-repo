import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
  });
  tearDown(() => api.setApiClientForTesting(null));

  Future<Uri> capture({String? sort}) async {
    Uri? url;
    api.setApiClientForTesting(MockClient((request) async {
      url = request.url;
      return http.Response(jsonEncode({'posts': <dynamic>[]}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await CommunityRepository.instance.fetchPosts(size: 4, sort: sort);
    return url!;
  }

  test('sort=hot 이면 쿼리에 붙는다', () async {
    expect((await capture(sort: 'hot')).queryParameters['sort'], 'hot');
  });

  test('sort 를 안 주면 쿼리에 붙지 않는다', () async {
    expect((await capture()).queryParameters.containsKey('sort'), isFalse);
  });
}
