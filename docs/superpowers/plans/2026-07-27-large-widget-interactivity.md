# 라지 위젯 인터랙션 + 디자인 정합화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android 라지 위젯(`schedule_widget_large`)의 이전/다음 달·필터·응원팀 버튼이 앱 UI를 열지 않고 위젯 안에서 바로 동작하게 하고, 30분 주기 자동 갱신이 실제 네트워크 재조회를 하게 하며, 2개 아이콘의 stroke 두께를 Figma 스펙에 맞춘다.

**Architecture:** 이미 설치된 `home_widget: 0.7.0+1` 패키지가 필요한 API(`HomeWidget.registerInteractivityCallback`, 네이티브 `HomeWidgetBackgroundIntent.getBroadcast`)를 전부 포함하고 있음을 실제 패키지 소스(`~/.pub-cache/hosted/pub.dev/home_widget-0.7.0+1`)로 확인했다. 버튼의 `PendingIntent`를 `Intent.ACTION_VIEW`(MainActivity 실행)에서 `HomeWidgetBackgroundIntent.getBroadcast`(브로드캐스트, `HomeWidgetBackgroundReceiver` 대상)로 바꾸면, 이미 `main.dart`에 등록되어 있는 headless Dart 콜백이 URI를 받아 앱 UI 없이 위젯을 갱신할 수 있다. 이 콜백이 호출할 새 진입점 `HomeWidgetService.handleBackgroundWidgetAction(Uri?)`을 추가한다.

**Tech Stack:** Flutter/Dart(`home_widget`, `http`), Android Kotlin(`AppWidgetProvider`, `RemoteViews`, `HomeWidgetBackgroundIntent`).

## Global Constraints

- **범위**: Android 라지 위젯(`ScheduleWidgetLargeProvider`/`ScheduleWidgetLargeService`)만. 소/중형 위젯(`ScheduleWidgetProvider`), iOS 위젯은 이번 계획에 포함하지 않는다.
- **패키지 버전은 그대로 유지한다.** 스펙 작성 시점엔 `home_widget`을 `^0.9.3`으로 올려야 한다고 가정했지만, 실제 설치된 `0.7.0+1`의 Dart(`lib/src/home_widget.dart`)·Kotlin(`HomeWidgetIntent.kt`, `HomeWidgetBackgroundReceiver.kt`) 소스를 직접 읽어 `registerInteractivityCallback`과 `HomeWidgetBackgroundIntent.getBroadcast`가 이미 존재함을 확인했다. `pubspec.yaml`은 건드리지 않는다.
- **위젯 토글은 위젯 전용 임시 상태다.** 필터/응원팀 아이콘 토글은 `FilterPreferenceRepository`(앱이 실제로 저장하는 필터)를 변경하지 않고, 위젯 쪽 `has_filter`/`team_selected` 값만 바꾼다. 앱을 열거나 30분 주기 자동 갱신(`refresh` 액션, 기존 `refreshFromApi()`)이 돌면 앱에 저장된 실제 필터로 되돌아간다 — 의도된 동작이다.
- **네이티브 위젯 리소스(`android/app/src/main/res/**`)는 `AppColors` 규칙 대상이 아니다.** CLAUDE.md의 "색 하드코딩 금지"는 Dart/Flutter UI 코드 기준이며, 기존 Kotlin/XML 위젯 코드는 이미 색상 하드코딩 패턴을 쓰고 있어 그 관례를 그대로 따른다.
- **테스트**: `HomeWidgetService`와 네이티브 Provider는 기존에 단위 테스트가 없다(플랫폼 채널·네트워크 의존이라 이 저장소 관례상 테스트 대상 밖). 이 관행을 그대로 따르고, 검증은 `flutter analyze` + Android 실기기 수동 테스트로 한다.
- 파일명 `snake_case`, 클래스명 `PascalCase` — 이번 작업은 기존 파일 수정뿐이라 해당 규칙 위반 여지 없음.

---

### Task 1: `HomeWidgetBackgroundReceiver`/`HomeWidgetBackgroundService`를 매니페스트에 등록

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: 없음.
- Produces: `es.antonborri.home_widget.HomeWidgetBackgroundReceiver` 컴포넌트가 앱에 등록됨 — Task 4에서 이 리시버를 대상으로 하는 `PendingIntent`가 실제로 배달되려면 반드시 필요하다.

**왜 필요한가:** `home_widget` 패키지의 `android/src/main/AndroidManifest.xml`은 `<manifest package="es.antonborri.home_widget" />` 한 줄뿐이라 이 리시버/서비스가 라이브러리 쪽에서 자동 등록되지 않는다. 패키지의 `example` 앱 매니페스트(`~/.pub-cache/hosted/pub.dev/home_widget-0.7.0+1/example/android/app/src/main/AndroidManifest.xml`)에 실제로 이 두 컴포넌트가 명시적으로 선언돼 있는 것으로 확인했다. 등록하지 않으면 `PendingIntent.getBroadcast`가 크래시 없이 조용히 아무 동작도 하지 않는다.

- [ ] **Step 1: 리시버 + 서비스 선언 추가**

`android/app/src/main/AndroidManifest.xml`에서 아래 블록(기존 `ScheduleWidgetLargeService` 선언, 74번째 줄 근처)을 찾는다:

```xml
        <service
            android:name=".ScheduleWidgetLargeService"
            android:permission="android.permission.BIND_REMOTEVIEWS"
            android:exported="false" />

        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
```

다음으로 교체 (사이에 새 블록 삽입):

```xml
        <service
            android:name=".ScheduleWidgetLargeService"
            android:permission="android.permission.BIND_REMOTEVIEWS"
            android:exported="false" />

        <!-- home_widget 패키지: 위젯 버튼 탭을 앱 UI 없이 백그라운드 Dart 콜백으로 처리한다.
             패키지 자체 매니페스트에는 선언되어 있지 않아 앱에서 직접 등록해야 한다. -->
        <receiver
            android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
            </intent-filter>
        </receiver>
        <service
            android:name="es.antonborri.home_widget.HomeWidgetBackgroundService"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:exported="true" />

        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
```

- [ ] **Step 2: XML 유효성 확인**

Run: `cd android && ./gradlew :app:processDebugMainManifest 2>&1 | tail -30`
Expected: `BUILD SUCCESSFUL` (매니페스트 병합 단계만 통과하면 충분 — 전체 빌드는 Task 6에서 확인).

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: home_widget 백그라운드 리시버/서비스 매니페스트 등록"
```

---

### Task 2: `HomeWidgetService`에 백그라운드 액션 처리 로직 추가

**Files:**
- Modify: `lib/util/home_widget_service.dart`

**Interfaces:**
- Consumes:
  - 기존 `ScheduleRepository.instance.fetchCalendar(DateTime, {List<String> leagues, List<int>? teamIds})` → `Future<List<MatchCalendarDay>>`.
  - 기존 `FilterPreferenceRepository.instance.load(String key)` → `Future<Map<String, dynamic>?>`, 키는 `saved['leagues']`(`List<String>`), `saved['teamIds']`(`List<int>`) — `lib/viewmodel/schedule/schedule_viewmodel.dart:61-65`가 저장하는 것과 동일한 스키마.
  - 기존 `HomeWidget.getWidgetData<T>(String id, {T? defaultValue})`.
  - 기존 클래스 내부 `updateCalendar(...)`, `updateFilterState(...)` (시그니처 변경 없음).
- Produces:
  - `static Future<void> HomeWidgetService.handleBackgroundWidgetAction(Uri? uri)` — Task 3(`main.dart`)에서 호출.
  - (내부 전용) `_loadPreferredTeamForWidget`, `_currentDisplayedMonth`, `_refetchAndUpdate`, `_handleMonthShift`, `_handleFilterToggle`, `_handleTeamToggle`.

- [ ] **Step 1: 선호 팀 로딩 로직을 공유 헬퍼로 추출**

`lib/util/home_widget_service.dart`의 `refreshFromApi()` 안에서 아래 블록(파일 419~436번째 줄 근처, "응원팀 정보도 위젯에 전달" 주석 블록)을 찾는다:

```dart
    // 응원팀 정보도 위젯에 전달
    try {
      Team? team;
      try {
        final me = await AuthService.instance.fetchMe();
        if (me.favoriteTeamId != null) {
          final teams = await OnboardingRepository.instance.fetchTeams();
          for (final t in teams) {
            if (t.id == me.favoriteTeamId) { team = t; break; }
          }
        }
      } catch (_) {
        team = await TeamPreferenceRepository.instance.loadPreferredTeam();
      }
      await updatePreferredTeam(team);
    } catch (e) {
      debugPrint('[HomeWidget] 응원팀 갱신 실패: $e');
    }
  }
}
```

다음으로 교체 (동작은 동일, 로직만 `_loadPreferredTeamForWidget()`로 추출 — 이후 Step에서 백그라운드 팀 토글도 같은 헬퍼를 재사용한다):

```dart
    // 응원팀 정보도 위젯에 전달
    try {
      final team = await _loadPreferredTeamForWidget();
      await updatePreferredTeam(team);
    } catch (e) {
      debugPrint('[HomeWidget] 응원팀 갱신 실패: $e');
    }
  }

  /// 로그인 회원은 서버 `favoriteTeamId` 기준, 실패(비로그인 등) 시 로컬 캐시로
  /// 폴백해 선호 팀을 읽는다. [refreshFromApi]와 백그라운드 팀 필터 토글이 공유한다.
  static Future<Team?> _loadPreferredTeamForWidget() async {
    try {
      final me = await AuthService.instance.fetchMe();
      if (me.favoriteTeamId != null) {
        final teams = await OnboardingRepository.instance.fetchTeams();
        for (final t in teams) {
          if (t.id == me.favoriteTeamId) return t;
        }
      }
      return null;
    } catch (_) {
      return TeamPreferenceRepository.instance.loadPreferredTeam();
    }
  }
}
```

주의: 교체 후에도 클래스를 닫는 `}`가 정확히 하나만 남아야 한다 (원본 마지막의 `}`는 `refreshFromApi` 메서드의 닫는 괄호였고, 새 코드에서는 `_loadPreferredTeamForWidget` 메서드의 닫는 괄호가 마지막 `}`가 된다).

- [ ] **Step 2: 정적 분석으로 확인**

Run: `flutter analyze lib/util/home_widget_service.dart`
Expected: `No issues found!`

- [ ] **Step 3: 표시 중인 월 읽기 + 재조회 헬퍼 + 액션별 핸들러 추가**

Step 1에서 남긴 파일 맨 끝(`_loadPreferredTeamForWidget` 메서드와 그 뒤에 오는 클래스 닫는 `}`)을 찾는다:

```dart
  static Future<Team?> _loadPreferredTeamForWidget() async {
    try {
      final me = await AuthService.instance.fetchMe();
      if (me.favoriteTeamId != null) {
        final teams = await OnboardingRepository.instance.fetchTeams();
        for (final t in teams) {
          if (t.id == me.favoriteTeamId) return t;
        }
      }
      return null;
    } catch (_) {
      return TeamPreferenceRepository.instance.loadPreferredTeam();
    }
  }
}
```

이 블록 전체(마지막 `}`까지 포함)를 아래로 교체한다 — 새 메서드들을 추가하고, 클래스를 닫는 `}`는 맨 끝으로 한 번만 남긴다:

```dart
  static Future<Team?> _loadPreferredTeamForWidget() async {
    try {
      final me = await AuthService.instance.fetchMe();
      if (me.favoriteTeamId != null) {
        final teams = await OnboardingRepository.instance.fetchTeams();
        for (final t in teams) {
          if (t.id == me.favoriteTeamId) return t;
        }
      }
      return null;
    } catch (_) {
      return TeamPreferenceRepository.instance.loadPreferredTeam();
    }
  }

  /// 위젯에 마지막으로 저장된 캘린더 데이터의 월(연/월)을 읽는다.
  /// 저장값이 없거나 파싱 실패 시 현재 실제 월로 폴백한다.
  static Future<DateTime> _currentDisplayedMonth() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('calendar_data');
      if (raw != null) {
        final monthStr =
            (jsonDecode(raw) as Map<String, dynamic>)['month'] as String?;
        if (monthStr != null) {
          final parts = monthStr.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]));
        }
      }
    } catch (_) {
      // 파싱 실패 시 아래 폴백으로.
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// [month]를 [hasFilter]/[teamSelected] 상태에 맞춰 다시 조회하고
  /// 위젯(캘린더 + 필터 상태)을 갱신한다.
  ///
  /// 리그 필터는 `FilterPreferenceRepository`에 저장된 마지막 조합을 쓰되,
  /// [hasFilter]가 false면 'ALL'로 되돌린다. 팀 필터는 [teamSelected]가
  /// true일 때만 선호 팀 ID를 추가로 합친다. 앱의 실제 저장 필터
  /// (`FilterPreferenceRepository`)는 읽기만 하고 쓰지 않는다 — 위젯 토글은
  /// 위젯에만 적용되는 임시 상태다.
  static Future<void> _refetchAndUpdate({
    required DateTime month,
    required bool hasFilter,
    required bool teamSelected,
  }) async {
    List<String> savedLeagues = const ['ALL'];
    List<int> savedTeamIds = const [];
    try {
      final saved = await FilterPreferenceRepository.instance
          .load(FilterPreferenceRepository.scheduleKey);
      if (saved != null) {
        savedLeagues =
            (saved['leagues'] as List?)?.cast<String>() ?? const ['ALL'];
        savedTeamIds = (saved['teamIds'] as List?)?.cast<int>() ?? const [];
      }
    } catch (e) {
      debugPrint('[HomeWidget] 저장된 필터 복원 실패: $e');
    }

    final leagues = hasFilter ? savedLeagues : const ['ALL'];
    var teamIds = hasFilter ? savedTeamIds : const <int>[];
    if (teamSelected) {
      final team = await _loadPreferredTeamForWidget();
      if (team != null) {
        teamIds = {...teamIds, team.id}.toList();
      }
    }

    final leagueParam = leagues.contains('ALL') ? const ['LCK'] : leagues;
    final days = await ScheduleRepository.instance.fetchCalendar(
      month,
      leagues: leagueParam,
      teamIds: teamIds.isNotEmpty ? teamIds : null,
    );
    final matchesByDay = <int, List<CalendarMatchBrief>>{
      for (final day in days) day.date.day: day.matches,
    };

    await updateCalendar(
      month: month,
      matchesByDay: matchesByDay,
      leagues: leagues,
      teamIds: teamIds,
    );
    await updateFilterState(hasFilter: hasFilter, teamSelected: teamSelected);
  }

  static Future<void> _handleMonthShift(int delta) async {
    final current = await _currentDisplayedMonth();
    final target = DateTime(current.year, current.month + delta);
    final hasFilter = await HomeWidget.getWidgetData<bool>(
          'has_filter',
          defaultValue: false,
        ) ??
        false;
    final teamSelected = await HomeWidget.getWidgetData<bool>(
          'team_selected',
          defaultValue: false,
        ) ??
        false;
    await _refetchAndUpdate(
      month: target,
      hasFilter: hasFilter,
      teamSelected: teamSelected,
    );
  }

  static Future<void> _handleFilterToggle() async {
    final hasFilter = await HomeWidget.getWidgetData<bool>(
          'has_filter',
          defaultValue: false,
        ) ??
        false;
    final teamSelected = await HomeWidget.getWidgetData<bool>(
          'team_selected',
          defaultValue: false,
        ) ??
        false;
    final month = await _currentDisplayedMonth();
    await _refetchAndUpdate(
      month: month,
      hasFilter: !hasFilter,
      teamSelected: teamSelected,
    );
  }

  static Future<void> _handleTeamToggle() async {
    final hasFilter = await HomeWidget.getWidgetData<bool>(
          'has_filter',
          defaultValue: false,
        ) ??
        false;
    final teamSelected = await HomeWidget.getWidgetData<bool>(
          'team_selected',
          defaultValue: false,
        ) ??
        false;
    final month = await _currentDisplayedMonth();
    await _refetchAndUpdate(
      month: month,
      hasFilter: hasFilter,
      teamSelected: !teamSelected,
    );
  }

  /// 위젯 백그라운드 인터랙션 진입점.
  ///
  /// `main.dart`의 `registerInteractivityCallback` 콜백에서 호출된다.
  /// 앱 UI를 열지 않고 URI(`warding://widget/{prev,next,filter,team}`,
  /// 주기 자동 갱신은 `/refresh`)에 따라 위젯만 갱신한다.
  static Future<void> handleBackgroundWidgetAction(Uri? uri) async {
    final action = uri?.path.replaceAll('/', '') ?? 'refresh';
    try {
      switch (action) {
        case 'prev':
          await _handleMonthShift(-1);
          break;
        case 'next':
          await _handleMonthShift(1);
          break;
        case 'filter':
          await _handleFilterToggle();
          break;
        case 'team':
          await _handleTeamToggle();
          break;
        default:
          await refreshFromApi();
      }
    } catch (e) {
      debugPrint('[HomeWidget] 백그라운드 액션 처리 실패($action): $e');
    }
  }
}
```

- [ ] **Step 4: 정적 분석으로 확인**

Run: `flutter analyze lib/util/home_widget_service.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/util/home_widget_service.dart
git commit -m "feat: 위젯 백그라운드 인터랙션(월 이동/필터/응원팀 토글) 처리 추가"
```

---

### Task 3: `main.dart`의 백그라운드 콜백이 새 진입점을 쓰도록 연결

**Files:**
- Modify: `lib/main.dart:26-31`

**Interfaces:**
- Consumes: `HomeWidgetService.handleBackgroundWidgetAction(Uri?)` (Task 2).
- Produces: 없음 — 기존 `HomeWidget.registerInteractivityCallback(_homeWidgetBackgroundCallback)` 등록은 그대로 유지된다.

- [ ] **Step 1: 콜백 본문 교체**

`lib/main.dart`에서 아래 함수:

```dart
@pragma('vm:entry-point')
Future<void> _homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidgetService.init();
  await HomeWidgetService.refreshFromApi();
}
```

다음으로 교체:

```dart
@pragma('vm:entry-point')
Future<void> _homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidgetService.init();
  await HomeWidgetService.handleBackgroundWidgetAction(uri);
}
```

- [ ] **Step 2: 정적 분석으로 확인**

Run: `flutter analyze lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: 위젯 백그라운드 콜백이 URI 기반 액션 처리로 동작하도록 연결"
```

---

### Task 4: `ScheduleWidgetLargeProvider`의 버튼을 백그라운드 브로드캐스트로 전환 + 주기 갱신 시 실제 재조회

**Files:**
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeProvider.kt`

**Interfaces:**
- Consumes: `es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(Context, Uri?): PendingIntent` (패키지 제공, Task 1의 매니페스트 등록 필요).
- Produces: 없음 (네이티브 위젯 최종 동작 변경).

- [ ] **Step 1: import 추가**

`android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeProvider.kt` 최상단 import 블록에서:

```kotlin
import android.widget.RemoteViews
import java.net.URL
```

다음으로 교체:

```kotlin
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.net.URL
```

- [ ] **Step 2: 이전/다음 달 버튼을 백그라운드 브로드캐스트로 전환**

아래 블록:

```kotlin
            val prevIntent = Intent(Intent.ACTION_VIEW, Uri.parse("warding://widget/prev?year=$year&month=$month"))
            prevIntent.setPackage(context.packageName)
            val prevPending = android.app.PendingIntent.getActivity(
                context, 1, prevIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.large_prev_btn, prevPending)

            val nextIntent = Intent(Intent.ACTION_VIEW, Uri.parse("warding://widget/next?year=$year&month=$month"))
            nextIntent.setPackage(context.packageName)
            val nextPending = android.app.PendingIntent.getActivity(
                context, 2, nextIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.large_next_btn, nextPending)
```

다음으로 교체:

```kotlin
            views.setOnClickPendingIntent(
                R.id.large_prev_btn,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("warding://widget/prev?year=$year&month=$month")
                )
            )

            views.setOnClickPendingIntent(
                R.id.large_next_btn,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("warding://widget/next?year=$year&month=$month")
                )
            )
```

- [ ] **Step 3: 필터 버튼을 백그라운드 브로드캐스트로 전환**

아래 블록:

```kotlin
            // 필터 클릭 → 앱 열고 필터 화면
            val filterIntent = Intent(Intent.ACTION_VIEW, Uri.parse("warding://widget/filter"))
            filterIntent.setPackage(context.packageName)
            val filterPending = android.app.PendingIntent.getActivity(
                context, 3, filterIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.large_filter_btn, filterPending)
```

다음으로 교체:

```kotlin
            // 필터 클릭 → 앱을 열지 않고 백그라운드에서 필터 ON/OFF 토글
            views.setOnClickPendingIntent(
                R.id.large_filter_btn,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("warding://widget/filter"))
            )
```

- [ ] **Step 4: 응원팀 버튼을 백그라운드 브로드캐스트로 전환**

아래 블록:

```kotlin
            // 팀 클릭 → 앱 열기
            val teamIntent = Intent(Intent.ACTION_VIEW, Uri.parse("warding://widget/team"))
            teamIntent.setPackage(context.packageName)
            val teamPending = android.app.PendingIntent.getActivity(
                context, 4, teamIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.large_team_btn, teamPending)
```

다음으로 교체:

```kotlin
            // 팀 클릭 → 앱을 열지 않고 백그라운드에서 응원팀 필터 ON/OFF 토글
            views.setOnClickPendingIntent(
                R.id.large_team_btn,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("warding://widget/team"))
            )
```

- [ ] **Step 5: 30분 주기 자동 갱신 시 실제 네트워크 재조회 트리거**

`onUpdate()` 함수:

```kotlin
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called, ids=${appWidgetIds.toList()}")
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
                Log.d(TAG, "updateWidget success for id=$appWidgetId")
            } catch (e: Exception) {
                Log.e(TAG, "updateWidget failed for id=$appWidgetId", e)
            }
        }
    }
```

다음으로 교체:

```kotlin
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called, ids=${appWidgetIds.toList()}")
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
                Log.d(TAG, "updateWidget success for id=$appWidgetId")
            } catch (e: Exception) {
                Log.e(TAG, "updateWidget failed for id=$appWidgetId", e)
            }
        }
        // 캐시 재렌더링뿐 아니라 실제 네트워크 재조회도 트리거한다 (30분 주기 자동 갱신 대응).
        try {
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("warding://widget/refresh")).send()
        } catch (e: android.app.PendingIntent.CanceledException) {
            Log.e(TAG, "refresh background intent failed", e)
        }
    }
```

- [ ] **Step 6: 컴파일 확인**

Run: `cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -40`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/kotlin/com/warding/app/ScheduleWidgetLargeProvider.kt
git commit -m "feat: 라지 위젯 버튼을 백그라운드 브로드캐스트로 전환, 주기 갱신 시 실제 재조회"
```

---

### Task 5: 아이콘 stroke 두께를 Figma 스펙에 맞춘다

**Files:**
- Modify: `android/app/src/main/res/drawable/ic_chevron_left.xml`
- Modify: `android/app/src/main/res/drawable/ic_chevron_left_dark.xml`
- Modify: `android/app/src/main/res/drawable/ic_chevron_right.xml`
- Modify: `android/app/src/main/res/drawable/ic_chevron_right_dark.xml`
- Modify: `android/app/src/main/res/drawable/ic_filter.xml`
- Modify: `android/app/src/main/res/drawable/ic_filter_dark.xml`

**Interfaces:**
- Consumes: 없음.
- Produces: 없음 (드로어블 리소스만 변경, 참조하는 레이아웃/Kotlin 코드 변경 없음).

- [ ] **Step 1: 화살표 아이콘 4개 stroke 두께 2 → 1**

아래 4개 파일 각각에서 `android:strokeWidth="2"`를 `android:strokeWidth="1"`로 바꾼다 (각 파일에 해당 속성은 1곳뿐):

- `ic_chevron_left.xml`
- `ic_chevron_left_dark.xml`
- `ic_chevron_right.xml`
- `ic_chevron_right_dark.xml`

예 (`ic_chevron_left.xml`):

```xml
    <path
        android:pathData="M15,6L9,12L15,18"
        android:strokeWidth="1"
        android:strokeColor="#FFFFFFFF"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:fillColor="@android:color/transparent" />
```

- [ ] **Step 2: 필터 아이콘 2개 stroke 두께 2 → 1.5**

`ic_filter.xml`, `ic_filter_dark.xml` 각각에서 `android:strokeWidth="2"`를 `android:strokeWidth="1.5"`로 바꾼다.

예 (`ic_filter.xml`):

```xml
    <path
        android:pathData="M5.5,5H18.5C18.644,5.051 18.775,5.133 18.882,5.242C18.989,5.351 19.07,5.483 19.118,5.627C19.166,5.772 19.181,5.926 19.16,6.077C19.14,6.229 19.085,6.373 19,6.5L14,12V19L10,16V12L5,6.5C4.915,6.373 4.86,6.229 4.84,6.077C4.82,5.926 4.834,5.772 4.882,5.627C4.931,5.483 5.011,5.351 5.118,5.242C5.226,5.133 5.356,5.051 5.5,5Z"
        android:strokeWidth="1.5"
        android:strokeColor="#FFFFFFFF"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:fillColor="@android:color/transparent" />
```

- [ ] **Step 3: 리소스 빌드 확인**

Run: `cd android && ./gradlew :app:processDebugResources 2>&1 | tail -30`
Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/res/drawable/ic_chevron_left.xml \
        android/app/src/main/res/drawable/ic_chevron_left_dark.xml \
        android/app/src/main/res/drawable/ic_chevron_right.xml \
        android/app/src/main/res/drawable/ic_chevron_right_dark.xml \
        android/app/src/main/res/drawable/ic_filter.xml \
        android/app/src/main/res/drawable/ic_filter_dark.xml
git commit -m "fix: 라지 위젯 화살표/필터 아이콘 stroke 두께를 Figma 스펙에 맞춤"
```

---

### Task 6: 실기기 수동 검증 (코드 작업 아님)

**Files:** 없음 (검증 전용 태스크).

**Interfaces:**
- Consumes: Task 1~5에서 완성된 전체 플로우.
- Produces: 없음.

이 태스크는 물리 기기(Android, 홈 화면 위젯 조작)가 필요해 에이전트가 자동 수행할 수 없다. 사용자가 직접 수행한다.

- [ ] **Step 1: 앱 재빌드 및 재설치**

Run: `flutter run -d <연결된 기기 ID>` (이번 세션에서 쓰던 SM A325N 등)
Expected: 빌드 성공, 앱 실행됨.

- [ ] **Step 2: 라지 위젯 재추가**

홈 화면에서 기존 라지 위젯을 삭제하고 다시 추가한다 (레이아웃/리시버 변경이 반영되도록).
확인 항목: 위젯이 오류 없이 로드된다.

- [ ] **Step 3: 이전/다음 달 이동 확인**

위젯의 좌/우 화살표를 각각 눌러본다.
확인 항목: 앱이 열리지 않고(화면이 앱으로 전환되지 않고), 몇 초 내에 위젯의 월 라벨과 캘린더 칸이 이동한 달로 바뀐다.

- [ ] **Step 4: 필터/응원팀 토글 확인**

필터 아이콘, 응원팀 아이콘을 각각 눌러본다.
확인 항목: 앱이 열리지 않고, 아이콘 테두리(그라데이션 보더)가 ON/OFF에 따라 바뀌고 캘린더 내용도 그에 맞게 갱신된다. 다시 누르면 원래대로 돌아간다.

- [ ] **Step 5: 콜드 스타트 확인**

최근 앱 목록에서 Warding 앱을 완전히 종료(스와이프로 제거)한 뒤, 앱을 다시 열지 않은 상태에서 위젯의 화살표나 필터 아이콘을 누른다.
확인 항목: (첫 탭은 백그라운드 Flutter 엔진 초기화 때문에 몇 초 더 걸릴 수 있음을 감안하고) 정상적으로 위젯이 갱신된다.

- [ ] **Step 6: 라이트/다크 모드 아이콘 두께 확인**

기기 설정에서 다크 모드 On/Off를 각각 전환한 뒤 위젯을 육안으로 확인한다.
확인 항목: 화살표·필터 아이콘의 선 두께가 이전보다 가늘어졌다(육안상 확인, 정확한 dp 비교는 불필요).

## 범위 밖

- 소형/중형 위젯, iOS 위젯의 인터랙션 개선.
- `home_widget` 패키지 버전 업그레이드 (불필요함을 확인함).
- 위젯 필터 토글 결과를 앱의 영구 저장 필터에 반영하는 것 (의도적으로 위젯 전용 임시 상태로 유지).
