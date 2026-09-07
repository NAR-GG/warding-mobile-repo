---
type: Design Convention
title: 색상 / 디자인 토큰
description: 모든 색은 AppColors에 정의하고 위젯에 하드코딩하지 않는다.
resource: https://github.com/NAR-GG/warding-mobile-repo/blob/main/lib/styles/app_colors.dart
tags: [design, colors, tokens]
timestamp: 2026-06-21T00:00:00Z
---

# 규칙

모든 색은 `lib/styles/app_colors.dart`의 `AppColors` 클래스에 정의한다.

- 위젯에 색을 **하드코딩하지 않는다.** 항상 `AppColors.xxx`를 참조한다.
- 디자인 시안의 토큰 이름을 그대로 쓴다 (`narText`, `narDark800`, `narButton1Bg` 등).
- 필요한 색이 없으면 위젯에 박지 말고 **먼저 `AppColors`에 추가한 뒤** 참조한다.

# 예시

```dart
// 단색
static const Color narText = Color(0xFFFFFFFF);

// 그라데이션
static const LinearGradient narBg = LinearGradient(...);
```

# 관련

- 크기·간격·폰트 스케일링은 [UI 스케일](/design/ui-scaling.md) 참조.
- 토큰 정의 위치(`styles/`)는 [폴더 구조](/architecture/folder-structure.md) 참조.

# Citations

[1] [CLAUDE.md — 색상 / 디자인 토큰](/references/claude-md.md)
