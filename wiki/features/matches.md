---
type: Feature
title: 경기 (일정·상세·라이브)
description: 경기 일정/상세 화면, 라이브 기준 스코어·세트 연동, 챔피언 픽/밴 탭.
tags: [matches, live, schedule]
timestamp: 2026-06-21T00:00:00Z
---

# 상태

✅ 경기 페이지 구현 완료(이슈 #8). 일부 UI·필터 후속 작업 진행 중.

# 구현됨

- 경기 페이지 구현 (#8).
- 경기 상세 헤더 **스코어/세트를 라이브 기준으로 연동** (#14).
- 경기 리스트 **커서 페이지네이션을 단일 호출로 교체** (성능, #19).
- 챔피언 픽 탭: 밴 챔피언 컬러·테두리 표시 수정 (#23, #32).
- 라이브 이벤트 탭 '경기 진행 중' 라벨이 종료 경기에 고정 표시되던 버그 수정 (#24).

# 후속 작업 (열린 이슈)

- 경기 상세 진행도에 따른 스코어·뱃지 UI 수정 (#34).
- 경기일정 필터에 '리그 전체 선택' 추가 (#33).
- 라이브 탭 자동 새로고침 도입 검토 (#16).

# 관련

- 라이브 경기 알림은 [라이브 알림](/features/live-notifications.md).
- 선수 평점은 [선수 평점](/features/player-ratings.md).
- 현황은 [GitHub 프로젝트 보드](/references/github-project.md).

# Citations

[1] [GitHub 프로젝트 보드 / 이슈](/references/github-project.md)
[2] [CLAUDE.md](/references/claude-md.md)
