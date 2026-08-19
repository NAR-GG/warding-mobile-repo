import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/auth/auth_service.dart';

/// 강제 로그아웃은 **서버가 401 로 토큰 무효를 확정했을 때만** 일어나야 한다.
///
/// 이 경계가 무너져 전 사용자가 튕겨나간 사고가 반복됐다(#150 잠금 -25308,
/// #174 refresh 일시 실패, #192 Keychain 강제 로그아웃). 그때마다 특정 오류
/// 코드를 하나씩 예외 처리했는데, 그 방식으로는 목록에 없는 실패가 계속
/// 남는다 — 여기서는 "읽지 못한 모든 경우"가 로그아웃으로 이어지지 않는지를
/// 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final auth = AuthService.instance;

  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// Keychain read 를 [error] 로 실패시킨다. write/delete 는 통과.
  ///
  /// [FlutterSecureStorage.setMockInitialValues] 도 같은 채널에 핸들러를
  /// 설치하므로, 반드시 그 뒤에 불러야 이쪽이 유효하다.
  void failReadWith(Object error) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') throw error;
      return null;
    });
  }

  setUp(() {
    auth.resetJwtCacheForTesting();
    // 앞선 테스트가 남긴 재발급 결과를 물려받지 않도록 비운다 —
    // refreshAccessToken 은 진행 중인 요청을 공유한다.
    auth.resetRefreshForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('리프레시 토큰을 읽지 못했을 때 — 로그아웃 금지', () {
    test('기기 잠금(-25308)은 일시 장애다', () async {
      failReadWith(PlatformException(
        code: '-25308',
        message: 'User interaction is not allowed.',
      ));

      final result = await auth.refreshAccessToken();

      expect(result.tokenInvalid, isFalse);
      expect(result.token, isNull);
    });

    test('잠금이 아닌 Keychain 오류(-25300)도 일시 장애다', () async {
      // 이 케이스가 재발의 실제 경로였다. 예전에는 read 실패가 null 로 접히고,
      // 그 null 이 '리프레시 토큰 없음 = 재로그인 필요'로 해석돼 곧장
      // 강제 로그아웃이 됐다.
      failReadWith(PlatformException(
        code: '-25300',
        message: 'The specified item could not be found in the keychain.',
      ));

      final result = await auth.refreshAccessToken();

      expect(
        result.tokenInvalid,
        isFalse,
        reason: '토큰이 죽었다는 증거가 없는데 로그아웃하면 안 된다',
      );
    });

    test('알 수 없는 예외도 일시 장애다 — 목록에 없는 실패가 계속 나온다', () async {
      failReadWith(Exception('알 수 없는 저장소 실패'));

      final result = await auth.refreshAccessToken();

      expect(result.tokenInvalid, isFalse);
    });
  });

  test('정말로 저장된 적 없으면 무효 확정 — 재로그인만이 답이다', () async {
    // read 가 성공적으로 '없음'을 알려 준 경우. 이때는 재발급할 수단이
    // 없으므로 로그아웃이 맞다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final result = await auth.refreshAccessToken();

    expect(result.tokenInvalid, isTrue);
  });
}
