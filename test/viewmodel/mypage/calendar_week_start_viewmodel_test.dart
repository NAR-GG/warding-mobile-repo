import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/calendar_week_start.dart';
import 'package:warding/repository/preference/calendar_week_start_preference_repository.dart';
import 'package:warding/viewmodel/mypage/calendar_week_start_viewmodel.dart';

class MockCalendarWeekStartPreferenceRepository extends Mock
    implements CalendarWeekStartPreferenceRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CalendarWeekStart.monday);
  });

  late MockCalendarWeekStartPreferenceRepository repo;

  setUp(() {
    repo = MockCalendarWeekStartPreferenceRepository();
  });

  test('초기값: cachedValue 가 있으면 그 값으로 즉시 시작한다', () {
    when(() => repo.cachedValue).thenReturn(CalendarWeekStart.sunday);
    when(() => repo.load()).thenAnswer((_) async => CalendarWeekStart.sunday);

    final vm = CalendarWeekStartViewModel(repository: repo);
    expect(vm.weekStart, CalendarWeekStart.sunday);
  });

  test('초기값: cachedValue 가 없으면 monday로 시작한 뒤 load() 결과로 갱신한다', () async {
    when(() => repo.cachedValue).thenReturn(null);
    when(() => repo.load()).thenAnswer((_) async => CalendarWeekStart.sunday);

    final vm = CalendarWeekStartViewModel(repository: repo);
    expect(vm.weekStart, CalendarWeekStart.monday);

    await Future<void>.delayed(Duration.zero);
    expect(vm.weekStart, CalendarWeekStart.sunday);
  });

  test('setWeekStart: 값을 바꾸고 저장소에 저장한다', () async {
    when(() => repo.cachedValue).thenReturn(CalendarWeekStart.monday);
    when(() => repo.load()).thenAnswer((_) async => CalendarWeekStart.monday);
    when(() => repo.save(any())).thenAnswer((_) async {});

    final vm = CalendarWeekStartViewModel(repository: repo);
    var notified = false;
    vm.addListener(() => notified = true);

    vm.setWeekStart(CalendarWeekStart.sunday);

    expect(vm.weekStart, CalendarWeekStart.sunday);
    expect(notified, isTrue);
    verify(() => repo.save(CalendarWeekStart.sunday)).called(1);
  });

  test('setWeekStart: 같은 값이면 저장하지 않는다', () async {
    when(() => repo.cachedValue).thenReturn(CalendarWeekStart.monday);
    when(() => repo.load()).thenAnswer((_) async => CalendarWeekStart.monday);

    final vm = CalendarWeekStartViewModel(repository: repo);
    vm.setWeekStart(CalendarWeekStart.monday);

    verifyNever(() => repo.save(any()));
  });
}
