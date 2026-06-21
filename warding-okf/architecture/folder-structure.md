---
type: Architecture Reference
title: 폴더 구조
description: lib/ 하위 디렉토리별 역할 정의.
resource: https://github.com/NAR-GG/warding-mobile-repo/tree/main/lib
tags: [architecture, structure]
timestamp: 2026-06-21T00:00:00Z
---

# lib/ 구조

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

# 비고

- `repository/`·`viewmodel/`은 **기능별 하위 폴더**로 나눈다.
- 한 화면에서만 쓰는 위젯은 그 화면 폴더의 `component/`에, 여러 화면에서 쓰면 `components/`에 둔다.
- 디자인 토큰은 `styles/`에 모은다 → [색상 토큰](/design/color-tokens.md).
- 계층별 책임은 [MVVM 패턴](/architecture/mvvm.md), 새 파일 위치는 [파일 생성 규칙](/architecture/file-conventions.md) 참조.

# Citations

[1] [CLAUDE.md — 폴더 구조](/references/claude-md.md)
