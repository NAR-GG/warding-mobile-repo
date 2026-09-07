# Bundle Update Log

## 2026-06-22
* **#11 완료**: 비회원 온보딩 로컬 저장 + 로그인 동기화. `OnboardingSelection` 모델·`OnboardingPreferenceRepository`·`OnboardingSyncService` 추가, `OnboardingViewModel`·`login_screen` 연동.

## 2026-06-21
* **Initialization**: warding 프로젝트 지식 번들 생성 (OKF v0.1).
* **Creation**: [개요](/overview.md), [아키텍처](/architecture/), [디자인](/design/), [기능](/features/), [플레이북](/playbooks/), [레퍼런스](/references/) 디렉토리 구성.
* **Note**: 진행 상황·TODO는 [GitHub 프로젝트 보드](/references/github-project.md)와 [CLAUDE.md](/references/claude-md.md)를 단일 출처로 한다.
* **Automation**: `gen_viz.py`(시각화), `sync_github.py`(보드→`references/github-project.md` 동기화) 추가. `.md` 편집 시 viz 자동 재생성(훅), `/sync-github`로 보드 갱신.
