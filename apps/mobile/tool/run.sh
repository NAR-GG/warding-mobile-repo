#!/usr/bin/env bash
# 앱을 환경별로 띄운다.
#
#   tool/run.sh local   웹뷰가 로컬 Next 서버(localhost:3100)를 본다
#   tool/run.sh prod    배포된 웹을 본다 (기본값과 같다)
#
# **flavor 를 쓰지 않는다.** 조사한 실제 앱 8개 중 dev/prod 분리에 flavor 를
# 쓴 곳은 0개였고, flavor 를 쓰는 3개는 전부 번들ID가 갈리는 배포 채널
# (Play/F-Droid) 문제였다. flavor 를 넣으면 `shorebird release`·`patch` 네
# 곳에 `--flavor` 를 붙여야 하는데, 그건 태그를 밀어야 검증된다.
#
# 대신 Flutter 공식 CD 문서가 권하는 `--dart-define` 을 쓴다. 이 레포가
# `HOME_MOCKS` 로 이미 쓰는 축이고, **기본값이 운영이라 플래그를 빼먹어도
# 안전하다.**
set -euo pipefail

cd "$(dirname "$0")/.."

ENV="${1:-prod}"
shift || true

# 로컬 웹 서버 주소. `pnpm web:dev` 의 포트(3100)와 같아야 한다.
LOCAL_WEB_HOST="${LOCAL_WEB_HOST:-http://localhost:3100}"

case "$ENV" in
  local)
    DEFINES=(--dart-define=WEBVIEW_HOST="$LOCAL_WEB_HOST")
    echo "▸ local — 웹뷰가 $LOCAL_WEB_HOST 를 본다"
    # 서버가 안 떠 있으면 웹뷰가 까맣게만 나온다. 미리 알려 준다.
    if ! curl -s -o /dev/null --max-time 2 "$LOCAL_WEB_HOST" 2>/dev/null; then
      echo "  ⚠️  $LOCAL_WEB_HOST 에 응답이 없다. 다른 터미널에서 'pnpm web:dev' 를 먼저 띄워라."
    fi
    ;;
  prod)
    # 아무것도 넘기지 않는다 — ApiConfig 의 기본값이 운영이다.
    DEFINES=()
    echo "▸ prod — 웹뷰가 배포된 웹을 본다"
    ;;
  *)
    echo "사용법: tool/run.sh [local|prod] [추가 flutter run 인자...]" >&2
    exit 1
    ;;
esac

# 부팅된 시뮬레이터가 있으면 그걸 쓰고, 없으면 flutter 가 고르게 둔다.
DEVICE_ARGS=()
DEVICE=$(xcrun simctl list devices booted -j 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; \
    ids=[x['udid'] for v in d.values() for x in v]; print(ids[0] if ids else '')" 2>/dev/null || true)
if [ -n "$DEVICE" ]; then
  DEVICE_ARGS=(-d "$DEVICE")
fi

# bash 3.2(맥 기본)는 `set -u` 에서 빈 배열 전개를 오류로 본다. `+` 치환으로 피한다.
exec fvm flutter run \
  ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} \
  ${DEFINES[@]+"${DEFINES[@]}"} \
  "$@"
