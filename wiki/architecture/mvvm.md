---
type: Architecture Pattern
title: MVVM 패턴
description: 상태와 로직은 ViewModel에, UI는 View에 두는 warding의 핵심 아키텍처.
tags: [architecture, mvvm, state-management]
timestamp: 2026-06-21T00:00:00Z
---

# 원칙

상태와 로직은 **ViewModel**에, UI는 **View**에 둔다.

# 구성 요소

| 계층 | 위치 | 역할 |
|------|------|------|
| **Model** | `model/`, `repository/` | 데이터 모델 클래스, 데이터 소스(API) |
| **ViewModel** | `viewmodel/` | `ChangeNotifier` 상속. 화면 상태·비즈니스 로직 담당, `notifyListeners()`로 변경 통지 |
| **View** | `screens/` | UI만 담당 |

자세한 위치 규칙은 [폴더 구조](/architecture/folder-structure.md)와 [파일 생성 규칙](/architecture/file-conventions.md) 참조.

# ViewModel 규칙

- `ChangeNotifier`를 상속한다.
- **`BuildContext`에 의존하지 않는다.**
- 화면 전환은 생성 시 주입받은 콜백(`onFinish` 등)으로 View에 위임한다.

# View 규칙

- `ListenableBuilder`로 ViewModel을 구독한다.
- 사용자 이벤트는 ViewModel 메서드 호출로 위임한다.
- 화면 전환(`Navigator`)만 View에서 직접 처리한다.

# 예시: 온보딩

`OnboardingViewModel`(ChangeNotifier)이 단계 이동·선택·권한 상태를 갖고, `onboarding_screen.dart`와 `step/*` 위젯은 이를 구독해 렌더링만 한다. → [온보딩 기능](/features/onboarding.md)

# Citations

[1] [CLAUDE.md — 아키텍처: MVVM](/references/claude-md.md)
