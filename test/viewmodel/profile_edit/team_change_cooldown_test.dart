import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/profile_edit/profile_edit_viewmodel.dart';

/// 응원팀은 30일에 한 번만 바꿀 수 있다. 화면이 아니라 여기서 막아야 "고를 수는
/// 있는데 저장이 안 되는" 상태가 안 생긴다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
    AuthService.instance.resetMeCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  /// `/auth/me` 는 [changeAvailableFrom] 을 실어 주고, 팀 목록은 둘만 준다.
  void serve(String? changeAvailableFrom) {
    api.setApiClientForTesting(
      MockClient((request) async {
        final body = request.url.path.contains('/onboarding/teams')
            ? jsonEncode([
                {'id': 1, 'name': 'T1', 'code': 'T1', 'imageUrl': ''},
                {'id': 2, 'name': 'HLE', 'code': 'HLE', 'imageUrl': ''},
              ])
            : jsonEncode({
                'id': 7,
                'nickname': '이름#0001',
                'name': '이름',
                'tag': '0001',
                'favoriteTeamId': 1,
                'favoriteTeamChangeAvailableFrom': changeAvailableFrom,
              });
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  Future<ProfileEditViewModel> loaded(String? changeAvailableFrom) async {
    serve(changeAvailableFrom);
    final vm = ProfileEditViewModel();
    // 생성자가 load() 를 띄운다. 두 요청이 끝날 때까지 기다린다.
    for (var i = 0; i < 20 && vm.isLoading; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return vm;
  }

  test('쿨다운이 없으면 다른 팀을 고를 수 있다', () async {
    final vm = await loaded(null);
    expect(vm.teamChangeLocked, isFalse);
    expect(vm.selectTeam(2), isTrue);
    expect(vm.favoriteTeamId, 2);
    expect(vm.teamChanged, isTrue);
    vm.dispose();
  });

  test('쿨다운 중이면 다른 팀 선택이 거절된다', () async {
    final vm = await loaded('2099-01-01T00:00:00');
    expect(vm.teamChangeLocked, isTrue);
    expect(vm.selectTeam(2), isFalse);
    // 거절됐으면 선택도 안 바뀌어야 한다 — 바뀐 채로 두면 저장에서야 알게 된다.
    expect(vm.favoriteTeamId, 1);
    expect(vm.teamChanged, isFalse);
    vm.dispose();
  });

  test('쿨다운 중이어도 원래 팀 재선택은 통과한다', () async {
    final vm = await loaded('2099-01-01T00:00:00');
    expect(vm.selectTeam(1), isTrue);
    expect(vm.teamChanged, isFalse);
    vm.dispose();
  });
}
