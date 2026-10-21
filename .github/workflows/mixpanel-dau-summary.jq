# Mixpanel 원시 export(JSONL) 한 날짜분 → 요약 지표 JSON.
#
# `mixpanel-daily-dau.yml` 이 `jq -sf` 로 호출한다. 워크플로우 YAML 안에
# 인라인으로 두지 않는 이유는, 셸 heredoc 안의 jq 는 문법 오류가 나도 매일
# 09:00 에 실 실행으로만 드러나고 에디터 하이라이팅도 안 받기 때문이다.
# 파일로 빼 두면 `jq -nf` 로 로컬에서 바로 검증할 수 있다.
#
# 무료 플랜에서 조회(Query) API 가 402 로 막혀 있어 집계를 우리가 한다.
# 자세한 배경은 호출하는 워크플로우의 주석 참고.

# Mixpanel 자동 이벤트($ae_session, $ae_first_open 등)는 우리가 심은 게 아니다.
# 화면·퍼널·참여 집계에 섞이면 사용자 행동 숫자가 부풀어 오른다.
#
# 단 DAU 는 자동 이벤트도 센다 — `$ae_session` 이 찍혔다는 건 앱을 켰다는
# 뜻이고, 그게 바로 '활성 사용자'의 정의다. 화면을 한 번도 안 보고 끈
# 사용자를 DAU 에서 빼면 숫자가 실제보다 작아진다.
def ours: map(select(.event | startswith("$") | not));

def uniq_users: map(.properties.distinct_id // empty) | unique;

# 값이 없는 이벤트는 버린다(`// empty`). 키가 안 실린 이벤트까지 묶으면
# `null` 이 하나의 항목처럼 집계돼 TOP 목록에 올라온다.
def count_by(f):
  ours | map(f // empty) | group_by(.) | map({key: .[0], n: length})
  | sort_by(-.n, .key);

def ev($name): ours | map(select(.event == $name));

# 퍼널 단계는 **고유 사용자 수**로 센다. 이벤트 수로 세면 한 사람이 로그인
# 화면을 두 번 본 것만으로 전환율이 100% 를 넘는다.
def page_users($p): ev("page_view") | map(select(.properties.location_page == $p)) | uniq_users | length;

{
  dau: (uniq_users | length),
  events_total: length,
  events_ours: (ours | length),

  # 화면 조회수. page_view 만 센다 — section_view 는 화면이 아니라 화면 안
  # 섹션이라 같은 축에 두면 중복 집계가 된다.
  pages: count_by(select(.event == "page_view") | .properties.location_page),

  funnel: {
    login_users: page_users("login"),
    login_click: (ev("login_button_click") | uniq_users | length),
    guest_click: (ev("guest_start_button_click") | uniq_users | length),
    onboarding_users: page_users("onboarding"),

    # `step=notification` 인 next_button_click 이 온보딩 완료 지표다.
    # 마지막 단계에서 버튼 라벨이 '와딩 시작하기' 로 바뀌고 같은 핸들러가
    # 완료를 처리한다(이벤트 설계 문서 23번, OnboardingViewModel.goNext 주석).
    onboarding_done: (ev("next_button_click")
                      | map(select(.properties.step == "notification"))
                      | uniq_users | length),

    # skip 은 단계 건너뛰기가 아니라 온보딩 전체 포기다(설계 문서 24번).
    onboarding_skip: (ev("skip_button_click") | uniq_users | length)
  },

  # 참여는 사용자 수가 아니라 **행동 횟수**다. 한 사람이 경기 카드를 5번
  # 눌렀다면 그게 참여의 실체라, 여기서 유니크로 접으면 정보가 사라진다.
  engagement: {
    match_card: (ev("match_card_click") | length),
    post_card: (ev("post_card_click") | length),
    review_submit: (ev("review_submit_button_click") | length),
    subscribe: (ev("subscribe_button_click") | length)
  },

  risk: {
    # `os_permanently_denied` 는 설정 앱으로 앱을 벗어나는 이탈 지점이라
    # OS 거부와 묶지 않고 값을 그대로 보여준다.
    permission: count_by(select(.event == "push_permission_button_click")
                         | .properties.permission_result),
    withdraw: (ev("withdraw_button_click") | uniq_users | length)
  },

  # 전일 대비 신규/재방문을 가르는 데만 쓴다. 호출부가 두 날짜의 이 배열을
  # 차집합한다.
  users: uniq_users
}
