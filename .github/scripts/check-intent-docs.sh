#!/usr/bin/env bash
# 사용법: check-intent-docs.sh <파일1> [파일2] ...
# intent.md/spec.md 파일에 필수 섹션 헤더가 다 있는지 검사한다.
set -euo pipefail

FAIL=0

check_file() {
  local file="$1"
  local base
  base=$(basename "$file")
  local -a required

  case "$base" in
    intent.md)
      required=("## Problem" "## Proposed outcome" "## Affected users and systems" "## Constraints" "## Open questions")
      ;;
    spec.md)
      required=("## Summary" "## Requirements" "## Design" "## Decisions" "## Out of scope" "## Open questions")
      ;;
    *)
      echo "건너뜀 (검사 대상 아님): $file"
      return 0
      ;;
  esac

  local h
  for h in "${required[@]}"; do
    if ! grep -qF "$h" "$file"; then
      echo "❌ $file: 필수 섹션 누락 — $h"
      FAIL=1
    fi
  done
}

if [ "$#" -eq 0 ]; then
  echo "검사할 파일 없음"
  exit 0
fi

for f in "$@"; do
  check_file "$f"
done

if [ "$FAIL" -eq 1 ]; then
  exit 1
fi
echo "✅ 모든 필수 섹션 확인됨"
