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

    # 로그인·비회원을 **둘 다** 누른 사용자. 두 버튼이 같은 화면에 있어
    # 배타적이지 않다(로그인에 실패하거나 되돌아 나와 비회원으로 시작하는
    # 경로가 있다). 이 값을 같이 보여주지 않으면 두 비율의 합이 100% 를
    # 넘는 게 집계 오류처럼 보인다 — 2026-10-21 자 알림이 100%/23% 로 나왔다.
    login_and_guest: ([(ev("login_button_click") | uniq_users),
                       (ev("guest_start_button_click") | uniq_users)]
                      | .[0] - (.[0] - .[1]) | length),

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
    subscribe: (ev("subscribe_button_click") | length),

    # 월즈 솔랭에서 켠 알림 신청만 따로 센다. 전체 `subscribe` 에 묶어 두면
    # 구독 설정 화면 수치에 섞여 이 화면의 신호가 안 보인다.
    # `is_on == true` 만 — 해제는 신청이 아니다.
    worlds_subscribe: (ev("subscribe_button_click")
                       | map(select(.properties.location_page == "worlds_solo"
                                    and .properties.is_on == true))
                       | length)
  },

  risk: {
    # `os_permanently_denied` 는 설정 앱으로 앱을 벗어나는 이탈 지점이라
    # OS 거부와 묶지 않고 값을 그대로 보여준다.
    permission: count_by(select(.event == "push_permission_button_click")
                         | .properties.permission_result),
    withdraw: (ev("withdraw_button_click") | uniq_users | length)
  },

  # 앱 버전 분포. `app_version` 은 super property 라 모든 이벤트에 붙는다
  # (자동 이벤트에도). 그래서 `ours` 가 아니라 전체에서 센다 — 계측이 안
  # 들어간 구버전은 자동 이벤트만 보내므로, ours 로 세면 그 버전이 아예
  # 안 보여서 "구버전이 얼마나 남았나" 를 못 본다.
  #
  # 사용자 수로 센다(이벤트 수로 세면 헤비 유저 한 명이 버전 분포를 왜곡한다).
  #
  # **사용자당 대표 버전 하나**만 센다. 그냥 이벤트를 버전으로 묶으면 한 명이
  # 여러 칸에 중복으로 들어가, 버전 분포 합이 DAU 를 넘어선다 —
  #   · 자동 이벤트(버전 없음) + 우리 이벤트(버전 있음)가 섞인 사용자는
  #     `versions` 와 `no_version` **양쪽**에 잡힌다
  #   · 같은 날 앱을 업데이트하면 두 버전에 모두 잡힌다
  # 그러면 "구버전이 얼마나 남았나" 를 읽을 수 없는데, 그게 이 지표를 넣은
  # 이유 자체다. 대표값은 **그날 마지막으로 본 버전**으로 한다(업데이트한
  # 사용자는 새 버전 쪽에 세는 게 롤아웃 추적에 맞다).
  versions: ((map(select(.properties.distinct_id != null))
              | group_by(.properties.distinct_id)
              | map(map(select(.properties.app_version != null))
                    | if length == 0 then empty
                      else (sort_by(.properties.time) | last.properties.app_version)
                      end))
             | group_by(.) | map({key: .[0], n: length})
             | sort_by(-.n, .key)),

  # 모든 이벤트에 `app_version` 이 없는 사용자 수. super property 를 심기 전
  # 빌드다(= 계측 미도달 구버전). 이 값이 DAU 의 대부분이면 다른 지표가 0 인
  # 게 집계 버그가 아니라 사실이라는 뜻이다 — 2026-10-20 에 실제로 겪었다.
  #
  # 버전이 **하나라도** 있으면 위 `versions` 쪽에만 센다. 그래서
  # `versions` 합 + `no_version` = DAU 가 성립한다(해석의 전제).
  no_version: (map(select(.properties.distinct_id != null))
               | group_by(.properties.distinct_id)
               | map(select(all(.[]; .properties.app_version == null)))
               | length),

  # 이탈 화면: 그 사용자의 **마지막** page_view 가 어느 화면이었나.
  # 하루 경계로 자르는 근사치다(자정 넘겨 계속 쓴 세션은 그날 마지막 화면이
  # 이탈로 잡힌다). 그래도 "어디서 앱을 덮는가" 의 신호로는 쓸 만하다.
  exit_pages: (ev("page_view")
               | map(select(.properties.location_page != null))
               | group_by(.properties.distinct_id)
               | map(sort_by(.properties.time) | last.properties.location_page)
               | group_by(.) | map({key: .[0], n: length})
               | sort_by(-.n, .key)),

  # 온보딩 단계별 도달 사용자 수. `section_view` 의 location_section 이
  # league/team/player/notification 이다.
  #
  # 주의: 권한이 이미 허용된 사용자는 notification 단계가 화면을 그리지 않고
  # 통과해 `section_view` 가 안 찍힌다(설계 21번, OnboardingViewModel 주석).
  # 그래서 notification 도달 수는 **실제보다 작게** 나오고, player →
  # notification 구간 이탈률은 과대평가된다. 이 왜곡은 보정할 방법이 없어
  # (통과한 사용자를 식별할 이벤트가 없다) 숫자를 그대로 두고 알림에
  # 주석을 달아 둔다.
  # 단계 이름을 `$step` 으로 묶어 쓴다. `select(... == .)` 로 쓰면 그 `.` 이
  # 단계 이름이 아니라 **순회 중인 이벤트**를 가리켜 전부 0 이 된다.
  onboarding_steps: ((ev("section_view")
                      | map(select(.properties.location_page == "onboarding"))) as $sv
    | ["league", "team", "player", "notification"]
    | map(. as $step
          | {key: $step,
             n: ($sv
                 | map(select(.properties.location_section == $step))
                 | uniq_users | length)})),

  # 단계별 포기(skip). `step` 이 "어느 단계에서 포기했는지" 다(설계 24번).
  #
  # 여기도 **고유 사용자 수**다. 이벤트 수로 세면 한 명이 같은 날 team 에서
  # 두 번 포기했을 때 2 로 보이는데, 같은 알림의 `funnel.onboarding_skip` 은
  # 1 이라 두 숫자가 어긋난다. 단위를 맞춰 둬야 나란히 읽을 수 있다.
  onboarding_skip_by_step: (ev("skip_button_click")
                            | map(select(.properties.step != null))
                            | group_by(.properties.step)
                            | map({key: .[0].properties.step, n: (. | uniq_users | length)})
                            | sort_by(-.n, .key)),

  # 전일 대비 신규/재방문을 가르는 데만 쓴다. 호출부가 두 날짜의 이 배열을
  # 차집합한다.
  users: uniq_users
}
