import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/calendar_week_start.dart';

void main() {
  group('CalendarWeekStart.dateTimeWeekday', () {
    test('monday → DateTime.monday', () {
      expect(CalendarWeekStart.monday.dateTimeWeekday, DateTime.monday);
    });
    test('sunday → DateTime.sunday', () {
      expect(CalendarWeekStart.sunday.dateTimeWeekday, DateTime.sunday);
    });
  });

  group('CalendarWeekStart.leadingDays', () {
    // 2024-01-01은 월요일, 2024-01-07은 일요일.
    test('monday 시작 — 1일이 월요일이면 앞 빈 칸 0개', () {
      expect(
        CalendarWeekStart.monday.leadingDays(DateTime(2024, 1, 1)),
        0,
      );
    });
    test('monday 시작 — 1일이 일요일이면 앞 빈 칸 6개', () {
      expect(
        CalendarWeekStart.monday.leadingDays(DateTime(2024, 1, 7)),
        6,
      );
    });
    test('sunday 시작 — 1일이 월요일이면 앞 빈 칸 1개', () {
      expect(
        CalendarWeekStart.sunday.leadingDays(DateTime(2024, 1, 1)),
        1,
      );
    });
    test('sunday 시작 — 1일이 일요일이면 앞 빈 칸 0개', () {
      expect(
        CalendarWeekStart.sunday.leadingDays(DateTime(2024, 1, 7)),
        0,
      );
    });
  });

  group('CalendarWeekStart.orderedWeekdayLabels', () {
    const mondayFirst = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    test('monday 시작이면 그대로', () {
      expect(
        CalendarWeekStart.monday.orderedWeekdayLabels(mondayFirst),
        mondayFirst,
      );
    });
    test('sunday 시작이면 일요일이 맨 앞으로 회전', () {
      expect(
        CalendarWeekStart.sunday.orderedWeekdayLabels(mondayFirst),
        ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      );
    });
  });

  group('CalendarWeekStart storage 직렬화', () {
    test('storageValue', () {
      expect(CalendarWeekStart.monday.storageValue, 'monday');
      expect(CalendarWeekStart.sunday.storageValue, 'sunday');
    });
    test('fromStorageValue — 정상값', () {
      expect(
        CalendarWeekStart.fromStorageValue('sunday'),
        CalendarWeekStart.sunday,
      );
    });
    test('fromStorageValue — null/손상값은 monday로 폴백', () {
      expect(CalendarWeekStart.fromStorageValue(null), CalendarWeekStart.monday);
      expect(CalendarWeekStart.fromStorageValue('garbage'), CalendarWeekStart.monday);
    });
  });
}
