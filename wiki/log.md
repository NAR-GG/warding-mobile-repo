# Bundle Update Log

## 2026-09-24
* **홈 화면 완료(spec v29)**: 홈이 앱 진입 화면이 됨(스플래시·로그인·온보딩 완료 → `HomeScreen`). 솔랭·오늘 경기·순위표·커뮤니티·콘텐츠 5섹션과 내 선수 화면 추가. 솔랭·평점·뉴스는 목업(`SoloRankSource`·`ReviewSource`·`NewsSource`), 백엔드 대기.
* **Creation**: [홈](/features/home.md) 개념 문서 추가.
* **홈 최종 리뷰 수정**: 솔랭·평점·뉴스 목업을 `HOME_MOCKS` 게이트(기본값 `kDebugMode`) 뒤로 옮김 — 릴리즈 빌드는 빈 소스, 빈 뉴스·한줄평이면 해당 탭을 숨김. 순위 칩·쇼츠 sort 문구 정정.
* **홈 새로고침·탭 전환**: 앱 복귀 시 새로고침(30초 스로틀)과 섹션별 최신 응답 우선 가드 추가. "커뮤니티 전체"가 탭 루트를 쌓지 않게 `pushReplacement`로 변경.
* **솔랭 분류 공용화**: 홈 솔랭 항목을 실제 구독 선수로 거르고, 홈·내 선수 화면이 `SoloRankClassification`(`solo_rank_rules.dart`) 하나를 쓰도록 통일.
* **홈 잔손질**: 배너 닫기 경쟁 조건 수정, 쇼츠 팀 매칭을 낱말 경계로, 쇼츠는 https 주소만 연다, 오늘 경기 LIVE 판정을 `isLiveMatchStatus`로, `SoloRankSnapshot.subscribedTotal` 제거, 내 선수 줄 key 를 playerId 로.

## 2026-06-22
* **#11 완료**: 비회원 온보딩 로컬 저장 + 로그인 동기화. `OnboardingSelection` 모델·`OnboardingPreferenceRepository`·`OnboardingSyncService` 추가, `OnboardingViewModel`·`login_screen` 연동.

## 2026-06-21
* **Initialization**: warding 프로젝트 지식 번들 생성 (OKF v0.1).
* **Creation**: [개요](/overview.md), [아키텍처](/architecture/), [디자인](/design/), [기능](/features/), [플레이북](/playbooks/), [레퍼런스](/references/) 디렉토리 구성.
* **Note**: 진행 상황·TODO는 [GitHub 프로젝트 보드](/references/github-project.md)와 [CLAUDE.md](../CLAUDE.md)를 단일 출처로 한다.
* **Automation**: `gen_viz.py`(시각화), `sync_github.py`(보드→`references/github-project.md` 동기화) 추가. `.md` 편집 시 viz 자동 재생성(훅), `/sync-github`로 보드 갱신.
