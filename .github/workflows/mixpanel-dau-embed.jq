# 요약 지표 JSON → Discord embed 페이로드.
#
# `mixpanel-daily-dau.yml` 이 `jq -f` 로 호출한다. 분리 이유는
# `mixpanel-dau-summary.jq` 주석 참고.
#
# 입력: {date, cur, prev_dau, delta_text, mix_text, footer, pages_top}

# 분모가 0이면 비율을 아예 쓰지 않는다. "0명 중 0명 (0%)" 은 정보가 없는데
# 읽는 사람에게는 "전환율 0%" 라는 나쁜 신호처럼 보인다. 분모가 작을 때의
# 경고는 footer 가 담당한다.
def pct($n; $d): if ($d // 0) > 0 then " (\(($n / $d * 100) | round)%)" else "" end;

# `{key, n}` 목록을 한 줄로. 빈 목록에 "없음" 을 쓰는 이유는 Discord 가
# 빈 문자열 field value 를 400 으로 거부하기 때문이다.
def lines: if length == 0 then "없음" else map("\(.key) \(.n)") | join(" · ") end;

. as $s | $s.cur as $c |
{embeds: [{
  title: "📊 DAU \($s.date)",
  color: 3447003,
  fields: ([
    {name: "활성 사용자", value: "\($c.dau)", inline: true},
    {name: "전일 대비", value: $s.delta_text, inline: true},
    {name: "구성", value: $s.mix_text, inline: true},

    {name: "화면 TOP 5", value: ($s.pages_top | lines), inline: false},

    {name: "로그인 퍼널",
     value: ("login 진입 \($c.funnel.login_users)명"
             + " → 로그인 \($c.funnel.login_click)\(pct($c.funnel.login_click; $c.funnel.login_users))"
             + " / 비회원 \($c.funnel.guest_click)\(pct($c.funnel.guest_click; $c.funnel.login_users))"
             + "\n온보딩 진입 \($c.funnel.onboarding_users)명"
             + " → 완료 \($c.funnel.onboarding_done)\(pct($c.funnel.onboarding_done; $c.funnel.onboarding_users))"
             + " / 포기 \($c.funnel.onboarding_skip)\(pct($c.funnel.onboarding_skip; $c.funnel.onboarding_users))"),
     inline: false},

    {name: "참여",
     value: ("경기 카드 \($c.engagement.match_card)"
             + " · 글 카드 \($c.engagement.post_card)"
             + " · 평점 \($c.engagement.review_submit)"
             + " · 구독 \($c.engagement.subscribe)"),
     inline: false}
  ]

  # 주의 블록은 내용이 있을 때만 붙인다. 매일 "탈퇴 0건" 이 박혀 있으면
  # 눈이 그 줄을 건너뛰게 되고, 정작 1건이 뜬 날에도 안 보인다.
  + (if ($c.risk.withdraw > 0) or (($c.risk.permission | length) > 0) then
       [{name: "⚠️ 주의",
         value: ((if ($c.risk.permission | length) > 0
                  then "알림 권한: \($c.risk.permission | lines)\n" else "" end)
                 + "탈퇴 \($c.risk.withdraw)건"),
         inline: false}]
     else [] end)),
  footer: {text: $s.footer}
}]}
