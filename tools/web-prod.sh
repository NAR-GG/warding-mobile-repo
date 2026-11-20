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

# 포트를 쓰는 프로세스 id. 없으면 빈 문자열.
#
# `|| true` 가 필요하다 — `lsof` 는 못 찾으면 exit 1 이고, `set -e` 아래에서
# 그대로 두면 "포트가 비어 있다" 는 정상 상황에 스크립트가 죽는다.
holders() { lsof -ti:"$PORT" 2>/dev/null || true; }

pids="$(holders)"
if [ -n "$pids" ]; then
  echo "▸ 포트 $PORT 이 이미 사용 중입니다."
  lsof -i:"$PORT" -sTCP:LISTEN -Pn 2>/dev/null | tail -n +2 \
    | awk '{print "   " $1 " (pid " $2 ")"}' || true
  echo

  # **대화형일 때만 묻는다.** pnpm 으로 감싸 돌리면 stdin 이 터미널이 아닐
  # 수 있는데, 그때 `read` 가 실패하면 `set -e` 가 스크립트를 조용히
  # 죽인다 — 질문도 안 보이고 끝난다(실제로 그렇게 겪었다).
  if [ -t 0 ]; then
    read -r -p "   종료하고 계속할까요? [y/N] " answer || answer=""
  else
    answer=""
    echo "   (대화형 입력이 아니라 묻지 않습니다)"
  fi

  case "$answer" in
    [yY]*)
      # shellcheck disable=SC2046 # 여러 pid 를 각각 넘겨야 한다
      kill -9 $pids 2>/dev/null || true
      sleep 1
      ;;
    *)
      echo
      echo "   그대로 두려면 이미 떠 있는 서버를 쓰면 됩니다."
      echo "   직접 끄려면:  lsof -ti:$PORT | xargs kill -9"
      exit 1
      ;;
  esac
fi

echo "▸ 빌드 중…"
pnpm web:build

echo "▸ 프로덕션 서버 시작 (http://localhost:$PORT)"
exec pnpm --filter warding-web exec next start -p "$PORT"
