import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';

/// 닫은 공지 id 저장의 회귀 테스트.
///
/// Keychain 실패를 삼키도록 바뀐 뒤에도 정상 경로(저장·누적·손상값 폴백)가
/// 그대로 도는지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = NoticePreferenceRepository.instance;

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('addDismissedId: 닫은 id 가 실제로 저장된다', () async {
    await repo.addDismissedId(7);

    expect(await repo.loadDismissedIds(), contains(7));
  });

  test('addDismissedId: 기존 id 를 유지한 채 누적된다', () async {
    await repo.addDismissedId(1);
    await repo.addDismissedId(2);

    expect(await repo.loadDismissedIds(), {1, 2});
  });

  test('loadDismissedIds: 저장된 적 없으면 빈 셋', () async {
    expect(await repo.loadDismissedIds(), isEmpty);
  });

  test('loadDismissedIds: 손상된 값이면 빈 셋', () async {
    FlutterSecureStorage.setMockInitialValues({
      'dismissed_notice_ids': 'not-json',
    });

    expect(await repo.loadDismissedIds(), isEmpty);
  });
}
