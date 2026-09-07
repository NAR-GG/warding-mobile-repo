---
type: Feature
title: 선수 평점
description: 선수 평점 탭 실데이터 연동 및 선수 사진 표시.
tags: [players, ratings, images]
timestamp: 2026-06-21T00:00:00Z
---

# 상태

✅ 실데이터 연동 완료(#15). 이미지 소스 안정화는 후속.

# 구현됨

- 선수 평점 탭 **실데이터 연동** (#15).
- 평점 상세 헤더에 선수 사진 렌더 (#28).
- 평점 리스트 행에 선수 사진 표시 (#31).
- 상대경로 이미지 URL에 API 호스트 prepend (선수/팀 이미지 표시, #27).

# 후속 작업

- 선수 이미지: `epromatch` 소스가 dead → 번들 이미지로 대체 + 서빙/매칭/호스트 수정 (#28 완료분), 번들 외 선수 커버리지 + mypage 팀로고 host prepend (#29, 열림).
- 상세는 [GitHub 프로젝트 보드](/references/github-project.md).

# 관련

- 경기 상세와 연계 → [경기](/features/matches.md).

# Citations

[1] [GitHub 이슈 #15/#27/#28/#29/#31](/references/github-project.md)
