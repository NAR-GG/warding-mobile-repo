import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/calendar_week_start.dart';
import 'package:warding/repository/preference/calendar_week_start_preference_repository.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late CalendarWeekStartPreferenceRepository repo;

  setUp(() {
    storage = MockSecureStorage();
    repo = CalendarWeekStartPreferenceRepository(storage: storage);
  });

  test('load: 저장값이 없으면 monday를 반환한다', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    expect(await repo.load(), CalendarWeekStart.monday);
  });

  test('load: 저장된 sunday를 복원한다', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'sunday');
    expect(await repo.load(), CalendarWeekStart.sunday);
  });

  test('load: 손상된 값이면 monday로 폴백한다', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'garbage');
    expect(await repo.load(), CalendarWeekStart.monday);
  });

  test('load: 스토리지 예외가 나도 monday로 폴백하고 던지지 않는다', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenThrow(Exception('platform error'));
    expect(await repo.load(), CalendarWeekStart.monday);
  });

  test('load: 두 번째 호출부터는 캐시를 쓰고 스토리지를 다시 읽지 않는다', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'sunday');
    await repo.load();
    await repo.load();
    verify(() => storage.read(key: 'calendar_week_start')).called(1);
  });

  test('save: calendar_week_start 키로 저장값을 write 한다', () async {
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    await repo.save(CalendarWeekStart.sunday);
    verify(() => storage.write(key: 'calendar_week_start', value: 'sunday'))
        .called(1);
    expect(repo.cachedValue, CalendarWeekStart.sunday);
  });

  test('save: 저장 실패해도 캐시값은 갱신되고 예외를 던지지 않는다', () async {
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenThrow(Exception('platform error'));
    await repo.save(CalendarWeekStart.sunday);
    expect(repo.cachedValue, CalendarWeekStart.sunday);
  });
}
