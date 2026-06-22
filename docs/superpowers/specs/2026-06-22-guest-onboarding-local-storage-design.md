# 비회원 온보딩 로컬 저장 + 로그인 동기화 (#11)

## 배경

비회원(JWT 없음)은 온보딩 완료 API(`POST /api/auth/onboarding`)를 호출하지 않는다.
현재 비회원의 선택 중 **선호 팀만** 로컬 캐싱되고(헤더용), 선호 리그·선수는 저장되지 않는다.

목표: 비회원이 온보딩에서 고른 리그·팀·선수를 로컬에 저장해 두었다가,
**나중에 로그인하면 1회 서버로 동기화**한다 (purpose A).

## 요구사항

1. 비회원 온보딩 완료 시 리그·팀·선수를 로컬 저장한다.
2. 로그인 성공 직후, 로컬에 저장된 온보딩 데이터가 있고 서버가 `isOnboarded=false`로 응답하면:
   - `POST /api/auth/onboarding`으로 1회 전송한다.
   - 성공하면 로컬 데이터를 삭제하고, **온보딩 화면을 건너뛰고** 일정 화면으로 보낸다. (Q2-1: 가)
3. 전송 실패 시 로컬 데이터를 보존하고 온보딩 화면으로 보낸다 (데이터 유실 방지).

## 저장 구조 (접근 1)

동기화 페이로드 전용 신규 repository를 둔다. 헤더가 읽는 기존 팀 캐시와 책임을 분리한다.

- `model/onboarding_selection.dart`
  - `OnboardingSelection { String? leagueName; int teamId; List<int> playerIds; }` + `toJson`/`fromJson`
- `repository/preference/onboarding_preference_repository.dart`
  - 싱글톤. `FlutterSecureStorage`를 주입 가능하게 받는다(테스트용).
  - key: `onboarding_selection`
  - `saveSelection(OnboardingSelection)`, `loadSelection() → OnboardingSelection?`, `clear()`
  - 손상된 저장값은 `null` 취급(기존 `TeamPreferenceRepository` 패턴과 동일).
- `repository/onboarding/onboarding_sync_service.dart`
  - `syncOnLogin(AuthResult) → Future<bool>` (반환값 = 최종 isOnboarded)
  - 서버 onboarded → 로컬 selection `clear()` 후 `true`
  - 서버 미onboarded → `loadSelection()`
    - 있으면 `completeOnboarding(...)` 호출 → 성공 시 `clear()` 후 `true`, 실패 시 보존 후 `false`
    - 없으면 `false`

## 수정 대상

- `viewmodel/onboarding/onboarding_viewmodel.dart`
  - 생성자에 `OnboardingPreferenceRepository` 주입(기본값은 싱글톤 인스턴스).
  - `_savePreferences()`:
    - 비회원(jwt == null): `onboardingPrefs.saveSelection(...)` (팀 캐시 저장은 기존대로 유지)
    - 회원(jwt != null): 기존 `completeOnboarding` + 팀 캐시 + `onboardingPrefs.clear()`
  - `skip()`: 팀 캐시 clear에 더해 `onboardingPrefs.clear()`
- `screens/login/login_screen.dart`
  - `_signIn`: `AuthResult` 수신 후 `OnboardingSyncService.instance.syncOnLogin(result)`로 최종 onboarded를 판정해 분기. View는 Navigator만 담당.

## 데이터 흐름

### 비회원 온보딩 저장
```
goNext()(마지막 단계) → _savePreferences()
  jwt == null → teamPrefs.savePreferredTeam(team)            // 헤더용(기존)
              → onboardingPrefs.saveSelection(selection)     // 동기화용(신규)
  jwt != null → repo.completeOnboarding(...) ; teamPrefs.save ; onboardingPrefs.clear()
```

### 로그인 동기화
```
_signIn() → AuthResult{jwt, isOnboarded}
  onboarded = syncOnLogin(result)
    server true  → clear ; true
    server false → sel = loadSelection()
                    sel != null → completeOnboarding(sel, jwt) → clear ; true
                                  (실패 → 보존 ; false)
                    sel == null → false
  Navigator: onboarded ? ScheduleScreen : OnboardingScreen
```

## 에러 처리

- 동기화 전송 실패: 로컬 selection 미삭제, `false` 반환 → 온보딩 화면으로. 기존 `_savePreferences` try/catch 패턴과 일관.
- 저장값 파싱 실패: `null` 취급.

## 테스트 (mocktail, 기존 패턴)

- `OnboardingPreferenceRepository`: 주입 storage로 save→load 라운드트립 / 손상값→null / clear
- `OnboardingViewModel._savePreferences`: 비회원→selection 저장 / 회원→clear 호출
- `OnboardingSyncService.syncOnLogin`: server-onboarded→true+clear / 로컬 있음→전송+true+clear / 로컬 없음→false / 전송 실패→false+미삭제

## 범위 밖

- 백엔드 변경 없음(기존 `POST /api/auth/onboarding` 계약 그대로 사용).
- 로컬 selection을 앱 내 화면에서 직접 읽어 표시하는 기능(purpose B)은 포함하지 않음.
