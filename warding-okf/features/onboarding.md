---
type: Feature
title: 온보딩
description: 선호 리그·팀·선수·알림 권한 4단계 온보딩. MVVM 구조로 구현.
tags: [onboarding, mvvm, done]
timestamp: 2026-06-21T00:00:00Z
---

# 상태

✅ 4단계 구현 완료. 일부 비회원 처리 미완(아래 참조).

# 내용

선호 **리그 · 팀 · 선수 · 알림 권한** 4단계로 구성.

- [MVVM](/architecture/mvvm.md) 구조: `OnboardingViewModel`(ChangeNotifier)이 단계 이동·선택·권한 상태를 갖고, `onboarding_screen.dart`와 `step/*` 위젯은 구독해 렌더링만 한다.
- 리그·선수 선택은 그리드 UI.
- 완료 시 `POST /api/auth/onboarding`에 리그·팀·선수를 연동.
- 알림 권한 '허용' 시 실제 권한 요청 연결됨.

# 미해결 / 후속

- **비회원(JWT 없음)** 은 온보딩 완료 API를 호출하지 않음. 선호 팀만 로컬 캐싱하고, 리그·선수 로컬 저장은 미구현 (이슈 #11).
- iOS 배포 시 `permission_handler` Podfile 매크로 설정 필요 (이슈 #12).
- 상세는 [GitHub 프로젝트 보드](/references/github-project.md) 참조.

# Citations

[1] [CLAUDE.md — 진행 상황 / 남은 TODO](/references/claude-md.md)
