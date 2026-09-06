---
description: NAR 백엔드 Swagger 스펙을 받아 docs/openapi_spec.json과 docs/api-reference.md를 최신화
allowed-tools: Bash(python3:*)
---

백엔드(`https://api.nar.kr`)의 최신 OpenAPI 스펙을 받아와 `docs/openapi_spec.json`에 저장하고,
`docs/api-reference.md` 요약본을 다시 생성한다.

Swagger 계정(`NAR_SWAGGER_USER` / `NAR_SWAGGER_PASS`)이 환경변수로 없으면 먼저 사용자에게 물어본다.

실행:

```bash
NAR_SWAGGER_USER=<아이디> NAR_SWAGGER_PASS=<비밀번호> python3 scripts/fetch_api_spec.py
python3 scripts/generate_api_reference.py
```

실행 후 `docs/api-reference.md`를 갱신 전과 비교해서(`git diff docs/api-reference.md`)
새로 추가되거나 삭제된 엔드포인트가 있으면 간단히 요약해준다.
