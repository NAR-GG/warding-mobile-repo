---
type: index
topics: [meta, navigation]
status: living
---

# INDEX.md — 문서 지도

이 레포에 흩어진 문서 시스템들을 한 곳에서 찾을 수 있게 연결한다. 각 시스템은
성격이 다르므로 서로 대체하지 않는다 — 아래 표에서 지금 찾는 게 "왜"인지
"어떻게"인지 "무슨 일이 있었는지"인지로 골라 들어간다.

## 규칙 / 컨텍스트

| 파일 | 역할 |
|------|------|
| [CLAUDE.md](./CLAUDE.md) | Claude Code용 개발 가이드 — 아키텍처, 폴더 구조, 색상·UI 규칙, 릴리즈 절차 |
| [AGENTS.md](./AGENTS.md) | 다른 에이전트/도구(CodeRabbit 등)용 축약 규칙 — CLAUDE.md와 동일 원칙, Shorebird 릴리즈 절차 제외 |

## 왜 만드는가 — `intent/`

기능 하나를 만들기 전 의도(Problem/Proposed outcome)와 설계(Requirements/Design/Decisions)를
남기는 곳. 슬러그 폴더 하나가 기능 하나에 대응하며, `intent.md`(선택) → `spec.md`(선택)
→ `plan.md`(구현 직전) 순으로 쌓인다. 전체 워크플로우는
[intent/loop-engineering-workflow/spec.md](./intent/loop-engineering-workflow/spec.md) 참고.

| 슬러그 | 내용 |
|--------|------|
| [loop-engineering-workflow](./intent/loop-engineering-workflow/) | 이 intent/spec/plan 체계 자체(+ Discord 자동화)의 설계 — 셀프 다잉푸딩 사례 |
| [lck-2026-summer-viewing-points](./intent/lck-2026-summer-viewing-points/) | LCK 2026 서머 콘텐츠 기획 산출물(리서치 보고서·카드뉴스 기획서·html) — intent.md 형식이 아닌 콘텐츠 기획 문서 |

Spec을 승인(머지)할 때, 그 설계가 아키텍처·기능 구조를 바꾼다면 아래 `warding-okf/`도
함께 갱신해야 한다 — [.github/PULL_REQUEST_TEMPLATE/spec.md](./.github/PULL_REQUEST_TEMPLATE/spec.md)
체크리스트 참고.

## 지금 어떻게 동작하는가 — `warding-okf/`

앱의 아키텍처·디자인 토큰·기능 현황을 담은 살아있는 참조 위키(OKF 형식). `intent/`가
"결정 당시의 왜"를 남긴다면, 이쪽은 "지금 코드가 실제로 어떻게 동작하는지"의 최신
스냅샷이다. 코드 변경 후 곧바로 오래된 문서가 되지 않도록 `AGENTS.md`의 동기화 규칙을
따른다.

- [overview.md](./warding-okf/overview.md) — 시작점, 기술 스택
- [architecture/](./warding-okf/architecture/) — MVVM, 폴더 구조, 파일 생성 규칙
- [design/](./warding-okf/design/) — 색상 토큰, UI 스케일 규칙
- [features/](./warding-okf/features/) — 기능별 지식(로그인·온보딩·경기·라이브 알림 등)
- [playbooks/](./warding-okf/playbooks/) — 반복 작업 절차
- [references/](./warding-okf/references/) — GitHub 프로젝트 보드, CLAUDE.md 사본
- [log.md](./warding-okf/log.md) — 번들 변경 이력
- [viz.html](./warding-okf/viz.html) — 문서 간 연결 그래프(`.md` 편집 시 훅이 자동 재생성)

## 자동화

| 파일 | 역할 |
|------|------|
| [.github/scripts/check-intent-docs.sh](./.github/scripts/check-intent-docs.sh) | intent.md/spec.md 필수 섹션 검증(doc-lint) |
| [.github/workflows/](./.github/workflows/) | Intent/Spec 자동 초안, Flutter CI, CI 반복 실패 에스컬레이션 |
| [tools/discord-bridge/](./tools/discord-bridge/) | Discord `/intent` 슬래시 커맨드 → GitHub PR 자동 생성 브릿지 |
| [.claude/hooks/regen_okf_viz.sh](./.claude/hooks/regen_okf_viz.sh) | `warding-okf/*.md` 편집 시 `viz.html` 자동 재생성 |
| [.claude/commands/sync-github.md](./.claude/commands/sync-github.md) | GitHub 프로젝트 보드 → `warding-okf/references/github-project.md` 동기화 |
