# Spec: 루프 엔지니어링 — Intent/Spec/Plan 개발 워크플로우

Intent: [intent.md](./intent.md)

## Summary

Anthropic의 AI-네이티브 SDLC(intent.md → spec.md → plan.md)를 이 레포에 맞게 도입한다.
Slack 대신 Discord, PO 승인 대신 개발자 셀프 머지, 배포는 계속 수동(Shorebird)을 유지하되
Intent/Spec 초안 생성과 테스트 검증은 CI로 자동화한다.

## 저장 구조

```
intent/
  <slug>/
    intent.md   (선택 — 문제가 불명확할 때만)
    spec.md     (선택 — 설계 결정이 필요할 때만)
    plan.md     (기능 브랜치에서 작성, 코딩 착수 직전 문서)
```

- 슬러그는 kebab-case.
- 한 슬러그 폴더에 같은 종류 파일은 1개만 — Spec이 2개 필요해지면 슬러그(Intent)를 쪼갠다.
- **진입점은 문제 성격에 따라 다르다** (모두 Intent부터 시작하지 않는다):

  | 상황 | 시작 지점 |
  |---|---|
  | 뭘 만들어야 하는지 자체가 불명확 | Intent부터 |
  | 문제는 명확한데 설계 결정이 필요 | Spec부터 (Intent 생략, spec.md 서두에 문제 상황 직접 기술) |
  | 문제·설계 다 명확한 버그/작업 | Plan부터 (Intent/Spec 생략) |
  | 오탈자·자명한 원라이너 | 문서 없이 바로 수정 (기존 CLAUDE.md 원칙 유지) |

## 브랜치 / PR 규칙

기존 `type/slug` 컨벤션(`feat/`, `fix/`, `chore/`, `docs/`)을 확장한다.

| 단계 | 브랜치 | 베이스 | PR 템플릿 |
|---|---|---|---|
| Intent | `intent/<slug>` | main | `intent.md` |
| Spec | `spec/<slug>` | main | `spec.md` |
| 구현 | 기존 `feat/`, `fix/` 등 (plan.md 포함) | main | 기본 템플릿 |

Intent/Spec 머지 = 승인. 승인자는 작성자 본인(셀프 머지)이어도 된다 — PR로 남기는 이유는
승인 자체보다 "의도가 확정된 시점"을 이력에 남기기 위함.

## 문서 템플릿

### intent.md
5개 섹션: `Problem` / `Proposed outcome` / `Affected users and systems` / `Constraints` /
`Open questions`.

### spec.md
`Summary`(Intent 링크, 또는 Intent 없을 시 문제 상황 직접 기술) / `Requirements` /
`Design / Approach` / `Decisions` / `Out of scope` / `Open questions`.

### plan.md
`Context`(Intent·Spec 링크, 있으면) / `Changes`(변경 순서) / `Verification`(테스트 방법).
내용상 `superpowers:writing-plans` 산출물과 거의 동일 — 실제로 그 스킬을 그대로 활용한다.

## PR 템플릿 3종

- `.github/pull_request_template.md` (기본, 기능 PR): plan.md 링크, 변경 요약, 테스트 방법,
  UI 변경 시 스크린샷, CLAUDE.md 체크리스트(AppColors 하드코딩 금지 등)
- `.github/PULL_REQUEST_TEMPLATE/intent.md`: 문서 링크 + "Problem·Outcome이 명확한가" 체크리스트
- `.github/PULL_REQUEST_TEMPLATE/spec.md`: Intent 링크(있으면) + "설계 결정이 다 내려졌는가" 체크리스트

## Discord → Intent/Spec 자동화 파이프라인

```
[Discord] /intent 슬래시 커맨드 (모달: slug + 설명)
   → [Vercel Function] /api/discord/interactions
       - Ed25519 서명 검증 (discord-interactions 라이브러리)
       - PING → PONG
       - APPLICATION_COMMAND(/intent) → MODAL 응답 (slug, description 입력)
       - MODAL_SUBMIT → "✅ 접수됨" 즉시 응답 + GitHub repository_dispatch 호출
           POST /repos/<owner>/<repo>/dispatches
           { event_type: "intent-request",
             client_payload: { slug, description, requestedBy, source: "discord" } }
   → [GitHub Actions] intent-autodraft.yml (on: repository_dispatch[intent-request])
       - intent/<slug> 브랜치 생성 (이미 있으면 실패)
       - Anthropic API(ANTHROPIC_API_KEY)로 intent.md 5섹션 초안 작성
       - 커밋 → PR 오픈 (gh pr create --template intent.md)
   → (기존 pr-discord-notify.yml이 "📝 Intent PR 열림" 알림)
   → 개발자가 intent.md 검토/수정 → 셀프 머지
   → [GitHub Actions] spec-autodraft.yml (on: pull_request closed+merged, head가 intent/*)
       - spec/<slug> 브랜치 생성
       - Anthropic API로 머지된 intent.md → spec.md 초안 확장
       - 커밋 → PR 오픈 (--template spec.md)
   → ("📐 Spec PR 열림" 알림) → 개발자 검토 → 셀프 머지
   → 개발자가 기능 브랜치에서 plan.md 작성(로컬, writing-plans 스킬) → 구현 → 기능 PR
```

수정이 필요하면(초안이 마음에 안 들면) 그냥 해당 브랜치를 체크아웃해 파일을 고치고 다시
푸시한다 — 평범한 git 브랜치이므로 별도 장치가 필요 없다.

### 새 인프라

- **Discord 슬래시 커맨드 등록**: `scripts/register-discord-commands.js` (1회 실행, 스키마
  변경 시 재실행) — `/intent` 커맨드를 Discord Application에 등록.
- **Vercel 프로젝트**: `tools/discord-bridge/` (작은 Node 프로젝트, Vercel Function 1개)를
  이 레포의 서브디렉토리로 Vercel에 연결. Flutter 툴체인과 완전히 분리되어 `flutter analyze`
  등에 영향 없음.
- **필요한 시크릿**
  - Vercel: `DISCORD_PUBLIC_KEY`, `GITHUB_DISPATCH_TOKEN` (repository_dispatch 권한의
    fine-grained PAT)
  - GitHub Actions: `ANTHROPIC_API_KEY` (신규), `DISCORD_PR_WEBHOOK_URL` (기존 재사용)

## Build 단계 (plan.md → 코드)

1. plan.md 완성 후 `superpowers:executing-plans` 스킬로 구현 시작. Plan 안의 태스크가 서로
   독립적이면 `subagent-driven-development`로 병렬화.
2. 각 태스크는 `superpowers:test-driven-development`를 따른다 — 테스트 먼저, 기존
   `test/{components,viewmodel,util,...}` 미러 구조 그대로 사용.
3. 버그 수정은 기존 스킬 우선순위 규칙대로 `systematic-debugging`이 자연히 적용된다.
4. "완료"라고 말하기 전엔 `verification-before-completion`으로 실제
   `flutter analyze && flutter test` 실행 결과를 확인한다.
5. UI 변경이 있는 화면은 프로젝트 전용 `run` 스킬(`.claude/skills/run-warding/`)로 시뮬레이터를
   띄워 직접 확인한다 — 웹 기준의 "브라우저로 확인" 규칙은 Flutter 앱에 맞지 않으므로 대체한다.

## CI/CD

### `ci-flutter-test.yml`
- `main` 대상 PR에서 `flutter pub get && flutter analyze && flutter test`.
- `intent/**` 문서만 바뀐 PR은 `paths-ignore`로 스킵.
- 실패 시 기존 Discord 웹훅으로 "🔴 CI 실패" 알림 전송.

### `ci-doc-lint.yml`
- `intent/**/intent.md`, `spec.md` 변경 시 필수 섹션 헤더가 모두 있는지 스크립트로 검사
  (자동 생성분도 포함, 셀프 머지 구조의 최소 안전장치).

### 브랜치 보호 (레포 설정, 코드 아님)
- `main`에 "Require status checks to pass before merging" 활성화, 필수 체크로
  `ci-flutter-test` 지정. 지금은 보호 규칙이 없어 CI가 빨갛게 떠도 머지를 막지 못한다 —
  구현 계획에 별도 스텝으로 포함한다.

### CI 반복 실패 → 자동 에스컬레이션

```
PR push → ci-flutter-test.yml 실행
  1차 실패 → Discord "🔴 CI 실패" 알림만
  2회 연속 실패 (직전 커밋 상태를 GitHub API로 조회 — 결정론적 체크, LLM 아님)
    → [escalate job] Anthropic API 1회 호출
        - 실패 로그 + diff + 커밋 이력 분석
        - 3등급 중 하나로 분류 + 그 등급 문서 초안 작성
          - Plan 등급(단순 버그): 같은 PR/브랜치에 plan.md 추가 커밋
            (시도한 것 · 실패 원인 · 수정 방향)
          - Spec 등급(설계 문제): 새 spec/<slug>-fix 브랜치+PR (spec-autodraft.yml 재사용)
          - Intent 등급(전제 문제): 새 intent/<slug>-fix 브랜치+PR (intent-autodraft.yml 재사용,
            실패 로그가 Problem 섹션 재료)
    → Discord 알림 ("⚠️ 2회 연속 실패 — Plan/Spec/Intent 자동 생성됨")
```

- 에스컬레이션이 **터지는 조건**(2회 연속 실패)은 결정론적 로직(GitHub API 조회)으로 판단한다.
  LLM은 이미 에스컬레이션하기로 정해진 다음 "어느 등급으로 대응할지 + 초안 작성"에만 쓴다.
- 자동으로 코드까지 고치지 않는다 — 딱 "다음 스텝을 위한 문서"까지만 만들고 멈춘다. 실제
  수정은 기존 Build 단계(개발자+에이전트, TDD)로 넘어간다.
- `intent-autodraft.yml` / `spec-autodraft.yml`의 `repository_dispatch` 페이로드에
  `source: "discord" | "ci-escalation"` 필드를 두어 두 트리거를 공용 워크플로우로 처리한다.

## Decisions

- Discord 연동은 웹훅 알림 확장 + `/intent` 슬래시 커맨드(모달) 조합으로 확정 (봇 상시 프로세스 없음).
- Intent/Spec 초안은 CI에서 Anthropic API로 완전 자동 생성 (뼈대만 자동 생성하는 대안은 기각).
- Vercel 브릿지는 이 레포의 서브폴더(`tools/discord-bridge/`)로 시작 (SSOT 취지, 필요시 분리).
- Discord 봇 호스팅은 Vercel 서버리스로 확정 (상시 프로세스 방식 기각 — 운영 부담).
- 시뮬레이터 `run` 스킬은 이번 구현 범위에 포함.
- CI 실패 알림은 Discord로 보낸다.

## Out of scope

- Shorebird 릴리즈/패치 자동화 (CLAUDE.md 규칙대로 계속 수동).
- CI가 실패 시 코드를 자동으로 고치는 것 (문서 생성까지만).
- 프로덕션 에러율/트래픽 기반 모니터링(운영 단계의 장애 감지) — 이번 범위는 CI(PR 단위) 실패에
  한정.

## Open questions

- (intent.md와 동일) Vercel 브릿지 분리 시점, 에스컬레이션 판정 기준 튜닝.
