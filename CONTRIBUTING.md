# Contributing Guide

## 협업 규칙

1. main에 직접 push할 수 없다. 모든 변경은 PR로 머지한다. (ruleset으로 강제됨)
2. PR 제목은 `feat:` / `fix:` 접두사로 시작한다. PR 제목이 그대로 릴리즈 노트가 된다.
3. `pubspec.yaml`의 version은 기능 PR에서 올리지 않는다. 릴리즈 직전 버전 bump PR에서만 올린다.

아키텍처, 폴더 배치 규칙, 색상 토큰, UI 스케일 패턴 등 코드 컨벤션은 `CLAUDE.md`를 참고한다.

## 문서 찾기 — INDEX.md

이 레포엔 목적이 다른 문서 시스템이 여러 개 있다(개발 규칙, 기능 설계 이력, 아키텍처
참조). 뭘 찾는지 모를 땐 매번 각 폴더를 뒤지지 말고 [INDEX.md](./INDEX.md)부터 연다 —
전체 문서 지도이자 각 시스템이 뭘 담당하는지 한 줄 요약이다.

## Intent 기반 개발 (intent/)

기능 하나를 만들기 전에 의도와 설계를 문서로 먼저 남기는 워크플로우다. 코드를 짜기
전 "왜 만드는지"를 명시적으로 적어두면, 나중에 리뷰나 후속 작업에서 그 결정을 다시
추론할 필요가 없다.

**모든 작업에 강제되지 않는다** — 문제 성격에 따라 시작 지점이 다르다:

| 상황 | 시작 지점 |
|---|---|
| 뭘 만들어야 하는지 자체가 불명확 | `intent/<slug>/intent.md`부터 |
| 문제는 명확한데 설계 결정이 필요 | `spec.md`부터 (Intent 생략) |
| 문제·설계 다 명확한 버그/작업 | `plan.md`부터 (Intent/Spec 생략) |
| 오탈자·자명한 원라이너 | 문서 없이 바로 수정 |

- 슬러그 폴더 하나(`intent/<slug>/`)가 기능 하나에 대응. `intent.md`(선택) → `spec.md`(선택)
  → `plan.md`(구현 직전, 로컬 작성) 순으로 쌓인다.
- Intent/Spec은 각각 `intent/<slug>` / `spec/<slug>` 브랜치의 PR로 제출되고, 머지가 곧
  승인이다. 셀프 머지 가능 — PR로 남기는 이유는 승인 절차보다 "의도가 확정된 시점"을
  이력에 남기기 위함이다.
- 필수 섹션 헤더는 CI(`ci-doc-lint.yml`)가 검증한다.
- 전체 설계는 이 워크플로우 자체를 셀프 다잉푸딩한 사례인
  [intent/loop-engineering-workflow/spec.md](./intent/loop-engineering-workflow/spec.md)에
  가장 자세히 나와 있다.

### 자동화 파이프라인 — Discord `/intent` → Intent PR → Spec PR

Intent/Spec 초안은 손으로 쓰지 않고 Discord에서 트리거해 자동 생성할 수 있다. 전체 흐름:

```
[Discord] /intent 슬래시 커맨드 (모달: slug + 설명 입력)
   │
   ▼
[Vercel Function] tools/discord-bridge/api/discord/interactions.js
   - Ed25519 서명 검증 (discord-interactions 라이브러리)
   - 모달 제출을 받으면 즉시 "접수됨" 응답 후
     GitHub repository_dispatch 호출
       POST /repos/<owner>/<repo>/dispatches
       { event_type: "intent-request",
         client_payload: { slug, description, requestedBy, source: "discord" } }
   │
   ▼
[GitHub Actions] .github/workflows/intent-autodraft.yml
   - intent/<slug> 브랜치 생성 (동명 브랜치가 이미 열려 있으면 중복 방지)
   - Anthropic API(ANTHROPIC_API_KEY)로 intent.md 5섹션(Problem / Proposed outcome /
     Affected users and systems / Constraints / Open questions) 초안 작성
   - 커밋 후 PR 오픈 (.github/PULL_REQUEST_TEMPLATE/intent.md 템플릿 사용)
   │
   ▼
개발자가 초안을 검토·수정 → 셀프 머지 (= "의도 확정"의 승인)
   │
   ▼
[GitHub Actions] .github/workflows/intent-merge-continue.yml
   - intent/* 브랜치의 PR이 머지되는 순간을 감지해 spec-request를 dispatch
   │
   ▼
[GitHub Actions] .github/workflows/spec-autodraft.yml
   - spec/<slug> 브랜치 생성
   - 머지된 intent.md를 입력으로 Anthropic API가 spec.md 초안(Summary / Requirements /
     Design·Approach / Decisions / Out of scope / Open questions) 확장 작성
   - 커밋 후 PR 오픈 (.github/PULL_REQUEST_TEMPLATE/spec.md 템플릿 사용)
   │
   ▼
개발자가 spec을 검토·수정 → 셀프 머지
   │
   ▼
기능 브랜치에서 plan.md 작성(로컬, writing-plans 스킬 활용) → 구현 → 기능 PR (기본 템플릿)
```

초안이 마음에 안 들면 그냥 해당 `intent/<slug>` 또는 `spec/<slug>` 브랜치를 체크아웃해
직접 고쳐서 다시 푸시하면 된다 — 평범한 git 브랜치라 별도 수정 절차가 없다. 이 파이프라인은
**문제가 불명확할 때만** 필요하다 — 문제·설계가 이미 명확하면 Intent/Spec을 생략하고
바로 `plan.md`나 코드 수정으로 시작해도 된다 (위 진입점 표 참고).

### CI 반복 실패 → 자동 에스컬레이션

`ci-flutter-test.yml`은 모든 PR(문서만 바뀐 Intent/Spec PR 포함)에서 `flutter analyze &&
flutter test`를 돌린다. 실패가 반복되면 다음 순서로 자동 대응한다:

1. **1차 실패**: Discord로 "🔴 CI 실패" 알림만 전송한다.
2. **같은 브랜치에서 2회 연속 실패**: 직전 커밋의 CI 결과를 GitHub API로 조회해 결정론적으로
   (LLM 판단 아님) 감지하고, `escalate` job이 Anthropic API를 한 번 호출해 실패 로그·diff·
   커밋 이력을 분석한 뒤 문제 성격에 따라 3등급 중 하나로 대응한다:
   - **Plan 등급** (단순 버그로 판단): 같은 브랜치에 `plan.md`를 추가 커밋한다
     (시도한 것 · 실패 원인 · 수정 방향).
   - **Spec 등급** (설계 결정이 잘못됐다고 판단): `spec/<slug>-fix` 브랜치로 새 PR을 연다
     (`spec-autodraft.yml` 재사용).
   - **Intent 등급** (문제 전제 자체가 잘못됐다고 판단): `intent/<slug>-fix` 브랜치로 새
     PR을 연다 (`intent-autodraft.yml` 재사용, 실패 로그가 Problem 섹션의 재료가 된다).
3. Discord로 "⚠️ 2회 연속 실패 — Plan/Spec/Intent 자동 생성됨" 알림을 보낸다.

이 자동화는 **코드를 직접 고치지 않는다** — 딱 "다음에 뭘 해야 하는지 적힌 문서"까지만
만들고 멈춘다. 실제 수정은 사람(+에이전트)이 그 문서를 보고 기존 개발 흐름대로 진행한다.

### 필요한 인프라

- **Vercel**: `tools/discord-bridge/`를 이 레포의 서브디렉토리로 배포 (Flutter 툴체인과
  완전히 분리돼 `flutter analyze` 등에 영향 없음). 환경변수 `DISCORD_PUBLIC_KEY`,
  `DISPATCH_TOKEN`, `GITHUB_REPO` 필요.
- **GitHub Actions 시크릿**: `ANTHROPIC_API_KEY`(초안 생성용), `DISPATCH_TOKEN`
  (`repository_dispatch` 호출 + PR 생성 권한을 가진 fine-grained PAT). 기본
  `GITHUB_TOKEN`으로 연 PR/푸시는 새 CI 실행을 못 띄우기 때문에(GitHub의 재귀 방지 동작)
  자동 초안 PR과 워크플로우 간 트리거에는 반드시 이 PAT을 쓴다.
- **Discord 슬래시 커맨드 등록**: `scripts/register-discord-commands.mjs`를 1회 실행
  (커맨드 스키마가 바뀌면 재실행).

## Wiki 갱신 (wiki/)

`wiki/`는 "지금 코드가 실제로 어떻게 동작하는지"를 담은 살아있는 참조 문서다.
`intent/`가 "결정 당시의 왜"를 남긴다면, `wiki/`는 그 결정이 반영된 이후의 최신
스냅샷이다.

이 갱신은 자동화된 스크립트가 아니라 **작업하면서 매번 스스로 판단해 적용하는
규칙**이다 — 커밋이나 PR 시점에 강제로 검증되지 않으므로, 아래 조건에 해당하는
변경을 할 때 놓치지 않는다:

- 기능을 완료/변경하면 → `wiki/features/{기능}.md` 갱신
- 아키텍처·파일 규칙·디자인 토큰이 바뀌면 → `wiki/architecture/` 또는 `wiki/design/` 갱신
- 새 기능 영역이 생기면 → `wiki/features/`에 문서 추가 + `features/index.md`·루트
  `index.md`에 링크
- 의미 있는 변경 후에는 `wiki/log.md` 맨 위에 날짜 항목 추가

정확한 규칙 전문과 프론트매터 스키마는 `CLAUDE.md`의 "지식 번들 (wiki)" 섹션에 있다.
Spec을 승인(머지)할 때도 그 설계가 위 조건에 해당하는지 다시 확인한다 —
`.github/PULL_REQUEST_TEMPLATE/spec.md` 체크리스트 참고.

## API 스펙 갱신

백엔드 Swagger 스펙 요약은 `docs/api-reference.md`, 원본 OpenAPI JSON은
`docs/openapi_spec.json`에 있다. 최신 스펙으로 갱신하려면:

```bash
NAR_SWAGGER_USER=아이디 NAR_SWAGGER_PASS=비밀번호 python3 scripts/fetch_api_spec.py
```

`docs/openapi_spec.json`이 갱신된다. `docs/api-reference.md` 요약본도 같이 갱신하려면
그 파일 내용을 새 스펙 기준으로 다시 생성해야 한다 (엔드포인트 태그별 목록).

Swagger 계정 정보는 팀 채널/노션 등에서 확인한다.

## 릴리즈

버전의 진실은 `pubspec.yaml`의 `version: X.Y.Z+N` 하나다.
`X.Y.Z`는 스토어 표시 버전, `+N`은 versionCode라 스토어 제출마다 반드시 +1 한다.

스토어 제출은 **반드시 `shorebird release`로 뽑는다** (`flutter build ipa`/`flutter build
appbundle` 금지 — 일반 빌드는 Shorebird 코드 푸시를 받을 수 없다). 빌드 직전 `release/<버전>`
형식의 annotated 태그를 찍어 어느 커밋이 릴리즈됐는지 남긴다. 전체 절차와 태그 규칙,
릴리즈 후 핫픽스(Shorebird patch) 정책은 `CLAUDE.md`의 "릴리즈 / 배포 (Shorebird)"를 참고한다.
