---
type: Architecture Reference
title: 파일 생성 규칙
description: 새 기능 추가 시 종류별 파일 위치와 네이밍 규칙.
tags: [architecture, conventions, naming]
timestamp: 2026-06-21T00:00:00Z
---

# 종류별 위치

| 종류 | 위치 | 예 |
|------|------|-----|
| 화면 | `screens/{기능}/{기능}_screen.dart` | `screens/onboarding/onboarding_screen.dart` |
| 화면 전용 위젯 | `screens/{기능}/component/` | `screens/onboarding/component/onboarding_header.dart` |
| 단계별 화면(멀티 스텝) | `screens/{기능}/step/` | `screens/onboarding/step/team_step.dart` |
| 앱 공용 위젯 | `components/` | `components/common_button.dart` |
| ViewModel | `viewmodel/{기능}/{기능}_viewmodel.dart` | `viewmodel/onboarding/onboarding_viewmodel.dart` |
| 모델 | `model/{이름}.dart` | `model/team.dart` |
| 리포지토리 | `repository/{기능}/{기능}_repository.dart` | `repository/onboarding/onboarding_repository.dart` |

# 네이밍

- 파일명은 `snake_case`, 클래스명은 `PascalCase`.
- 한 화면에서만 쓰는 위젯 → 그 화면 폴더의 `component/`.
- 여러 화면에서 쓰는 위젯 → `lib/components/`.

# 관련

- 디렉토리 역할: [폴더 구조](/architecture/folder-structure.md)
- 계층 책임: [MVVM 패턴](/architecture/mvvm.md)
- 새 기능을 처음부터 만드는 절차: [새 기능 추가 플레이북](/playbooks/add-feature.md)

# Citations

[1] [CLAUDE.md — 파일 생성 규칙](/references/claude-md.md)
