---
type: Architecture Reference
title: 폴더 구조
description: lib/ 하위 디렉토리별 역할 정의. feature 단위 구조.
resource: https://github.com/NAR-GG/warding-mobile-repo/tree/main/lib
tags: [architecture, structure]
timestamp: 2026-11-10T00:00:00Z
---

# lib/ 구조

**feature 단위 구조다.** 기능별로 `data`·`domain`·`presentation` 세 레이어를 한 폴더에
모은다. 이전에는 레이어가 최상위 축이어서 한 기능을 작업할 때 네 군데
(`model`·`repository`·`viewmodel`·`screens`)를 오가야 했다.

```
lib/
├── features/     기능별 27개
│   └── {기능}/
│       ├── data/           repository, API 예외, 그 기능 전용 DTO
│       ├── domain/         모델, 규칙·상수
│       └── presentation/
│           ├── screens/    화면 (멀티스텝은 step/, guide 는 page/)
│           ├── viewmodels/ ViewModel
│           └── widgets/    그 화면 전용 위젯
├── core/
│   ├── domain/             여러 기능이 쓰는 모델 12개
│   └── infrastructure/     여러 기능이 쓰는 서비스·repository 9개
│
├── config/       앱 설정 (API URL, 키 등)
├── components/   앱 전역 공용 위젯
├── styles/       디자인 토큰 (app_colors 등)
└── util/         유틸리티
```

# core 에 있는 것

| 대상 | 쓰는 곳 |
|---|---|
| `auth` | 18 |
| `preference` | 10 |
| `notification` | 5 |
| `rating` | 4 |
| `fcm`, `ad`, `live_activity` | 3 |
| `team` | 2 |
| `device` | 0 (미사용) |

소유 기능이 없는 횡단 관심사다. `core/domain` 에는 `team`·`schedule_match`(각 7곳),
`player_subscription`(5곳) 등 모델 12개가 있다.

**소유자 판단 기준**: 쓰는 기능이 둘 이상이고 이름이 같은 기능이 없으면 `core/`. 이름이
같은 기능이 있으면 그 기능 소유로 본다 — `notice` repository 는 `home` 도 쓰지만
`features/notice/data/` 에 둔다. `home` 은 집계 화면이라 거의 모든 기능을 소비하므로,
`home` 을 소비처로 세면 대부분이 `core/` 로 가 버린다.

# import 규칙

**`package:warding/...` 절대경로로 쓴다.** 상대경로(`../../model/...`)는 파일을 옮길 때
대량으로 깨진다 — 이 전환에서 540건이 났다. `export` 도 마찬가지다(`export '../../../util/
shorts_url.dart'` 하나가 테스트 10건을 깨뜨렸다).

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
