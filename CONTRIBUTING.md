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
- Discord `/intent` 슬래시 커맨드로 Intent 초안을 자동 생성할 수 있다 — 모달에 slug와
  설명을 입력하면 Anthropic API가 초안을 써서 PR을 연다. 머지되면 Spec 초안도 자동으로
  이어서 생성된다.
- 필수 섹션 헤더는 CI(`ci-doc-lint.yml`)가 검증한다.
- 전체 설계와 자동화 파이프라인은 이 워크플로우 자체를 셀프 다잉푸딩한 사례인
  [intent/loop-engineering-workflow/spec.md](./intent/loop-engineering-workflow/spec.md)에
  가장 자세히 나와 있다.

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
