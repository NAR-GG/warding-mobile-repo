---
type: Project Overview
title: Warding 모바일 앱
description: LCK 등 e스포츠 팬을 위한 Flutter 모바일 앱.
resource: https://github.com/NAR-GG/warding-mobile-repo
tags: [flutter, esports, lck, mobile]
timestamp: 2026-06-21T00:00:00Z
---

# 개요

`warding`은 LCK를 비롯한 e스포츠 팬을 위한 **Flutter 모바일 앱**이다. 경기 일정·상세, 라이브 경기 알림, 선수 평점, 솔로랭크 알림, 마이페이지 등을 제공한다. 저장소는 `NAR-GG/warding-mobile-repo`(GitHub).

# 기술 스택

| 항목 | 내용 |
|------|------|
| 프레임워크 | Flutter (Dart) |
| 아키텍처 | [MVVM](/architecture/mvvm.md) |
| 패키지명 | `com.warding.app` |
| 인증 | [카카오 로그인](/features/kakao-login.md) (네이티브 앱 키, 릴리즈 키스토어 서명) |
| 푸시 | FCM — [라이브 알림](/features/live-notifications.md) |

# 핵심 규칙 (요약)

- 상태·로직은 ViewModel에, UI는 View에 둔다 → [MVVM](/architecture/mvvm.md)
- 종류별 파일 위치가 정해져 있다 → [폴더 구조](/architecture/folder-structure.md), [파일 생성 규칙](/architecture/file-conventions.md)
- 색은 하드코딩 금지, 항상 `AppColors` 참조 → [색상 토큰](/design/color-tokens.md)
- 디자인 시안 폭 375 기준 비율 스케일 적용 → [UI 스케일](/design/ui-scaling.md)

# 기능 영역

기능별 상세는 [Features](/features/) 참조. 주요 영역: [온보딩](/features/onboarding.md), [경기](/features/matches.md), [라이브 알림](/features/live-notifications.md), [선수 평점](/features/player-ratings.md), [솔랭 알림](/features/solo-rank-alarm.md), [프로필](/features/profile.md).

# 진행 상황

최신 진행 상황과 남은 작업은 [CLAUDE.md](/references/claude-md.md)의 "진행 상황" 섹션과 [GitHub 프로젝트 보드](/references/github-project.md)를 단일 출처로 본다.

# Citations

[1] [warding-mobile-repo (GitHub)](https://github.com/NAR-GG/warding-mobile-repo)
[2] [CLAUDE.md](/references/claude-md.md)
