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

## 지식 번들 (warding-okf)

`warding-okf/`는 이 프로젝트의 지식을 OKF(Open Knowledge Format) 형식으로 정리한 번들이다.
마크다운 + YAML 프론트매터 개념 문서들의 그래프로, 아키텍처·디자인 규칙·기능 현황을 담는다.

**동기화 규칙 — 작업 중 다음이 바뀌면 번들도 함께 갱신한다:**

- **기능을 완료/변경**하면 → `warding-okf/features/{기능}.md`의 상태·내용을 갱신한다.
- **아키텍처·파일 규칙·디자인 토큰**이 바뀌면 → `warding-okf/architecture/` 또는 `warding-okf/design/`의 해당 개념을 갱신한다.
- **새 기능 영역**이 생기면 → `warding-okf/features/`에 개념 문서를 추가하고 `features/index.md`와 루트 `index.md`에 링크를 건다.
- 의미 있는 변경 후에는 `warding-okf/log.md` 맨 위에 `YYYY-MM-DD` 항목을 추가한다.
- 개념 문서는 프론트매터에 `type`(필수)을 두고, 다른 개념은 `[제목](/path/to/concept.md)` 형식의 번들-상대 링크로 연결한다.

진행 상황·이슈 번호의 단일 출처는 `warding-okf/references/github-project.md`와 이 `AGENTS.md`다.

> `warding-okf/*.md`를 편집하면 `viz.html`(인터랙티브 그래프)은 PostToolUse 훅이 자동 재생성한다
> (`.Codex/hooks/regen_okf_viz.sh`, 개인 설정 `.Codex/settings.local.json`에 등록). 수동 재생성:
> `python3 warding-okf/gen_viz.py warding-okf warding-okf/viz.html "Warding OKF"`
