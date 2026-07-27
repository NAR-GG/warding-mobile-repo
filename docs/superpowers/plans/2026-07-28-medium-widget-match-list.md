# 미디움 위젯 오늘 경기 리스트 표시 규칙 변경 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android 미디움 위젯의 오늘 경기 리스트에서 지난 경기는 최대 1개만 노출하고, 실제 매치 카드는 최대 2개까지만 보여준 뒤 나머지는 "+N"으로 합산하도록 선택 로직을 바꾼다.

**Architecture:** `ScheduleWidgetProvider.kt`에 순수 함수 `selectDisplayMatches()`를 추가해 "어떤 매치를 어떤 역할(지난/다음/그외)로 보여줄지"를 결정하고, 기존 렌더링 루프는 이 결과를 그대로 순회하며 스타일만 적용하도록 단순화한다. 레이아웃 XML, 색상 상수, 다크/라이트 분기는 변경하지 않는다.

**Tech Stack:** Kotlin (Android `RemoteViews`), 기존 `TodayMatchInfo` 데이터 모델 재사용.

## Global Constraints

- 이 저장소의 Android 네이티브 코드(`android/app/src/main/kotlin/**`)에는 JUnit/androidTest 설정이 없다 (build.gradle에 `testImplementation` 없음, `kotlinc` 미설치). 새 테스트 프레임워크를 도입하지 않고, 기존 라지 위젯 작업(`docs/superpowers/plans` 참고)과 동일하게 **컴파일 검증 + 수동 위젯 확인**으로 검증한다.
- 스펙 문서: `docs/superpowers/specs/2026-07-28-medium-widget-match-list-design.md` (규칙 원문 및 4가지 예시 케이스 참고).
- 지난 경기 취소선, 브랜드 그라데이션 근사 색(`#E87558`/`#C865C9`), 다크/라이트 기본 텍스트 색 분기는 **변경 금지** — 기존 값 그대로 재사용.
- 실제 카드 최대 개수 = 2, 지난 경기 노출 최대 개수 = 1 (스펙 확정값, 매직 넘버 금지 — named const로 정의).

---

### Task 1: 매치 선택 로직 함수 추가

**Files:**
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt`

**Interfaces:**
- Consumes: 기존 `TodayMatchInfo(val time: String, val status: String, val display: String)` (파일 하단에 이미 정의됨, 변경 없음).
- Produces:
  - `enum class MatchRole { PAST, NEXT, OTHER }`
  - `data class DisplayMatch(val match: TodayMatchInfo, val role: MatchRole)`
  - `data class MatchDisplayResult(val rows: List<DisplayMatch>, val overflowCount: Int)`
  - `fun selectDisplayMatches(matches: List<TodayMatchInfo>): MatchDisplayResult` — Task 2가 이 시그니처를 그대로 호출한다.

- [ ] **Step 1: 파일 상단 상수 영역에 `MAX_REAL_SLOTS` 추가**

`private const val TAG = "ScheduleWidget"` 바로 아래에 추가한다 (`android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt:16` 부근):

```kotlin
private const val TAG = "ScheduleWidget"
private const val MAX_REAL_SLOTS = 2
```

- [ ] **Step 2: 파일 하단(`TodayWidgetData` 정의 아래)에 역할/결과 타입과 선택 함수 추가**

`data class TodayWidgetData(...)` 블록(현재 파일의 `224~228`행 부근) 바로 아래에 다음을 추가한다:

```kotlin
enum class MatchRole { PAST, NEXT, OTHER }

data class DisplayMatch(val match: TodayMatchInfo, val role: MatchRole)

data class MatchDisplayResult(val rows: List<DisplayMatch>, val overflowCount: Int)

fun selectDisplayMatches(matches: List<TodayMatchInfo>): MatchDisplayResult {
    val sorted = matches.sortedBy { it.time }
    val finished = sorted.filter { it.status == "FINISHED" || it.status == "COMPLETED" }
    val upcoming = sorted.filter { it.status != "FINISHED" && it.status != "COMPLETED" }

    // 지난 경기는 가장 최근에 끝난 1개만 노출한다.
    val pastShown = finished.lastOrNull()
    val remainingSlots = MAX_REAL_SLOTS - (if (pastShown != null) 1 else 0)
    val upcomingShown = upcoming.take(remainingSlots)

    val rows = mutableListOf<DisplayMatch>()
    if (pastShown != null) {
        rows.add(DisplayMatch(pastShown, MatchRole.PAST))
    }
    upcomingShown.forEachIndexed { index, m ->
        rows.add(DisplayMatch(m, if (index == 0) MatchRole.NEXT else MatchRole.OTHER))
    }

    val overflow = sorted.size - rows.size
    return MatchDisplayResult(rows, overflow)
}
```

- [ ] **Step 3: 컴파일 검증**

Run: `cd android && ./gradlew :app:compileDebugKotlin`
Expected: `BUILD SUCCESSFUL` (새 타입/함수가 아직 아무 데서도 안 쓰여도 컴파일은 통과해야 한다 — Kotlin은 미사용 top-level 함수를 에러로 취급하지 않는다).

- [ ] **Step 4: 커밋**

```bash
git add android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt
git commit -m "feat: 미디움 위젯 매치 선택 로직(selectDisplayMatches) 추가"
```

---

### Task 2: 렌더링 루프를 새 선택 로직으로 교체

**Files:**
- Modify: `android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt` (`updateWidget()` 내 매치 리스트 렌더링 블록, 현재 `85~138`행 부근)

**Interfaces:**
- Consumes: Task 1의 `selectDisplayMatches()`, `DisplayMatch`, `MatchRole`, `MatchDisplayResult`.
- Produces: 없음 (이 태스크가 최종 렌더링 단계).

- [ ] **Step 1: 기존 매치 리스트 렌더링 블록을 아래 코드로 교체**

`updateWidget()` 안의 다음 블록(주석 `// 왼쪽: 오늘 경기 리스트 채우기`부터 `경기 없음` 처리까지, 현재 파일 `85~138`행)을 통째로 아래로 바꾼다:

```kotlin
            // 왼쪽: 오늘 경기 리스트 채우기
            views.removeAllViews(R.id.matches_container)
            val matches = todayData.matches
            val displayResult = selectDisplayMatches(matches)

            for (displayMatch in displayResult.rows) {
                val m = displayMatch.match
                val row = RemoteViews(context.packageName, R.layout.match_row)
                row.setTextViewText(R.id.match_time, m.time)
                row.setTextViewText(R.id.match_display, m.display)

                when (displayMatch.role) {
                    MatchRole.PAST -> {
                        // 취소선 + 투명도
                        row.setInt(R.id.match_time, "setPaintFlags",
                            Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                        row.setInt(R.id.match_display, "setPaintFlags",
                            Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                        row.setTextColor(R.id.match_time, defaultTextColor)
                        row.setTextColor(R.id.match_display, defaultTextColor)
                        row.setInt(R.id.match_row_root, "setAlpha", 153) // 0.6 * 255
                    }
                    MatchRole.NEXT -> {
                        // 바로 다음 예정(또는 진행중) 경기: 브랜드 그라데이션 근사 색 (다크/라이트 동일)
                        row.setTextColor(R.id.match_time, Color.parseColor("#E87558"))
                        row.setTextColor(R.id.match_display, Color.parseColor("#C865C9"))
                    }
                    MatchRole.OTHER -> {
                        // 기본 텍스트 색
                        row.setTextColor(R.id.match_time, defaultTextColor)
                        row.setTextColor(R.id.match_display, defaultTextColor)
                    }
                }

                views.addView(R.id.matches_container, row)
            }

            if (displayResult.overflowCount > 0) {
                val moreRow = RemoteViews(context.packageName, R.layout.match_row)
                moreRow.setTextViewText(R.id.match_time, "+${displayResult.overflowCount}")
                moreRow.setTextViewText(R.id.match_display, "")
                moreRow.setTextColor(R.id.match_time, defaultTextColor)
                views.addView(R.id.matches_container, moreRow)
            }

            if (matches.isEmpty()) {
                val emptyRow = RemoteViews(context.packageName, R.layout.match_row)
                emptyRow.setTextViewText(R.id.match_time, "")
                emptyRow.setTextViewText(R.id.match_display, "경기 없음")
                emptyRow.setTextColor(R.id.match_display, Color.parseColor("#A6A7AB"))
                views.addView(R.id.matches_container, emptyRow)
            }
```

- [ ] **Step 2: 컴파일 검증**

Run: `cd android && ./gradlew :app:compileDebugKotlin`
Expected: `BUILD SUCCESSFUL`. 실패 시 흔한 원인: 옛 블록의 `maxShow`/`foundNextScheduled` 변수가 다른 곳에서 참조되고 있었는지 확인 (`grep -n "maxShow\|foundNextScheduled" android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt` 결과가 없어야 정상).

- [ ] **Step 3: 디버그 APK 빌드 및 기기/에뮬레이터 설치**

Run: `flutter build apk --debug && flutter install` (또는 `flutter run` 으로 기기에 직접 실행)

- [ ] **Step 4: `loadTodayData()` 호출부를 임시 하드코딩으로 바꿔 스펙 문서의 4가지 케이스를 수동 검증**

이 프로젝트에는 위젯의 `SharedPreferences`를 외부에서 직접 주입하는 디버그 훅이 없으므로, `updateWidget()` 안의 `val todayData = loadTodayData(context)` 한 줄을 케이스별로 아래처럼 임시로 바꿔가며 `Task 2 Step 3` 빌드→설치→홈 화면 위젯 확인을 반복한다. 실제 경기 데이터로 확인하려면 앱을 정상 실행해 데이터를 한 번 채운 뒤 이 줄만 하드코딩으로 덮어써도 된다.

케이스 A — 지난 1 + 예정 2 (총 3개): 지난 경기 1줄(취소선) + 다음 경기 1줄(브랜드색) = 2줄만 보이고 "+1"이 떠야 한다.

```kotlin
// 임시 디버그용 — 케이스 A 확인 후 반드시 제거
val todayData = TodayWidgetData(listOf(
    TodayMatchInfo("10:00", "FINISHED", "T1 VS HLE"),
    TodayMatchInfo("15:00", "unstarted", "T1 VS GEN"),
    TodayMatchInfo("21:00", "unstarted", "T1 VS KT"),
))
```

케이스 B — 지난 0 + 예정 2 (총 2개): 2줄 모두 보이고(15:00 브랜드색 + 21:00 기본색) "+N"이 없어야 한다.

```kotlin
// 임시 디버그용 — 케이스 B 확인 후 반드시 제거
val todayData = TodayWidgetData(listOf(
    TodayMatchInfo("15:00", "unstarted", "T1 VS GEN"),
    TodayMatchInfo("21:00", "unstarted", "T1 VS KT"),
))
```

케이스 C — 지난 2 + 예정 1 (총 3개): `13:00`(가장 최근에 끝난 경기) 1줄(취소선) + `15:00` 1줄(브랜드색), "+1"(10:00 합산)이 떠야 한다. **주의**: `13:00`이 아니라 `10:00`이 보이면 "가장 최근" 로직이 잘못된 것이다.

```kotlin
// 임시 디버그용 — 케이스 C 확인 후 반드시 제거
val todayData = TodayWidgetData(listOf(
    TodayMatchInfo("10:00", "FINISHED", "T1 VS HLE"),
    TodayMatchInfo("13:00", "COMPLETED", "GEN VS KT"),
    TodayMatchInfo("15:00", "unstarted", "T1 VS GEN"),
))
```

케이스 D — 매치 0개: 기존과 동일하게 "경기 없음" 한 줄만 보여야 한다.

```kotlin
// 임시 디버그용 — 케이스 D 확인 후 반드시 제거
val todayData = TodayWidgetData(emptyList())
```

각 케이스 확인이 끝나면 `val todayData = loadTodayData(context)`로 반드시 되돌린다 (임시 코드가 커밋에 남지 않도록 `git diff`로 확인).

- [ ] **Step 5: 다크/라이트 모드 전환 후 육안 확인**

기기 설정에서 다크 모드 ON/OFF 전환 후 각 케이스를 다시 확인한다. 취소선 텍스트 색(다크 흰색/라이트 `#101113`), 브랜드 그라데이션 근사 색(`#E87558`/`#C865C9`, 다크·라이트 동일), 기본 텍스트 색이 스펙 문서의 Figma CSS와 일치하는지 확인.

- [ ] **Step 6: 임시 디버그 코드 제거 확인 후 커밋**

```bash
git diff android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt
```

위 diff에 `Step 4`의 임시 하드코딩 리스트가 남아있지 않은지 확인한 뒤:

```bash
git add android/app/src/main/kotlin/com/warding/app/ScheduleWidgetProvider.kt
git commit -m "feat: 미디움 위젯 렌더링 루프를 선택 로직 결과 기반으로 교체"
```
