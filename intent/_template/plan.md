# Plan: <제목>

## Context

- Intent: `intent/<slug>/intent.md` (있다면)
- Spec: `intent/<slug>/spec.md` (있다면)

## Changes


## Verification

- `flutter analyze && flutter test`
- e2e (spec Requirements 기반, `integration_test/`): 이 기능이 spec.md의 Requirements를
  바꾸거나 새로 추가했다면, 그 요건을 검증하는 시나리오를 `integration_test/`에 추가한다.
  기존 요건과 무관한 버그 수정 등은 생략 가능. e2e는 PR CI가 아니라 릴리즈 직전
  `e2e-release-check.yml` 수동 실행으로 돈다.
