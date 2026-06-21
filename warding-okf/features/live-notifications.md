---
type: Feature
title: 라이브 알림 (FCM)
description: 라이브 경기 FCM 수신 및 딥링크. 백엔드 prod 선행 후 배포.
tags: [fcm, push, live, notifications, in-progress]
timestamp: 2026-06-21T00:00:00Z
---

# 상태

🟡 진행 중 (이슈 #21 — 보드 In Progress). 모바일 수신·딥링크는 구현됨.

# 구현됨

- 라이브 경기 **FCM 수신 + 딥링크** (모바일, #21).
- 관련 코드: `repository/fcm/fcm_service.dart`.
- Flutter 라이브 기능 배포는 백엔드 prod 선행 후 진행 (#17).

# 관련

- 라이브 경기 화면·스코어는 [경기](/features/matches.md).
- 솔로랭크 알림은 별도 → [솔랭 알림](/features/solo-rank-alarm.md).
- 현황은 [GitHub 프로젝트 보드](/references/github-project.md).

# Citations

[1] [GitHub 이슈 #21 — 라이브 알림 연동](/references/github-project.md)
