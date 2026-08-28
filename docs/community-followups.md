# 커뮤니티 후속 작업 — 1차 범위 밖

커뮤니티 1차(PR #215, 정적 더미)에는 들어가지 않는다. **백엔드 연동이 끝난 뒤에
붙이는 작업**을 모아둔다.

관련 문서
- 규칙 원문 — `docs/community-policy.md`
- 심사 리스크 — `docs/community-store-review-risks.md`
- 백엔드 설계 — `nar-back-repo/docs/community-backend-design.md`

목업
- 알림함 — https://claude.ai/code/artifact/f8cccd47-ee32-4873-a4b6-18b85ed1401c
- 내 활동 — https://claude.ai/code/artifact/1f313c9d-4d1d-4bd6-b947-b10fab622fa3

---

# A. 알림함 분리

## 왜

지금 마이페이지 벨은 **마이구독으로 간다.** 틀린 설계는 아니었다. 알림 타입이
넷뿐이고 **전부 구독에서 파생**되기 때문이다.

```
SET_START / SET_END / LIVE_EVENT   ← 팀·경기 구독
PLAYER_SOLO_RANK_STARTED           ← 선수 구독
```

받을 알림이 전부 구독 결과물이라 "알림함 = 마이구독"이 우연히 성립했다.

**커뮤니티가 들어오면 바로 깨진다.** 내 글에 달린 댓글, 답글, 신고 처리 결과,
이용 제한 안내 — 전부 구독과 무관하다. 마이구독에 넣을 자리가 없고, 안 보내면
커뮤니티가 굴러가지 않는다. **댓글 알림 없는 커뮤니티는 사람이 다시 안 들어온다.**

## 구조

```
홈(경기일정) 헤더 🔔  →  알림함
                         [전체] [경기] [커뮤니티]
```

**진입점은 홈.** 마이페이지 안쪽에 두면 커뮤니티 댓글 알림을 확인하려고
마이페이지를 들어가야 한다. 지금은 알림이 전부 경기 관련이라 급하지 않았지만
댓글 알림은 즉시성이 있다.

마이페이지 벨은 **그대로 둔다** — 같은 알림함으로 보낸다. 진입점이 둘이어도
도착지가 하나면 혼란이 없다.

**미읽음 배지는 알림함에만.** 두 군데 배지가 있으면 사용자가 어디를 봐야 할지
모른다. 이게 알림함을 하나로 두는 진짜 이유다.

**마이구독은 성격을 좁힌다.** 지금 알림 목록을 **"내가 구독한 선수·팀의 최근
소식"** 으로 프레이밍한다. 데이터는 그대로고 의미만 좁아진다. 커뮤니티 알림은
여기 오지 않고, 배지도 달지 않는다.

**중복 노출은 의도적.** 선수 솔랭 알림이 알림함에도, 마이구독에도 나온다. 유튜브도
구독 탭과 알림함에 같은 영상이 뜬다. 조건은 둘이다 — 읽음 상태 공유
(`notificationReadUrl(id)` 가 이미 단건 처리라 그대로 된다), 배지는 한 곳만.

## 알림 타입

`ApiConfig.notificationsUrl({type, page, size})` 에 **타입 필터가 이미 있다.**
백엔드는 커뮤니티 타입 4종 추가뿐이다.

| 타입 | 탭 | 언제 | 상태 |
|---|---|---|---|
| `SET_START` / `SET_END` / `LIVE_EVENT` | 경기 | 구독 경기 | 있음 |
| `PLAYER_SOLO_RANK_STARTED` | 경기 | 구독 선수 솔랭 | 있음 |
| `COMMUNITY_COMMENT` | 커뮤니티 | 내 글에 댓글 | **추가** |
| `COMMUNITY_REPLY` | 커뮤니티 | 내 댓글에 답글 | **추가** |
| `COMMUNITY_REPORT_RESULT` | 커뮤니티 | 내 신고 처리 결과 | **추가** |
| `COMMUNITY_RESTRICTION` | 커뮤니티 | 이용 제한 안내 | **추가** |

## 헤더 자리 — 확인 필요

`ScheduleHeader` 우측이 `필터(44 원형)` + 조건부 `팀 아이콘(44 원형)` 이다. 벨을
더하면 **최대 3개**가 된다.

- 지금(2개): `44 + 8 + 44 = 96`
- 벨 추가(3개): `44 + 8 + 44 + 8 + 44 = 148`

375 기준으로는 여유가 있지만 **320px 에서 빠듯하다.** `AppBottomNav` 가 같은
이유로 overflow 났던 전례가 있다. **320·375·430 세 폭 회귀 테스트를 붙인다.**

## 구현 — 새로 만드는 게 아니라 옮기는 것

알림 목록 화면은 **이미 있다.** 마이구독 안의 알림 피드가 그것이다.

| 옮길 것 | 지금 위치 |
|---|---|
| 알림 카드 5종 | `screens/subscription/component/*_notification.dart` |
| 피드 ViewModel | `viewmodel/subscription/subscription_feed_viewmodel.dart` |
| 스와이프 삭제 · 딥링크 이동 · 전체 읽음/삭제 | `subscription_screen.dart` |

카드와 ViewModel 을 그대로 재사용하고 **화면만 새로 만들어 진입점을 나눈다.**

## 순서

1. `screens/notification/notification_screen.dart` — 알림함 + 타입 탭
2. 알림 카드·ViewModel 을 `subscription` 에서 공용 위치로 이동
3. 홈 헤더에 벨 + 미읽음 배지, 320px 회귀 테스트
4. 마이페이지 벨 → 같은 알림함으로 연결
5. 마이구독은 선수·팀 알림만, 배지 제거
6. (백엔드) 커뮤니티 알림 타입 4종 + 발송

---

# B. 마이페이지 내 활동 확장

마이페이지 > 내 활동에 이미 **내 평점·리뷰**가 있다. 커뮤니티가 들어오면 같은
자리에 셋이 더 붙는다.

| 항목 | 보여줄 것 | 동작 | 상태 |
|---|---|---|---|
| 내 평점·리뷰 | 선수 평점 + 코멘트 | 탭 → 상세 / 스와이프 삭제 | 있음 |
| **내가 쓴 글** | 게시판 · 제목 · 본문 2줄 · 반응 수 | 탭 → 글 상세 / 스와이프 삭제 | 추가 |
| **내가 쓴 댓글** | **원문 맥락 + 내 댓글** | 탭 → 그 댓글 위치 / 스와이프 삭제 | 추가 |
| **스크랩** | 글 목록과 같은 카드 | 탭 → 글 상세 / 스와이프 해제 | 추가 |

## 기존 패턴을 그대로 쓴다

`MypageCardSection` + `MypageCardItem(count:)` + `NarDetailHeader` + 날짜 헤더
그룹 + 총 건수 + 무한 스크롤. **내 평점·리뷰가 이미 이 구조다.** 새 패턴을 만들
이유가 없고, 옆에 나란히 놓였을 때 이질감도 없다.

## 화면별로 갈리는 것

**댓글은 원문 맥락을 위에 둔다.** "정글 동선 자체가 미드 우선이라" 만 보면 무슨
얘기였는지 알 수 없다. **어느 글에 단 댓글인지가 없으면 목록이 쓸모없어진다.**
게시판 · 원문 제목을 한 줄로 얹고 내 댓글은 좌측 보더로 구분한다.

**스크랩만 작성자를 보여준다.** 내가 쓴 글 목록에서 작성자는 전부 나라서 의미가
없다. 스크랩은 남의 글이라 누가 썼는지가 정보다. 같은 카드를 쓰되 메타 한 칸이
다르다.

**스와이프 결과가 다르다.** 글·댓글은 **삭제**(되돌릴 수 없음), 스크랩은
**해제**(언제든 다시 저장). 같은 제스처라 라벨과 색을 다르게 한다 — 삭제는
빨강 + `showNarConfirmDialog`, 해제는 회색 + 바로 실행.

**빈 상태에는 다음 행동을 준다.** "없어요"만 두면 막다른 길이다.

## API

전부 커서 페이지네이션. 내 것만 보는 목록이라 `member_id` 선행 인덱스로 돈다.

| 엔드포인트 | 인덱스 |
|---|---|
| `GET /api/mobile/me/community/posts` | `idx_community_post_member (member_id, id DESC)` |
| `GET /api/mobile/me/community/comments` | FK 가 만든 `(member_id)` 인덱스로 충분 (C-1) — **API 만 필요** |
| `GET /api/mobile/me/community/scraps` | `idx_community_scrap_member (member_id, id DESC, post_id)` — **이미 있음** |
| `GET /api/mobile/me/community/counts` | 세 건수 한 번에 |

**건수는 서버가 한 번에 준다.** 마이페이지 진입마다 목록 네 개를 세면 안 된다.
지금 `MypageViewModel.reviewCount` 가 하는 것과 같은 방식이다.

---

# C. 백엔드 쪽 확인 결과

작성 당시 미결로 적었던 둘은 **이미 정리돼 있었다.** 백엔드가 그 사이 구현까지
진행했다(`nar-back-repo` #487, #488 — V79 테이블 생성 + API 인수인계 문서).

### C-1. `community_comment` 의 `member_id` 인덱스 — **불필요**

처음에 "인덱스가 없어 '내가 쓴 댓글' 화면이 풀스캔" 이라고 적었는데 **사실이
아니었다.**

V79 DDL 에 `INDEX` 로 명시되지 않았을 뿐, FK(`fk_community_comment_member`)를
만들며 MySQL 이 `(member_id)` 인덱스를 자동 생성해 뒀다. 프로드에서 확인했다.

InnoDB 의 secondary index 는 리프에 PK 를 담으므로 `(member_id)` 는 실질적으로
`(member_id, id)` 다 — 커서 조건(`id < ?`)과 `ORDER BY id DESC`(backward index
scan)가 같은 인덱스 안에서 처리된다.

**따로 추가하면 중복이라 댓글 쓰기마다 유지 비용만 는다.** "내가 쓴 댓글"은
**API 만 붙이면 된다.**

### C-2. 글을 지우면 남의 댓글은 — **D-8 로 확정됨**

백엔드 설계에서 이미 정해졌다.

> 회원 하드 삭제 시 글·댓글은 `member_id NULL` + `ON DELETE SET NULL`.
> 화면은 **"탈퇴한 사용자"**. 행위 기록(좋아요·스크랩·투표)은 CASCADE.

우려했던 "남의 콘텐츠가 내 삭제로 소멸" 이 그 근거로 잡혀 있다. 글 자체는
`status` 소프트 삭제라 댓글이 살아남는다.

다만 **`Warding 계정 삭제 안내` 문서의 문구는 아직 실제 동작과 다르다.**

> 삭제되는 데이터: … 작성한 댓글·평점 … 탈퇴 즉시 삭제되며 별도 보관하지 않습니다

실제로는 개인정보(계정 식별자·닉네임)만 끊기고 **글·댓글 본문은 "탈퇴한
사용자" 로 남는다.** 개인정보처리방침 3조와 이 안내 문구를 실제 동작에 맞게
고쳐야 한다 — Play Data safety 의 삭제 정책 항목과도 맞아야 한다.

---

# D. 투표 — API 가 없어 2단계에서 뺐다

목업과 1차 더미에는 투표(주제 + 항목 2~5개 + "투표해야 결과 보기")가 있었다.
API 연동(2단계)에서 **화면과 모델을 지웠다** — 백엔드 커뮤니티 API 에 투표가
없어서, 남겨두면 눌러도 아무 일이 없는 버튼이 된다.

지웠던 것: `model/community_poll.dart`, `component/poll_view.dart`, 글쓰기
툴바의 '투표' 버튼, `communityPoll*` l10n 키. 되살릴 땐 git 히스토리에서
`feat/community-api-wiring` 직전 커밋을 보면 된다.

필요한 계약:

| 항목 | 내용 |
|---|---|
| 테이블 | `community_poll(post_id, question, hide_results_until_voted)`, `community_poll_option(poll_id, label, vote_count)`, `community_poll_vote(option_id, member_id)` — `(poll_id, member_id)` 유니크로 1인 1표 |
| 작성 | `POST /posts` 본문에 `poll` 오브젝트 추가 |
| 조회 | 상세 응답에 `poll { question, hideResultsUntilVoted, options[], myOptionId }` |
| 투표 | `POST /posts/{id}/poll/votes` — 항목 id, 멱등(다시 누르면 변경) |

`vote_count` 는 조회수와 같은 이유로 역정규화한다 — 막대를 그릴 때마다
`COUNT(*)` 를 돌릴 수는 없다.

---

# 순서 정리

이 문서의 작업은 전부 **커뮤니티 API 연동 이후**다.

| # | 작업 | 시점 |
|---|---|---|
| C-2 | 계정 삭제 안내·개인정보처리방침 문구를 D-8 동작에 맞게 수정 | 문서 작업, 언제든 |
| A | 알림함 분리 (앱 1~5, 백엔드 6) | 커뮤니티 연동 후 |
| B | 내 활동 확장 — 인덱스는 이미 있고 API 만 필요 | 커뮤니티 연동 후 |
| D | 투표 — 백엔드 계약부터 | 우선순위 낮음 |

## 백엔드가 남긴 미결 항목

`nar-back-repo/docs/community-api-handoff.md` 에 앱 쪽 답을 기다리는 항목이 둘 있다.

1. ~~**쿨다운 잠금 바를 넣을지**~~ — **해결됨.** 백엔드가 `/api/auth/me` 대신
   목록 응답에 `boardViewer { canWrite, reason, writableFrom }` 를 넣는 쪽으로
   구현했고, 앱이 그대로 쓴다(`CommunityListViewModel.canWrite`). 판정 주체가
   서버라 앱이 모르는 사유(쿨다운)도 잠금 바에 뜬다.
2. **마이페이지 내 글·댓글 추가 여부** — 이 문서의 B 가 그 답이다.
   스크랩까지 3종으로 간다.
