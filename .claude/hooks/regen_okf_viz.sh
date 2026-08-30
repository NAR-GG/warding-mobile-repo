#!/usr/bin/env bash
# PostToolUse hook: warding-okf/ 안의 .md 파일이 편집되면 viz.html을 재생성한다.
# stdin 으로 hook payload(JSON)를 받는다. jq가 있으면 jq, 없으면 python으로 file_path 추출.
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BUNDLE="$ROOT/warding-okf"
GEN="$BUNDLE/gen_viz.py"

payload="$(cat)"

if command -v jq >/dev/null 2>&1; then
  f="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
else
  f="$(printf '%s' "$payload" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); ti=d.get("tool_input") or {}; tr=d.get("tool_response") or {}
    print(ti.get("file_path") or tr.get("filePath") or "")
except Exception:
    print("")' 2>/dev/null)"
fi

case "$f" in
  */warding-okf/*.md|warding-okf/*.md)
    [ -f "$GEN" ] && python3 "$GEN" "$BUNDLE" "$BUNDLE/viz.html" "Warding OKF" >/dev/null 2>&1 || true
    ;;
esac
exit 0
