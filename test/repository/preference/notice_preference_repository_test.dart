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

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    // repo 는 테스트 파일 전체가 공유하는 싱글턴이라, storage 를 갈아끼우면
    // 인메모리 캐시도 같이 비워야 이전 테스트가 넣어 둔 id 가 남지 않는다.
    repo.resetCacheForTesting();
  });

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
    repo.resetCacheForTesting();

    expect(await repo.loadDismissedIds(), isEmpty);
  });

  test('cachedValue: 로드 전엔 null, 로드 후엔 그 값을 동기로 준다', () async {
    // 일정 화면이 첫 프레임에 배너 표시 여부를 정하는 근거다 — 여기가 null 이면
    // 닫았던 배너가 한 프레임 보였다가 사라지며 캘린더를 밀어낸다.
    expect(repo.cachedValue, isNull);

    await repo.addDismissedId(5);

    expect(repo.cachedValue, contains(5));
  });

  test('cachedValue 를 밖에서 고쳐도 저장된 목록은 그대로다', () async {
    await repo.addDismissedId(1);
    repo.cachedValue!.add(999);

    expect(await repo.loadDismissedIds(), {1});
  });
}
