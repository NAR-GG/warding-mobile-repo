import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 앱 전역 공용 secure storage.
///
/// iOS Keychain 기본 접근성(`unlocked`)은 기기 잠금 중 백그라운드 실행
/// (prewarming·홈 위젯 갱신·FCM)에서 읽기가 -25308(errSecInteractionNotAllowed)로
/// 실패한다. `first_unlock_this_device`는 재부팅 후 첫 잠금해제 이후엔
/// 잠금 상태에서도 접근된다.
///
/// 새 저장소는 반드시 이 인스턴스를 쓴다 — 기본 `FlutterSecureStorage()`를
/// 직접 만들면 접근성이 갈라져, 같은 키가 안 읽히거나(-25308) 이미 있는
/// 항목에 write 가 duplicate 로 실패하는 사고가 재발한다.
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// Keychain 접근 실패를 '값 없음'과 구분해 전달하는 예외.
///
/// 기기 잠금(-25308) 등으로 **읽지 못한** 것이지 저장된 값이 없는 게 아니다.
/// 로그인 여부처럼 null 을 '비로그인'으로 해석하는 호출부는 이 예외를 잡아
/// 판단을 보류해야 한다 — null 로 뭉개면 멀쩡한 유저가 로그아웃된다.
class SecureStorageUnavailableException implements Exception {
  const SecureStorageUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'SecureStorageUnavailableException($cause)';
}

/// 기기 잠금 때문에 Keychain 을 못 읽는 상황인지.
///
/// -25308 `errSecInteractionNotAllowed`: 잠금 상태 백그라운드 접근.
/// -25291 `errSecNotAvailable`: Keychain 자체가 아직 안 열림(부팅 직후 등).
/// 둘 다 시간이 해결하는 문제라 '값 없음'으로 단정하면 안 된다.
bool isKeychainLockedError(Object e) {
  if (e is! PlatformException) return false;
  final code = e.code;
  final message = e.message ?? '';
  return code.contains('-25308') ||
      code.contains('-25291') ||
      message.contains('-25308') ||
      message.contains('-25291') ||
      message.contains('User interaction is not allowed') ||
      message.contains('No keychain is available');
}

/// 항목이 이미 존재해 write 가 거부된 상황(-25299 `errSecDuplicateItem`)인지.
///
/// 같은 키가 다른 접근성으로 남아 있을 때 발생한다. delete 후 재시도하면 풀린다.
bool isKeychainDuplicateError(Object e) {
  if (e is! PlatformException) return false;
  final code = e.code;
  final message = e.message ?? '';
  return code.contains('-25299') ||
      message.contains('-25299') ||
      message.contains('already exists in the keychain');
}

/// 잠금 등으로 읽지 못하면 [SecureStorageUnavailableException] 을 던지고,
/// 그 밖의 실패는 null(값 없음)로 접는다.
///
/// 로컬 설정처럼 못 읽어도 기본값으로 굴러가면 되는 호출부는
/// [readOrNull] 을 쓴다 — 이쪽은 잠금까지 null 로 접는다.
Future<String?> readOrThrowIfLocked(
  String key, {
  FlutterSecureStorage? storage,
}) async {
  try {
    return await (storage ?? secureStorage).read(key: key);
  } catch (e) {
    if (isKeychainLockedError(e)) {
      throw SecureStorageUnavailableException(e);
    }
    debugPrint('[SecureStorage] read 실패($key): $e');
    return null;
  }
}

/// 어떤 실패든 null 로 접고 읽는다 — 못 읽으면 기본값으로 굴러가는 값 전용.
///
/// 로그인 여부·토큰처럼 null 의 의미가 큰 값에는 쓰면 안 된다
/// ([readOrThrowIfLocked] 를 쓸 것).
Future<String?> readOrNull(String key, {FlutterSecureStorage? storage}) async {
  try {
    return await (storage ?? secureStorage).read(key: key);
  } catch (e) {
    debugPrint('[SecureStorage] read 실패(무시, $key): $e');
    return null;
  }
}

/// 항목이 이미 있어(-25299) 실패하면 지우고 한 번 더 쓴다.
///
/// 접근성이 갈린 잔여 항목 때문에 write 가 duplicate 로 튕기는 경우가 있다
/// (로그인 직후 jwt 저장이 실패해 '로그인이 안 되는' 증상의 원인).
/// delete 는 접근성을 가리지 않으므로 구·신 항목 모두 정리된다.
Future<void> writeWithDuplicateRecovery({
  required String key,
  required String? value,
  IOSOptions? iOptions,
  FlutterSecureStorage? storage,
}) async {
  final s = storage ?? secureStorage;
  try {
    await s.write(key: key, value: value, iOptions: iOptions);
    return;
  } catch (e) {
    if (!isKeychainDuplicateError(e)) rethrow;
    debugPrint('[SecureStorage] write duplicate($key) — 삭제 후 재시도');
  }
  await s.delete(key: key, iOptions: iOptions);
  // 구 접근성으로 남은 잔여 항목도 함께 지운다 — 이게 duplicate 의 실제 원인이다.
  try {
    await s.delete(key: key, iOptions: const IOSOptions());
  } catch (_) {
    // 없으면 그만이다.
  }
  await s.write(key: key, value: value, iOptions: iOptions);
}

/// 구(기본 `unlocked`) 접근성으로 저장된 기존 Keychain 항목을
/// `first_unlock_this_device`로 옮긴다. 앱 시작(스플래시)에서 호출.
///
/// 반환값: 마이그레이션이 완료된 상태면 true. false 면 아직 구 접근성
/// 항목이 남아 있어 **새 옵션 read 가 예외 없이 null 을 반환한다** —
/// 호출부는 이 상태에서 jwt null 을 '비로그인'으로 해석하면 안 된다.
///
/// 옵션만 바꾸면 안 되는 이유: 플러그인이 read/write 쿼리에
/// `kSecAttrAccessible`을 포함해서, 구 항목은 새 옵션으로 안 읽히고(null →
/// 전 유저 로그아웃) 같은 키 write 는 duplicate 로 실패한다.
/// 그래서 구 옵션으로 전부 읽어 → 지우고 → 새 옵션으로 다시 쓴다.
///
/// 완료 플래그는 성공 시에만 남으므로 실패해도 다음 실행에서 재시도된다.
Future<bool> migrateKeychainAccessibility() async {
  if (kIsWeb || !Platform.isIOS) return true;
  const doneKey = 'keychain_accessibility_v2';
  const legacyOptions = IOSOptions(); // accessibility: unlocked (구 기본값)
  try {
    if (await secureStorage.read(key: doneKey) == 'done') return true;

    // 잠금 상태면 구 항목 read 자체가 -25308이고, delete→write 사이에
    // 프로세스가 죽으면(백그라운드 jetsam) 값이 유실된다 —
    // 잠금해제(포그라운드) 상태에서만 수행한다.
    if (await secureStorage.isCupertinoProtectedDataAvailable() != true) {
      return false;
    }

    final legacy = await secureStorage.readAll(iOptions: legacyOptions);
    for (final entry in legacy.entries) {
      await secureStorage.delete(key: entry.key, iOptions: legacyOptions);
      try {
        await secureStorage.write(key: entry.key, value: entry.value);
      } on PlatformException {
        // 새 옵션 write 실패 시 구 옵션으로 복원 — jwt 등 값 유실 방지.
        await secureStorage.write(
          key: entry.key,
          value: entry.value,
          iOptions: legacyOptions,
        );
        rethrow;
      }
    }
    await secureStorage.write(key: doneKey, value: 'done');
    debugPrint('[SecureStorage] 접근성 마이그레이션 완료: ${legacy.length}개');
    return true;
  } on PlatformException catch (e) {
    debugPrint('[SecureStorage] 접근성 마이그레이션 보류(다음 실행에 재시도): $e');
    return false;
  }
}
