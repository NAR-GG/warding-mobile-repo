# 캘린더 시작 요일 설정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 마이페이지에서 캘린더 시작 요일(월요일/일요일)을 고를 수 있게 하고, 그 값을 앱 안 경기 일정 캘린더·월 선택 시트와 iOS/Android 홈 화면 위젯 캘린더에 모두 반영한다.

**Architecture:** `CalendarWeekStart` enum(월/일 매핑 + 그리드 오프셋·라벨 순서 헬퍼)과 `CalendarWeekStartPreferenceRepository`(FlutterSecureStorage 로컬 저장, `SpoilerPreferenceRepository`와 동일 패턴)를 기반으로, 마이페이지 `CalendarWeekStartViewModel`이 값을 바꿀 때마다 로컬 저장 + `HomeWidgetService`를 통해 홈 위젯 공유 저장소(App Group UserDefaults / Android SharedPreferences)에 전파한다. 앱 안 캘린더(`ScheduleViewModel`)는 화면 전환마다 새로 생성되며 저장소의 캐시값을 동기로 읽어 즉시 반영한다. 네이티브 위젯(Swift/Kotlin)은 공유 저장소에서 같은 키를 읽어 요일 헤더 순서·그리드 오프셋을 계산한다.

**Tech Stack:** Flutter/Dart(MVVM, ChangeNotifier), flutter_secure_storage, home_widget 패키지, iOS WidgetKit(Swift/SwiftUI), Android AppWidget(Kotlin/RemoteViews).

## Global Constraints

- 색은 `AppColors`만 참조, 하드코딩 금지 (Dart UI 코드).
- 화면 폭 비례 스케일(`scale = width.clamp(320,430)/375`)을 모든 신규 위젯 수치에 곱한다.
- ViewModel은 `BuildContext`에 의존하지 않는다.
- 파일명 `snake_case`, 클래스명 `PascalCase`.
- 새 화면 전용 위젯은 해당 화면 폴더의 `component/`에 둔다.
- 로컬 기기 설정 저장은 `FlutterSecureStorage`를 재사용한다(SharedPreferences 신규 도입 금지 — 기존 관례).
- `lib/screens/subscription/component/subscription_date_sheet.dart`는 이번 범위에서 변경하지 않는다(구독 설정 전용, "경기 일정" 아님).

---

## Task 1: `CalendarWeekStart` 모델

**Files:**
- Create: `lib/model/calendar_week_start.dart`
- Test: `test/model/calendar_week_start_test.dart`

**Interfaces:**
- Produces: `enum CalendarWeekStart { monday, sunday }`, `int get dateTimeWeekday`, `int leadingDays(DateTime firstOfMonth)`, `List<String> orderedWeekdayLabels(List<String> mondayFirstLabels)`, `String get storageValue`, `static CalendarWeekStart fromStorageValue(String? value)`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/model/calendar_week_start_test.dart`:

```dart
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
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `flutter test test/model/calendar_week_start_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:warding/model/calendar_week_start.dart'`

- [ ] **Step 3: 모델 구현**

`lib/model/calendar_week_start.dart`:

```dart
/// 캘린더가 어느 요일부터 시작하는지 — 마이페이지 설정값.
enum CalendarWeekStart {
  monday,
  sunday;

  /// [DateTime.weekday] 기준 값 (월=1 ... 일=7).
  int get dateTimeWeekday =>
      this == CalendarWeekStart.monday ? DateTime.monday : DateTime.sunday;

  /// [firstOfMonth]가 속한 주에서, 이 설정 기준 주 시작일까지 거슬러 올라갈 일수.
  /// 월간 그리드의 앞쪽 빈 칸 수로 쓰인다.
  int leadingDays(DateTime firstOfMonth) =>
      (firstOfMonth.weekday - dateTimeWeekday + 7) % 7;

  /// [mondayFirstLabels](월~일 순서 7개)를 이 설정 기준 순서로 회전한다.
  List<String> orderedWeekdayLabels(List<String> mondayFirstLabels) {
    assert(mondayFirstLabels.length == 7);
    if (this == CalendarWeekStart.monday) return mondayFirstLabels;
    return [mondayFirstLabels.last, ...mondayFirstLabels.take(6)];
  }

  /// 저장/전송용 문자열 — 'monday' / 'sunday'.
  String get storageValue => name;

  /// [storageValue]의 역변환. 알 수 없는 값이면 monday로 폴백.
  static CalendarWeekStart fromStorageValue(String? value) {
    return CalendarWeekStart.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CalendarWeekStart.monday,
    );
  }
}
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `flutter test test/model/calendar_week_start_test.dart`
Expected: PASS (모든 케이스)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/calendar_week_start.dart test/model/calendar_week_start_test.dart
git commit -m "feat: 캘린더 시작 요일 모델(CalendarWeekStart) 추가"
```

---

## Task 2: `CalendarWeekStartPreferenceRepository`

**Files:**
- Create: `lib/repository/preference/calendar_week_start_preference_repository.dart`
- Test: `test/repository/preference/calendar_week_start_preference_repository_test.dart`

**Interfaces:**
- Consumes: `CalendarWeekStart`, `CalendarWeekStart.fromStorageValue`, `.storageValue` (Task 1). `lib/config/secure_storage.dart`의 전역 `secureStorage` 싱글턴.
- Produces: `class CalendarWeekStartPreferenceRepository { static final instance; CalendarWeekStart? get cachedValue; Future<CalendarWeekStart> load(); Future<void> save(CalendarWeekStart value); }`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/repository/preference/calendar_week_start_preference_repository_test.dart` (기존 `onboarding_preference_repository_test.dart`의 `MockSecureStorage` 패턴을 그대로 따른다):

```dart
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
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `flutter test test/repository/preference/calendar_week_start_preference_repository_test.dart`
Expected: FAIL — 파일이 없어 컴파일 에러.

- [ ] **Step 3: 리포지토리 구현**

`lib/repository/preference/calendar_week_start_preference_repository.dart` (`spoiler_preference_repository.dart`와 동일 구조):

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';
import '../../model/calendar_week_start.dart';

/// 캘린더 시작 요일(월요일/일요일) 설정을 기기에 로컬 저장한다.
///
/// 경기 일정 화면의 캘린더·월 선택 시트, 홈 화면 위젯이 같은 값을 공유한다.
/// 민감 정보는 아니지만 기존 관례대로 [FlutterSecureStorage] 를 재사용한다.
class CalendarWeekStartPreferenceRepository {
  CalendarWeekStartPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? secureStorage;

  static final CalendarWeekStartPreferenceRepository instance =
      CalendarWeekStartPreferenceRepository();

  static const String _key = 'calendar_week_start';

  final FlutterSecureStorage _storage;

  /// 저장값을 읽기 전까지 각 ViewModel 이 매번 스토리지를 때리지 않도록 캐싱한다.
  /// 화면 전환마다 ViewModel 이 새로 만들어지므로 첫 프레임 깜빡임도 줄인다.
  CalendarWeekStart? _cached;

  /// 마지막으로 읽어둔 값. 아직 한 번도 로드 전이면 null.
  CalendarWeekStart? get cachedValue => _cached;

  /// 저장된 값을 읽는다. 저장된 적 없거나 손상됐으면 기본값 monday.
  Future<CalendarWeekStart> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await _storage.read(key: _key);
      _cached = CalendarWeekStart.fromStorageValue(raw);
    } catch (e) {
      debugPrint('[CalendarWeekStartPreference] 복원 실패: $e');
      _cached = CalendarWeekStart.monday;
    }
    return _cached!;
  }

  /// 값을 저장한다. 실패해도 화면 동작은 막지 않는다.
  Future<void> save(CalendarWeekStart value) async {
    _cached = value;
    try {
      await _storage.write(key: _key, value: value.storageValue);
    } catch (e) {
      debugPrint('[CalendarWeekStartPreference] 저장 실패: $e');
    }
  }
}
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `flutter test test/repository/preference/calendar_week_start_preference_repository_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/repository/preference/calendar_week_start_preference_repository.dart test/repository/preference/calendar_week_start_preference_repository_test.dart
git commit -m "feat: 캘린더 시작 요일 로컬 저장소(CalendarWeekStartPreferenceRepository) 추가"
```

---

## Task 3: `HomeWidgetService.updateWeekStart` + 앱 시작 시 동기화

**Files:**
- Modify: `lib/util/home_widget_service.dart`

**Interfaces:**
- Consumes: `CalendarWeekStart` (Task 1), `CalendarWeekStartPreferenceRepository` (Task 2), 기존 `HomeWidget.saveWidgetData`/`HomeWidget.updateWidget`/`_androidWidgetName`/`_androidSmallWidgetName`/`_androidLargeWidgetName`/`_iOSWidgetName` (이미 파일에 있음).
- Produces: `static Future<void> HomeWidgetService.updateWeekStart(CalendarWeekStart value)`.

이 파일은 기존에 단위 테스트가 없다(플랫폼 채널을 직접 호출하는 클래스라 기존 관례상 테스트 대상이 아님) — 이 태스크도 자동 테스트 없이 진행하고, 마지막 태스크(수동 검증)에서 확인한다.

- [ ] **Step 1: import 추가**

`lib/util/home_widget_service.dart` 상단 import 블록에 추가 (기존 `import '../model/match_calendar_day.dart';` 다음 줄):

```dart
import '../model/calendar_week_start.dart';
import '../repository/preference/calendar_week_start_preference_repository.dart';
```

- [ ] **Step 2: `updateWeekStart` 메서드 추가**

`updateFilterState` 메서드(현재 파일의 252~271번째 줄) 바로 다음에 추가:

```dart
  /// 캘린더 시작 요일 설정을 위젯에 전달하고 갱신을 트리거한다.
  static Future<void> updateWeekStart(CalendarWeekStart value) async {
    try {
      await HomeWidget.saveWidgetData<String>('week_start', value.storageValue);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidSmallWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidLargeWidgetName,
        iOSName: _iOSWidgetName,
      );
      debugPrint('[HomeWidget] 캘린더 시작 요일 갱신: ${value.storageValue}');
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 시작 요일 갱신 실패: $e');
    }
  }
```

- [ ] **Step 3: 앱 시작 시 동기화 — `refreshFromApi()`에서 로컬 설정을 위젯에 반영**

`refreshFromApi()` 메서드(현재 파일 472~531번째 줄) 맨 끝, "응원팀 정보도 위젯에 전달" 블록(524~530번째 줄) 다음에 추가:

```dart
    // 캘린더 시작 요일 로컬 설정을 위젯에도 동기화한다 (재설치 등으로
    // 공유 저장소와 로컬 저장소가 어긋나는 경우 대비 — 앱 시작마다 맞춘다).
    try {
      final weekStart = await CalendarWeekStartPreferenceRepository.instance.load();
      await updateWeekStart(weekStart);
    } catch (e) {
      debugPrint('[HomeWidget] 캘린더 시작 요일 동기화 실패: $e');
    }
  }
```

주의: 기존 메서드의 마지막 닫는 `}`를 대체하는 것이 아니라, 기존 마지막 블록 다음 줄에 위 코드를 추가하고 원래 있던 메서드 닫는 `}`는 그대로 유지한다(위 코드 블록의 마지막 `}`가 그 자리를 대신한다).

- [ ] **Step 4: 정적 분석으로 컴파일 확인**

Run: `flutter analyze lib/util/home_widget_service.dart`
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/util/home_widget_service.dart
git commit -m "feat: 홈 위젯에 캘린더 시작 요일 설정 전달(updateWeekStart) 추가"
```

---

## Task 4: `CalendarWeekStartViewModel` (마이페이지)

**Files:**
- Create: `lib/viewmodel/mypage/calendar_week_start_viewmodel.dart`
- Test: `test/viewmodel/mypage/calendar_week_start_viewmodel_test.dart`

**Interfaces:**
- Consumes: `CalendarWeekStart`, `CalendarWeekStartPreferenceRepository`(Task 1,2), `HomeWidgetService.updateWeekStart`(Task 3).
- Produces: `class CalendarWeekStartViewModel extends ChangeNotifier { CalendarWeekStart get weekStart; void setWeekStart(CalendarWeekStart value); }` — 생성자 `CalendarWeekStartViewModel({CalendarWeekStartPreferenceRepository? repository})`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/viewmodel/mypage/calendar_week_start_viewmodel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/calendar_week_start.dart';
import 'package:warding/repository/preference/calendar_week_start_preference_repository.dart';
import 'package:warding/viewmodel/mypage/calendar_week_start_viewmodel.dart';

class MockCalendarWeekStartPreferenceRepository extends Mock
    implements CalendarWeekStartPreferenceRepository {}

void main() {
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
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `flutter test test/viewmodel/mypage/calendar_week_start_viewmodel_test.dart`
Expected: FAIL — 파일이 없어 컴파일 에러.

- [ ] **Step 3: ViewModel 구현**

`lib/viewmodel/mypage/calendar_week_start_viewmodel.dart` (`MatchListViewModel`의 스포방지 처리 패턴과 동일):

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/calendar_week_start.dart';
import '../../repository/preference/calendar_week_start_preference_repository.dart';
import '../../util/home_widget_service.dart';

/// 마이페이지 — 캘린더 시작 요일 설정 ViewModel.
///
/// 기기 로컬 설정이라 로그인 여부와 무관하게 동작한다(QuietHours와 다른 점).
class CalendarWeekStartViewModel extends ChangeNotifier {
  CalendarWeekStartViewModel({CalendarWeekStartPreferenceRepository? repository})
      : _repository = repository ?? CalendarWeekStartPreferenceRepository.instance {
    // 이미 읽어둔 값이 있으면 첫 프레임부터 그 상태로 그린다.
    _weekStart = _repository.cachedValue ?? CalendarWeekStart.monday;
    _restore();
  }

  final CalendarWeekStartPreferenceRepository _repository;

  bool _disposed = false;

  CalendarWeekStart _weekStart = CalendarWeekStart.monday;
  CalendarWeekStart get weekStart => _weekStart;

  /// 저장된 값을 복원한다. 생성자에서 캐시로 이미 맞춘 값과 같으면 알리지 않는다.
  Future<void> _restore() async {
    final saved = await _repository.load();
    if (_disposed || saved == _weekStart) return;
    _weekStart = saved;
    notifyListeners();
  }

  void setWeekStart(CalendarWeekStart value) {
    if (_weekStart == value) return;
    _weekStart = value;
    notifyListeners();
    // 저장·위젯 갱신 실패해도 화면 선택은 그대로 반영되므로 기다리지 않는다.
    unawaited(_repository.save(value));
    unawaited(HomeWidgetService.updateWeekStart(value));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `flutter test test/viewmodel/mypage/calendar_week_start_viewmodel_test.dart`
Expected: PASS (모든 케이스)

- [ ] **Step 5: 커밋**

```bash
git add lib/viewmodel/mypage/calendar_week_start_viewmodel.dart test/viewmodel/mypage/calendar_week_start_viewmodel_test.dart
git commit -m "feat: 캘린더 시작 요일 마이페이지 ViewModel 추가"
```

---

## Task 5: 마이페이지 설정 UI + l10n 키

**Files:**
- Create: `lib/screens/mypage/component/calendar_week_start_sheet.dart`
- Create: `lib/screens/mypage/component/calendar_week_start_section.dart`
- Modify: `lib/screens/mypage/mypage_screen.dart`
- Modify: `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `CalendarWeekStart`(Task 1), `CalendarWeekStartViewModel`(Task 4), 기존 `AppBottomSheet`/`showAppBottomSheet`(`components/app_bottom_sheet.dart`), `AppColors`.
- Produces: `class CalendarWeekStartSheet extends StatelessWidget`, `Future<void> showCalendarWeekStartSheet({required BuildContext context, required CalendarWeekStart current, ValueChanged<CalendarWeekStart>? onChanged})`, `class CalendarWeekStartSection extends StatefulWidget({double scale})`.

- [ ] **Step 1: l10n 키 추가**

`lib/l10n/app_ko.arb` 맨 끝(`"quietHoursSave": "저장"` 다음, 파일을 닫는 `}` 앞)에 추가:

```json
  "quietHoursSave": "저장",
  "calendarWeekStartSetting": "캘린더 시작 요일",
  "calendarWeekStartRowLabel": "시작 요일",
  "calendarWeekStartMonday": "월요일",
  "calendarWeekStartSunday": "일요일"
}
```

`lib/l10n/app_en.arb` 맨 끝(`"quietHoursSave": "Save"` 다음)에 추가:

```json
  "quietHoursSave": "Save",
  "calendarWeekStartSetting": "Calendar start day",
  "calendarWeekStartRowLabel": "Starts on",
  "calendarWeekStartMonday": "Monday",
  "calendarWeekStartSunday": "Sunday"
}
```

- [ ] **Step 2: 로컬라이제이션 코드 생성**

Run: `flutter gen-l10n`
Expected: 성공 종료(exit code 0), `lib/l10n/app_localizations.dart`/`app_localizations_ko.dart`/`app_localizations_en.dart`에 `calendarWeekStartSetting`/`calendarWeekStartRowLabel`/`calendarWeekStartMonday`/`calendarWeekStartSunday` getter가 새로 생김.

검증: `grep -n "calendarWeekStartSetting" lib/l10n/app_localizations.dart` — 3개 파일 모두에서 매치되어야 한다.

- [ ] **Step 3: 바텀시트 구현**

`lib/screens/mypage/component/calendar_week_start_sheet.dart` (`language_setting_sheet.dart`와 동일한 2지선다 리스트 패턴):

```dart
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../model/calendar_week_start.dart';
import '../../../styles/app_colors.dart';

/// 마이페이지 캘린더 시작 요일 설정 바텀시트.
///
/// [AppBottomSheet] 안에 월요일/일요일 옵션을 나열한다. 선택하면 [onChanged]로
/// 알리고 시트를 닫는다.
class CalendarWeekStartSheet extends StatelessWidget {
  const CalendarWeekStartSheet({
    super.key,
    required this.current,
    this.onChanged,
  });

  final CalendarWeekStart current;
  final ValueChanged<CalendarWeekStart>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    final options = <(CalendarWeekStart, String)>[
      (CalendarWeekStart.monday, l.calendarWeekStartMonday),
      (CalendarWeekStart.sunday, l.calendarWeekStartSunday),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36 * scale,
            height: 4 * scale,
            margin: EdgeInsets.only(bottom: 20 * scale),
            decoration: BoxDecoration(
              color: AppColors.narDark200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 16 * scale),
          child: Text(
            l.calendarWeekStartSetting,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 18 * scale,
              height: 1.4,
              color: AppColors.narText,
            ),
          ),
        ),
        ...options.map((option) {
          final (value, label) = option;
          final isSelected = value == current;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              onChanged?.call(value);
              Navigator.of(context).pop();
            },
            child: Container(
              height: 48 * scale,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.narBgTertiary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15 * scale,
                  height: 1.55,
                  color: isSelected
                      ? AppColors.narText
                      : AppColors.narTextTertiary,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// [CalendarWeekStartSheet] 를 [AppBottomSheet] 모달로 띄우는 헬퍼.
Future<void> showCalendarWeekStartSheet({
  required BuildContext context,
  required CalendarWeekStart current,
  ValueChanged<CalendarWeekStart>? onChanged,
}) {
  return showAppBottomSheet(
    context: context,
    child: CalendarWeekStartSheet(current: current, onChanged: onChanged),
  );
}
```

- [ ] **Step 4: 섹션(카드) 구현**

`lib/screens/mypage/component/calendar_week_start_section.dart` (`quiet_hours_section.dart`의 카드+`_Row` 패턴, 로그인 게이트 없음):

```dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/calendar_week_start.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/mypage/calendar_week_start_viewmodel.dart';
import 'calendar_week_start_sheet.dart';

/// 마이페이지 — 캘린더 시작 요일 설정 섹션 (양옆 20 패딩).
///
/// QuietHours 섹션 바로 아래에 온다. 기기 로컬 설정이라 로그인 여부와 무관하게
/// 항상 보인다(서버 저장이 필요한 QuietHours와 다른 점).
class CalendarWeekStartSection extends StatefulWidget {
  const CalendarWeekStartSection({super.key, this.scale = 1});

  final double scale;

  @override
  State<CalendarWeekStartSection> createState() =>
      _CalendarWeekStartSectionState();
}

class _CalendarWeekStartSectionState extends State<CalendarWeekStartSection> {
  final CalendarWeekStartViewModel _viewModel = CalendarWeekStartViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    await showCalendarWeekStartSheet(
      context: context,
      current: _viewModel.weekStart,
      onChanged: _viewModel.setWeekStart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildSection(widget.scale),
    );
  }

  Widget _buildSection(double scale) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.calendarWeekStartSetting,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 17 * scale,
              height: 25 / 17,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 16 * scale),
          _buildCard(scale, l),
        ],
      ),
    );
  }

  Widget _buildCard(double scale, AppLocalizations l) {
    final label = _viewModel.weekStart == CalendarWeekStart.monday
        ? l.calendarWeekStartMonday
        : l.calendarWeekStartSunday;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: _Row(
        label: l.calendarWeekStartRowLabel,
        scale: scale,
        onTap: _openSheet,
        trailing: _ValueChip(label: label, scale: scale),
      ),
    );
  }
}

/// 라벨 + 우측 값 칩 한 행. `quiet_hours_section.dart`의 `_Row`와 동일 스타일.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.trailing,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final Widget trailing;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 5 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                color: AppColors.narText,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 값 + chevron. `quiet_hours_section.dart`의 `_TimeValue`와 동일 스타일.
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        border: Border.all(color: AppColors.narLine),
        borderRadius: BorderRadius.circular(6 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
          SizedBox(width: 4 * scale),
          Icon(Icons.chevron_right, size: 16 * scale, color: AppColors.narText2),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 마이페이지에 섹션 삽입**

`lib/screens/mypage/mypage_screen.dart` — import 블록의 `import 'component/quiet_hours_section.dart';` 다음 줄에 추가:

```dart
import 'component/calendar_week_start_section.dart';
```

같은 파일에서 (현재 197~199번째 줄):

```dart
                    QuietHoursSection(scale: scale),
                    SizedBox(height: 16 * scale),
                    ListenableBuilder(
```

를 다음으로 교체:

```dart
                    QuietHoursSection(scale: scale),
                    SizedBox(height: 16 * scale),
                    CalendarWeekStartSection(scale: scale),
                    SizedBox(height: 16 * scale),
                    ListenableBuilder(
```

- [ ] **Step 6: 정적 분석 + 기존 테스트 회귀 확인**

Run: `flutter analyze lib/screens/mypage lib/l10n`
Expected: `No issues found!`

Run: `flutter test`
Expected: 기존 테스트 전부 PASS(회귀 없음), Task 1~4에서 추가한 테스트도 PASS.

- [ ] **Step 7: 수동 확인**

`flutter run`으로 앱을 띄워 마이페이지 → "캘린더 시작 요일" 카드 탭 → 바텀시트에서 "일요일" 선택 → 카드에 "일요일"로 바뀌는지 확인한다. (경기 일정 화면 반영은 Task 6에서 확인)

- [ ] **Step 8: 커밋**

```bash
git add lib/screens/mypage/component/calendar_week_start_sheet.dart lib/screens/mypage/component/calendar_week_start_section.dart lib/screens/mypage/mypage_screen.dart lib/l10n/app_ko.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_ko.dart lib/l10n/app_localizations_en.dart
git commit -m "feat: 마이페이지에 캘린더 시작 요일 설정 UI 추가"
```

---

## Task 6: 경기 일정 화면 캘린더에 반영

**Files:**
- Modify: `lib/screens/schedule/component/calendar_weekday_header.dart`
- Modify: `lib/screens/schedule/component/calendar_month_grid.dart`
- Modify: `lib/screens/schedule/component/schedule_calendar.dart`
- Modify: `lib/viewmodel/schedule/schedule_viewmodel.dart`
- Modify: `lib/screens/schedule/schedule_screen.dart`

**Interfaces:**
- Consumes: `CalendarWeekStart`(Task 1), `CalendarWeekStartPreferenceRepository`(Task 2).
- Produces: `ScheduleViewModel.weekStart` getter. `CalendarWeekdayHeader`/`CalendarMonthGrid`/`ScheduleCalendar` 모두 `weekStart` 파라미터(기본값 `CalendarWeekStart.monday`) 추가.

이 화면들은 기존에 단위 테스트가 없다(위젯 트리·네트워크 의존적). 회귀는 `flutter analyze` + 기존 테스트 스위트로, 실제 동작은 마지막 태스크에서 수동 확인한다.

- [ ] **Step 1: `CalendarWeekdayHeader`에 `weekStart` 추가**

`lib/screens/schedule/component/calendar_weekday_header.dart` 상단 import에 추가:

```dart
import '../../../model/calendar_week_start.dart';
```

`CalendarWeekdayHeader` 클래스 전체를 다음으로 교체:

```dart
class CalendarWeekdayHeader extends StatelessWidget {
  const CalendarWeekdayHeader({
    super.key,
    required this.scale,
    this.weekStart = CalendarWeekStart.monday,
  });

  final double scale;
  final CalendarWeekStart weekStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final weekdays = weekStart.orderedWeekdayLabels([
      l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu,
      l.weekdayFri, l.weekdaySat, l.weekdaySun,
    ]);
    return Column(
      children: [
        Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 14 * scale, bottom: 10 * scale),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600, // SF Pro 590 ≈ Semibold
                      fontSize: 16 * scale,
                      height: 1.0, // line-height 100%
                      letterSpacing: 0,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 주간 구분선 — 1px 그라데이션
        Container(
          height: 1,
          decoration: const BoxDecoration(gradient: AppColors.narBg),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: `CalendarMonthGrid`에 `weekStart` 추가**

`lib/screens/schedule/component/calendar_month_grid.dart` 상단 import에 추가:

```dart
import '../../../model/calendar_week_start.dart';
```

생성자와 필드(현재 12~29번째 줄)를 다음으로 교체:

```dart
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.scale,
    required this.matchesOf,
    this.selectedDate,
    this.onDateTap,
    this.weekStart = CalendarWeekStart.monday,
  });

  final DateTime month;
  final double scale;
  final CalendarWeekStart weekStart;

  /// 특정 날짜의 경기 목록을 반환한다.
  final List<CalendarMatch> Function(DateTime date) matchesOf;

  /// 강조할 선택 날짜. null 이면 강조 없음.
  final DateTime? selectedDate;

  /// 경기가 있는 날짜 칸을 탭하면 그 날짜로 호출한다. null 이면 탭 비활성.
  final ValueChanged<DateTime>? onDateTap;
```

`build()` 안의 `leadingDays` 계산(현재 36~37번째 줄)을 다음으로 교체:

```dart
    // 그리드 시작일이 속한 주에서, 설정된 시작 요일까지 거슬러 올라갈 일수.
    final leadingDays = weekStart.leadingDays(month);
```

- [ ] **Step 3: `ScheduleCalendar`가 `weekStart`를 전달**

`lib/screens/schedule/component/schedule_calendar.dart` 상단 import에 추가:

```dart
import '../../../model/calendar_week_start.dart';
```

생성자(현재 15~23번째 줄)에 필드 추가:

```dart
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.month,
    required this.matchesByDay,
    this.onMonthShift,
    this.selectedDate,
    this.onDateTap,
    this.weekStart = CalendarWeekStart.monday,
  });
```

필드 선언 블록(현재 25~39번째 줄, `final ValueChanged<DateTime>? onDateTap;` 다음)에 추가:

```dart
  /// 캘린더 시작 요일 설정. 요일 헤더·월간 그리드에 그대로 전달한다.
  final CalendarWeekStart weekStart;
```

`build()` 안에서 `CalendarWeekdayHeader(scale: scale)`(현재 71번째 줄)를 다음으로 교체:

```dart
          CalendarWeekdayHeader(scale: scale, weekStart: widget.weekStart),
```

`CalendarMonthGrid(...)` 생성 부분(현재 105~116번째 줄)에 `weekStart: widget.weekStart,` 를 `scale: scale,` 다음 줄에 추가:

```dart
              child: CalendarMonthGrid(
                key: ValueKey(month),
                month: month,
                scale: scale,
                weekStart: widget.weekStart,
                selectedDate: widget.selectedDate,
                onDateTap: widget.onDateTap,
                matchesOf:
                    (date) =>
                        date.month == month.month
                            ? (matchesByDay[date.day] ?? const [])
                            : const [],
              ),
```

- [ ] **Step 4: `ScheduleViewModel`에 `weekStart` 노출**

`lib/viewmodel/schedule/schedule_viewmodel.dart` 상단 import 블록(`import '../../model/notice.dart';` 다음 줄)에 추가:

```dart
import '../../model/calendar_week_start.dart';
```

`import '../../repository/preference/filter_preference_repository.dart';` 다음 줄에 추가:

```dart
import '../../repository/preference/calendar_week_start_preference_repository.dart';
```

생성자(현재 23~46번째 줄)를 다음으로 교체:

```dart
  ScheduleViewModel({
    DateTime? initialMonth,
    ScheduleRepository? repository,
    TeamPreferenceRepository? teamPreferences,
    FilterPreferenceRepository? filterPreferences,
    AuthService? auth,
    OnboardingRepository? onboarding,
    NoticeRepository? notices,
    NoticePreferenceRepository? noticePreferences,
    CalendarWeekStartPreferenceRepository? weekStartPreferences,
  }) : _displayMonth = _monthOf(initialMonth ?? DateTime.now()),
       _repository = repository ?? ScheduleRepository.instance,
       _teamPreferences =
           teamPreferences ?? TeamPreferenceRepository.instance,
       _filterPreferences =
           filterPreferences ?? FilterPreferenceRepository.instance,
       _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance,
       _notices = notices ?? NoticeRepository.instance,
       _noticePreferences =
           noticePreferences ?? NoticePreferenceRepository.instance,
       _weekStartPreferences = weekStartPreferences ??
           CalendarWeekStartPreferenceRepository.instance {
    _weekStart = _weekStartPreferences.cachedValue ?? CalendarWeekStart.monday;
    _init();
    _loadPreferredTeam();
    _loadPromotedNotice();
    _restoreWeekStart();
  }

  final ScheduleRepository _repository;
  final TeamPreferenceRepository _teamPreferences;
  final FilterPreferenceRepository _filterPreferences;
  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final NoticeRepository _notices;
  final NoticePreferenceRepository _noticePreferences;
  final CalendarWeekStartPreferenceRepository _weekStartPreferences;
```

`monthLabel` getter(현재 126~128번째 줄) 다음에 추가:

```dart

  CalendarWeekStart _weekStart = CalendarWeekStart.monday;

  /// 캘린더 시작 요일 설정. 마이페이지에서 바꾼 값을, 탭 전환으로 이 ViewModel이
  /// 새로 만들어질 때 캐시로 즉시 반영한다(스포방지 설정과 동일한 보장).
  CalendarWeekStart get weekStart => _weekStart;

  /// 저장된 캘린더 시작 요일 설정을 복원한다. 생성자에서 캐시로 이미 맞춘 값과 같으면 알리지 않는다.
  Future<void> _restoreWeekStart() async {
    final saved = await _weekStartPreferences.load();
    if (_disposed || saved == _weekStart) return;
    _weekStart = saved;
    notifyListeners();
  }
```

- [ ] **Step 5: `ScheduleScreen`이 `weekStart`를 캘린더·월 선택 시트에 전달**

`lib/screens/schedule/schedule_screen.dart`의 `_buildCalendarArea` 안, `ScheduleCalendar(...)` 생성 부분(현재 160~166번째 줄)을 다음으로 교체:

```dart
    return ScheduleCalendar(
      month: _viewModel.displayMonth,
      matchesByDay: matchesByDay,
      onMonthShift: _viewModel.shiftMonth,
      selectedDate: _viewModel.selectedDate,
      onDateTap: _openDay,
      weekStart: _viewModel.weekStart,
    );
```

- [ ] **Step 6: 정적 분석 + 회귀 테스트**

Run: `flutter analyze lib/screens/schedule lib/viewmodel/schedule`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS.

- [ ] **Step 7: 수동 확인**

`flutter run` → 마이페이지에서 "일요일"로 바꾼 뒤 경기 일정 탭으로 전환 → 캘린더 요일 헤더가 "일 월 화 수 목 금 토" 순서로 바뀌고, 날짜 그리드도 그에 맞춰 배열되는지 확인한다.

- [ ] **Step 8: 커밋**

```bash
git add lib/screens/schedule/component/calendar_weekday_header.dart lib/screens/schedule/component/calendar_month_grid.dart lib/screens/schedule/component/schedule_calendar.dart lib/viewmodel/schedule/schedule_viewmodel.dart lib/screens/schedule/schedule_screen.dart
git commit -m "feat: 경기 일정 캘린더에 시작 요일 설정 반영"
```

---

## Task 7: 월 선택 바텀시트(`MonthPickerSheet`)에 반영

**Files:**
- Modify: `lib/screens/schedule/component/month_picker_sheet.dart`
- Modify: `lib/screens/schedule/schedule_screen.dart`

**Interfaces:**
- Consumes: `CalendarWeekStart`(Task 1), `ScheduleViewModel.weekStart`(Task 6).
- Produces: `MonthPickerSheet`에 `weekStart` 파라미터(기본값 monday) 추가. `MonthPickerViewModel`은 변경하지 않는다(날짜 데이터만 다루고 렌더링 순서는 View 레이어 책임).

- [ ] **Step 1: `MonthPickerSheet`에 `weekStart` 필드 추가**

`lib/screens/schedule/component/month_picker_sheet.dart` 상단 import(`import '../../../viewmodel/schedule/month_picker_viewmodel.dart';` 다음 줄)에 추가:

```dart
import '../../../model/calendar_week_start.dart';
```

`MonthPickerSheet` 생성자(현재 15~20번째 줄)를 다음으로 교체:

```dart
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    super.key,
    required this.initialMonth,
    this.filterLeagues = const ['ALL'],
    this.filterTeamIds,
    this.weekStart = CalendarWeekStart.monday,
  });

  /// 모달을 열 때 처음 보여줄 월.
  final DateTime initialMonth;

  /// 메인 화면의 리그·팀 필터 — 점 표시가 본문 캘린더와 같은 조건으로 조회되게 한다.
  final List<String> filterLeagues;
  final List<int>? filterTeamIds;

  /// 캘린더 시작 요일 설정. 요일 행·날짜 그리드에 그대로 전달한다.
  final CalendarWeekStart weekStart;
```

`build()` 안에서 `_WeekdayRow(scale: scale)`와 `_DayGrid(...)` 호출부(현재 99~105번째 줄)를 다음으로 교체:

```dart
            _WeekdayRow(scale: scale, weekStart: widget.weekStart),
            _DayGrid(
              month: _viewModel.month,
              matchDays: _viewModel.matchDays,
              scale: scale,
              weekStart: widget.weekStart,
              onDaySelected: _selectDay,
            ),
```

- [ ] **Step 2: `_WeekdayRow`가 `weekStart` 순서로 렌더링**

`_WeekdayRow` 클래스(현재 139~182번째 줄)를 다음으로 교체:

```dart
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.scale, required this.weekStart});

  final double scale;
  final CalendarWeekStart weekStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final weekdays = weekStart.orderedWeekdayLabels([
      l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu,
      l.weekdayFri, l.weekdaySat, l.weekdaySun,
    ]);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31.5 * scale),
      child: SizedBox(
        height: 32 * scale,
        child: Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.5 * scale),
                  child: Center(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w400,
                        fontSize: 16 * scale,
                        height: 1.5, // line-height 24px / font-size 16px
                        letterSpacing: 0,
                        color: AppColors.narTextGnbDefault, // #CED4DA
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: `_DayGrid`가 `weekStart` 기준으로 오프셋 계산**

`_DayGrid` 클래스(현재 188~246번째 줄)를 다음으로 교체:

```dart
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.month,
    required this.matchDays,
    required this.scale,
    required this.weekStart,
    required this.onDaySelected,
  });

  final DateTime month;

  /// 경기가 있는 '일(day)' 집합.
  final Set<int> matchDays;
  final double scale;
  final CalendarWeekStart weekStart;

  /// 날짜 칸 탭 콜백. 인자는 탭한 '일(day)'.
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    // 1일이 속한 주에서, 설정된 시작 요일까지 거슬러 올라갈 빈 칸 수.
    final leadingDays = weekStart.leadingDays(firstDay);
    // 이번 달 일수 (다음 달 0일 = 이번 달 말일).
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = ((leadingDays + daysInMonth) / 7).ceil();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31.5 * scale),
      child: Column(
        children: [
          for (var week = 0; week < weekCount; week++)
            Row(
              children: [
                for (var dow = 0; dow < 7; dow++)
                  Expanded(
                    child: _cell(week * 7 + dow - leadingDays + 1, daysInMonth),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// [day] 가 이번 달 범위 밖이면 빈 칸(행 높이만 확보), 안이면 날짜 칸.
  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return SizedBox(height: 40 * scale);
    }
    return Center(
      child: _DayCell(
        day: day,
        hasMatch: matchDays.contains(day),
        scale: scale,
        onTap: () => onDaySelected(day),
      ),
    );
  }
}
```

(`_DayCell` 클래스는 변경하지 않는다.)

- [ ] **Step 4: `ScheduleScreen`이 월 선택 시트에도 `weekStart` 전달**

`lib/screens/schedule/schedule_screen.dart`의 `_openMonthPicker()`(현재 86~98번째 줄) 안 `MonthPickerSheet(...)` 생성 부분을 다음으로 교체:

```dart
      child: MonthPickerSheet(
        initialMonth: _viewModel.displayMonth,
        filterLeagues: _viewModel.filterLeagues,
        filterTeamIds: _viewModel.filterTeamIds,
        weekStart: _viewModel.weekStart,
      ),
```

- [ ] **Step 5: 정적 분석 + 회귀 테스트**

Run: `flutter analyze lib/screens/schedule`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS.

- [ ] **Step 6: 수동 확인**

`flutter run` → 마이페이지에서 "일요일"로 바꾼 뒤 경기 일정 화면 상단 월 라벨을 탭해 월 선택 바텀시트를 열고, 요일 행이 "일 월 화 수 목 금 토" 순서이고 날짜 그리드도 맞게 배열되는지 확인한다.

- [ ] **Step 7: 커밋**

```bash
git add lib/screens/schedule/component/month_picker_sheet.dart lib/screens/schedule/schedule_screen.dart
git commit -m "feat: 월 선택 바텀시트에 캘린더 시작 요일 설정 반영"
```

---

## Task 8: iOS 홈 화면 위젯 반영

**Files:**
- Modify: `ios/WardingScheduleWidget/WardingScheduleWidget.swift`

**Interfaces:**
- Consumes: 앱 그룹 UserDefaults(`group.com.warding.app`)의 `week_start` 문자열 키(Task 3이 `HomeWidget.saveWidgetData<String>('week_start', ...)`로 기록).
- Produces: `firstWeekdayIndex(year:month:sundayFirst:)`, `weekdayLabels(sundayFirst:)`, `sundayColumnIndex(sundayFirst:)` 파일 스코프 헬퍼. `ScheduleEntry.sundayFirst: Bool` 필드.

이 파일은 SwiftUI/WidgetKit 코드라 자동 테스트가 없다 — Xcode 시뮬레이터에서 수동 확인한다(마지막 태스크).

- [ ] **Step 1: `ScheduleProvider.loadData()`가 `week_start`를 읽도록 수정**

`ios/WardingScheduleWidget/WardingScheduleWidget.swift`의 `loadData()`(현재 86~95번째 줄)를 다음으로 교체:

```swift
    private func loadData() -> (CalendarData, TodayData, String?, Bool, Bool, String, Bool) {
        guard let ud = UserDefaults(suiteName: "group.com.warding.app") else {
            return (.empty, .empty, nil, false, false, "", false)
        }
        let teamUrl = ud.string(forKey: "team_image_url")
        let hasFilter = ud.bool(forKey: "has_filter")
        let teamSelected = ud.bool(forKey: "team_selected")
        let teamCode = ud.string(forKey: "team_code") ?? ""
        let sundayFirst = ud.string(forKey: "week_start") == "sunday"
        return (loadCalendar(ud), loadToday(ud), teamUrl, hasFilter, teamSelected, teamCode, sundayFirst)
    }
```

- [ ] **Step 2: 튜플 확장에 맞춰 `getSnapshot`/`getTimeline`/`placeholder` 갱신**

`placeholder(in:)`(현재 52~54번째 줄)를 다음으로 교체:

```swift
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), calendar: .empty, today: .empty, teamImageUrl: nil, teamImage: nil, hasFilter: false, teamSelected: false, teamCode: "", sundayFirst: false)
    }
```

`getSnapshot(in:completion:)`(현재 56~61번째 줄)를 다음으로 교체:

```swift
    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let (cal, today, teamUrl, hasFilter, teamSelected, teamCode, sundayFirst) = loadData()
        downloadTeamImage(url: teamUrl) { image in
            completion(ScheduleEntry(date: Date(), calendar: cal, today: today, teamImageUrl: teamUrl, teamImage: image, hasFilter: hasFilter, teamSelected: teamSelected, teamCode: teamCode, sundayFirst: sundayFirst))
        }
    }
```

`getTimeline(in:completion:)`(현재 63~70번째 줄)를 다음으로 교체:

```swift
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let (cal, today, teamUrl, hasFilter, teamSelected, teamCode, sundayFirst) = loadData()
        downloadTeamImage(url: teamUrl) { image in
            let entry = ScheduleEntry(date: Date(), calendar: cal, today: today, teamImageUrl: teamUrl, teamImage: image, hasFilter: hasFilter, teamSelected: teamSelected, teamCode: teamCode, sundayFirst: sundayFirst)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
```

- [ ] **Step 3: `ScheduleEntry`에 `sundayFirst` 필드 추가**

`ScheduleEntry` 구조체(현재 152~161번째 줄)를 다음으로 교체:

```swift
struct ScheduleEntry: TimelineEntry {
    let date: Date
    let calendar: CalendarData
    let today: TodayData
    let teamImageUrl: String?
    let teamImage: UIImage?
    let hasFilter: Bool
    let teamSelected: Bool
    let teamCode: String
    let sundayFirst: Bool
}
```

- [ ] **Step 4: 공용 헬퍼 함수 추가**

`ScheduleEntry` 구조체 정의 바로 다음(현재 161번째 줄, `MediumWidgetView` 정의 전)에 추가:

```swift

// MARK: - Week-start-aware calendar helpers

/// [year]년 [month]월 1일이 그리드에서 몇 번째 칸(0-based)에 오는지.
/// [sundayFirst] 가 false면 월요일 시작(0=월 ... 6=일), true면 일요일 시작(0=일 ... 6=토).
func firstWeekdayIndex(year: Int, month: Int, sundayFirst: Bool) -> Int {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = 1
    let date = Calendar.current.date(from: comps) ?? Date()
    let wd = Calendar.current.component(.weekday, from: date) // Sun=1 ... Sat=7
    return sundayFirst ? (wd - 1) : ((wd + 5) % 7)
}

/// [sundayFirst] 기준으로 정렬된 요일 라벨 7개.
func weekdayLabels(sundayFirst: Bool) -> [String] {
    let mondayFirst = ["월", "화", "수", "목", "금", "토", "일"]
    guard sundayFirst else { return mondayFirst }
    return [mondayFirst.last!] + mondayFirst.dropLast()
}

/// [sundayFirst] 기준 그리드에서 일요일이 위치한 컬럼(0-based).
func sundayColumnIndex(sundayFirst: Bool) -> Int {
    sundayFirst ? 0 : 6
}
```

- [ ] **Step 5: `MediumWidgetView` — 미니 캘린더에 헬퍼 적용**

`firstWeekday` 계산 프로퍼티(현재 345~353번째 줄)를 다음으로 교체:

```swift
    private var firstWeekday: Int {
        firstWeekdayIndex(year: displayYear, month: displayMonth, sundayFirst: entry.sundayFirst)
    }
```

`miniCalendarView`의 요일 헤더(현재 375~383번째 줄)를 다음으로 교체:

```swift
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdayLabels(sundayFirst: entry.sundayFirst)[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(i == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor : textColor)
                        .frame(width: 20, height: 22)
                }
            }
```

날짜 그리드 안 텍스트 색상 계산(현재 399~404번째 줄, `dow == 6 ? sundayColor :` 부분)을 다음으로 교체:

```swift
                                    .foregroundColor(
                                        isToday ? Color(hex: 0xFF6B6B) :
                                        dow == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor :
                                        hasMatches ? textColor :
                                        Color(hex: 0xA6A7AB)
                                    )
```

주의: `weekdayNames`/`weekdayShort` 프로퍼티(174~175번째 줄)는 **건드리지 않는다** — 이건 `todayWeekdayLabel`(오늘이 무슨 요일인지 표시)에 쓰이는 값으로, 캘린더 그리드 시작 요일 설정과 무관한 고정 순서다.

- [ ] **Step 6: `LargeWidgetView` — 전체 캘린더에 헬퍼 적용**

`weekdays` 프로퍼티(현재 612번째 줄, `private let weekdays = ["월", "화", "수", "목", "금", "토", "일"]`)를 다음으로 교체:

```swift
    private var weekdays: [String] { weekdayLabels(sundayFirst: entry.sundayFirst) }
```

`firstWeekday` 계산 프로퍼티(현재 625~633번째 줄)를 다음으로 교체:

```swift
    private var firstWeekday: Int {
        firstWeekdayIndex(year: displayYear, month: displayMonth, sundayFirst: entry.sundayFirst)
    }
```

`largeWeekdayRow`(현재 770~780번째 줄) 안 `foregroundColor(i == 6 ? sundayColor : textColor)`를 다음으로 교체:

```swift
                        .foregroundColor(i == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor : textColor)
```

`largeDayCell(week:dow:)`(현재 817~843번째 줄) 안 날짜 숫자 색상 계산(현재 828~831번째 줄, `dow == 6 ? sundayColor : textColor` 부분)을 다음으로 교체:

```swift
                .foregroundColor(
                    isToday ? Color(hex: 0xFF6B6B) :
                    dow == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor : textColor
                )
```

- [ ] **Step 7: Xcode에서 빌드 확인**

Run: `cd ios && xcodebuild -workspace Runner.xcworkspace -scheme WardingScheduleWidgetExtension -configuration Debug -sdk iphonesimulator build`
Expected: `** BUILD SUCCEEDED **` (스킴 이름이 다르면 `xcodebuild -workspace Runner.xcworkspace -list`로 정확한 스킴명을 먼저 확인한다).

- [ ] **Step 8: 커밋**

```bash
git add ios/WardingScheduleWidget/WardingScheduleWidget.swift
git commit -m "feat: iOS 홈 화면 위젯 캘린더에 시작 요일 설정 반영"
```

---

## Task 9: Android 홈 화면 위젯 반영

**Files:**
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt`
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeProvider.kt`
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetService.kt`
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeService.kt`

**Interfaces:**
- Consumes: `HomeWidgetPreferences` SharedPreferences(Task 3이 `week_start` 문자열을 기록)의 `week_start` 키.
- Produces: `CalendarWidgetData.weekStart: String`, `CalendarWidgetData.sundayColumn: Int`, 파일 스코프 `fun orderedWeekdayLabels(weekStart: String): List<String>`.

`ScheduleWidgetSmallProvider.kt`는 캘린더 그리드가 없고(오늘 요일 라벨 하나만 씀, 정렬 개념 없음) 변경하지 않는다.

이 코드도 Android View 렌더링이라 자동 테스트가 없다 — 에뮬레이터에서 수동 확인한다(마지막 태스크).

- [ ] **Step 1: `CalendarWidgetData`에 `weekStart` 필드 + `sundayColumn` 추가**

`android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt`의 `CalendarWidgetData` 클래스(현재 315~348번째 줄)를 다음으로 교체:

```kotlin
data class CalendarWidgetData(
    val year: Int,
    val month: Int,
    val days: Map<Int, List<MatchInfo>>,
    val weekStart: String = "monday"
) {
    companion object {
        fun empty(weekStart: String = "monday"): CalendarWidgetData {
            val cal = Calendar.getInstance()
            return CalendarWidgetData(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, emptyMap(), weekStart)
        }
    }

    /** 그리드에서 일요일이 위치하는 컬럼(0-based). weekStart="sunday"면 0, 아니면 6. */
    val sundayColumn: Int get() = if (weekStart == "sunday") 0 else 6

    fun firstWeekday(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        val wd = cal.get(Calendar.DAY_OF_WEEK) // Sun=1 ... Sat=7
        return if (weekStart == "sunday") (wd - 1) else (wd + 5) % 7
    }

    fun daysInMonth(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        return cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    }

    fun prevMonthDays(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        cal.add(Calendar.MONTH, -1)
        return cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    }

    fun weekCount(): Int = ((firstWeekday() + daysInMonth() - 1) / 7) + 1
}

/** 월~일 순서 요일 라벨을 [weekStart] 기준으로 회전한다. */
fun orderedWeekdayLabels(weekStart: String): List<String> {
    val mondayFirst = listOf("월", "화", "수", "목", "금", "토", "일")
    return if (weekStart == "sunday") listOf(mondayFirst.last()) + mondayFirst.dropLast(1) else mondayFirst
}
```

- [ ] **Step 2: `loadCalendarData()`가 `week_start`를 읽어 전달**

같은 파일의 companion object에 `loadWeekStart` 헬퍼를 `getPrefs` 바로 다음(현재 55~57번째 줄 다음)에 추가:

```kotlin
        private fun loadWeekStart(context: Context): String =
            getPrefs(context).getString("week_start", "monday") ?: "monday"
```

`loadCalendarData(context: Context): CalendarWidgetData`(현재 182~216번째 줄)를 다음으로 교체:

```kotlin
        fun loadCalendarData(context: Context): CalendarWidgetData {
            val prefs = getPrefs(context)
            val weekStart = loadWeekStart(context)
            val jsonStr = prefs.getString("calendar_data", null)
                ?: return CalendarWidgetData.empty(weekStart)
            return try {
                val json = JSONObject(jsonStr)
                val monthStr = json.optString("month", "")
                val parts = monthStr.split("-")
                val year = parts.getOrNull(0)?.toIntOrNull()
                    ?: Calendar.getInstance().get(Calendar.YEAR)
                val month = parts.getOrNull(1)?.toIntOrNull()
                    ?: (Calendar.getInstance().get(Calendar.MONTH) + 1)
                val daysObj = json.optJSONObject("days") ?: JSONObject()
                val days = mutableMapOf<Int, List<MatchInfo>>()
                val keys = daysObj.keys()
                while (keys.hasNext()) {
                    val dayStr = keys.next()
                    val dayNum = dayStr.toIntOrNull() ?: continue
                    val matchArr = daysObj.optJSONArray(dayStr) ?: continue
                    val matches = mutableListOf<MatchInfo>()
                    for (i in 0 until matchArr.length()) {
                        val m = matchArr.optJSONObject(i) ?: continue
                        matches.add(MatchInfo(
                            blue = m.optString("blue", ""),
                            red = m.optString("red", ""),
                            display = m.optString("display", "")
                        ))
                    }
                    days[dayNum] = matches
                }
                CalendarWidgetData(year, month, days, weekStart)
            } catch (e: Exception) {
                CalendarWidgetData.empty(weekStart)
            }
        }
```

- [ ] **Step 3: 일반(중형) 위젯 요일 헤더를 런타임에 순서·색 함께 설정**

같은 파일 `updateWidget(...)` 안, "미니 캘린더 요일 헤더 색상" 블록(현재 96~101번째 줄)을 다음으로 교체:

```kotlin
            // 미니 캘린더 요일 헤더 — 텍스트 순서와 색을 설정에 맞춰 함께 갱신한다.
            val weekStart = loadWeekStart(context)
            val allWdIds = intArrayOf(
                R.id.wd_mon, R.id.wd_tue, R.id.wd_wed, R.id.wd_thu,
                R.id.wd_fri, R.id.wd_sat, R.id.wd_sun
            )
            val orderedLabels = orderedWeekdayLabels(weekStart)
            val sundayCol = if (weekStart == "sunday") 0 else 6
            for (i in allWdIds.indices) {
                views.setTextViewText(allWdIds[i], orderedLabels[i])
                views.setTextColor(allWdIds[i], if (i == sundayCol) sundayColor else weekdayHeaderColor)
            }
```

- [ ] **Step 4: 대형 위젯 요일 헤더도 동일하게 (기존 `calData` 재사용)**

`android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeProvider.kt`의 "요일 헤더 색상" 블록(현재 112~120번째 줄)을 다음으로 교체:

```kotlin
            // 요일 헤더 — 텍스트 순서와 색을 설정에 맞춰 함께 갱신한다.
            val allLargeWdIds = intArrayOf(
                R.id.large_wd_mon, R.id.large_wd_tue, R.id.large_wd_wed, R.id.large_wd_thu,
                R.id.large_wd_fri, R.id.large_wd_sat, R.id.large_wd_sun
            )
            val orderedLabels = orderedWeekdayLabels(calData.weekStart)
            for (i in allLargeWdIds.indices) {
                views.setTextViewText(allLargeWdIds[i], orderedLabels[i])
                views.setTextColor(allLargeWdIds[i], if (i == calData.sundayColumn) sundayColor else weekdayHeaderColor)
            }
```

(`calData`는 이 파일의 `updateWidget()`에 이미 `val calData = ScheduleWidgetProvider.loadCalendarData(context)`로 있다 — 현재 87번째 줄.)

- [ ] **Step 5: 그리드 셀의 일요일 강조 컬럼을 설정 기준으로 변경**

`android/app/src/main/kotlin/com/warding/app/ScheduleWidgetService.kt`의 `getViewAt(position:)` 안(현재 137번째 줄):

```kotlin
            val isSunday = dow == 6
```

를 다음으로 교체:

```kotlin
            val isSunday = dow == data.sundayColumn
```

`android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeService.kt`의 `getViewAt(position:)` 안(현재 149번째 줄):

```kotlin
            val isSunday = dow == 6
```

를 다음으로 교체:

```kotlin
            val isSunday = dow == data.sundayColumn
```

- [ ] **Step 6: Gradle 빌드로 컴파일 확인**

Run: `cd android && ./gradlew :app:compileDebugKotlin`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: 커밋**

```bash
git add android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeProvider.kt android/app/src/main/kotlin/com/warding/app/ScheduleWidgetService.kt android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeService.kt
git commit -m "feat: Android 홈 화면 위젯 캘린더에 시작 요일 설정 반영"
```

---

## Task 10: 전체 수동 검증

**Files:** 없음 (코드 변경 없음, 체크리스트만 수행)

**Interfaces:**
- Consumes: Task 1~9의 전체 결과물.

- [ ] **Step 1: Flutter 전체 회귀 테스트**

Run: `flutter test`
Expected: 전부 PASS.

- [ ] **Step 2: 정적 분석 전체**

Run: `flutter analyze`
Expected: `No issues found!` (기존에 있던 무관한 warning이 있다면 그대로 두고, 이번 변경으로 새로 생긴 issue가 없는지만 확인)

- [ ] **Step 3: 앱 내 설정 → 경기 일정 → 월 선택 시트 흐름 확인 (시뮬레이터/에뮬레이터)**

1. `flutter run`으로 앱 실행 (iOS 시뮬레이터 또는 Android 에뮬레이터)
2. 마이페이지 → "캘린더 시작 요일" → "일요일" 선택
3. 경기 일정 탭으로 전환 → 요일 헤더가 "일 월 화 수 목 금 토" 순서인지, 날짜 그리드가 그에 맞는지 확인
4. 월 라벨 탭 → 월 선택 바텀시트도 같은 순서인지 확인
5. 마이페이지로 돌아가 "월요일"로 되돌리고, 경기 일정에서 원래대로 "월 화 수 목 금 토 일" 순서로 돌아오는지 확인

- [ ] **Step 4: iOS 홈 화면 위젯 확인 (시뮬레이터)**

1. 앱을 한 번 실행해 "일요일" 설정이 적용된 상태로 둔다.
2. 시뮬레이터 홈 화면에 Warding 경기 일정 위젯(중형·대형)을 추가한다.
3. 요일 헤더가 "일 월 화 수 목 금 토" 순서이고, 일요일 컬럼이 보라색(`sundayColor`)으로 강조되는지 확인한다.
4. 잠금화면 위젯(`accessoryRectangular`/`accessoryCircular`)은 요일 그리드가 없으므로 영향 없음을 확인한다(변경 안 됐어야 함).
5. 마이페이지에서 "월요일"로 되돌리고 위젯이 갱신되는지 확인한다(30분 타임라인 갱신을 기다리지 않으려면 위젯을 길게 눌러 "위젯 편집"에서 나왔다 들어가거나, 시뮬레이터를 재실행해 확인).

- [ ] **Step 5: Android 홈 화면 위젯 확인 (에뮬레이터)**

1. "일요일" 설정이 적용된 상태에서 에뮬레이터 홈 화면에 소/중/대 위젯을 각각 추가한다.
2. 소형 위젯은 캘린더가 없으므로 오늘 날짜 라벨만 정상 표시되는지 확인(변경 안 됐어야 함).
3. 중형·대형 위젯 요일 헤더가 "일 월 화 수 목 금 토" 순서이고, 일요일 컬럼 색이 보라색인지 확인한다.
4. 위젯의 이전/다음 달 이동 버튼을 눌러도 요일 순서가 유지되는지 확인한다.

- [ ] **Step 6: 완료 보고**

위 5개 스텝이 모두 통과하면 이 플랜은 완료된 것으로 간주한다. 실패한 항목이 있으면 해당 태스크로 돌아가 원인을 조사한다(요일 헤더 정적 XML 텍스트가 실제로 덮어써지는지, `week_start` 키가 공유 저장소에 실제로 도착하는지 등).

