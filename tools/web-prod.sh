#!/usr/bin/env bash
#
# 웹을 **프로덕션 모드**로 띄운다 — 실제 속도를 볼 때 쓴다.
#
# `web:dev` 와 왜 나누는가: dev 서버는 번들을 쪼개지 않고 HMR·소스맵을 전부
# 싣는다. 실측(2026-11-20) 결과 같은 화면이 **dev 1,899KB / prod 111KB** 로
# 17배 차이였고, 로드도 423ms 대 75ms 였다. 체감 속도를 보려면 이쪽이다.
#
# 대신 **고쳐도 반영되지 않는다**(고정된 빌드를 서빙한다). UI 를 반복해
# 고칠 때는 `pnpm web:dev` 를 쓴다.
set -euo pipefail

PORT=3100

# 포트가 막혀 있으면 누가 쓰는지 알려 준다 — EADDRINUSE 스택만 보면
# 직전에 띄운 dev 서버가 범인인지 알 수 없다.
if lsof -ti:"$PORT" >/dev/null 2>&1; then
  echo "▸ 포트 $PORT 이 이미 사용 중입니다."
  lsof -i:"$PORT" -sTCP:LISTEN -Pn | tail -n +2 | awk '{print "   " $1 " (pid " $2 ")"}'
  echo
  read -r -p "   종료하고 계속할까요? [y/N] " answer
  case "$answer" in
    [yY]*)
      lsof -ti:"$PORT" | xargs kill -9 2>/dev/null || true
      sleep 1
      ;;
    *)
      echo "   중단합니다."
      exit 1
      ;;
  esac
fi

echo "▸ 빌드 중…"
pnpm web:build

echo "▸ 프로덕션 서버 시작 (http://localhost:$PORT)"
exec pnpm --filter warding-web exec next start -p "$PORT"
