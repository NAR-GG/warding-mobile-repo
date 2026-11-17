#!/usr/bin/env bash
# turbo 캐시가 Flutter 쪽 생성물을 잃지 않는지 검증한다.
#
# 왜 필요한가: turbo 의 `outputs` 는 패키지 밖을 캐시하지 못한다. 토큰 생성기가
# `apps/mobile/lib/core/theme/app_colors.dart` 를 직접 쓰면, 캐시 적중 시 그
# 파일이 복원되지 않는데 turbo 는 `FULL TURBO` 로 보고한다. 실제로 재현했다 —
# 생성물이 사라진 채 "성공"이 찍히고, 그 뒤 `flutter analyze` 가 터진다.
#
# 그래서 생성은 패키지 안(`build/`)에 하고 복사만 `sync:dart`(cache:false)로
# 분리했다. 이 스크립트는 그 분리가 유지되는지 본다.
set -euo pipefail

cd "$(dirname "$0")/../.."

DART=apps/mobile/lib/core/theme/app_colors.dart
PASS=0
FAIL=0

ok()   { printf '  ✅ %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  🔴 %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "turbo 캐시 ↔ Flutter 생성물"

# 캐시를 채워 둔다.
pnpm build > /dev/null 2>&1

# 1. 캐시가 적중하는 상태에서 생성물을 지워도 되돌아와야 한다.
rm -f "$DART"
pnpm build > /dev/null 2>&1
if [ -f "$DART" ]; then
  ok "캐시 적중 상태에서 app_colors.dart 가 복원된다"
else
  bad "캐시 적중 후 app_colors.dart 가 없다 — sync:dart 가 cache:false 인지 확인"
fi

# 2. build 태스크는 실제로 캐시되어야 한다 (안 되면 turbo 를 쓸 이유가 없다).
if pnpm build 2>&1 | grep -q 'warding-design-tokens:build: cache hit'; then
  ok "토큰 build 는 캐시된다"
else
  bad "토큰 build 가 캐시되지 않는다 — inputs/outputs 설정 확인"
fi

# 3. 소스를 바꾸면 Dart 까지 반영되어야 한다.
cp packages/design-tokens/source/theme.json /tmp/turbo-test-theme.bak
trap 'cp /tmp/turbo-test-theme.bak packages/design-tokens/source/theme.json; pnpm build >/dev/null 2>&1 || true' EXIT

python3 - <<'PY'
import json, collections
p = 'packages/design-tokens/source/theme.json'
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
d['color']['_turboProbe'] = {'$value': '#123456', '$type': 'color'}
open(p, 'w').write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
PY

pnpm build > /dev/null 2>&1
if grep -q '_turboProbe' "$DART"; then
  ok "소스 변경이 Dart 까지 반영된다"
else
  bad "소스를 바꿨는데 Dart 가 그대로다 — 캐시 무효화가 안 된다"
fi

echo
if [ "$FAIL" -gt 0 ]; then
  echo "🔴 실패 ${FAIL}건 / 통과 ${PASS}건"
  exit 1
fi
echo "✅ 전부 통과 (${PASS}건)"
