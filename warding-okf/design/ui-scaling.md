---
type: Design Convention
title: UI 비율 스케일 / 폰트
description: 디자인 시안 폭 375 기준으로 크기·간격·폰트를 비율 스케일한다.
tags: [design, responsive, scaling, fonts]
timestamp: 2026-06-21T00:00:00Z
---

# 비율 스케일

디자인 시안 기준 폭은 **375**. 화면 폭을 모바일 범위(320~430)로 clamp 한 뒤 375로 나눈 `scale` 값을 크기·간격·폰트 등 수치에 곱한다.

```dart
final width = MediaQuery.of(context).size.width;
final scale = width.clamp(320.0, 430.0) / 375;
```

재사용 컴포넌트는 `scale` 파라미터를 받아 내부 수치에 곱한다.

# 폰트

- 기본 `Pretendard`, 일부 `Open Sans`.
- ⚠️ 현재 두 폰트가 **pubspec에 미등록**이라 fallback 폰트로 렌더링됨 → 미해결 (GitHub 이슈 #10, [프로젝트 보드](/references/github-project.md) 참조).
- `line-height`가 폰트 크기보다 많이 작으면 `height` 대신 부모의 `alignment`로 정렬한다.

# 관련

- 색 토큰은 [색상 토큰](/design/color-tokens.md) 참조.

# Citations

[1] [CLAUDE.md — UI 작성 규칙](/references/claude-md.md)
