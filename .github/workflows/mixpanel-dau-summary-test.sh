#!/usr/bin/env bash
# mixpanel-dau-summary.jq 회귀 테스트.
#
# jq 는 타입·스코프 오류를 조용히 삼키는 편이라(예: `select(.x == .)` 가 빈
# 결과를 내고 끝난다) 눈으로 봐서는 0 이 "사실" 인지 "버그" 인지 구분이 안 된다.
# 실제로 온보딩 단계 집계가 그 `.` 스코프 때문에 전부 0 이 나온 적이 있다.
# 기대값을 박아 두면 다음에 같은 실수를 하면 여기서 걸린다.
#
# 실행: .github/workflows/mixpanel-dau-summary-test.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
JQ_FILE=.github/workflows/mixpanel-dau-summary.jq
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT

fail=0
check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok   $label"
  else
    echo "  FAIL $label"
    echo "       기대: $expected"
    echo "       실제: $actual"
    fail=1
  fi
}

# 하루치 샘플. 자동 이벤트($ae_*)·우리 이벤트·버전 있는/없는 사용자를 섞는다.
cat > "$FIX/day.jsonl" <<'EOF'
{"event":"page_view","properties":{"distinct_id":"u1","time":100,"location_page":"home","app_version":"1.0.36+86"}}
{"event":"page_view","properties":{"distinct_id":"u1","time":200,"location_page":"match_detail","app_version":"1.0.36+86"}}
{"event":"match_card_click","properties":{"distinct_id":"u1","time":150,"location_page":"home","app_version":"1.0.36+86"}}
{"event":"match_card_click","properties":{"distinct_id":"u1","time":160,"location_page":"home","app_version":"1.0.36+86"}}
{"event":"page_view","properties":{"distinct_id":"u2","time":300,"location_page":"login","app_version":"1.0.36+86"}}
{"event":"login_button_click","properties":{"distinct_id":"u2","time":310,"location_page":"login","login_method":"kakao","app_version":"1.0.36+86"}}
{"event":"page_view","properties":{"distinct_id":"u2","time":320,"location_page":"onboarding","app_version":"1.0.36+86"}}
{"event":"section_view","properties":{"distinct_id":"u2","time":321,"location_page":"onboarding","location_section":"league","app_version":"1.0.36+86"}}
{"event":"section_view","properties":{"distinct_id":"u2","time":322,"location_page":"onboarding","location_section":"team","app_version":"1.0.36+86"}}
{"event":"section_view","properties":{"distinct_id":"u2","time":323,"location_page":"onboarding","location_section":"player","app_version":"1.0.36+86"}}
{"event":"section_view","properties":{"distinct_id":"u2","time":324,"location_page":"onboarding","location_section":"notification","app_version":"1.0.36+86"}}
{"event":"next_button_click","properties":{"distinct_id":"u2","time":330,"location_page":"onboarding","step":"notification","app_version":"1.0.36+86"}}
{"event":"page_view","properties":{"distinct_id":"u3","time":400,"location_page":"login","app_version":"1.0.35+85"}}
{"event":"guest_start_button_click","properties":{"distinct_id":"u3","time":410,"location_page":"login","app_version":"1.0.35+85"}}
{"event":"page_view","properties":{"distinct_id":"u3","time":420,"location_page":"onboarding","app_version":"1.0.35+85"}}
{"event":"section_view","properties":{"distinct_id":"u3","time":421,"location_page":"onboarding","location_section":"league","app_version":"1.0.35+85"}}
{"event":"section_view","properties":{"distinct_id":"u3","time":422,"location_page":"onboarding","location_section":"team","app_version":"1.0.35+85"}}
{"event":"skip_button_click","properties":{"distinct_id":"u3","time":430,"location_page":"onboarding","step":"team","app_version":"1.0.35+85"}}
{"event":"push_permission_button_click","properties":{"distinct_id":"u2","time":325,"location_page":"onboarding","permission_result":"os_granted","app_version":"1.0.36+86"}}
{"event":"withdraw_button_click","properties":{"distinct_id":"u4","time":500,"location_page":"withdraw","app_version":"1.0.36+86"}}
{"event":"$ae_session","properties":{"distinct_id":"u5","time":600}}
{"event":"$ae_first_open","properties":{"distinct_id":"u5","time":601}}
EOF

echo "[1] 정상 집계"
OUT=$(jq -sf "$JQ_FILE" "$FIX/day.jsonl")
j() { printf '%s' "$OUT" | jq -c "$1"; }

# DAU 는 자동 이벤트도 센다 → u1..u5 = 5명
check "dau (자동 이벤트 포함)" "5" "$(j '.dau')"
check "events_total" "22" "$(j '.events_total')"
# 자동 이벤트 2건 제외
check "events_ours" "20" "$(j '.events_ours')"

# 퍼널은 고유 사용자 수
check "funnel.login_users" "2" "$(j '.funnel.login_users')"
check "funnel.login_click" "1" "$(j '.funnel.login_click')"
check "funnel.guest_click" "1" "$(j '.funnel.guest_click')"
check "funnel.onboarding_done" "1" "$(j '.funnel.onboarding_done')"
check "funnel.onboarding_skip" "1" "$(j '.funnel.onboarding_skip')"

# 참여는 행동 횟수 → u1 이 2번 눌렀으므로 2
check "engagement.match_card (횟수)" "2" "$(j '.engagement.match_card')"

# 온보딩 단계: u2 가 4단계 전부, u3 는 league/team 까지
check "onboarding_steps" \
  '[{"key":"league","n":2},{"key":"team","n":2},{"key":"player","n":1},{"key":"notification","n":1}]' \
  "$(j '.onboarding_steps')"
check "onboarding_skip_by_step" '[{"key":"team","n":1}]' "$(j '.onboarding_skip_by_step')"

# 버전은 사용자 수 기준. 자동 이벤트만 보낸 u5 는 버전이 없다.
check "versions" '[{"key":"1.0.36+86","n":3},{"key":"1.0.35+85","n":1}]' "$(j '.versions')"
check "no_version" "1" "$(j '.no_version')"

# 이탈 화면 = 사용자별 마지막 page_view
check "exit_pages" \
  '[{"key":"onboarding","n":2},{"key":"match_detail","n":1}]' \
  "$(j '.exit_pages')"

check "risk.withdraw" "1" "$(j '.risk.withdraw')"

echo "[2] 빈 하루(이벤트 0건)"
: > "$FIX/empty.jsonl"
E=$(jq -sf "$JQ_FILE" "$FIX/empty.jsonl")
check "dau" "0" "$(printf '%s' "$E" | jq -c '.dau')"
check "pages" "[]" "$(printf '%s' "$E" | jq -c '.pages')"
check "exit_pages" "[]" "$(printf '%s' "$E" | jq -c '.exit_pages')"
check "versions" "[]" "$(printf '%s' "$E" | jq -c '.versions')"
# 단계는 항상 4칸을 유지해야 알림 렌더가 깨지지 않는다
check "onboarding_steps 길이" "4" "$(printf '%s' "$E" | jq -c '.onboarding_steps | length')"

echo "[3] 자동 이벤트만 있는 하루 (계측 미도달 구버전)"
printf '{"event":"$ae_session","properties":{"distinct_id":"x1","time":1}}\n' > "$FIX/auto.jsonl"
A=$(jq -sf "$JQ_FILE" "$FIX/auto.jsonl")
check "dau (앱은 켰다)" "1" "$(printf '%s' "$A" | jq -c '.dau')"
check "events_ours" "0" "$(printf '%s' "$A" | jq -c '.events_ours')"
check "no_version (버전 미상)" "1" "$(printf '%s' "$A" | jq -c '.no_version')"

if [ "$fail" -ne 0 ]; then
  echo
  echo "실패한 검사가 있다."
  exit 1
fi
echo
echo "전부 통과."
