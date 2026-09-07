# Intent: 루프 엔지니어링 — Intent/Spec/Plan 개발 워크플로우 도입

## Problem

- 개발자(현재 소수 인원)가 기능 요청을 받아 구현까지 가는 과정에서 "왜 만드는지", "무엇이
  확정됐는지"가 코드와 커밋 메시지에만 흩어져 있어, 나중에 맥락을 복원하기 어렵다.
- Discord로 기획 아이디어가 들어와도 이를 구조화된 문서로 남기는 절차가 없어, 아이디어→실행
  사이에 수동 타이핑·정리 병목이 있다.
- CI가 실패했을 때 같은 시도를 반복하다가 근본 원인(설계 미비·전제 오류)을 놓치는 경우가 있다.
- 지금 `main` 브랜치는 브랜치 보호 규칙이 없어, CI가 실패해도 물리적으로 머지를 막지 못한다.

## Proposed outcome

- Discord에서 `/intent` 슬래시 커맨드로 기획안을 넣으면 intent.md 초안 + PR이 자동 생성되고,
  머지되면 spec.md 초안도 자동으로 이어서 생성된다.
- 개발자는 문제의 성격에 따라 Intent → Spec → Plan 중 적절한 지점에서 시작할 수 있다. 모든
  작업이 반드시 Intent부터 시작할 필요는 없다.
- CI가 같은 브랜치에서 2회 연속 실패하면, 실패 로그를 분석해 적절한 등급(Plan/Spec/Intent)의
  문서를 자동 생성해 "같은 방식으로 재시도만 반복"하는 것을 막는다.
- 모든 단계 전환(Intent/Spec PR 생성·머지, CI 실패·에스컬레이션)이 Discord 알림으로 가시화된다.
- `main`은 CI(`flutter analyze && flutter test`)를 통과해야만 머지 가능해진다.

## Affected users and systems

- 이 레포(warding-mobile-repo)에서 작업하는 개발자들
- GitHub Actions (CI/CD)
- 신규: Vercel에 배포되는 Discord 인터랙션 브릿지 (`tools/discord-bridge/`)
- Discord 서버의 알림/커맨드 채널
- GitHub 저장소 설정 (브랜치 보호 규칙, PR 템플릿)

## Constraints

- 스토어 릴리즈(Shorebird)는 계속 수동으로 유지한다 — CLAUDE.md에 이미 명시된 규칙이며 이번
  작업의 자동화 대상이 아니다.
- Anthropic API 호출은 문서(Intent/Spec) 초안 생성에만 쓴다 — CI가 자동으로 코드를 고치지는
  않는다. 실제 코드 수정은 항상 개발자+에이전트의 로컬 Build 단계를 거친다.
- 기존 `pr-discord-notify.yml`, `test/` 폴더 구조(= `lib/` 미러링), MVVM 규칙을 깨지 않는다.
- 새 Node/Vercel 프로젝트는 Flutter 툴체인(`flutter analyze` 등)에 영향을 주지 않는 별도
  폴더에 격리한다.

## Open questions

- Vercel 브릿지를 이 모노레포 서브폴더로 유지할지, 트래픽/운영 부담이 커지면 별도 레포로 분리할지는
  실제 운영해보고 결정한다.
- CI 에스컬레이션의 "2회 연속 실패" 판정 기준(완전히 같은 실패 시그니처인지까지 볼지, 단순히
  연속 실패 여부만 볼지)은 운영 데이터를 보고 튜닝한다.
