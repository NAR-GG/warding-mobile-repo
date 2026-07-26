# Warding 모바일 앱 - 개발 가이드

LCK 등 e스포츠 팬을 위한 Flutter 앱.

## 아키텍처: MVVM

상태와 로직은 ViewModel에, UI는 View에 둔다.

- **Model** (`model/`, `repository/`): 데이터 모델 클래스와 데이터 소스(API).
- **ViewModel** (`viewmodel/`): `ChangeNotifier`를 상속한다. 화면 상태와 비즈니스 로직을 담당하고 `notifyListeners()`로 변경을 통지한다.
  - `BuildContext`에 의존하지 않는다.
  - 화면 전환은 생성 시 주입받은 콜백(`onFinish` 등)으로 View에 위임한다.
- **View** (`screens/`): UI만 담당한다.
  - `ListenableBuilder`로 ViewModel을 구독한다.
  - 사용자 이벤트는 ViewModel 메서드 호출로 위임한다.
  - 화면 전환(`Navigator`)만 View에서 직접 처리한다.

예) 온보딩: `OnboardingViewModel`(ChangeNotifier)이 단계 이동·선택·권한 상태를 갖고,
`onboarding_screen.dart`와 `step/*` 위젯은 이를 구독해 렌더링만 한다.

## 폴더 구조

```
lib/
├── config/       앱 설정 (API URL, 키 등)
├── model/        데이터 모델 클래스
├── repository/   API 통신·데이터 소스 (기능별 하위 폴더)
├── viewmodel/    ViewModel (기능별 하위 폴더)
├── screens/      화면 (기능별 폴더)
├── components/   앱 전역 공용 위젯
├── styles/       디자인 토큰 (app_colors 등)
└── util/         유틸리티
```

## 파일 생성 규칙

새 기능을 추가할 때 종류별 위치:

| 종류 | 위치 | 예 |
|------|------|-----|
| 화면 | `screens/{기능}/{기능}_screen.dart` | `screens/onboarding/onboarding_screen.dart` |
| 화면 전용 위젯 | `screens/{기능}/component/` | `screens/onboarding/component/onboarding_header.dart` |
| 단계별 화면 (멀티 스텝) | `screens/{기능}/step/` | `screens/onboarding/step/team_step.dart` |
| 앱 공용 위젯 | `components/` | `components/common_button.dart` |
| ViewModel | `viewmodel/{기능}/{기능}_viewmodel.dart` | `viewmodel/onboarding/onboarding_viewmodel.dart` |
| 모델 | `model/{이름}.dart` | `model/team.dart` |
| 리포지토리 | `repository/{기능}/{기능}_repository.dart` | `repository/onboarding/onboarding_repository.dart` |

- 파일명은 `snake_case`, 클래스명은 `PascalCase`.
- 한 화면에서만 쓰는 위젯은 그 화면 폴더의 `component/`에, 여러 화면에서 쓰면 `lib/components/`에 둔다.

## 색상 / 디자인 토큰

모든 색은 `lib/styles/app_colors.dart`의 `AppColors` 클래스에 정의한다.

- 위젯에 색을 **하드코딩하지 않는다**. 항상 `AppColors.xxx`를 참조한다.
- 디자인 시안의 토큰 이름을 그대로 쓴다 (`narText`, `narDark800`, `narButton1Bg` 등).
- 단색: `static const Color narText = Color(0xFFFFFFFF);`
- 그라데이션: `static const LinearGradient narBg = LinearGradient(...);`
- 필요한 색이 없으면 위젯에 박지 말고 먼저 `AppColors`에 추가한 뒤 참조한다.

## UI 작성 규칙

- **비율 스케일**: 디자인 시안 기준 폭은 375. 화면 폭을 모바일 범위(320~430)로 clamp 한 뒤
  375로 나눈 `scale` 값을 크기·간격·폰트 등 수치에 곱한다.
  ```dart
  final width = MediaQuery.of(context).size.width;
  final scale = width.clamp(320.0, 430.0) / 375;
  ```
  재사용 컴포넌트는 `scale` 파라미터를 받아 내부 수치에 곱한다.
- **폰트**: 기본 `Pretendard`, 일부 `Open Sans` (pubspec에 폰트 등록 필요).
- `line-height`가 폰트 크기보다 많이 작으면 `height` 대신 부모의 `alignment`로 정렬한다.

## 릴리즈 / 배포 (Shorebird)

**스토어 제출용 빌드는 반드시 `shorebird release`로 뽑는다. `flutter build ipa`/`flutter build appbundle` 금지.**
일반 빌드에는 Shorebird 업데이터가 안 들어가서, 그 빌드를 설치한 유저는 코드 푸시 패치를 영원히 못 받는다
(1.0.3 iOS가 이 실수로 나가서 다음 스토어 릴리즈 전까지 패치 불가였음).

```bash
# 스토어 릴리즈 (버전은 pubspec.yaml의 version 사용)
shorebird release ios        # → build/ios/ipa/*.ipa 를 Transporter로 업로드
shorebird release android    # → build/app/outputs/bundle/release/*.aab 를 Play Console에 업로드

# 제출 전 확인: 해당 버전이 목록에 있어야 shorebird 빌드가 맞음
shorebird releases list

# 출시 후 Dart 코드 핫픽스 (심사 불필요, 앱 재실행 2번이면 적용)
shorebird patch ios --release-version <pubspec의 version>
shorebird patch android --release-version <pubspec의 version>
```

패치 규칙:
- 패치는 **Dart 코드만** 배포한다. 네이티브 플러그인 추가·에셋 추가·pubspec 네이티브 의존성 변경은 패치로 못 나가고 스토어 재제출 필요.
- 구버전 릴리즈(예: 1.0.1+7)에 패치를 낼 때는 현재 main이 아니라 **그 릴리즈의 마지막 패치가 빌드된 시점의 커밋**을 worktree로 checkout 해서 픽스만 cherry-pick 한다. main으로 내면 그 사이 추가된 네이티브 의존성(sentry 등) 때문에 시작 크래시 위험.
- 패치가 어느 코드였는지는 `shorebird patches list --release-version <버전> --json`의 artifact `created_at`으로 역추적.

## 진행 상황

### 완료
- 카카오 로그인 (네이티브 앱 키, 패키지명 `com.warding.app`, 릴리즈 키스토어 서명 설정)
- 화면 폴더 구조 정리 (`screens/login·home·onboarding`)
- 온보딩 4단계 (선호 리그·팀·선수·알림 권한) — MVVM 구조로 구현
- 온보딩 리그·선수 선택 그리드, 완료 API(`POST /api/auth/onboarding`)에 리그·팀·선수 연동

### 다음 작업
- 경기 페이지

### 남은 TODO
- `Pretendard` / `Open Sans` 폰트가 pubspec에 미등록 (현재 fallback 폰트로 렌더링)
- 비회원(JWT 없음)은 온보딩 완료 API를 호출하지 않음 — 선호 팀만 로컬 캐싱, 리그·선수 로컬 저장 미구현
- 알림 권한 '허용' 시 실제 권한 요청은 연결됨 — iOS 배포 시 `permission_handler` Podfile 매크로 설정 필요
