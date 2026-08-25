import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/filter_preference_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/schedule/schedule_viewmodel.dart';

class MockFilterPreferenceRepository extends Mock
    implements FilterPreferenceRepository {}

/// "경기 일정 필터가 간헐적으로 전체로 풀린다"의 회귀 테스트.
///
/// 저장된 필터를 못 읽었을 때(Keychain 잠금 등) 화면은 기본값 '전체'로 서는데,
/// 그 상태에서 저장까지 하면 디스크의 멀쩡한 필터가 영구히 날아갔다.
/// 못 읽은 것과 저장된 적 없는 것을 구분해, 전자면 저장을 막는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFilterPreferenceRepository prefs;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    NoticeRepository.instance.resetPromotedCacheForTesting();
    NoticePreferenceRepository.instance.resetCacheForTesting();

    prefs = MockFilterPreferenceRepository();
    when(() => prefs.save(any(), any())).thenAnswer((_) async {});

    // 캘린더·공지 등 모든 조회를 빈 응답으로 성립만 시킨다.
    api.setApiClientForTesting(MockClient((_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('저장값을 못 읽었으면(readFailed) 필터를 덮어쓰지 않는다', () async {
    when(() => prefs.load(FilterPreferenceRepository.scheduleKey))
        .thenAnswer((_) async => const FilterPreferenceResult.failed());

    final vm = ScheduleViewModel(filterPreferences: prefs);
    await pumpEventQueue();

    vm.applyFilter(leagues: ['ALL'], teamIds: const []);
    await pumpEventQueue();

    verifyNever(() => prefs.save(any(), any()));
  });

  test('정상적으로 읽었으면(값 없음 포함) 필터를 저장한다', () async {
    when(() => prefs.load(FilterPreferenceRepository.scheduleKey))
        .thenAnswer((_) async => const FilterPreferenceResult.loaded(null));

    final vm = ScheduleViewModel(filterPreferences: prefs);
    await pumpEventQueue();

    vm.applyFilter(leagues: ['LCK'], teamIds: const []);
    await pumpEventQueue();

    final saved = verify(() =>
            prefs.save(FilterPreferenceRepository.scheduleKey, captureAny()))
        .captured
        .last as Map<String, dynamic>;
    expect(saved['leagues'], ['LCK']);
  });

  test('응원팀을 모르면 팀 토글이 필터를 비우지 않는다', () async {
    when(() => prefs.load(FilterPreferenceRepository.scheduleKey))
        .thenAnswer((_) async => const FilterPreferenceResult.loaded({
              'leagues': ['LCK'],
              'teamIds': [7],
              'teamSelected': true,
            }));

    final vm = ScheduleViewModel(filterPreferences: prefs);
    await pumpEventQueue();

    // 응원팀 조회는 위 MockClient 의 빈 응답 때문에 확정되지 않는다.
    expect(vm.preferredTeam, isNull);

    vm.toggleTeamSelected();
    await pumpEventQueue();

    expect(vm.filterTeamIds, [7], reason: '저장된 팀 필터가 유지돼야 한다');
    expect(vm.teamSelected, isTrue);
  });
}
