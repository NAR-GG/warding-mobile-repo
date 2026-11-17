---
type: index
topics: [meta, navigation]
status: living
---

# INDEX.md: 문서 지도

이 레포에 흩어진 문서 시스템들을 한 곳에서 찾을 수 있게 연결합니다. 각 시스템은
성격이 다르므로 서로 대체하지 않습니다. 아래 표에서 지금 찾는 게 "왜"인지
"어떻게"인지 "무슨 일이 있었는지"인지로 골라 들어가세요.

## 규칙 / 컨텍스트

| 파일 | 역할 |
|------|------|
| [CLAUDE.md](./CLAUDE.md) | 실제 규칙 본문: 아키텍처, 폴더 구조, 색상·UI 규칙, 릴리즈 절차, intent/wiki 안내 |
| [AGENTS.md](./AGENTS.md) | `AGENTS.md`를 읽는 다른 코딩 에이전트용 포인터. 본문을 복제하지 않고 CLAUDE.md로 넘깁니다 — 규칙은 한 곳에서만 고치면 됩니다 |

## 레포 배치

`apps/` + `packages/` 모노레포입니다. 2026-11-17에 Flutter를 루트에서 `apps/mobile/`로
내렸습니다.

| 경로 | 내용 |
|------|------|
| [apps/mobile/](./apps/mobile/) | Flutter 앱. **Flutter 명령은 이 폴더에서 돌립니다** |
| [apps/web/](./apps/web/) | 웹뷰용 Next.js 앱 |
| [packages/design-tokens/](./packages/design-tokens/) | 디자인 토큰 단일 출처 → Dart·CSS 생성 |
| [packages/ui/](./packages/ui/) | 웹 공용 React 컴포넌트. 빌드 없이 소스를 내보냅니다 |
| [packages/api/](./packages/api/) | 웹용 API 클라이언트(`Result<T>` 반환). 매퍼 회귀 테스트를 포함합니다 |
| [tools/](./tools/) | 운영 스크립트 + Discord 브릿지 |
| [distribution/](./distribution/) | 스토어 패치노트 |

구조의 근거와 폴더 규칙은 [CLAUDE.md](./CLAUDE.md)의 "폴더 구조" 절에 있습니다.

## 왜 만드는가: `intent/`

기능 하나를 만들기 전 의도(Problem/Proposed outcome)와 설계(Requirements/Design/Decisions)를
남기는 곳입니다. 슬러그 폴더 하나가 기능 하나에 대응하며, `intent.md`(선택) → `spec.md`(선택)
→ `plan.md`(구현 직전) 순으로 쌓입니다. 전체 워크플로우는
[intent/loop-engineering-workflow/spec.md](./intent/loop-engineering-workflow/spec.md)를 참고하세요.

| 슬러그 | 내용 |
|--------|------|
| [loop-engineering-workflow](./intent/loop-engineering-workflow/) | 이 intent/spec/plan 체계 자체(+ Discord 자동화)의 설계. 셀프 도그푸딩 사례입니다 |
| [hybrid-webview-monorepo](./intent/hybrid-webview-monorepo/) | 웹뷰 전환(웹 중심). 모노레포 배치(`apps/` + `packages/`), 디자인 토큰·공용 UI 패키지를 정합니다 |
| [release-build-automation](./intent/release-build-automation/) | 태그를 밀면 빌드·e2e·업로드가 도는 릴리즈 자동화 설계 |
| [discord-release-approval](./intent/discord-release-approval/) | Discord 버튼 2단계 확인으로 스토어 심사를 제출하는 흐름 |
| [youtube-shorts](./intent/youtube-shorts/) | 쇼츠 앱 내 재생(세로 피드) |
| [lck-2026-summer-viewing-points](./intent/lck-2026-summer-viewing-points/) | LCK 2026 서머 콘텐츠 기획 산출물(리서치 보고서·카드뉴스 기획서·html). intent.md 형식이 아닌 콘텐츠 기획 문서입니다 |
| [_template](./intent/_template/) | 새 슬러그를 만들 때 복사하는 빈 양식 |

Spec을 승인(머지)할 때, 그 설계가 아키텍처·기능 구조를 바꾼다면 아래 `wiki/`도
함께 갱신해야 합니다. [.github/PULL_REQUEST_TEMPLATE/spec.md](./.github/PULL_REQUEST_TEMPLATE/spec.md)
체크리스트를 참고하세요.

## 무엇을 만들지 (별도 레포): `warding-docs`

화면 기획(md)과 디자인 목업(html)의 확정본은
[NAR-GG/warding-docs](https://github.com/NAR-GG/warding-docs)에 있습니다. 계정이 달라도 같은
파일을 보려고 레포를 따로 뒀습니다. 구현할 때 읽는 법은 [CLAUDE.md](./CLAUDE.md)의
"기획·디자인 확정본" 절을 참고하세요. `intent/<slug>/spec.md`가 이 파일들을 링크로
연결합니다.

## 지금 어떻게 동작하는가: `wiki/`

앱의 아키텍처·디자인 토큰·기능 현황을 담은 살아있는 참조 위키(OKF 형식)입니다. `intent/`가
"결정 당시의 왜"를 남긴다면, 이쪽은 "지금 코드가 실제로 어떻게 동작하는지"의 최신
스냅샷입니다. 코드 변경 후 곧바로 오래된 문서가 되지 않도록 `CLAUDE.md`의 동기화 규칙을
따릅니다.

- [overview.md](./wiki/overview.md): 시작점, 기술 스택
- [architecture/](./wiki/architecture/): MVVM, 폴더 구조, 파일 생성 규칙
- [design/](./wiki/design/): 색상 토큰, UI 스케일 규칙
- [features/](./wiki/features/): 기능별 지식(로그인·온보딩·경기·라이브 알림 등)
- [playbooks/](./wiki/playbooks/): 반복 작업 절차(새 기능 추가, Clean Architecture 전환)
- [references/](./wiki/references/): 백엔드 API 스펙(`api-reference.md`·`openapi_spec.json`),
  GitHub 프로젝트 보드 미러
- [policies/](./wiki/policies/): 개인정보처리방침·이용약관·계정 삭제 안내(법적 문서 보관본)
- [plans/](./wiki/plans/) · [specs/](./wiki/specs/): 지난 작업의 설계·계획 기록(과거 시점 그대로 둡니다)
- [log.md](./wiki/log.md): 번들 변경 이력

## 자동화

워크플로우 15개가 있습니다. 성격별로 묶으면 다음과 같습니다.

| 묶음 | 파일 | 역할 |
|------|------|------|
| PR 검증 | `ci-flutter-test` · `ci-tokens` · `ci-web-build` · `ci-bridge-test` · `ci-doc-lint` | analyze·test, 토큰 생성물 일치 + turbo 캐시 회귀, Next 빌드, 브릿지 테스트, intent/spec 필수 섹션 검증 |
| 릴리즈 | `release-deploy` · `patch-deploy` · `e2e-release-check` · `submit-for-review` · `release-submit-dispatch` | 태그를 밀면 도는 빌드·패치·e2e, Discord 버튼으로 심사 제출 |
| 문서 자동화 | `intent-autodraft` · `spec-autodraft` · `intent-merge-continue` | Discord `/intent` → 초안 PR, 머지 후 다음 단계 이어가기 |
| 알림·집계 | `pr-discord-notify` · `mixpanel-daily-dau` | PR 알림, DAU 일일 집계 |

태그를 밀어야 도는 워크플로우는 눈으로 검증할 수 없어 **셸 회귀 테스트**를 붙여 뒀고,
이것들은 PR마다 돕니다.

| 스크립트 | 검증 대상 |
|---|---|
| [patch-deploy-test.sh](./.github/workflows/patch-deploy-test.sh) | 패치 태그 파싱, 네이티브·에셋 변경 차단 정규식, pubspec 의존성 감지 |
| [turbo-cache-test.sh](./.github/workflows/turbo-cache-test.sh) | turbo 캐시가 `apps/mobile/` 쪽 생성물을 잃지 않는지 |
| [mixpanel-dau-summary-test.sh](./.github/workflows/mixpanel-dau-summary-test.sh) | DAU 요약 집계 |

그 밖에:

| 파일 | 역할 |
|------|------|
| [.github/scripts/check-intent-docs.sh](./.github/scripts/check-intent-docs.sh) | intent.md/spec.md 필수 섹션 검증(doc-lint) |
| [tools/discord-bridge/](./tools/discord-bridge/) | Discord `/intent` 슬래시 커맨드 → GitHub PR 자동 생성 브릿지 |
| [tools/sync_github.py](./tools/sync_github.py) | GitHub 프로젝트 보드 → `wiki/references/github-project.md` 동기화 (`/sync-github`) |
| [tools/fetch_api_spec.py](./tools/fetch_api_spec.py) · [generate_api_reference.py](./tools/generate_api_reference.py) | 백엔드 Swagger → `wiki/references/` 갱신 (`/sync-api-docs`) |
| [packages/design-tokens/](./packages/design-tokens/) | 토큰 소스 → Dart·CSS 생성 (`pnpm tokens:build`) |
