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
git tag -a release/1.0.13+20 -m "shorebird release ios+android"   # 빌드 직전에 (아래 태그 규칙)
shorebird release ios        # → build/ios/ipa/*.ipa 를 Transporter로 업로드
shorebird release android    # → build/app/outputs/bundle/release/*.aab 를 Play Console에 업로드
git push --follow-tags

# 제출 전 확인: 해당 버전이 목록에 있어야 shorebird 빌드가 맞음
shorebird releases list

# 출시 후 Dart 코드 핫픽스 (심사 불필요, 앱 재실행 2번이면 적용)
shorebird patch ios --release-version <pubspec의 version>
shorebird patch android --release-version <pubspec의 version>
```

### 릴리즈 태그 규칙

**`shorebird release` 실행 직전에 annotated 태그를 찍는다.** shorebird 는 업로드 시각만
저장하고 어느 커밋이었는지는 남기지 않는다. 태그가 없으면 "이 릴리즈가 어느 코드였나"를
업로드 시각으로 역추적해야 하는데, 커밋 시각 ≠ 빌드 시각이고 uncommitted 상태로 빌드했으면
아예 못 찾는다.

- 태그명은 `release/<pubspec의 version 그대로>` — 예: `release/1.0.13+20`.
  조회는 언제나 "shorebird 가 말하는 버전 → 커밋" 방향이라 이름에 버전이 들어가야 한다.
- **`-a` 필수.** lightweight 태그는 자기 날짜가 없어 커밋 날짜로 대체되는데, 알고 싶은 건
  빌드 시각이다. annotated 는 태그를 찍은 시각을 따로 저장해 shorebird 의 `created_at` 과
  대조할 수 있다.
- 빌드 번호를 올려 다시 뽑으면 태그도 새로 찍는다. 옛 태그는 지우지 않는다 — 어느 빌드가
  실제로 스토어에 나갔는지 구분된다 (예: `+19` 는 폐기, `+20` 이 제출분).
- 날짜순으로 보려면:
  `git tag --sort=-creatordate --format='%(creatordate:short)  %(refname:short)  %(contents:subject)'`

패치 태그(`patch/<version>/<번호>`)는 만들지 않는다. shorebird 패치를 당분간 쓰지 않기로 했다.
다시 쓰게 되면 같은 방식으로 패치 직전에 찍는다.

패치 규칙 (현재 미사용, 재개할 때 참고):
- 패치는 **Dart 코드만** 배포한다. 네이티브 플러그인 추가·에셋 추가·pubspec 네이티브 의존성 변경은 패치로 못 나가고 스토어 재제출 필요.
- 구버전 릴리즈(예: 1.0.1+7)에 패치를 낼 때는 현재 main이 아니라 **그 릴리즈의 마지막 패치가 빌드된 시점의 커밋**을 worktree로 checkout 해서 픽스만 cherry-pick 한다. main으로 내면 그 사이 추가된 네이티브 의존성(sentry 등) 때문에 시작 크래시 위험.
- 태그가 없던 시절 릴리즈는 `shorebird patches list --release-version <버전> --json`의 artifact `created_at`으로 역추적해야 한다. 태그 규칙이 이걸 없애려는 것이다.
- 과금은 **패치 설치 수** 기준이라(Free 5,000/월) 패치를 남발하면 한도가 찬다. 릴리즈 빌드 자체는 과금 대상이 아니므로, 패치를 안 쓰더라도 빌드는 계속 `shorebird release` 로 뽑아 비상구를 열어 둔다.

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
