import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/schedule/schedule_viewmodel.dart';

/// 헤더 필터 버튼 테두리 표시([hasActiveFilter])의 회귀 테스트.
///
/// 리그·팀 모두 '전체'일 때만 false — 그 외(특정 리그 선택, 팀 선택,
/// 헤더 응원팀 토글)는 모두 true 여야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    NoticeRepository.instance.resetPromotedCacheForTesting();
    NoticePreferenceRepository.instance.resetCacheForTesting();

    api.setApiClientForTesting(MockClient((_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('기본값(리그·팀 전체)이면 false', () async {
    final vm = ScheduleViewModel();
    await pumpEventQueue();

    expect(vm.hasActiveFilter, isFalse);
  });

  test('특정 리그를 선택하면 true', () async {
    final vm = ScheduleViewModel();
    await pumpEventQueue();

    vm.applyFilter(leagues: ['LCK'], teamIds: const []);
    await pumpEventQueue();

    expect(vm.hasActiveFilter, isTrue);
  });

  test('리그는 전체여도 팀을 선택하면 true', () async {
    final vm = ScheduleViewModel();
    await pumpEventQueue();

    vm.applyFilter(leagues: const ['ALL'], teamIds: [7]);
    await pumpEventQueue();

    expect(vm.hasActiveFilter, isTrue);
  });

  test('필터를 초기화(전체로 되돌림)하면 다시 false', () async {
    final vm = ScheduleViewModel();
    await pumpEventQueue();

    vm.applyFilter(leagues: ['LCK'], teamIds: [7]);
    await pumpEventQueue();
    expect(vm.hasActiveFilter, isTrue);

    vm.applyFilter(leagues: const ['ALL'], teamIds: const []);
    await pumpEventQueue();

    expect(vm.hasActiveFilter, isFalse);
  });
}
