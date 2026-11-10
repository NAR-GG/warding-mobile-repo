---
type: Architecture Reference
title: 폴더 구조
description: lib/ 하위 디렉토리별 역할 정의. feature 단위 구조로 전환 중.
resource: https://github.com/NAR-GG/warding-mobile-repo/tree/main/lib
tags: [architecture, structure]
timestamp: 2026-11-10T00:00:00Z
---

# lib/ 구조

**feature 단위 구조로 옮기는 중이다.** 기능별로 `data`·`domain`·`presentation` 세 레이어를
한 폴더에 모은다. 이전에는 레이어가 최상위 축이어서 한 기능을 작업할 때 네 군데
(`model`·`repository`·`viewmodel`·`screens`)를 오가야 했다.

```
lib/
├── features/     새 구조. 기능별로 레이어를 모은다
│   └── {기능}/
│       ├── data/           repository, API 예외, 그 기능 전용 DTO
│       ├── domain/         모델, 규칙·상수
│       └── presentation/
│           ├── screens/    화면
│           ├── viewmodels/ ViewModel
│           └── widgets/    그 화면 전용 위젯
├── core/         여러 기능이 공유하는 domain·infrastructure
│
├── config/       앱 설정 (API URL, 키 등)
├── components/   앱 전역 공용 위젯
├── styles/       디자인 토큰 (app_colors 등)
├── util/         유틸리티
│
└── (이전 구조 — 아직 옮기지 않은 기능)
    ├── model/        데이터 모델 클래스
    ├── repository/   API 통신·데이터 소스 (기능별 하위 폴더)
    ├── viewmodel/    ViewModel (기능별 하위 폴더)
    └── screens/      화면 (기능별 폴더)
```

# 전환 상태

| 기능 | 상태 |
|---|---|
| `community` | 완료 |
| `my_community_activity` | 완료 |
| 그 외 24개 | 이전 구조 |

한 기능씩 옮긴다. `community` 실측으로 **기능 하나가 77 파일 변경**(이동 44 / import 수정 33)
이라, 한 번에 옮기면 리뷰가 불가능하고 진행 중인 다른 브랜치와 충돌한다.

`core/`는 생성만 해 두고 비어 있다. 여러 기능이 공유하는 것을 올릴 자리다 — `auth`(8개 기능),
`preference`(7), `onboarding`(5), `rating`·`subscription`(각 4)이 후보다. 이동은 영향 범위가
한 기능을 넘어가므로 별도로 판단한다.

# import 규칙

**`package:warding/...` 절대경로로 쓴다.** 상대경로(`../../model/...`)는 파일을 옮길 때
대량으로 깨진다 — `community`를 옮길 때 540건이 났다. 새 코드는 절대경로로 쓰고, 기존
상대경로는 그 기능을 옮길 때 함께 바꾼다.

# 비고

- `data` 와 `domain` 의 구분: `domain`은 그 기능의 개념(모델·규칙·상수), `data`는 그것을
  가져오는 수단(repository·API 예외)과 그 기능 전용 DTO다. `community_permission.dart`처럼
  화면이 아닌 규칙 파일은 `screens`가 아니라 `domain`에 둔다.
- 한 기능 소유가 아닌 것을 `features/` 안에 두면 다른 기능이 남의 폴더를 들여다봐야 한다.
  쓰는 기능이 둘 이상이면 `core/` 후보다.
- 한 화면에서만 쓰는 위젯은 그 기능의 `presentation/widgets/`에, 여러 기능에서 쓰면
  `components/`에 둔다.
- 디자인 토큰은 `styles/`에 모은다 → [색상 토큰](/design/color-tokens.md).
- 계층별 책임은 [MVVM 패턴](/architecture/mvvm.md), 새 파일 위치는
  [파일 생성 규칙](/architecture/file-conventions.md) 참조.
- 상태 관리는 `ChangeNotifier` 기반 MVVM 을 유지한다. `presentation/`은 BLoC 을 전제한
  이름이지만, 지금은 ViewModel 이 그 자리에 있다 — 나중에 상태 관리를 바꿀 때 폴더는
  그대로 쓸 수 있다.

# Citations

[1] [CLAUDE.md — 폴더 구조](../../CLAUDE.md)
[2] [웹뷰 전환 Spec — 레포 배치](../../intent/hybrid-webview-monorepo/spec.md)
