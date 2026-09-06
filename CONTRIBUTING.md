# Contributing Guide

## 협업 규칙

1. main에 직접 push할 수 없다. 모든 변경은 PR로 머지한다. (ruleset으로 강제됨)
2. PR 제목은 `feat:` / `fix:` 접두사로 시작한다. PR 제목이 그대로 릴리즈 노트가 된다.
3. `pubspec.yaml`의 version은 기능 PR에서 올리지 않는다. 릴리즈 직전 버전 bump PR에서만 올린다.

아키텍처, 폴더 배치 규칙, 색상 토큰, UI 스케일 패턴 등 코드 컨벤션은 `CLAUDE.md`를 참고한다.

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
