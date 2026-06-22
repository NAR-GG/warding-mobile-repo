---
type: Feature
title: 온보딩
description: 선호 리그·팀·선수·알림 권한 4단계 온보딩. MVVM 구조로 구현.
tags: [onboarding, mvvm, done]
timestamp: 2026-06-22T00:00:00Z
---

# 상태

✅ 4단계 구현 완료. 비회원 로컬 저장·로그인 동기화 완료 (#11).

# 내용

선호 **리그 · 팀 · 선수 · 알림 권한** 4단계로 구성.

- [MVVM](/architecture/mvvm.md) 구조: `OnboardingViewModel`(ChangeNotifier)이 단계 이동·선택·권한 상태를 갖고, `onboarding_screen.dart`와 `step/*` 위젯은 구독해 렌더링만 한다.
- 리그·선수 선택은 그리드 UI.
- 완료 시 `POST /api/auth/onboarding`에 리그·팀·선수를 연동.
- 알림 권한 '허용' 시 실제 권한 요청 연결됨.

# 비회원 처리 (이슈 #11 — 완료)

**비회원(JWT 없음)** 은 온보딩 완료 API를 호출하지 않고, 리그·팀·선수를 `OnboardingSelection`으로 로컬에 저장한다(`OnboardingPreferenceRepository`).
로그인 성공 직후 `OnboardingSyncService.syncOnLogin`이 로컬 selection이 있으면 `POST /api/auth/onboarding`으로 1회 동기화하고 로컬을 비운다(서버 저장 성공 시에만).
`login_screen`은 반환값(`isOnboarded`)으로 온보딩·일정 화면을 분기한다.

# 미해결 / 후속

- iOS 배포 시 `permission_handler` Podfile 매크로 설정 필요 (이슈 #12).
- 상세는 [GitHub 프로젝트 보드](/references/github-project.md) 참조.

# Citations

[1] [CLAUDE.md — 진행 상황 / 남은 TODO](/references/claude-md.md)
