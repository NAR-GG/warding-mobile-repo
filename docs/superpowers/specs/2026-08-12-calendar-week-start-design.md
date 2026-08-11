# 캘린더 시작 요일 설정 — 설계

날짜: 2026-08-12

## 배경 / 목적

마이페이지에서 캘린더 시작 요일(월요일 시작 vs 일요일 시작)을 사용자가 고를 수 있게 한다.
설정값은 다음 세 곳에 모두 반영되어야 한다.

1. 마이페이지 설정 UI
2. 앱 안 경기 일정 탭(`ScheduleScreen`)의 캘린더·월 선택 시트
3. iOS/Android 홈 화면 위젯(WidgetKit / AppWidget)의 미니/전체 캘린더

`lib/screens/subscription/component/subscription_date_sheet.dart`(구독 설정 전용 날짜 선택기)는
"경기 일정"이 아니므로 이번 범위에서 제외하고 월요일 시작을 유지한다.

## 현재 상태 (조사 결과)

- 앱 안 캘린더는 외부 패키지 없이 자체 구현이며, 월요일 시작이 다음 3곳에 각각 하드코딩돼 있다.
  - `lib/screens/schedule/component/calendar_weekday_header.dart` — 요일 라벨 순서
  - `lib/screens/schedule/component/calendar_month_grid.dart:37` — `leadingDays = month.weekday - DateTime.monday`
  - `lib/screens/schedule/component/month_picker_sheet.dart:209` — 동일 공식 중복
- 홈 화면 위젯도 동일 문제가 네이티브 코드에 중복돼 있다.
  - iOS: `ios/WardingScheduleWidget/WardingScheduleWidget.swift` — `MediumWidgetView`와 `LargeWidgetView` 양쪽에
    `firstWeekday`(`(wd + 5) % 7`), `weekdayNames` 배열이 각각 따로 있음.
  - Android: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt`의
    `CalendarWidgetData.firstWeekday()`가 `ScheduleWidgetService.kt`/`ScheduleWidgetLargeService.kt` 양쪽에서
    공유되지만, 요일 헤더 텍스트는 `schedule_widget.xml`/`schedule_widget_large.xml`에 월~일 순서로 정적으로
    박혀 있고 색상만 런타임에 `wd_sun` id에 지정됨.
- 로컬 기기 설정 저장은 `SpoilerPreferenceRepository`(스포방지 on/off, 커밋 36e333f)가 확립한 패턴을 따른다:
  `FlutterSecureStorage` 재사용 + `static final instance` + 동기 캐시 필드(`cachedValue`) + try/catch 폴백.
  `MatchListViewModel`이 생성자에서 `cachedValue`로 즉시 반영 후 비동기로 재검증하는 방식을 그대로 재사용한다.
- 홈 위젯 데이터 전달은 `lib/util/home_widget_service.dart`의 `HomeWidgetService`가
  `HomeWidget.saveWidgetData<T>(key, value)`(App Group UserDefaults / Android SharedPreferences)로
  담당하고, `HomeWidget.updateWidget(...)`으로 3개 위젯(소/중/대)을 갱신 트리거한다.
- 설정 UI 참고 패턴: `lib/screens/mypage/component/quiet_hours_section.dart`(카드형 컨테이너 + `_Row` + 값 트레일링
  + 탭하면 바텀시트) 와 `lib/screens/mypage/component/language_setting_sheet.dart`(2지선다 리스트 바텀시트).

## 설계

### 1. 모델 — `lib/model/calendar_week_start.dart`

```dart
enum CalendarWeekStart {
  monday,
  sunday;

  int get dateTimeWeekday =>
      this == CalendarWeekStart.monday ? DateTime.monday : DateTime.sunday;

  /// [firstOfMonth]가 속한 주에서, 이 설정 기준 주 시작일까지 거슬러 올라갈 일수.
  int leadingDays(DateTime firstOfMonth) =>
      (firstOfMonth.weekday - dateTimeWeekday + 7) % 7;

  /// 이 설정 기준으로 정렬된 요일 라벨 7개 (월~일 순서 리스트를 회전).
  List<String> orderedWeekdayLabels(List<String> mondayFirstLabels) {
    if (this == CalendarWeekStart.monday) return mondayFirstLabels;
    return [mondayFirstLabels.last, ...mondayFirstLabels.take(6)];
  }
}
```

`calendar_month_grid.dart`, `month_picker_sheet.dart`가 각자 구현하던
`month.weekday - DateTime.monday` 공식을 이 헬퍼로 교체해 중복을 없앤다.

### 2. 로컬 저장 — `CalendarWeekStartPreferenceRepository`

`lib/repository/preference/calendar_week_start_preference_repository.dart`.
`SpoilerPreferenceRepository`와 동일한 구조로 작성한다.

```dart
class CalendarWeekStartPreferenceRepository {
  static final instance = CalendarWeekStartPreferenceRepository();
  static const _key = 'calendar_week_start';

  CalendarWeekStart? _cached;
  CalendarWeekStart? get cachedValue => _cached;

  Future<CalendarWeekStart> load() async { ... } // 실패/미저장 시 monday
  Future<void> save(CalendarWeekStart value) async { ... } // 실패해도 무시
}
```

저장값은 `'monday'`/`'sunday'` 문자열로 직렬화한다.

### 3. 마이페이지 설정 UI

- `lib/viewmodel/mypage/calendar_week_start_viewmodel.dart` — `CalendarWeekStartViewModel(ChangeNotifier)`.
  생성자에서 `repository.cachedValue ?? CalendarWeekStart.monday`로 동기 초기화 후 `load()`로 재검증(스포방지
  패턴). `setWeekStart(value)`는 즉시 `notifyListeners()` 후 `repository.save(value)` + 위젯 동기화를 호출한다.
  ViewModel 자체는 로그인 여부를 확인하지 않지만, 화면은 `QuietHoursSection`과 마찬가지로 마이페이지
  전체를 덮는 `GuestLockOverlay` 안에 놓인다 — 최종 리뷰에서 게스트 접근 허용 여부를 확인한 결과, 다른
  마이페이지 설정과 동일하게 로그인해야 사용 가능하도록 유지하기로 결정했다(초안의 "게스트 락 없음"
  방침을 뒤집음).
- `lib/screens/mypage/component/calendar_week_start_section.dart` — `QuietHoursSection`과 같은 카드 스타일
  (제목 텍스트 + `narDark600` 카드), 카드 안에 `_Row` 하나: 라벨 "캘린더 시작 요일", 트레일링은 quiet hours의
  `_TimeValue`와 같은 값+chevron 칩("월요일"/"일요일"), 탭하면 바텀시트 오픈.
- `lib/screens/mypage/component/calendar_week_start_sheet.dart` — `LanguageSettingSheet`과 동일한 2지선다
  리스트 바텀시트("월요일부터"/"일요일부터"), 선택 즉시 `Navigator.pop`.
- `lib/screens/mypage/mypage_screen.dart`에서 `QuietHoursSection` 바로 아래(`SizedBox(height: 16*scale)` 간격)에
  `CalendarWeekStartSection`을 삽입한다.
- 새 l10n 키(`app_en.arb`/`app_ko.arb` + 생성 파일): `calendarWeekStartSetting`("캘린더 시작 요일"),
  `calendarWeekStartMonday`("월요일부터"), `calendarWeekStartSunday`("일요일부터").

### 4. 앱 안 경기 일정 반영

- `ScheduleViewModel`에 `CalendarWeekStart get weekStart` 추가. 생성자에서
  `CalendarWeekStartPreferenceRepository.instance.cachedValue ?? CalendarWeekStart.monday`로 동기 초기화,
  이후 비동기 `load()`로 재검증 후 다르면 `notifyListeners()` (스포방지가 `MatchListViewModel`에서 하는 것과
  동일 패턴 — 탭을 `pushReplacement`로 전환할 때마다 VM이 새로 만들어지므로 캐시값이면 충분).
- `MonthPickerViewModel`도 동일하게 `weekStart`를 노출(또는 `ScheduleScreen`이 `_viewModel.weekStart`를
  `MonthPickerSheet` 생성자 파라미터로 그대로 넘겨도 됨 — 구현 단계에서 더 단순한 쪽으로 결정).
- 전달 경로: `ScheduleScreen` → `ScheduleCalendar(weekStart: ...)` → `CalendarWeekdayHeader(weekStart: ...)` /
  `CalendarMonthGrid(weekStart: ...)`. `ScheduleScreen._openMonthPicker()` → `MonthPickerSheet(weekStart: ...)`
  → `_WeekdayRow`/`_DayGrid`.
- 각 위젯은 하드코딩된 `DateTime.monday` 기준 공식을 `weekStart.leadingDays(...)`/`weekStart.orderedWeekdayLabels(...)`
  호출로 교체한다.

### 5. 홈 화면 위젯 반영

**Flutter → 공유 저장소**: `HomeWidgetService.updateWeekStart(CalendarWeekStart value)` 추가.
`HomeWidget.saveWidgetData<String>('week_start', value.name)` 후 기존 3개 위젯(`updateWidget` 소/중/대)을
갱신 트리거한다. `CalendarWeekStartViewModel.setWeekStart()`에서 저장 직후 `unawaited`로 호출한다. 앱 시작 시에도
(`HomeWidgetService.init()` 근처, `main.dart`) 저장된 값을 한 번 읽어 동기화해 위젯 쪽 데이터가 항상 최신
로컬 설정과 일치하게 한다(재설치 등으로 공유 저장소와 로컬 저장소가 어긋나는 경우 대비).

**iOS (`WardingScheduleWidget.swift`)**:
- `loadData()`에서 `ud.string(forKey: "week_start")`를 읽어 `sundayFirst: Bool`로 변환(키 없으면 `false`=월요일).
- `ScheduleEntry`에 `sundayFirst` 필드 추가.
- `MediumWidgetView`·`LargeWidgetView`에 중복된 `firstWeekday`(`(wd + 5) % 7`)와 `weekdayNames` 배열을
  파일 스코프 공용 헬퍼(`func firstWeekdayIndex(year:month:sundayFirst:) -> Int`,
  `func weekdayLabels(sundayFirst: Bool) -> [String]`)로 추출해 양쪽 뷰가 공유하게 한다(기존 중복 제거 겸함).
  월요일 시작 공식은 그대로, 일요일 시작이면 `(wd - 1 + 7) % 7`.
- "일요일 칸 보라색 강조" 로직(`dow == 6`)이 가리키는 컬럼도 `sundayFirst ? 0 : 6`으로 바뀌어야 한다.

**Android (`ScheduleWidgetProvider.kt` 등)**:
- `CalendarWidgetData`에 `weekStart: String` 필드 추가(로드 시 `prefs.getString("week_start", "monday")`),
  `firstWeekday()`가 이 값에 따라 분기(`sunday`면 `(wd - 1 + 7) % 7`). `ScheduleWidgetService.kt`/
  `ScheduleWidgetLargeService.kt`는 이 함수를 그대로 재사용하므로 그리드 오프셋은 자동 반영된다.
- 요일 헤더는 `schedule_widget.xml`/`schedule_widget_large.xml`의 정적 텍스트(`wd_mon`..`wd_sun`,
  `large_wd_mon`..`large_wd_sun`) 대신, `ScheduleWidgetProvider.kt`/`ScheduleWidgetLargeProvider.kt`
  렌더링 시점에 `views.setTextViewText(id, label)`을 7개 뷰 전부에 대해 순서대로 호출해 덮어쓴다. 색상 지정도
  (현재 `wd_sun` id 고정) 컬럼 위치 기준으로 옮겨 라벨과 함께 이동한다.
- `ScheduleWidgetSmallProvider.kt`는 그리드가 없고 오늘 요일 라벨 하나만 쓰므로(정렬 개념 없음) 변경 불필요 —
  구현 단계에서 확인만 한다.

## 에러 처리 / 엣지 케이스

- 저장/복원 실패는 기존 관례대로 try/catch로 삼키고 로그만 남기며, 기본값 `monday`로 폴백한다.
- 네이티브 위젯은 `week_start` 키가 없으면(최초 설치, 아직 한 번도 설정 안 함) `monday`로 기본 동작한다.
- 위젯 갱신 호출은 `unawaited`로 fire-and-forget — 마이페이지 설정 화면이 위젯 갱신 완료를 기다리지 않는다.
- 마이페이지에서 값을 바꾼 뒤 앱을 종료하지 않고 바로 경기 일정 탭으로 이동해도, 탭 전환이 `pushReplacement`로
  `ScheduleViewModel`을 새로 만들기 때문에 캐시값을 통해 즉시 반영된다(기존 스포방지와 동일 보장).

## 테스트

- `CalendarWeekStart.leadingDays`/`orderedWeekdayLabels` 유닛 테스트 (`test/model/`).
- `CalendarWeekStartPreferenceRepository` 저장/복원/캐시/실패 폴백 유닛 테스트.
- `CalendarWeekStartViewModel` 유닛 테스트(초기값, `setWeekStart` 호출 시 저장·notify 여부).
- 네이티브(Swift/Kotlin) 쪽은 자동 테스트 대상이 아니므로 시뮬레이터/에뮬레이터에서 소/중/대 위젯 모두
  수동으로 요일 순서를 확인한다 — 실행 계획에 체크리스트로 명시한다.

## 범위 밖

- `lib/screens/subscription/component/subscription_date_sheet.dart`(구독 설정 날짜 선택기)는 변경하지 않는다.
- 다국어 요일 라벨 자체(영문 "Mon" 등)의 신규 추가는 없다 — 기존 `weekdayMon`..`weekdaySun` l10n 키를 재사용한다.
