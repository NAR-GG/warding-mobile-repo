---
type: Architecture Reference
title: 파일 생성 규칙
description: 새 기능 추가 시 종류별 파일 위치와 네이밍 규칙. feature 단위 구조 기준.
tags: [architecture, conventions, naming]
timestamp: 2026-11-10T00:00:00Z
---

# 종류별 위치

**새 기능은 `features/` 에 만든다.**

| 종류 | 위치 | 예 |
|------|------|-----|
| 화면 | `features/{기능}/presentation/screens/` | `features/community/presentation/screens/community_screen.dart` |
| 화면 전용 위젯 | `features/{기능}/presentation/widgets/` | `features/community/presentation/widgets/post_list_item.dart` |
| 단계별 화면(멀티 스텝) | `features/{기능}/presentation/screens/step/` | `.../presentation/screens/step/team_step.dart` |
| ViewModel | `features/{기능}/presentation/viewmodels/` | `features/community/presentation/viewmodels/community_list_viewmodel.dart` |
| 모델·규칙·상수 | `features/{기능}/domain/` | `features/community/domain/community_remote_post.dart` |
| 리포지토리 | `features/{기능}/data/` | `features/community/data/community_repository.dart` |
| 여러 기능이 쓰는 모델 | `core/domain/` | — |
| 여러 기능이 쓰는 서비스·리포지토리 | `core/infrastructure/` | — |
| 앱 공용 위젯 | `core/ui/` | `core/ui/common_button.dart` |

`lib/` 전체가 이 구조다 — `screens/`·`viewmodel/`·`model/`·`repository/` 최상위 폴더는
없어졌다. → [폴더 구조](/architecture/folder-structure.md)

# 레이어 구분

- **`domain`** — 그 기능의 개념. 모델, 규칙, 상수. 화면이 아닌 규칙 파일
  (`community_permission.dart`, `community_rules.dart` 등)도 여기 둔다.
- **`data`** — 개념을 가져오는 수단. repository, API 예외, 그 기능 전용 DTO.
- **`presentation`** — 화면과 상태 관리.

# core 로 올리는 기준

한 기능 소유가 아닌 것을 `features/` 안에 두면 다른 기능이 남의 폴더를 들여다봐야 한다.
**쓰는 기능이 둘 이상이면 `core/` 후보다.**

반대로 이름이 공용처럼 보여도 한 기능만 쓰면 그 기능 안에 둔다 — `community_my_activity`는
접두어가 `community_`지만 `my_community_activity` 기능만 쓰므로 그 기능의 `data/`에 있다.

# 네이밍

- 파일명은 `snake_case`, 클래스명은 `PascalCase`.
- 한 화면에서만 쓰는 위젯 → 그 기능의 `presentation/widgets/`.
- 여러 기능에서 쓰는 위젯 → `lib/core/ui/`.

# import

**`package:warding/...` 절대경로로 쓴다.** 상대경로는 파일을 옮길 때 대량으로 깨진다.

```dart
// 쓴다
import 'package:warding/features/community/domain/community_remote_post.dart';

// 쓰지 않는다
import '../../model/community_remote_post.dart';
```

# 관련

- 디렉토리 역할: [폴더 구조](/architecture/folder-structure.md)
- 계층 책임: [MVVM 패턴](/architecture/mvvm.md)
- 새 기능을 처음부터 만드는 절차: [새 기능 추가 플레이북](/playbooks/add-feature.md)

# Citations

[1] [CLAUDE.md — 파일 생성 규칙](../../CLAUDE.md)
