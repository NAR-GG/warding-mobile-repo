# 구독 설정 선수 목록 정렬 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 구독 설정 화면의 선수 목록을 포지션순(기본)과 이름순(A–Z) 중 선택해 볼 수 있게 한다.

**Architecture:** `SubscriptionSettingsViewModel`에 `PlayerSortMode` enum과 정렬 상태를 추가하고,
`_subscribedPlayers`/`_availablePlayers`를 항상 현재 모드로 정렬된 상태로 유지한다(로드·검색·
페이지 추가·토글·모드 변경 시점마다 재정렬). View는 공유 정렬 칩 1개를 추가해 모드를 바꾼다.
서버 API·페이로드는 변경하지 않는다.

**Tech Stack:** Flutter, `ChangeNotifier` 기반 MVVM, `flutter_test` + `mocktail`.

## Global Constraints

- 서버 API·쿼리 파라미터 변경 없음. 정렬은 클라이언트에서만 수행한다.
- "이름순"은 `playerName`(로마자) 오름차순이다. `real_name`(한글 본명) 기준 정렬은 하지 않는다.
- 포지션순 규칙(서버 `PlayerRoleOrder`와 동일): `TOP → JUNGLE → MID → ADC → SUPPORT`, 이후
  이름 오름차순. 알 수 없는/빈 `role`은 맨 뒤.
- `role` 비교는 대소문자 무시(`toUpperCase()` 후 비교).
- `playerName` 비교는 대소문자 무시(`toLowerCase()` 후 비교).
- `_pageSize`는 100 → 200으로 올린다 (백엔드 PR #367 `available-players` size 상한 100→300 배포
  확인됨 — 사용자 확인 완료, 2026-08-12).
- 팀별 그룹핑, 서버 `sort` 파라미터 추가, 본명 기준 정렬은 범위 밖.

---

## File Structure

- **Modify** `lib/viewmodel/subscription/subscription_settings_viewmodel.dart`
  - `PlayerSortMode` enum 추가 (`position`(기본), `name`).
  - `_pageSize` 100 → 200.
  - 정렬 상태(`_sortMode`)와 `setSortMode()` 추가.
  - `_ROLE_ORDER` 맵 + `_comparePlayers()` comparator 추가.
  - `load()`, `searchPlayers()`, `loadMorePlayers()`, `_applyPlayerToggle()`에서 리스트를
    항상 현재 모드로 정렬된 채로 유지.
- **Modify** `lib/screens/subscription/subscription_settings_screen.dart`
  - 검색창 아래, 섹션들 위에 공유 정렬 칩 1개(포지션순/이름순 토글 2개) 추가.
  - `NarChip`(토글 variant, `player_select_sheet.dart` 사용례 참고) 재사용.
- **Modify** `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`
  - `playerSortByPosition`("포지션순"/"Position"), `playerSortByName`("이름순"/"Name (A–Z)") 추가.
- **Modify** `test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
  - 기존 `size=100` 하드코딩 테스트를 200으로 갱신.
  - 정렬 관련 신규 테스트 추가 (아래 Task 2, 3).

---

## Task 1: `_pageSize` 200으로 올리고 기존 테스트 갱신

**Files:**
- Modify: `lib/viewmodel/subscription/subscription_settings_viewmodel.dart:24`
- Modify: `test/viewmodel/subscription/subscription_settings_viewmodel_test.dart:62-80`

**Interfaces:**
- Consumes: 없음 (기존 코드).
- Produces: `SubscriptionSettingsViewModel._pageSize == 200` — 이후 태스크의 `load()` 관련
  테스트들이 이 값을 전제로 한다.

- [ ] **Step 1: 기존 size=100 테스트를 200 기준으로 고쳐서 실행 → 실패 확인**

`test/viewmodel/subscription/subscription_settings_viewmodel_test.dart:62-80`의 테스트를 아래로
교체한다.

```dart
  test('load(): 전체 로스터를 한 번에 받도록 size=200 으로 요청한다', () async {
    when(() => repo.searchAvailablePlayers(query: '', page: 0, size: 200))
        .thenAnswer(
      (_) async => _page(
        content: [for (var i = 0; i < 102; i++) _player(i)],
        page: 0,
        totalPages: 1,
        totalElements: 102,
      ),
    );

    final vm = SubscriptionSettingsViewModel(repository: repo);
    await vm.load();

    expect(vm.availablePlayers, hasLength(102));
    expect(vm.hasMorePlayers, isFalse);
    verify(() => repo.searchAvailablePlayers(query: '', page: 0, size: 200))
        .called(greaterThanOrEqualTo(1));
  });
```

Run: `flutter test test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
Expected: FAIL — `_pageSize`가 아직 100이라 `repo.searchAvailablePlayers(..., size: 200)`가
호출되지 않음 (mocktail이 등록되지 않은 인자 조합에 대해 예외를 던짐).

- [ ] **Step 2: `_pageSize`를 200으로 변경**

`lib/viewmodel/subscription/subscription_settings_viewmodel.dart:22-24`:

```dart
  /// 한 페이지에 받을 선수 수. 백엔드 상한(300, PR #367)에 맞춰 구독 가능 선수 전원(약
  /// 102명)을 한 번에 받는다. 로스터가 커지면 [loadMorePlayers] 무한 스크롤로 이어 받는다.
  static const int _pageSize = 200;
```

- [ ] **Step 3: 테스트 재실행 → 통과 확인**

Run: `flutter test test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
Expected: PASS (전체 테스트 파일, 이 시점엔 다른 테스트들도 기존 그대로 통과해야 함)

- [ ] **Step 4: Commit**

```bash
git add lib/viewmodel/subscription/subscription_settings_viewmodel.dart \
  test/viewmodel/subscription/subscription_settings_viewmodel_test.dart
git commit -m "fix: 선수 구독 페이지 크기를 200으로 올림 (PR #367 배포 확인됨)"
```

---

## Task 2: `PlayerSortMode` + comparator + `setSortMode()` 추가

**Files:**
- Modify: `lib/viewmodel/subscription/subscription_settings_viewmodel.dart`
- Test: `test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`

**Interfaces:**
- Consumes: `PlayerSubscription.role`, `PlayerSubscription.playerName` (기존 모델, 변경 없음).
- Produces:
  - `enum PlayerSortMode { position, name }` (파일 최상단, 클래스 밖에 정의).
  - `SubscriptionSettingsViewModel.sortMode` → `PlayerSortMode` getter, 기본값 `position`.
  - `SubscriptionSettingsViewModel.setSortMode(PlayerSortMode mode)` → 즉시 재정렬 +
    `notifyListeners()`. 서버 재조회 없음.
  - Task 3(`_applyPlayerToggle`)이 이 태스크의 `_comparePlayers`를 재사용한다.

- [ ] **Step 1: 실패하는 테스트 작성 — 기본 정렬(포지션순)과 미상 role 처리**

`test/viewmodel/subscription/subscription_settings_viewmodel_test.dart` 상단의 `_player` 헬퍼를
`role`을 받도록 바꾸고(기본값 `'MID'`로 기존 테스트 호환 유지), 파일 끝에 새 테스트 그룹을
추가한다.

```dart
PlayerSubscription _player(int id, {String? name, String role = 'MID'}) =>
    PlayerSubscription(
      playerId: id,
      playerName: name ?? 'P$id',
      playerImageUrl: '',
      role: role,
      teamId: 1,
      teamCode: 'T1',
      teamName: 'Team1',
      teamImageUrl: '',
      subscribed: false,
    );
```

```dart
  group('선수 정렬', () {
    test('기본 정렬 모드는 position 이다', () {
      final vm = SubscriptionSettingsViewModel(repository: repo);
      expect(vm.sortMode, PlayerSortMode.position);
    });

    test('포지션순: TOP→JUNGLE→MID→ADC→SUPPORT, 동일 포지션은 이름 오름차순', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'Zeus', role: 'top'), // 대소문자 무시
            _player(2, name: 'Faker', role: 'MID'),
            _player(3, name: 'Gumayusi', role: 'ADC'),
            _player(4, name: 'Oner', role: 'Jungle'),
            _player(5, name: 'Keria', role: 'SUPPORT'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async => _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();

      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Zeus', 'Oner', 'Faker', 'Gumayusi', 'Keria']);
    });

    test('포지션순: role 이 비어있으면 맨 뒤로 밀린다', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'Faker', role: 'MID'),
            _player(2, name: 'Unranked', role: ''),
            _player(3, name: 'Zeus', role: 'TOP'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async => _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();

      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Zeus', 'Faker', 'Unranked']);
    });

    test('setSortMode(name): 이름 오름차순(대소문자 무시)으로 바뀌고 알린다', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'zeus', role: 'TOP'),
            _player(2, name: 'Faker', role: 'MID'),
            _player(3, name: 'Gumayusi', role: 'ADC'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async => _page(content: const [], page: 0, totalPages: 1, totalElements: 0),
      );

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();

      var notified = false;
      vm.addListener(() => notified = true);
      vm.setSortMode(PlayerSortMode.name);

      expect(notified, isTrue);
      expect(vm.sortMode, PlayerSortMode.name);
      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Faker', 'Gumayusi', 'zeus']);
    });
  });
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
Expected: FAIL — `PlayerSortMode`, `vm.sortMode`, `vm.setSortMode` 미정의 컴파일 에러.

- [ ] **Step 3: 구현 — enum, comparator, setSortMode, 정렬 유지**

`lib/viewmodel/subscription/subscription_settings_viewmodel.dart` 클래스 선언 위에 enum 추가:

```dart
/// 구독 설정 화면 선수 목록 정렬 모드.
enum PlayerSortMode {
  /// 포지션(탑→정글→미드→원딜→서포터) 후 이름순. 서버 기본 정렬과 동일.
  position,

  /// 이름(playerName, 로마자) 오름차순.
  name,
}
```

클래스 내부, `_pageSize` 아래에 comparator·정렬 상태 추가:

```dart
  static const Map<String, int> _roleOrder = {
    'TOP': 0,
    'JUNGLE': 1,
    'MID': 2,
    'ADC': 3,
    'SUPPORT': 4,
  };

  PlayerSortMode _sortMode = PlayerSortMode.position;
  PlayerSortMode get sortMode => _sortMode;

  /// 정렬 모드를 바꾸고 즉시 재정렬한다. 서버 재조회는 하지 않는다.
  void setSortMode(PlayerSortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _subscribedPlayers = _sortPlayers(_subscribedPlayers);
    _availablePlayers = _sortPlayers(_availablePlayers);
    _notify();
  }

  List<PlayerSubscription> _sortPlayers(List<PlayerSubscription> list) =>
      [...list]..sort(_comparePlayers);

  int _comparePlayers(PlayerSubscription a, PlayerSubscription b) {
    if (_sortMode == PlayerSortMode.name) {
      return a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
    }
    final orderA = _roleOrder[a.role.toUpperCase()] ?? _roleOrder.length;
    final orderB = _roleOrder[b.role.toUpperCase()] ?? _roleOrder.length;
    if (orderA != orderB) return orderA.compareTo(orderB);
    return a.playerName.toLowerCase().compareTo(b.playerName.toLowerCase());
  }
```

`load()`에서 두 콜백을 정렬 적용하도록 수정 (`subscribed`/`available` 내부):

```dart
    final subscribed = _repo.fetchSubscribedPlayers().then((v) {
      _subscribedPlayers = _sortPlayers(v);
      _notify();
    });
    ...
    final available = _repo
        .searchAvailablePlayers(query: _query, page: 0, size: _pageSize)
        .then((v) {
      _availablePlayers = _sortPlayers(v.content);
      _availPage = v.page;
      _availTotalPages = v.totalPages;
      _availTotalElements = v.totalElements;
      _loadingAvailablePlayers = false;
      _notify();
    });
```

`searchPlayers()`에서도 `_availablePlayers = _sortPlayers(v.content);`로 교체.

`loadMorePlayers()`에서:

```dart
      _availablePlayers = _sortPlayers([..._availablePlayers, ...v.content]);
```

- [ ] **Step 4: 테스트 재실행 → 통과 확인**

Run: `flutter test test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/viewmodel/subscription/subscription_settings_viewmodel.dart \
  test/viewmodel/subscription/subscription_settings_viewmodel_test.dart
git commit -m "feat: 구독 선수 목록에 포지션순/이름순 정렬 모드 추가"
```

---

## Task 3: 구독 토글 직후 정렬 깨짐 버그 수정 (`_applyPlayerToggle`)

**Files:**
- Modify: `lib/viewmodel/subscription/subscription_settings_viewmodel.dart:185-201`
- Test: `test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`

**Interfaces:**
- Consumes: Task 2의 `_sortPlayers()`, `_comparePlayers()`.
- Produces: `togglePlayer()` 호출 후에도 `subscribedPlayers`가 항상 현재 `sortMode` 기준
  정렬된 상태를 유지함 (다른 태스크가 이 동작에 의존하지 않음 — 최종 태스크).

- [ ] **Step 1: 실패하는 테스트 작성 — 구독 추가 시 정렬 유지**

`subscription_repository.dart`의 `subscribePlayer`/`unsubscribePlayer` 시그니처를 확인해 mock을
등록한다 (기존 리포지토리 인터페이스 그대로 사용). 새 테스트:

```dart
    test('togglePlayer(): 구독 추가 후에도 정렬된 위치에 들어간다', () async {
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => [
            _player(1, name: 'Faker', role: 'MID'),
            _player(2, name: 'Zeus', role: 'TOP'),
          ]);
      when(() => repo.searchAvailablePlayers(
          query: '', page: 0, size: any(named: 'size'))).thenAnswer(
        (_) async => _page(
          content: [
            _player(1, name: 'Faker', role: 'MID').copyWith(subscribed: true),
            _player(2, name: 'Zeus', role: 'TOP').copyWith(subscribed: true),
            _player(3, name: 'Oner', role: 'JUNGLE'),
          ],
          page: 0,
          totalPages: 1,
          totalElements: 3,
        ),
      );
      when(() => repo.subscribePlayer(3)).thenAnswer((_) async {});

      final vm = SubscriptionSettingsViewModel(repository: repo);
      await vm.load();
      await vm.togglePlayer(3, false);

      // 포지션순: Zeus(TOP) → Oner(JUNGLE) → Faker(MID). 맨 끝에 그냥 붙지 않아야 한다.
      expect(vm.subscribedPlayers.map((p) => p.playerName),
          ['Zeus', 'Oner', 'Faker']);
    });
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
Expected: FAIL — 현재 구현은 `_subscribedPlayers = [..._subscribedPlayers, added];`로 끝에
붙이므로 `['Faker', 'Zeus', 'Oner']` 같은(정렬 안 된) 순서가 나옴.

- [ ] **Step 3: 구현 — append를 정렬 유지로 교체**

`lib/viewmodel/subscription/subscription_settings_viewmodel.dart:185-201`의
`_applyPlayerToggle`을 교체:

```dart
  /// 선수 토글 결과를 구독중 목록·전체 목록 양쪽에 반영한다.
  ///
  /// 두 목록 모두 항상 현재 [sortMode] 기준으로 정렬된 상태를 유지한다 — 여기서 끝에
  /// 그냥 append 하면 방금 구독한 선수만 정렬 순서 밖으로 밀려난다.
  void _applyPlayerToggle(int playerId, bool nowSubscribed) {
    _availablePlayers = [
      for (final p in _availablePlayers)
        p.playerId == playerId ? p.copyWith(subscribed: nowSubscribed) : p,
    ];
    if (nowSubscribed) {
      if (!_subscribedPlayers.any((p) => p.playerId == playerId)) {
        final added = _availablePlayers
            .firstWhere((p) => p.playerId == playerId)
            .copyWith(subscribed: true);
        _subscribedPlayers = _sortPlayers([..._subscribedPlayers, added]);
      }
    } else {
      _subscribedPlayers =
          _subscribedPlayers.where((p) => p.playerId != playerId).toList();
    }
  }
```

(`_availablePlayers`의 `copyWith` 매핑은 순서를 바꾸지 않으므로 재정렬이 필요 없다 — 이미
정렬된 리스트에서 값만 바뀌기 때문.)

- [ ] **Step 4: 테스트 재실행 → 전체 통과 확인**

Run: `flutter test test/viewmodel/subscription/subscription_settings_viewmodel_test.dart`
Expected: PASS (전체 파일)

- [ ] **Step 5: Commit**

```bash
git add lib/viewmodel/subscription/subscription_settings_viewmodel.dart \
  test/viewmodel/subscription/subscription_settings_viewmodel_test.dart
git commit -m "fix: 선수 구독 토글 직후 정렬이 깨지던 문제 수정"
```

---

## Task 4: l10n 라벨 추가

**Files:**
- Modify: `lib/l10n/app_ko.arb`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: 없음.
- Produces: `AppLocalizations.playerSortByPosition`, `AppLocalizations.playerSortByName` —
  Task 5(화면)에서 칩 라벨로 사용.

- [ ] **Step 1: `app_ko.arb`에 라벨 추가**

`lib/l10n/app_ko.arb`의 `"playerSelect"`/`"subscribedPlayerList"` 옆(190-191번 줄 부근)에 추가:

```json
  "playerSortByPosition": "포지션순",
  "playerSortByName": "이름순",
```

- [ ] **Step 2: `app_en.arb`에 대응 라벨 추가**

`lib/l10n/app_en.arb`의 동일 위치(`playerSelect`/`subscribedPlayerList` 근처)에 추가:

```json
  "playerSortByPosition": "Position",
  "playerSortByName": "Name (A–Z)",
```

- [ ] **Step 3: l10n 재생성**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart`, `app_localizations_ko.dart`,
`app_localizations_en.dart`에 `playerSortByPosition`/`playerSortByName` getter가 생성됨. (별도
커밋 불필요 — `flutter pub get`/build 시 `generate: true`로 자동 재생성되지만, 이 리포는 생성물을
git에 커밋하는 관례이므로 결과를 함께 커밋한다.)

- [ ] **Step 4: 생성 확인**

Run: `grep -n "playerSortByPosition" lib/l10n/app_localizations_ko.dart lib/l10n/app_localizations_en.dart`
Expected: 두 파일 모두에서 getter 정의가 보여야 함.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_ko.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart \
  lib/l10n/app_localizations_ko.dart lib/l10n/app_localizations_en.dart
git commit -m "feat: 선수 정렬 칩 라벨(포지션순/이름순) 추가"
```

---

## Task 5: 화면에 공유 정렬 칩 추가

**Files:**
- Modify: `lib/screens/subscription/subscription_settings_screen.dart`

**Interfaces:**
- Consumes: `_viewModel.sortMode` (`PlayerSortMode`), `_viewModel.setSortMode(PlayerSortMode)`
  (Task 2), `l.playerSortByPosition`/`l.playerSortByName` (Task 4), `NarChip` 기본 토글 생성자
  (`lib/components/nar_chip.dart:27` — `label`, `selected`, `onTap`, `scale`).
- Produces: 화면상 정렬 칩 UI. 이후 태스크 없음(최종 태스크).

- [ ] **Step 1: import 추가**

`lib/screens/subscription/subscription_settings_screen.dart` 상단에 추가:

```dart
import '../../components/nar_chip.dart';
```

- [ ] **Step 2: 정렬 칩 행을 검색창 아래, 섹션들 위에 삽입**

`build()` 메서드의 `ListView` children에서, `SizedBox(height: 7 * scale)` 다음(현재 172번 줄
직후, `if (hasQuery)` 분기 이전)에 삽입:

```dart
                    SizedBox(height: 7 * scale),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: Row(
                        children: [
                          NarChip(
                            label: l.playerSortByPosition,
                            selected:
                                _viewModel.sortMode == PlayerSortMode.position,
                            onTap: () =>
                                _viewModel.setSortMode(PlayerSortMode.position),
                            scale: scale,
                          ),
                          SizedBox(width: 8 * scale),
                          NarChip(
                            label: l.playerSortByName,
                            selected: _viewModel.sortMode == PlayerSortMode.name,
                            onTap: () =>
                                _viewModel.setSortMode(PlayerSortMode.name),
                            scale: scale,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    // 검색 중이면 결과(전체 목록) 섹션을 검색창 바로 아래에 둔다.
                    if (hasQuery) ...[
```

(기존 `if (hasQuery) ...[` 줄은 그대로 두고 그 앞에 칩 블록만 추가한다. 선수 목록이 '구독중인
선수' 섹션과 '전체 목록 선수' 탭 두 군데에 있지만 정렬 모드는 뷰모델 하나를 공유하므로 칩도
화면에 하나만 둔다.)

- [ ] **Step 3: 정적 분석**

Run: `flutter analyze lib/screens/subscription/subscription_settings_screen.dart lib/viewmodel/subscription/subscription_settings_viewmodel.dart`
Expected: No issues found.

- [ ] **Step 4: 수동 확인**

Run: `flutter run` 로 앱을 실행해 마이 구독 → ⚙️ 구독 설정 화면 진입 후:
- 정렬 칩 2개가 검색창 아래에 보이고 기본은 '포지션순'이 선택 상태인지 확인.
- '이름순' 탭 시 '구독중인 선수' 섹션과 '전체 목록 › 선수' 탭 둘 다 A–Z로 바뀌는지 확인.
- 검색어를 입력한 뒤에도 선택한 정렬 모드가 유지되는지 확인.
- 선수를 구독/해제한 직후에도 정렬 순서가 유지되는지 확인.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/subscription/subscription_settings_screen.dart
git commit -m "feat: 구독 설정 화면에 선수 정렬 칩(포지션순/이름순) 추가"
```
