# Android 라지 위젯 인터랙션 + 디자인 정합화 설계

## 배경

`feat/home-widget` 브랜치의 Android 라지 위젯(`schedule_widget_large`)을 실기기(SM A325N)에서 테스트한 결과, 다음 문제를 확인했다.

1. **좌우 화살표(월 이동), 필터 아이콘, 응원팀 아이콘을 탭해도 동작하지 않음.**
   로그로 확인한 근본 원인: 세 버튼 모두 `Intent.ACTION_VIEW`로 `MainActivity`를 여는 방식이다. `MainActivity`가 짧게 열렸다가 앱 내부에서 자동으로 홈으로 복귀하는데, 이때 실제로 갱신되는 것은 **앱 안의 `ScheduleScreen`** 뿐이고 **홈 화면의 위젯 자체(RemoteViews)는 갱신되지 않는다.** 사용자 입장에서는 "눌러도 안 바뀐다"로 보인다.
2. 추가로 확인된 문제: 위젯의 `updatePeriodMillis`(30분) 주기 자동 갱신도 실제로는 네트워크 재조회 없이 **마지막에 캐시된 `SharedPreferences` 데이터를 재렌더링만 한다.** 앱을 켜지 않으면 위젯 데이터가 계속 오래된 상태로 남는다.
3. 라지 위젯을 Figma 디자인(라이트/다크 각각 CSS 스펙)과 대조한 결과, 색상·간격·그라데이션·모서리 반경 등 대부분이 이미 정확히 일치했다. 발견된 실제 차이는 두 가지 아이콘의 stroke 두께뿐이다 (아래 "시각적 정합화" 참고).

## 범위

- **대상**: Android 라지 위젯(`ScheduleWidgetLargeProvider`/`ScheduleWidgetLargeService`)만. 소/중형 위젯, iOS 위젯은 이번 범위에 포함하지 않는다.
- 위젯 크기(`targetCellHeight`)나 미디엄 위젯의 `minHeight` 이슈는 이번 세션에서 이미 별도로 수정 완료된 상태이며 이 설계 문서의 범위가 아니다.

## 아키텍처: `home_widget` 배경 인터랙션 콜백 도입

### 현재 구조의 한계

앱의 모든 백엔드 API 호출은 Dart(`ScheduleRepository` 등)에만 구현되어 있고, 네이티브(Kotlin) 쪽에는 네트워크 호출 코드가 전혀 없다. 따라서 앱 UI를 띄우지 않고 위젯 탭에 반응해 최신 데이터를 가져오려면, Dart 코드를 앱이 포그라운드로 뜨지 않은 상태에서 실행할 방법이 필요하다.

### 채택하는 방법

`home_widget` 패키지를 `^0.7.0` → `^0.9.3`으로 업그레이드하고, 패키지가 제공하는 백그라운드 인터랙션 콜백을 사용한다 (GitHub `home_widget-v0.9.3` 태그 기준으로 API 확인 완료).

**Dart 측:**
```dart
// main.dart 또는 별도 top-level 파일에 정의 (클로저 불가, top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 이 콜백은 별도의 headless Flutter 엔진(Background Isolate)에서 실행되므로
  // main()에서 하던 앱 전체 초기화가 자동으로 되어 있지 않다.
  // 이 콜백 안에서 필요한 최소 초기화만 다시 수행한다 (아래 "리스크" 참고).
  await HomeWidgetService.handleBackgroundWidgetAction(uri);
}

// main() 안에서 최초 1회 등록
await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
```

**Kotlin 측 (각 위젯 Provider):** 버튼의 `PendingIntent`를 Activity 실행용에서 브로드캐스트용으로 교체한다.

```kotlin
// 기존 (MainActivity를 여는 방식) — 제거
// val prevPending = PendingIntent.getActivity(context, 1, prevIntent, ...)

// 변경 (백그라운드 브로드캐스트로 Dart 콜백만 실행, 앱 UI 없음)
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

val prevUri = Uri.parse("warding://widget/prev?year=$year&month=$month")
val prevPending = HomeWidgetBackgroundIntent.getBroadcast(context, prevUri)
views.setOnClickPendingIntent(R.id.large_prev_btn, prevPending)
```

동일한 방식을 `large_next_btn`, `large_filter_btn`, `large_team_btn`에 적용한다. URI 스킴(`warding://widget/prev`, `/next`, `/filter`, `/team`)은 기존 값을 그대로 재사용하므로 파싱 로직(`_handleWidgetUrl`의 URI 파싱 부분)은 재사용 가능하다.

### `HomeWidgetService.handleBackgroundWidgetAction(uri)` 동작

기존 `_handleWidgetUrl`이 하던 "화면 이동"을 대신해, 다음을 수행하고 함수를 종료한다 (화면 전환 없음):

1. URI의 `action`(`prev`/`next`/`filter`/`team`)과 `year`/`month` 파싱 (기존 로직 재사용).
2. `prev`/`next`: 목표 연/월로 `ScheduleRepository.instance.fetchCalendar(...)`를 실시간 호출 (범위 제한 없이 몇 달이든 이동 가능).
3. `filter`: `FilterPreferenceRepository`에 저장된 마지막 리그 필터 조합을 ON/OFF 토글. OFF → 저장된 조합 적용, ON → `ALL`로 되돌림.
4. `team`: 저장된 선호 팀 적용 여부(`team_selected`)를 ON/OFF 토글.
5. 위 결과로 다시 계산한 캘린더 데이터를 `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget()`으로 반영해 위젯을 즉시 갱신한다 (기존 `updateCalendar`/`updateFilterState`/`updatePreferredTeam` 함수 재사용).

같은 콜백 등록 메커니즘을 이용해, **30분 주기 자동 갱신 시에도 실제 네트워크 재조회가 일어나도록** `ScheduleWidgetLargeProvider.onUpdate()` 쪽에서도 이 백그라운드 콜백을 트리거하도록 연결한다 (기존엔 캐시 재렌더링만 하던 부분의 근본 수정).

### 리스크 / 주의사항

- 백그라운드 콜백은 앱의 메인 엔진과 **별도의 Flutter 엔진(Isolate)**에서 실행된다. 즉 `main()`에서 하던 Firebase 초기화, Sentry 초기화, DI 등록 등이 자동으로 되어 있지 않다. `handleBackgroundWidgetAction` 안에서 이 호출에 실제로 필요한 최소 구성(예: `ApiConfig`, `AuthService`가 내부적으로 쓰는 `flutter_secure_storage` 접근)만 다시 초기화해야 한다. Firebase/Sentry처럼 필요 없는 무거운 초기화는 생략한다.
- Android 인터랙션은 내부적으로 WorkManager를 사용하므로(`home_widget` 0.9.x 변경사항), 탭 즉시가 아니라 최대 몇 초의 지연이 있을 수 있다. 위젯에는 별도 로딩 인디케이터가 없으므로, 갱신 전까지는 이전 화면이 그대로 보인다 (수용 가능한 수준으로 판단, 별도 로딩 UI는 범위 밖).
- `registerInteractivityCallback`은 앱이 콜드 스타트로 완전히 종료된 상태에서도 위젯 탭만으로 실행되어야 하므로, 이 등록 코드가 `main()` 최상단 가까이에서 항상 실행되는지 확인이 필요하다.

## 인터랙션 요약

| 버튼 | 동작 | 앱 화면 열림 |
|---|---|---|
| 이전/다음 달 | 해당 월 실시간 API 재조회 → 위젯 캘린더 갱신 | 아니오 |
| 필터 아이콘 | 마지막 저장된 리그 필터 ON/OFF 토글 → 위젯 갱신 | 아니오 |
| 응원팀 아이콘 | 저장된 선호 팀 필터 ON/OFF 토글 → 위젯 갱신 | 아니오 |
| 위젯 배경(그 외 영역) | 앱 열기 (기존 동작 유지) | 예 |

## 시각적 정합화 (Figma 대조)

라지 위젯 전체(컨테이너 배경/모서리 반경, 헤더, 요일 행, 날짜 셀, "오늘" 그라데이션 배경, 매치 칩 배경/텍스트색, 구분선 색상 등)를 라이트/다크 각각 Figma CSS 스펙과 대조했다. 대부분 이미 정확히 일치한다 (예: 오늘 강조 그라데이션 `E87558/C865C9/791BB8` 20% 투명도, 칩 배경 `#1F2024`/`#FCFDFE`, 일요일 색상 `#9672AC`/`#6D2E92` 등 모두 일치).

발견된 실제 차이, 수정 대상:

1. `ic_chevron_left(_dark).xml`, `ic_chevron_right(_dark).xml`: 현재 `strokeWidth="2"` → Figma 스펙은 1px. `1`로 수정.
2. `ic_filter(_dark).xml`: 현재 `strokeWidth="2"` → Figma 스펙은 1.5px. `1.5`로 수정.

발견되었으나 수정하지 않는 항목 (근거 명시):

- 캘린더 그리드(`con`) 자체의 17dp 모서리 반경: Figma 스펙에는 있으나, 이 영역이 바깥 위젯 배경과 같은 색을 공유하고 별도 배경색이 없어 시각적으로 구분되지 않는다. 적용해도 육안상 차이가 없으므로 생략한다.

## 테스트 계획

- Android 실기기(SM A325N)에서 `flutter run` 후 라지 위젯을 홈 화면에 재추가.
- 이전/다음 달 버튼 반복 탭 → 위젯이 앱을 열지 않고 캘린더가 갱신되는지 확인.
- 필터/응원팀 아이콘 탭 → 토글 상태가 위젯에 즉시 반영되는지 확인 (아이콘 보더 그라데이션 표시 여부 포함).
- 완전히 종료(force-stop)한 상태에서 위젯 탭 → 콜드 스타트에서도 정상 동작하는지 확인.
- 라이트/다크 모드 전환 후 아이콘 stroke 두께 육안 확인.
