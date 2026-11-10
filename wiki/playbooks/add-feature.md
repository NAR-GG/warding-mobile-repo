---
type: Playbook
title: 새 기능 추가
description: MVVM 규칙과 파일 위치 규약을 지키며 새 기능을 추가하는 절차.
tags: [playbook, how-to, mvvm]
timestamp: 2026-06-21T00:00:00Z
---

# 목적

warding에 새 화면/기능을 추가할 때 일관성을 유지하는 절차.

# 단계

새 기능은 `lib/features/{기능}/` 아래에 만든다 → [폴더 구조](/architecture/folder-structure.md)

1. **모델 정의** — `features/{기능}/domain/{이름}.dart`. 여러 기능이 쓸 모델이면 `core/domain/`.
2. **리포지토리 작성** — API 통신을 `features/{기능}/data/{기능}_repository.dart`에 둔다.
   여러 기능이 쓸 서비스면 `core/infrastructure/`.
3. **ViewModel 작성** — `features/{기능}/presentation/viewmodels/{기능}_viewmodel.dart`에
   `ChangeNotifier` 상속 클래스. 상태·로직을 담고 `notifyListeners()`로 통지.
   **`BuildContext` 의존 금지**, 화면 전환은 콜백으로 위임. → [MVVM](/architecture/mvvm.md)
4. **View 작성** — `features/{기능}/presentation/screens/{기능}_screen.dart`.
   `ListenableBuilder`로 ViewModel 구독, 이벤트는 ViewModel 메서드로 위임,
   `Navigator`만 직접 처리.
5. **위젯 분리** — 화면 전용 위젯은 `features/{기능}/presentation/widgets/`, 여러 기능에서
   쓰는 위젯은 `components/`. → [파일 생성 규칙](/architecture/file-conventions.md)
6. **import 는 절대경로** — `package:warding/features/...` 로 쓴다. 상대경로는 파일을 옮길 때
   깨진다.
7. **색·치수** — 색은 [`AppColors`](/design/color-tokens.md) 토큰만 사용(하드코딩 금지). 크기·폰트는 [비율 스케일](/design/ui-scaling.md) 적용.

# 체크리스트

- [ ] 파일명 `snake_case`, 클래스명 `PascalCase`
- [ ] ViewModel이 `BuildContext`를 참조하지 않음
- [ ] 하드코딩된 색이 없음 (`AppColors`만 참조)
- [ ] `scale` 적용된 치수

# Citations

[1] [CLAUDE.md — 아키텍처 / 파일 생성 규칙 / UI 작성 규칙](../../CLAUDE.md)
