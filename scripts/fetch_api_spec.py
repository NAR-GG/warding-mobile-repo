#!/usr/bin/env python3
"""NAR API 서버(https://api.nar.kr)에서 OpenAPI 스펙을 받아 docs/openapi_spec.json에 저장한다.

사용법:
    NAR_SWAGGER_USER=아이디 NAR_SWAGGER_PASS=비밀번호 python3 scripts/fetch_api_spec.py

주의: /v3/api-docs는 Basic Auth + `Accept: application/json` 헤더가 없으면
소셜 로그인 페이지(HTML)로 리다이렉트된다.
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request

SPEC_URL = "https://api.nar.kr/v3/api-docs"
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "..", "docs", "openapi_spec.json")


def main():
    user = os.environ.get("NAR_SWAGGER_USER")
    password = os.environ.get("NAR_SWAGGER_PASS")
    if not user or not password:
        print("NAR_SWAGGER_USER, NAR_SWAGGER_PASS 환경변수를 설정해줘.", file=sys.stderr)
        sys.exit(1)

    cred = base64.b64encode(f"{user}:{password}".encode()).decode()
    headers = {
        "Authorization": f"Basic {cred}",
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0",
    }

    req = urllib.request.Request(SPEC_URL, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read()
    except urllib.error.HTTPError as e:
        print(f"요청 실패: HTTP {e.code}", file=sys.stderr)
        sys.exit(1)

    spec = json.loads(body)

    out_path = os.path.abspath(OUTPUT_PATH)
    with open(out_path, "w") as f:
        json.dump(spec, f, ensure_ascii=False, indent=2)

    print(f"저장 완료: {out_path}")
    print(f"title: {spec['info']['title']} {spec['info']['version']}")
    print(f"paths: {len(spec.get('paths', {}))}")


if __name__ == "__main__":
    main()
