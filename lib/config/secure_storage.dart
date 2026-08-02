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
