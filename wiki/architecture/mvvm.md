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
| **Model** | `features/{기능}/domain/`, `features/{기능}/data/` | 데이터 모델 클래스, 데이터 소스(API). 여러 기능이 쓰면 `domain/`·`core/infrastructure/` |
| **ViewModel** | `features/{기능}/presentation/viewmodels/` | `ChangeNotifier` 상속. 화면 상태·비즈니스 로직 담당, `notifyListeners()`로 변경 통지 |
| **View** | `features/{기능}/presentation/screens/`, `widgets/` | UI만 담당 |

폴더 이름은 `presentation`이지만 상태 관리는 `ChangeNotifier` MVVM 이다. Flutter 공식
아키텍처 권고도 MVVM + Repository 라서 그대로 쓴다 — 나중에 상태 관리를 바꿀 때 폴더는
건드리지 않아도 된다.

자세한 위치 규칙은 [폴더 구조](/architecture/folder-structure.md)와 [파일 생성 규칙](/architecture/file-conventions.md) 참조.

# ViewModel 규칙

- `ChangeNotifier`를 상속한다.
- **`BuildContext`에 의존하지 않는다.**
- 화면 전환은 생성 시 주입받은 콜백(`onFinish` 등)으로 View에 위임한다.

# 섹션 ViewModel

**한 화면이 여러 기능의 섹션을 모아 보여줄 때, 각 섹션은 그 기능의 ViewModel 이 갖는다.**
집계 화면은 그걸 구독해 배치만 한다 — 홈이 섹션 8개를 그렇게 쓴다
([폴더 구조](/architecture/folder-structure.md)의 "집계 화면은 섹션을 조합만 한다").

- **전체 화면 VM 과 요약 섹션 VM 은 따로 둔다.** 요청 모양이 다르다(목록은 페이지네이션,
  요약은 최신 몇 건). 한 클래스에 두 역할을 넣으면 그 VM 이 비대해진다.
- **섹션 VM 생성자는 조회하지 않는다.** 첫 로드 시점은 쓰는 쪽이 `load()` 로 정한다. 여러
  섹션을 한 번에 당기는 화면이 자기 갱신 주기를 가져야 한다.
- **섹션 간 의존은 생성자로 주입한다.** 솔랭 카드는 구독 목록 없이 성립하지 않아
  `SoloRankViewModel(subscriptions: ...)` 로 받는다. 상대 VM 의 통지를 듣고 다시 계산한다.
- **집계 화면은 섹션 VM 의 통지를 자기 통지로 올린다.** 기존 위젯이 화면 VM 하나만 구독하는
  구조를 유지하려는 것이다. 섹션만 독립으로 쓰는 화면은 그 VM 을 직접 구독하면 된다.

# View 규칙

- `ListenableBuilder`로 ViewModel을 구독한다.
- 사용자 이벤트는 ViewModel 메서드 호출로 위임한다.
- 화면 전환(`Navigator`)만 View에서 직접 처리한다.

# 예시: 온보딩

`OnboardingViewModel`(ChangeNotifier)이 단계 이동·선택·권한 상태를 갖고, `onboarding_screen.dart`와 `step/*` 위젯은 이를 구독해 렌더링만 한다. → [온보딩 기능](/features/onboarding.md)

# Citations

[1] [CLAUDE.md — 아키텍처: MVVM](../../CLAUDE.md)
