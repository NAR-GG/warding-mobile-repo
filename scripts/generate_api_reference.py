#!/usr/bin/env python3
"""docs/openapi_spec.json을 읽어 docs/api-reference.md 요약본을 다시 생성한다.

사용법:
    python3 scripts/generate_api_reference.py
"""

import json
import os
from collections import defaultdict

BASE_DIR = os.path.join(os.path.dirname(__file__), "..")
SPEC_PATH = os.path.join(BASE_DIR, "docs", "openapi_spec.json")
OUTPUT_PATH = os.path.join(BASE_DIR, "docs", "api-reference.md")

HTTP_METHODS = ("get", "post", "put", "delete", "patch")


def main():
    with open(SPEC_PATH) as f:
        spec = json.load(f)

    paths = spec["paths"]
    by_tag = defaultdict(list)
    for path, methods in paths.items():
        for method, op in methods.items():
            if method not in HTTP_METHODS:
                continue
            tags = op.get("tags", ["(태그 없음)"])
            for tag in tags:
                by_tag[tag].append((method.upper(), path, op.get("summary", "")))

    tag_order = [t["name"] for t in spec.get("tags", [])]
    extra_tags = sorted(t for t in by_tag if t not in tag_order)
    descriptions = {t["name"]: t.get("description", "") for t in spec.get("tags", [])}

    total_ops = sum(len(ops) for ops in by_tag.values())

    lines = [
        "# NAR API 레퍼런스",
        "",
        "백엔드(`https://api.nar.kr`)의 Swagger(OpenAPI 3.0.1) 스펙을 태그별로 정리한 목록이다.",
        "요청/응답 스키마 등 전체 상세는 원본 스펙 `docs/openapi_spec.json`을 참고한다 (이 문서는 요약).",
        "",
        f"- 스펙 버전: `{spec['info']['version']}`",
        f"- 총 {len(paths)}개 경로, {total_ops}개 엔드포인트",
        "- 갱신 방법: 리포지토리 루트 README의 \"API 스펙 갱신\" 참고",
        "",
    ]

    for tag in tag_order + extra_tags:
        ops = by_tag.get(tag)
        if not ops:
            continue
        lines.append(f"## {tag}")
        if descriptions.get(tag):
            lines.append(descriptions[tag])
            lines.append("")
        for method, path, summary in sorted(ops, key=lambda x: x[1]):
            suffix = f" — {summary}" if summary else ""
            lines.append(f"- **{method}** `{path}`{suffix}")
        lines.append("")

    with open(OUTPUT_PATH, "w") as f:
        f.write("\n".join(lines))

    print(f"저장 완료: {os.path.abspath(OUTPUT_PATH)}")
    print(f"{len(paths)}개 경로, {total_ops}개 엔드포인트, {len(tag_order) + len(extra_tags)}개 태그")


if __name__ == "__main__":
    main()
