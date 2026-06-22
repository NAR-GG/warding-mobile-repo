# 비회원 온보딩 로컬 저장 + 로그인 동기화 (#11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 비회원이 온보딩에서 고른 리그·팀·선수를 로컬에 저장하고, 나중에 로그인하면 1회 서버로 동기화한다.

**Architecture:** 동기화 페이로드 전용 신규 repository(`OnboardingPreferenceRepository`)와 모델(`OnboardingSelection`)을 추가한다. 온보딩 ViewModel은 비회원일 때 selection을 저장한다. 신규 `OnboardingSyncService`가 로그인 직후 로컬 selection을 서버에 전송하고 최종 onboarded 여부를 반환하면, 로그인 화면이 그에 따라 분기한다.

**Tech Stack:** Flutter, `flutter_secure_storage`, `http`, 테스트는 `flutter_test` + `mocktail`.

## Global Constraints

- 색은 하드코딩 금지(이 작업엔 UI 색 변경 없음).
- 파일명 `snake_case`, 클래스명 `PascalCase`.
- ViewModel은 `BuildContext`에 의존하지 않는다. 화면 전환은 View에서만 처리한다.
- 기존 백엔드 계약 `POST /api/auth/onboarding`을 그대로 사용한다(백엔드 변경 없음).
- 테스트는 기존 패턴(mocktail `Mock` 서브클래스, `test/` 미러 구조)을 따른다.

---

### Task 1: OnboardingSelection 모델

**Files:**
- Create: `lib/model/onboarding_selection.dart`
- Test: `test/model/onboarding_selection_test.dart`

**Interfaces:**
- Produces: `class OnboardingSelection { const OnboardingSelection({String? leagueName, required int teamId, List<int> playerIds}); final String? leagueName; final int teamId; final List<int> playerIds; Map<String,dynamic> toJson(); factory OnboardingSelection.fromJson(Map<String,dynamic>); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/model/onboarding_selection_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/onboarding_selection.dart';

void main() {
  test('toJson/fromJson 라운드트립', () {
    const sel = OnboardingSelection(
      leagueName: 'LCK',
      teamId: 1,
      playerIds: [10, 20],
    );
    final restored = OnboardingSelection.fromJson(
      jsonDecode(jsonEncode(sel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.leagueName, 'LCK');
    expect(restored.teamId, 1);
    expect(restored.playerIds, [10, 20]);
  });

  test('leagueName 없이도(기본 playerIds) 복원된다', () {
    const sel = OnboardingSelection(teamId: 2);
    final restored = OnboardingSelection.fromJson(
      jsonDecode(jsonEncode(sel.toJson())) as Map<String, dynamic>,
    );
    expect(restored.leagueName, isNull);
    expect(restored.teamId, 2);
    expect(restored.playerIds, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/model/onboarding_selection_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:warding/model/onboarding_selection.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/model/onboarding_selection.dart
/// 비회원 온보딩 선택값(리그·팀·선수). 로그인 시 `POST /api/auth/onboarding`
/// 으로 1회 동기화하기 위한 로컬 저장 페이로드다.
class OnboardingSelection {
  const OnboardingSelection({
    this.leagueName,
    required this.teamId,
    this.playerIds = const [],
  });

  /// 선호 리그 이름. 예: 'LCK'. 선택 안 했으면 null.
  final String? leagueName;

  /// 선호 팀 ID.
  final int teamId;

  /// 선호 선수 ID 목록.
  final List<int> playerIds;

  Map<String, dynamic> toJson() => {
        'leagueName': leagueName,
        'teamId': teamId,
        'playerIds': playerIds,
      };

  factory OnboardingSelection.fromJson(Map<String, dynamic> json) {
    return OnboardingSelection(
      leagueName: json['leagueName'] as String?,
      teamId: json['teamId'] as int,
      playerIds: ((json['playerIds'] as List<dynamic>?) ?? const [])
          .map((e) => e as int)
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/model/onboarding_selection_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/model/onboarding_selection.dart test/model/onboarding_selection_test.dart
git commit -m "feat(onboarding): OnboardingSelection 모델 추가 (#11)"
```

---

### Task 2: OnboardingPreferenceRepository

**Files:**
- Create: `lib/repository/preference/onboarding_preference_repository.dart`
- Test: `test/repository/preference/onboarding_preference_repository_test.dart`

**Interfaces:**
- Consumes: `OnboardingSelection` (Task 1)
- Produces: `class OnboardingPreferenceRepository { OnboardingPreferenceRepository({FlutterSecureStorage? storage}); static final OnboardingPreferenceRepository instance; Future<void> saveSelection(OnboardingSelection); Future<OnboardingSelection?> loadSelection(); Future<void> clear(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/repository/preference/onboarding_preference_repository_test.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/onboarding_selection.dart';
import 'package:warding/repository/preference/onboarding_preference_repository.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late OnboardingPreferenceRepository repo;

  setUp(() {
    storage = MockSecureStorage();
    repo = OnboardingPreferenceRepository(storage: storage);
  });

  test('saveSelection: onboarding_selection 키로 JSON을 write 한다', () async {
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});

    await repo.saveSelection(
      const OnboardingSelection(leagueName: 'LCK', teamId: 1, playerIds: [10]),
    );

    final value = verify(() => storage.write(
          key: 'onboarding_selection',
          value: captureAny(named: 'value'),
        )).captured.single as String;
    final json = jsonDecode(value) as Map<String, dynamic>;
    expect(json['teamId'], 1);
    expect(json['leagueName'], 'LCK');
    expect(json['playerIds'], [10]);
  });

  test('loadSelection: 저장값을 복원한다', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode(
        const OnboardingSelection(teamId: 3, playerIds: [7]).toJson(),
      ),
    );

    final sel = await repo.loadSelection();
    expect(sel, isNotNull);
    expect(sel!.teamId, 3);
    expect(sel.playerIds, [7]);
  });

  test('loadSelection: 값이 없으면 null', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    expect(await repo.loadSelection(), isNull);
  });

  test('loadSelection: 손상된 값이면 null', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'not-json');
    expect(await repo.loadSelection(), isNull);
  });

  test('clear: onboarding_selection 키를 delete 한다', () async {
    when(() => storage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    await repo.clear();
    verify(() => storage.delete(key: 'onboarding_selection')).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repository/preference/onboarding_preference_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../onboarding_preference_repository.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/repository/preference/onboarding_preference_repository.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../model/onboarding_selection.dart';

/// 비회원 온보딩 선택값을 기기에 로컬 저장한다.
///
/// 로그인 시 [OnboardingSyncService] 가 읽어 서버로 1회 동기화한 뒤 지운다.
/// 헤더가 읽는 전체 팀 캐시([TeamPreferenceRepository])와 책임을 분리한다.
/// 민감 정보는 아니지만 이미 설치된 [FlutterSecureStorage] 를 재사용한다.
class OnboardingPreferenceRepository {
  OnboardingPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final OnboardingPreferenceRepository instance =
      OnboardingPreferenceRepository();

  static const _key = 'onboarding_selection';

  final FlutterSecureStorage _storage;

  /// 온보딩 선택값을 저장한다.
  Future<void> saveSelection(OnboardingSelection selection) async {
    await _storage.write(key: _key, value: jsonEncode(selection.toJson()));
  }

  /// 저장된 선택값을 읽는다. 없거나 손상됐으면 null.
  Future<OnboardingSelection?> loadSelection() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OnboardingSelection.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[OnboardingPreference] 저장값 파싱 실패: $e');
      return null;
    }
  }

  /// 저장된 선택값을 지운다 (동기화 완료·온보딩 건너뛰기 시).
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repository/preference/onboarding_preference_repository_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/repository/preference/onboarding_preference_repository.dart test/repository/preference/onboarding_preference_repository_test.dart
git commit -m "feat(onboarding): OnboardingPreferenceRepository 추가 (#11)"
```

---

### Task 3: OnboardingViewModel — 비회원 selection 저장

**Files:**
- Modify: `lib/viewmodel/onboarding/onboarding_viewmodel.dart` (생성자, `_savePreferences`, `skip`)
- Test: `test/viewmodel/onboarding/onboarding_viewmodel_test.dart` (Create)

**Interfaces:**
- Consumes: `OnboardingSelection` (Task 1), `OnboardingPreferenceRepository` (Task 2)
- Produces: `OnboardingViewModel` 생성자에 `OnboardingPreferenceRepository? onboardingPreferences` 추가.

- [ ] **Step 1: Write the failing test**

```dart
// test/viewmodel/onboarding/onboarding_viewmodel_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/onboarding_selection.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/onboarding/onboarding_repository.dart';
import 'package:warding/repository/preference/onboarding_preference_repository.dart';
import 'package:warding/repository/preference/team_preference_repository.dart';
import 'package:warding/viewmodel/onboarding/onboarding_viewmodel.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockTeamPreferenceRepository extends Mock
    implements TeamPreferenceRepository {}

class MockOnboardingPreferenceRepository extends Mock
    implements OnboardingPreferenceRepository {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockOnboardingRepository repo;
  late MockTeamPreferenceRepository teamPrefs;
  late MockOnboardingPreferenceRepository onboardingPrefs;
  late MockAuthService auth;

  setUpAll(() {
    registerFallbackValue(const OnboardingSelection(teamId: 0));
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    repo = MockOnboardingRepository();
    teamPrefs = MockTeamPreferenceRepository();
    onboardingPrefs = MockOnboardingPreferenceRepository();
    auth = MockAuthService();

    when(() => repo.fetchLeagues()).thenAnswer((_) async => const []);
    when(() => repo.fetchTeams()).thenAnswer((_) async => const []);
    when(() => repo.fetchPlayers(
          year: any(named: 'year'),
          teamId: any(named: 'teamId'),
        )).thenAnswer((_) async => const []);
    when(() => teamPrefs.savePreferredTeam(any())).thenAnswer((_) async {});
    when(() => teamPrefs.clearPreferredTeam()).thenAnswer((_) async {});
    when(() => onboardingPrefs.saveSelection(any())).thenAnswer((_) async {});
    when(() => onboardingPrefs.clear()).thenAnswer((_) async {});
  });

  OnboardingViewModel build() => OnboardingViewModel(
        repository: repo,
        onFinish: () {},
        teamPreferences: teamPrefs,
        onboardingPreferences: onboardingPrefs,
        authService: auth,
      );

  // 온보딩 마지막 단계까지 진행시켜 _savePreferences 가 실행되게 한다.
  Future<void> completeFlow(OnboardingViewModel vm) async {
    vm.selectLeague('LCK');
    await vm.goNext(); // league -> team
    vm.selectTeam(1);
    await vm.goNext(); // team -> player (loadPlayers)
    vm.togglePlayer(5);
    await vm.goNext(); // player -> notification
    vm.markNotificationDone();
    await vm.goNext(); // notification -> finish (_savePreferences)
  }

  test('비회원이면 selection을 로컬 저장한다', () async {
    when(() => auth.jwt).thenAnswer((_) async => null);

    final vm = build();
    await completeFlow(vm);

    final sel = verify(() => onboardingPrefs.saveSelection(captureAny()))
        .captured
        .single as OnboardingSelection;
    expect(sel.leagueName, 'LCK');
    expect(sel.teamId, 1);
    expect(sel.playerIds, [5]);
    verifyNever(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        ));
  });

  test('회원이면 서버 저장하고 로컬 selection을 지운다', () async {
    when(() => auth.jwt).thenAnswer((_) async => 'jwt-token');
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenAnswer((_) async {});

    final vm = build();
    await completeFlow(vm);

    verify(() => repo.completeOnboarding(
          favoriteLeagueName: 'LCK',
          favoriteTeamId: 1,
          favoritePlayerIds: [5],
          jwt: 'jwt-token',
        )).called(1);
    verify(() => onboardingPrefs.clear()).called(1);
    verifyNever(() => onboardingPrefs.saveSelection(any()));
  });

  test('skip()은 로컬 selection을 지운다', () async {
    final vm = build();
    await vm.skip();
    verify(() => onboardingPrefs.clear()).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/viewmodel/onboarding/onboarding_viewmodel_test.dart`
Expected: FAIL — `OnboardingViewModel` 생성자에 `onboardingPreferences` 명명 인자가 없어 컴파일 에러.

- [ ] **Step 3: Write minimal implementation**

`lib/viewmodel/onboarding/onboarding_viewmodel.dart` 상단 import에 추가:

```dart
import '../../model/onboarding_selection.dart';
import '../../repository/preference/onboarding_preference_repository.dart';
```

생성자를 다음으로 교체:

```dart
  OnboardingViewModel({
    required OnboardingRepository repository,
    required VoidCallback onFinish,
    TeamPreferenceRepository? teamPreferences,
    OnboardingPreferenceRepository? onboardingPreferences,
    AuthService? authService,
  })  : _repository = repository,
        _onFinish = onFinish,
        _teamPreferences =
            teamPreferences ?? TeamPreferenceRepository.instance,
        _onboardingPreferences =
            onboardingPreferences ?? OnboardingPreferenceRepository.instance,
        _authService = authService ?? AuthService.instance {
    loadLeagues();
    loadTeams();
  }

  final OnboardingRepository _repository;
  final VoidCallback _onFinish;
  final TeamPreferenceRepository _teamPreferences;
  final OnboardingPreferenceRepository _onboardingPreferences;
  final AuthService _authService;
```

`skip()` 을 다음으로 교체:

```dart
  /// 온보딩 건너뛰기. 선호 팀·온보딩 selection 로컬 저장값을 지운 뒤 완료한다.
  Future<void> skip() async {
    await _teamPreferences.clearPreferredTeam();
    await _onboardingPreferences.clear();
    _onFinish();
  }
```

`_savePreferences()` 를 다음으로 교체:

```dart
  /// 선택한 선호 리그·팀·선수를 저장하고 온보딩을 마무리한다.
  ///
  /// 회원(JWT 보유)은 서버에 저장하고(`POST /api/auth/onboarding`) 로컬
  /// selection 을 지운다. 비회원은 selection 을 로컬에 저장해 두었다가 로그인
  /// 시 동기화한다. 회원·비회원 모두 선호 팀은 로컬에 캐싱해 헤더가 읽게 한다.
  Future<void> _savePreferences() async {
    final teamId = _selectedTeamId;
    if (teamId == null) return;

    final team = selectedTeam;

    final jwt = await _authService.jwt;
    if (jwt != null) {
      try {
        await _repository.completeOnboarding(
          favoriteLeagueName: _selectedLeagueName,
          favoriteTeamId: teamId,
          favoritePlayerIds: _selectedPlayerIds.toList(),
          jwt: jwt,
        );
      } catch (e) {
        debugPrint('[Onboarding] 서버 온보딩 저장 실패: $e');
      }
      // 혹시 비회원 시절 남아 있던 로컬 selection 제거.
      await _onboardingPreferences.clear();
    } else {
      // 비회원: 로그인 시 동기화할 selection 을 로컬에 저장.
      await _onboardingPreferences.saveSelection(
        OnboardingSelection(
          leagueName: _selectedLeagueName,
          teamId: teamId,
          playerIds: _selectedPlayerIds.toList(),
        ),
      );
    }

    // 회원·비회원 모두 로컬에 팀 캐싱 (헤더가 로컬에서 읽음).
    if (team != null) {
      await _teamPreferences.savePreferredTeam(team);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/viewmodel/onboarding/onboarding_viewmodel_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/viewmodel/onboarding/onboarding_viewmodel.dart test/viewmodel/onboarding/onboarding_viewmodel_test.dart
git commit -m "feat(onboarding): 비회원 온보딩 selection 로컬 저장 (#11)"
```

---

### Task 4: OnboardingSyncService — 로그인 동기화

**Files:**
- Create: `lib/repository/onboarding/onboarding_sync_service.dart`
- Test: `test/repository/onboarding/onboarding_sync_service_test.dart`

**Interfaces:**
- Consumes: `AuthResult` (`lib/repository/auth/auth_service.dart` — `AuthResult({required String jwt, required bool isOnboarded})`), `OnboardingRepository.completeOnboarding`, `OnboardingPreferenceRepository` (Task 2)
- Produces: `class OnboardingSyncService { OnboardingSyncService({OnboardingRepository?, OnboardingPreferenceRepository?}); static final OnboardingSyncService instance; Future<bool> syncOnLogin(AuthResult); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/repository/onboarding/onboarding_sync_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/onboarding_selection.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/onboarding/onboarding_repository.dart';
import 'package:warding/repository/onboarding/onboarding_sync_service.dart';
import 'package:warding/repository/preference/onboarding_preference_repository.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockOnboardingPreferenceRepository extends Mock
    implements OnboardingPreferenceRepository {}

void main() {
  late MockOnboardingRepository repo;
  late MockOnboardingPreferenceRepository prefs;
  late OnboardingSyncService service;

  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    repo = MockOnboardingRepository();
    prefs = MockOnboardingPreferenceRepository();
    service = OnboardingSyncService(repository: repo, preferences: prefs);
    when(() => prefs.clear()).thenAnswer((_) async {});
  });

  void stubComplete() {
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenAnswer((_) async {});
  }

  test('서버가 onboarded면 로컬을 지우고 true', () async {
    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'j', isOnboarded: true),
    );
    expect(result, isTrue);
    verify(() => prefs.clear()).called(1);
    verifyNever(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        ));
  });

  test('미onboarded + 로컬 selection 있으면 전송하고 지우고 true', () async {
    when(() => prefs.loadSelection()).thenAnswer(
      (_) async =>
          const OnboardingSelection(leagueName: 'LCK', teamId: 1, playerIds: [5]),
    );
    stubComplete();

    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'jwt-token', isOnboarded: false),
    );

    expect(result, isTrue);
    verify(() => repo.completeOnboarding(
          favoriteLeagueName: 'LCK',
          favoriteTeamId: 1,
          favoritePlayerIds: [5],
          jwt: 'jwt-token',
        )).called(1);
    verify(() => prefs.clear()).called(1);
  });

  test('미onboarded + 로컬 selection 없으면 false (전송 안 함)', () async {
    when(() => prefs.loadSelection()).thenAnswer((_) async => null);

    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'j', isOnboarded: false),
    );

    expect(result, isFalse);
    verifyNever(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        ));
  });

  test('전송 실패하면 로컬을 지우지 않고 false', () async {
    when(() => prefs.loadSelection()).thenAnswer(
      (_) async => const OnboardingSelection(teamId: 1),
    );
    when(() => repo.completeOnboarding(
          favoriteLeagueName: any(named: 'favoriteLeagueName'),
          favoriteTeamId: any(named: 'favoriteTeamId'),
          favoritePlayerIds: any(named: 'favoritePlayerIds'),
          jwt: any(named: 'jwt'),
        )).thenThrow(Exception('network'));

    final result = await service.syncOnLogin(
      const AuthResult(jwt: 'j', isOnboarded: false),
    );

    expect(result, isFalse);
    verifyNever(() => prefs.clear());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repository/onboarding/onboarding_sync_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../onboarding_sync_service.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/repository/onboarding/onboarding_sync_service.dart
import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../preference/onboarding_preference_repository.dart';
import 'onboarding_repository.dart';

/// 로그인 직후 비회원 시절 로컬에 저장된 온보딩 선택값을 서버로 1회 동기화한다.
class OnboardingSyncService {
  OnboardingSyncService({
    OnboardingRepository? repository,
    OnboardingPreferenceRepository? preferences,
  })  : _repository = repository ?? OnboardingRepository.instance,
        _preferences = preferences ?? OnboardingPreferenceRepository.instance;

  static final OnboardingSyncService instance = OnboardingSyncService();

  final OnboardingRepository _repository;
  final OnboardingPreferenceRepository _preferences;

  /// 로그인 결과를 받아 최종 onboarded 여부를 반환한다.
  ///
  /// - 서버가 이미 onboarded면 남은 로컬 selection 을 지우고 true.
  /// - 미onboarded인데 로컬 selection 이 있으면 서버로 전송 후 지우고 true.
  ///   전송 실패 시 로컬을 보존하고 false (다음 로그인에 재시도).
  /// - 로컬 selection 이 없으면 false.
  Future<bool> syncOnLogin(AuthResult result) async {
    if (result.isOnboarded) {
      await _preferences.clear();
      return true;
    }

    final selection = await _preferences.loadSelection();
    if (selection == null) return false;

    try {
      await _repository.completeOnboarding(
        favoriteLeagueName: selection.leagueName,
        favoriteTeamId: selection.teamId,
        favoritePlayerIds: selection.playerIds,
        jwt: result.jwt,
      );
    } catch (e) {
      debugPrint('[OnboardingSync] 로그인 동기화 실패: $e');
      return false;
    }

    await _preferences.clear();
    return true;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repository/onboarding/onboarding_sync_service_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/repository/onboarding/onboarding_sync_service.dart test/repository/onboarding/onboarding_sync_service_test.dart
git commit -m "feat(onboarding): 로그인 시 온보딩 동기화 서비스 추가 (#11)"
```

---

### Task 5: login_screen 연결

**Files:**
- Modify: `lib/screens/login/login_screen.dart` (import 추가, `_signIn` 분기)

**Interfaces:**
- Consumes: `OnboardingSyncService.instance.syncOnLogin(AuthResult)` (Task 4)

UI 화면이라 위젯 단위 테스트 대신 정적 분석 + 전체 테스트 + 수동 검증으로 확인한다.

- [ ] **Step 1: import 추가**

`lib/screens/login/login_screen.dart` 의 import 블록에 추가(기존 onboarding import 근처):

```dart
import '../../repository/onboarding/onboarding_sync_service.dart';
```

- [ ] **Step 2: `_signIn` 분기 수정**

`_signIn` 안에서 FCM 등록 직후 ~ Navigator 사이를 다음으로 교체. (기존: `if (!mounted) return; Navigator... result.isOnboarded ? ScheduleScreen() : OnboardingScreen()`)

```dart
      // 로그인 성공 직후 FCM 토큰을 백엔드에 등록한다 (실패해도 흐름은 계속).
      unawaited(FcmService.instance.registerToken());
      // 비회원 시절 로컬에 저장한 온보딩 선택값이 있으면 서버로 동기화한다.
      final onboarded =
          await OnboardingSyncService.instance.syncOnLogin(result);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              onboarded ? const ScheduleScreen() : const OnboardingScreen(),
        ),
        (route) => false,
      );
```

- [ ] **Step 3: 정적 분석**

Run: `flutter analyze lib/screens/login/login_screen.dart lib/repository/onboarding lib/repository/preference lib/viewmodel/onboarding lib/model/onboarding_selection.dart`
Expected: `No issues found!`

- [ ] **Step 4: 전체 테스트**

Run: `flutter test`
Expected: 모든 테스트 PASS (이번 작업 추가분 포함, 기존 테스트 회귀 없음)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login/login_screen.dart
git commit -m "feat(onboarding): 로그인 시 비회원 온보딩 동기화 연결 (#11)"
```

---

### Task 6: 지식 번들(OKF) 갱신

**Files:**
- Modify: `warding-okf/features/onboarding.md` (비회원 로컬 저장·로그인 동기화 현황 반영)
- Modify: `warding-okf/log.md` (최상단에 `2026-06-22` 항목 추가)

CLAUDE.md의 OKF 동기화 규칙에 따른다. `viz.html`은 PostToolUse 훅이 자동 재생성한다.

- [ ] **Step 1: onboarding.md 상태 갱신**

`warding-okf/features/onboarding.md`에서 "비회원은 선호 팀만 로컬 캐싱" 취지의 서술을 찾아, 비회원도 리그·팀·선수를 `OnboardingSelection`으로 로컬 저장하고 로그인 시 `OnboardingSyncService`가 `POST /api/auth/onboarding`으로 1회 동기화한다는 내용으로 갱신한다. (#11 완료 반영)

- [ ] **Step 2: log.md 항목 추가**

`warding-okf/log.md`의 `# Bundle Update Log` 바로 아래에 추가:

```markdown
## 2026-06-22
* **#11 완료**: 비회원 온보딩 로컬 저장 + 로그인 동기화. `OnboardingSelection` 모델·`OnboardingPreferenceRepository`·`OnboardingSyncService` 추가, `OnboardingViewModel`·`login_screen` 연동.
```

- [ ] **Step 3: Commit**

```bash
git add warding-okf/features/onboarding.md warding-okf/log.md warding-okf/viz.html
git commit -m "docs(okf): 비회원 온보딩 로컬 저장·동기화 반영 (#11)"
```

---

## Self-Review

**Spec coverage:**
- 요구사항 1 (비회원 리그·팀·선수 로컬 저장) → Task 1·2·3 ✅
- 요구사항 2 (로그인 시 동기화 + 건너뛰기) → Task 4·5 ✅
- 요구사항 3 (전송 실패 시 보존) → Task 4 Step 1 4번째 테스트 + Step 3 catch ✅
- 저장 구조 접근 1 (신규 repo + 헤더용 팀 캐시 유지) → Task 2, Task 3 (teamPrefs 호출 유지) ✅
- 에러 처리(파싱 실패 null) → Task 2 ✅
- 테스트 4종 → Task 1~4 ✅
- 범위 밖(백엔드 변경 없음, purpose B 미포함) → 준수 ✅
- OKF 동기화 규칙(CLAUDE.md) → Task 6 ✅

**Placeholder scan:** 모든 step에 실제 코드/명령 포함. 플레이스홀더 없음. (Task 6은 기존 문장을 못 보므로 "찾아서 갱신" 서술 — 문서 편집 특성상 허용)

**Type consistency:** `OnboardingSelection(leagueName?, teamId, playerIds)`, `saveSelection`/`loadSelection`/`clear`, `syncOnLogin(AuthResult)→bool`, `AuthResult(jwt, isOnboarded)` — 전 태스크에서 일관. `completeOnboarding` 시그니처는 실제 repo와 일치(`favoriteLeagueName?`, `favoriteTeamId`, `favoritePlayerIds`, `jwt`).
