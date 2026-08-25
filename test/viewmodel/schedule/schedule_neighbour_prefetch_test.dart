import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/match_calendar_day.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/filter_preference_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/viewmodel/schedule/schedule_viewmodel.dart';

class MockScheduleRepository extends Mock implements ScheduleRepository {}

class MockFilterPreferenceRepository extends Mock
    implements FilterPreferenceRepository {}

/// 캘린더 스와이프 중 이웃 달 페이지가 빈 그리드로 나오던 문제의 회귀 테스트.
///
/// `PageView` 는 전환 중 두 달을 나란히 보여 주는데, ViewModel 이 표시 월
/// 하나만 들고 있으면 들어오는(또는 나가는) 쪽에 칩이 없어 화면이 한 번
/// 깨진 것처럼 보인다. 표시 월을 받은 뒤 앞뒤 달까지 채워 둔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockScheduleRepository repository;
  late MockFilterPreferenceRepository prefs;

  MatchCalendarDay dayOf(DateTime month) => MatchCalendarDay(
    date: DateTime(month.year, month.month, 1),
    matchCount: 1,
    matches: [
      CalendarMatchBrief(
        matchId: '${month.year}-${month.month}',
        blueTeamCode: 'T1',
        redTeamCode: 'GEN',
        blueTeamName: 'T1',
        redTeamName: 'Gen.G',
        displayText: 'T1 vs GEN',
      ),
    ],
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    NoticeRepository.instance.resetPromotedCacheForTesting();
    NoticePreferenceRepository.instance.resetCacheForTesting();

    prefs = MockFilterPreferenceRepository();
    when(() => prefs.save(any(), any())).thenAnswer((_) async {});
    when(() => prefs.load(any()))
        .thenAnswer((_) async => const FilterPreferenceResult.loaded(null));

    repository = MockScheduleRepository();
    // 어느 달을 물어도 그 달 1일에 경기 하나 — 어느 달이 채워졌는지만 본다.
    when(
      () => repository.fetchCalendar(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((invocation) async {
      final month = invocation.positionalArguments.first as DateTime;
      return [dayOf(month)];
    });
  });

  ScheduleViewModel createViewModel(DateTime month) => ScheduleViewModel(
    initialMonth: month,
    repository: repository,
    filterPreferences: prefs,
  );

  test('표시 월을 받으면 앞뒤 달도 미리 채워 둔다', () async {
    final vm = createViewModel(DateTime(2026, 8));
    await pumpEventQueue();

    expect(vm.matchesOfMonth(DateTime(2026, 7)), isNotEmpty, reason: '이전 달');
    expect(vm.matchesOfMonth(DateTime(2026, 8)), isNotEmpty, reason: '표시 달');
    expect(vm.matchesOfMonth(DateTime(2026, 9)), isNotEmpty, reason: '다음 달');
  });

  test('연말을 넘겨도 이웃 달이 해까지 정규화된다', () async {
    final vm = createViewModel(DateTime(2026, 12));
    await pumpEventQueue();

    expect(vm.matchesOfMonth(DateTime(2027, 1)), isNotEmpty);
    expect(vm.matchesOfMonth(DateTime(2026, 11)), isNotEmpty);
  });

  test('멀리 이동하면 옛 달 데이터는 버린다', () async {
    final vm = createViewModel(DateTime(2026, 8));
    await pumpEventQueue();
    expect(vm.matchesOfMonth(DateTime(2026, 7)), isNotEmpty);

    // 날짜 피커로 멀리 점프 — 이전 달들은 이제 화면에 걸릴 일이 없다.
    vm.displayMonth = DateTime(2027, 3);
    await pumpEventQueue();

    expect(vm.matchesOfMonth(DateTime(2027, 3)), isNotEmpty);
    expect(vm.matchesOfMonth(DateTime(2026, 7)), isEmpty);
  });

  test('필터가 바뀌면 이웃 달까지 통째로 다시 받는다', () async {
    final vm = createViewModel(DateTime(2026, 8));
    await pumpEventQueue();

    vm.applyFilter(leagues: ['LCK']);
    // 캐시를 비웠으니 통지 직후 프레임에서는 표시 월도 비어 있어야 한다.
    expect(vm.matchesOfMonth(DateTime(2026, 8)), isEmpty);
    expect(vm.matchesOfMonth(DateTime(2026, 9)), isEmpty);

    await pumpEventQueue();
    expect(vm.matchesOfMonth(DateTime(2026, 8)), isNotEmpty);
    expect(vm.matchesOfMonth(DateTime(2026, 9)), isNotEmpty);
  });
}
