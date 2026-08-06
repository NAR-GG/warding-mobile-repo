# 백엔드 응답 성능 개선 요청 (모바일 앱)

작성일: 2026-08-06 · 대상: `api.nar.kr` (nginx 1.24.0 / Ubuntu)

앱에서 "초기 접속·경기 상세가 느리다"는 문의를 받고 원인을 재봤다.
**서버 처리 시간 자체는 문제가 없다** — TTFB 기준 대부분 100ms 안팎이다.
앱 쪽 지연 요인(스플래시 고정 대기, 커넥션 미재사용, 직렬 호출)은 앱에서
수정했고, 아래 두 가지는 서버 설정이라 백엔드 도움이 필요하다.

## 실측값

로컬(유선, 서울) 기준. 모바일 셀룰러에서는 왕복 지연이 몇 배로 늘어난다.

| 엔드포인트 | TTFB | 응답 크기 |
|---|---|---|
| `GET /api/mobile/schedules/calendar?month=…&league=ALL` | 72ms | **33,738 B** |
| `GET /api/mobile/schedules/calendar?month=…&league=LCK` | 68ms | 7,835 B |
| `GET /api/mobile/live/games/{gameId}/events` | 274ms | **13,122 B** |
| `GET /api/mobile/schedules/filters?league=LCK` | — | 2,054 B |
| `GET /api/mobile/matches/{matchId}/games` | 66ms | 523 B |

---

## 1. gzip 응답 압축이 꺼져 있다 (우선순위 높음)

`Accept-Encoding: gzip, deflate, br` 를 보내도 응답에 `Content-Encoding` 헤더가
없고 본문이 원본 크기 그대로 온다.

```
$ curl -s -H "Accept-Encoding: gzip" -D - \
    "https://api.nar.kr/api/mobile/schedules/calendar?month=2026-08&league=ALL"
Server: nginx/1.24.0 (Ubuntu)
Content-Length: 33738          ← 압축되지 않음
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
(Content-Encoding 헤더 없음)
```

JSON은 압축률이 높아 대개 1/5~1/8로 줄어든다. 위 33KB 응답은 5KB 안팎이
될 것으로 보인다. 이 응답은 **앱 첫 화면(경기 일정)이 진입 즉시 부르는 것**이라
체감에 직접 영향을 준다.

**요청**: nginx에서 `application/json` 에 대해 gzip을 켜 주세요.

```nginx
gzip on;
gzip_types application/json;
gzip_min_length 1024;   # 작은 응답은 압축 오버헤드가 더 큼
gzip_vary on;           # 캐시가 인코딩별로 분리되도록
gzip_comp_level 5;      # 5 정도면 압축률 대비 CPU 부담이 적음
```

> WAS(Spring Boot)에서 `server.compression.enabled=true` 로 켜는 방법도 있지만,
> nginx가 앞단에 있으므로 nginx에서 처리하는 편이 낫다. 둘 다 켜면 이중 압축
> 시도로 불필요한 CPU를 쓴다.

---

## 2. 모든 응답에 `Cache-Control: no-store` 가 걸려 있다

확인한 엔드포인트 전부 동일한 헤더를 내려준다.

```
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
```

이 값은 Spring Security의 기본 헤더 설정이 인증/비인증 구분 없이 전 경로에
적용될 때 나오는 전형적인 형태다. 인증이 필요한 개인 데이터(`/me/**`)에는
맞는 설정이지만, 아래는 **인증이 필요 없는 공개 데이터**인데도 캐싱이
원천 차단된다.

| 엔드포인트 | 성격 | 제안 |
|---|---|---|
| `/api/mobile/schedules/calendar` | 월 단위 일정 | 진행 중 경기 반영 필요 → `max-age=30` 정도 |
| `/api/mobile/schedules/filters` | 리그·팀 목록 | 거의 안 바뀜 → `max-age=3600` + `ETag` |
| `/api/mobile/matches/{id}/games` | 세트 목록 | 종료 경기는 불변 → `max-age=300` |
| `/api/mobile/live/games/{id}/events` | 라이브 이벤트 | 실시간 → 현행 유지 가능 |
| `/api/categories/tree` | 카테고리 트리 | 거의 안 바뀜 → `max-age=3600` + `ETag` |

**요청**:
- 위 공개 엔드포인트에 한해 `no-store` 를 걷어내고 짧은 `max-age` 를 주세요.
- 특히 변경이 드문 `filters` / `categories/tree` 는 `ETag` 를 함께 주시면
  앱이 `If-None-Match` 로 304를 받아 본문 전송을 아예 건너뛸 수 있습니다.
- `/api/mobile/me/**`, `/api/auth/**` 등 인증 경로는 **현행 `no-store` 유지**가
  맞습니다.

---

## 3. (참고) 응답 형태 관련

`GET /api/mobile/matches/{matchId}/games` 응답에 팀 정보(`teamA`/`blueTeam`)가
포함되지 않는 경우, 앱은 화면을 채우려고 `GET /api/mobile/matches/{matchId}` 를
한 번 더 호출한다. 현재는 앱에서 두 요청을 병렬로 띄우도록 고쳐 왕복이
더해지지는 않지만, `games` 응답에 팀 정보가 항상 포함된다면 요청 자체를
하나 줄일 수 있다. 우선순위는 낮다.

---

## 앱에서 이미 처리한 것 (참고용)

백엔드 작업과 무관하게 앱 측에서 아래를 수정했다.

- 스플래시의 고정 2초 대기를 제거하고, 그 시간에 첫 화면 데이터를 미리 받도록 변경
- 요청마다 새로 맺던 TCP/TLS 연결을 공용 클라이언트로 재사용 (keep-alive)
- 경기 상세의 `games` / `matches/{id}` 순차 호출을 병렬로 변경
- 전 요청에 15초 타임아웃 적용 (기존에는 사실상 무제한 대기)
