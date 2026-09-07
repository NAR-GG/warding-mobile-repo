---
type: Feature
title: 프로필 (마이페이지)
description: 마이페이지 프로필 저장 연동 및 프로필 수정 화면.
tags: [profile, mypage, in-progress]
timestamp: 2026-06-21T00:00:00Z
---

# 상태

✅ 프로필 저장 연동 완료(#20). 🟡 프로필 수정 화면(이미지 업로드 + name/tag) Flutter 연동 진행 중(#35).

# 구현됨

- 프로필 저장 연동 (#20).
- 관련 화면: `screens/mypage/mypage_screen.dart`, `screens/profile_edit/profile_edit_screen.dart`.
- 모델: `model/user_profile.dart`.

# 진행 중 (#35)

- 프로필 수정 화면 Flutter 연동: **이미지 업로드 + name/tag**.
- 현재 작업 브랜치에 미커밋 변경 다수 (`profile_edit_screen.dart`, `user_profile.dart`, `repository/profile/` 등).

# 관련

- 마이페이지의 솔랭 알림 섹션 → [솔랭 알림](/features/solo-rank-alarm.md).
- mypage 팀로고 이미지 host prepend는 [선수 평점](/features/player-ratings.md) #29와 연관.
- 현황은 [GitHub 프로젝트 보드](/references/github-project.md).

# Citations

[1] [GitHub 이슈 #20 / #35](/references/github-project.md)
