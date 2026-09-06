# 경기 상세 champions API — 와드 수치·라인 퀘스트 아이템 요청

작성일: 2026-09-13 · 대상: `nar-back-repo`

`GET /api/mobile/live/games/{gameId}/champions` 응답에 앱(Team Summary, Player
Builds)에서 실데이터로 쓰려던 필드 두 가지가 있는데, 확인해보니 원인이 서로
다른 두 이슈였다. 코드까지 따라가서 원인을 특정했으니 바로 참고해달라.

---

## 1. `wardsPlaced` / `wardsDestroyed` 가 항상 null

### 증상

최근 종료 경기 13건(130명 픽, 8/21~9/2)을 `champions` API로 직접 조회하면 두
필드 모두 **모든 선수, 모든 경기에서 null**이다.

```bash
$ curl -s ".../api/mobile/live/games/117030752644841608/champions" | jq '.blueTeam.picks[0] | {playerName, wardsPlaced, wardsDestroyed}'
{
  "playerName": "T1 Doran",
  "wardsPlaced": null,
  "wardsDestroyed": null
}
```

### 원인 (코드로 확인함)

`V87__Add_ward_counts_to_live_participant_snapshot.sql` 마이그레이션 코멘트에
이미 답이 적혀 있었다:

```sql
-- 피드 details 프레임의 wardsPlaced / wardsDestroyed 를 분 스냅샷에 같이 적는다.
-- 지금까지 파싱하지 않고 버리던 값. 시야점수는 아니다(개수). 추가 컬럼만이라 롤아웃 중 옛 코드와 공존한다.
-- 과거 행은 NULL — 종료 경기는 CSV game_player_stat.wards_placed / wards_killed 로 채울 수 있다.
```

`LiveGameMinuteParticipantSnapshot.wardsPlaced` 필드 주석도 동일:
"V87 이전 행은 null". 즉:

- V87 마이그레이션 **이후** 저장되는 새 라이브 스냅샷부터는 값이 채워진다
  (라이브 진행 중인 경기로 재확인 필요 — 이번 조사는 전부 과거 종료 경기였음).
- **과거에 이미 저장된 스냅샷**(테스트한 8/21~9/2 경기 포함)은 컬럼 자체가
  없던 시점에 쌓인 행이라 영구히 null. 재수집이 아니면 못 채운다.
- `LiveStateQueryService.toParticipantState()` 가 이 스냅샷 엔티티를 그대로
  `LiveParticipantState` 로 옮기고, `MobileLiveGameService.toPick()` 이 그걸
  다시 `Pick.wardsPlaced/wardsDestroyed` 로 내보낸다 — 이 경로 자체는 문제
  없고, 소스(DB 스냅샷)가 비어 있는 것.

### 요청

마이그레이션 코멘트가 제안한 대로, **종료된 경기(과거 스냅샷)일 때는
`champions` 응답의 `wardsPlaced`/`wardsDestroyed` 를 `game_player_stat.wards_placed`
/ `wards_killed`(CSV 적재분, `/api/games/{recordGameId}/record` 가 쓰는 것과
같은 테이블)로 폴백해서 채워줄 수 있을까?

앱은 이미 `wardsPlaced`/`wardsDestroyed` 를 파싱해서 Team Summary 화면(5명
합산)까지 연결해 뒀다 — 이 폴백만 채워지면 프론트 쪽 추가 작업 없이 바로
반영된다. 라이브 진행 중 경기는 재확인해볼 예정이라, 혹시 라이브 경로도
이미 값이 비어 있다면 같이 알려달라.

---

## 2. 원딜 외 라인 퀘스트 아이템이 `questItemImageUrl` 로 안 잡힘

### 증상

2026 시즌엔 라인마다 퀘스트 완료 보상 아이템이 있다(예시 3개, 파일명이
아이템 id):

| id | 이름 | ddragon 태그 |
|---|---|---|
| 1220 | 강력 순간이동 (상단 공격로 퀘스트 보상) | `Lane` |
| 1209 | 정글 퀘스트 보상 | `Lane` |
| 1206 | 중단(미드) 공격로 퀘스트 보상 | `Lane` |
| 3008 | 탐욕의 군화 (원딜/바텀 퀘스트 보상, 신발) | `LifeSteal`, `SpellVamp`, `Boots` |

13경기(130명) 표본에서 `questItemImageUrl` 에 값이 있던 건 **원딜(3008)
1건뿐**, 탑·정글·미드 퀘스트(1206/1209/1220)는 `core`/`quest`/`trinket`
어디에도 한 번도 안 잡혔다.

### 원인 (코드로 확인함)

`ItemMetadataResolver.groupItems()` (`ItemMetadataResolver.java:88-126`)의
분류 규칙이 원딜 퀘스트 하나만 보고 설계돼 있다:

```java
// 퀘스트 칸(V26.01 바텀 퀘스트 보상)은 "신발이 7번째 칸으로 이동"하는 것이다 — 마지막에 산
// 아이템이 아니다. 피드 items[] 는 구매 순서라 신발이 2~4번째에 있으므로(실측 29건 전부),
// 코어가 6칸을 넘으면 신발을 뽑아 퀘스트 칸에 놓는다. 서포터 퀘스트 칸은 제어와드 전용이라
// 이미 소모품으로 빠져 있다(코어 7 인 서포터 실측 0건).
String questItemImageUrl = null;
if (core.size() > CORE_SLOTS) {
    questItemImageUrl = bootsInCore.isEmpty() ? core.get(CORE_SLOTS) : bootsInCore.get(0);
    ...
}
```

이 로직은 "코어 아이템이 7개(6칸 초과)면 그 신발을 퀘스트 칸으로 뺀다"는
규칙이라 **원딜의 신발 승급형 보상만** 감지한다. 탑/정글/미드 퀘스트 보상
(1206/1209/1220)은 신발이 아니라 `Lane` 태그가 붙은 별도 표식 아이템인데,
`groupItems()`는 `Trinket`/`Consumable`/`Boots` 세 태그만 검사해서 `Lane`
태그를 아예 모른다 — 코어 취급으로 빠지거나(스탯 없는 아이템이라 대개
코어 6칸을 못 채워 그냥 묻힘), 분류 로직 밖에서 사라진다.

### 요청

`groupItems()`에 `Lane` 태그 분기를 하나 추가해줄 수 있을까? 예:

```java
} else if (item.tags().contains("Lane")) {
    // 라인별 퀘스트 완료 보상(탑 1220·정글 1209·미드 1206). 원딜(3008)은
    // 기존 "코어 초과 시 신발 추출" 규칙으로 이미 처리되고 있음.
    questItemImageUrl = item.imageUrl();
}
```

`Lane` 태그 아이템은 코어 슬롯을 점유하지 않는 표식 아이템으로 보여서
(스탯이 없음), 원딜의 "코어 초과분에서 신발 추출" 규칙과 자연스럽게
공존할 수 있을 것 같다 — 다만 실제 필드 데이터 조합(예: 한 선수가 신발
승급 + Lane 아이템을 동시에 갖는 경우가 있는지)은 백엔드에서 한 번
확인해주면 좋겠다.

앱은 `questItemImageUrl` 하나만 렌더링하는 슬롯이라 위 필드 값만 채워지면
추가 작업 없이 바로 반영된다.

---

## 참고

- 이번 조사에 쓴 gameId: `117030752644841608`, `117030752644841602`,
  `117030752644841596`, `117030752644841590` 등 (2026-08-21 ~ 09-02 종료
  경기 13건, `GET /api/mobile/matches` 응답의 `games[].gameId`).
- 관련 백엔드 파일:
  - `src/main/java/com/toy/nar/app/lolesports/live/LiveStateQueryService.java`
  - `src/main/java/com/toy/nar/app/lolesports/live/entity/LiveGameMinuteParticipantSnapshot.java`
  - `src/main/resources/db/migration/V87__Add_ward_counts_to_live_participant_snapshot.sql`
  - `src/main/java/com/toy/nar/app/lolesports/live/ItemMetadataResolver.java`
- 앱 쪽 연동 코드: `lib/model/match_champion_pick.dart`
  (`ChampionPick.wardsPlaced/wardsDestroyed`, `ChampionTeam.summaryWithWards`),
  `lib/repository/match/match_detail_repository.dart`
  (`fetchChampionPick` — 확인용 `debugPrint` 로그 추가해 둠).
