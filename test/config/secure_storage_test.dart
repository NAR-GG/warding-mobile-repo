import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/config/secure_storage.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Keychain 실패를 '값 없음'과 구분하는 헬퍼들의 회귀 테스트.
///
/// 잠금(-25308)으로 못 읽은 것을 null 로 접으면 호출부가 '비로그인'으로
/// 오해해 멀쩡한 유저를 로그아웃시킨다 (Sentry WARDING-APP-FLUTTER-C, 491명).
/// duplicate(-25299)로 write 가 튕기면 로그인 직후 토큰이 저장되지 않아
/// '로그인이 안 되는' 것처럼 보인다 (WARDING-APP-FLUTTER-12 외).
void main() {
  late MockSecureStorage storage;

  setUp(() => storage = MockSecureStorage());

  PlatformException lockedError() => PlatformException(
        code: 'Unexpected security result code',
        message: 'Code: -25308, Message: User interaction is not allowed.',
      );

  PlatformException duplicateError() => PlatformException(
        code: 'Unexpected security result code',
        message:
            'Code: -25299, Message: The specified item already exists in the keychain.',
      );

  group('isKeychainLockedError', () {
    test('-25308 을 잠금으로 인식한다', () {
      expect(isKeychainLockedError(lockedError()), isTrue);
    });

    test('-25291(Keychain 미가용)도 잠금으로 인식한다', () {
      expect(
        isKeychainLockedError(PlatformException(
          code: 'Unexpected security result code',
          message: 'Code: -25291, Message: No keychain is available.',
        )),
        isTrue,
      );
    });

    test('duplicate(-25299)는 잠금이 아니다', () {
      expect(isKeychainLockedError(duplicateError()), isFalse);
    });

    test('PlatformException 이 아니면 잠금이 아니다', () {
      expect(isKeychainLockedError(Exception('네트워크')), isFalse);
    });
  });

  group('readOrThrowIfLocked', () {
    test('잠금 실패는 예외로 올려 보낸다 — null(값 없음)로 접지 않는다', () async {
      when(() => storage.read(key: any(named: 'key'))).thenThrow(lockedError());

      expect(
        () => readOrThrowIfLocked('jwt', storage: storage),
        throwsA(isA<SecureStorageUnavailableException>()),
      );
    });

    test('잠금이 아닌 실패는 null 로 접는다', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenThrow(Exception('알 수 없는 실패'));

      expect(await readOrThrowIfLocked('jwt', storage: storage), isNull);
    });

    test('정상 읽기는 값을 그대로 준다', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'token');

      expect(await readOrThrowIfLocked('jwt', storage: storage), 'token');
    });
  });

  group('readOrNull', () {
    test('잠금 실패도 null 로 접는다 — 기본값으로 굴러가면 되는 값 전용', () async {
      when(() => storage.read(key: any(named: 'key'))).thenThrow(lockedError());

      expect(await readOrNull('preferred_team', storage: storage), isNull);
    });
  });

  group('writeWithDuplicateRecovery', () {
    test('duplicate(-25299)면 지우고 다시 써서 성공시킨다', () async {
      var writes = 0;
      when(() => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            iOptions: any(named: 'iOptions'),
          )).thenAnswer((_) async {
        writes++;
        if (writes == 1) throw duplicateError();
      });
      when(() => storage.delete(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
          )).thenAnswer((_) async {});

      await writeWithDuplicateRecovery(
        key: 'jwt',
        value: 'new-token',
        storage: storage,
      );

      // 첫 write 실패 → delete → 재시도 write 성공.
      expect(writes, 2);
      verify(() => storage.delete(
            key: 'jwt',
            iOptions: any(named: 'iOptions'),
          )).called(greaterThanOrEqualTo(1));
    });

    test('duplicate 가 아닌 실패는 그대로 던진다', () async {
      when(() => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            iOptions: any(named: 'iOptions'),
          )).thenThrow(lockedError());

      expect(
        () => writeWithDuplicateRecovery(
          key: 'jwt',
          value: 'token',
          storage: storage,
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    test('정상 write 는 한 번만 호출한다', () async {
      when(() => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            iOptions: any(named: 'iOptions'),
          )).thenAnswer((_) async {});

      await writeWithDuplicateRecovery(
        key: 'jwt',
        value: 'token',
        storage: storage,
      );

      verify(() => storage.write(
            key: 'jwt',
            value: 'token',
            iOptions: any(named: 'iOptions'),
          )).called(1);
      verifyNever(() => storage.delete(
            key: any(named: 'key'),
            iOptions: any(named: 'iOptions'),
          ));
    });
  });
}
