# 이미지 최적화 요청 — 챔피언·선수·팀 로고를 Cloudinary 로 (모바일 앱)

작성일: 2026-08-19 · 대상: `nar-back-repo`

앱에서 "경기 상세 이미지가 느리다"는 제보를 받고 조사했다. 앱에서 할 수 있는
것(디코딩 크기 제한·https 승격·경량 변형 선택)은 이미 해봤지만 **병목이 앱
바깥에 있어** 백엔드 도움이 필요하다.

**요청 한 줄**: 챔피언·선수·팀 로고 이미지를 Cloudinary 에 올려서 쓰면 좋겠다.
이미 `PlayerImageStorageService` 가 쓰고 있는 파이프라인을 넓히는 것이라
새로 도입할 것은 없고, 무료 티어 안에서 충분하다(아래 계산).

---

## 지금 상태

세 종류 모두 외부 원본을 그대로 앱에 내려주고 있다.

| 이미지 | 개수 | 호스트 | 원본 | 앱 표시 |
|---|---|---|---|---|
| 팀 로고 | 10 | `static.lolesports.com` | **1426×1426 / 127 KB** | **40 px** |
| 선수 | 102 | `static.lolesports.com` (83건) | **408 KB** | 44 px |
| 챔피언 | 173 | `cdn.communitydragon.org` | 1280×720 / 96 KB | 60×101 px |

선수만 일부(11명)가 Cloudinary 를 타고 있다 — 백오피스에서 수동 업로드한
분이다. 나머지는 전부 원본이다.

```
선수 102건 중  static.lolesports.com 83 · res.cloudinary.com 11 · 이미지 없음 8
```

### 실측

10장 동시 요청 기준(Flutter 와 같은 User-Agent):

| | 합계 용량 | 소요 |
|---|---|---|
| 챔피언 10장 (현재) | 963 KB | **1.27 s** |
| 팀 로고 10개 (현재) | 352 KB | 0.95 s |
| 선수 1명 (현재) | 408 KB | 0.82 s |
| **Cloudinary 경유 (기존 11명 중 1명)** | **20 KB** | **0.03 s** |

---

## 왜 앱에서 못 고치나

### 원본 호스트가 리사이즈·포맷 변환을 지원하지 않는다

```
$ curl -sI "https://static.lolesports.com/players/....png?w=128"
content-length: 389656              # 리사이즈 파라미터 무시

$ curl -sI "https://static.lolesports.com/players/....png" -H "Accept: image/webp"
content-type: binary/octet-stream   # WebP 변환 없음, 캐시 헤더도 없음
```

앱에서 디코딩 크기를 줄여도 **다운로드 용량은 그대로**라 체감이 바뀌지 않는다
(실제로 시도했다가 화질만 나빠져 되돌렸다).

### 병목이 파일 크기가 아니라 CDN 응답 대기다

같은 이미지를 반복 요청하며 "첫 바이트까지 대기"와 "전송"을 나눠 재면:

```
CommunityDragon (챔피언)
  1회차  대기 0.76s  전송 0.24s   Age=없음   Cache-Control: max-age=3600
  2회차  대기 0.48s  전송 0.03s   Age=없음
  3회차  대기 0.16s  전송 0.00s   Age=0      ← 세 번째에야 엣지에 캐시됨

Cloudinary (선수)
  1회차  대기 0.09s  전송 0.00s   Cache-Control: max-age=2592000, immutable
  2회차  대기 0.11s  전송 0.00s
  3회차  대기 0.12s  전송 0.00s   ← 처음부터 일정하게 빠름
```

전송은 0.2초 안쪽인데 **응답이 시작될 때까지 0.5~0.9초**가 걸린다. 엣지 캐시가
잘 적중하지 않아 매번 원본까지 가는 것으로 보이고, `max-age=3600`(1시간)이라
재방문 때도 금방 다시 받는다.

그래서 챔피언 이미지를 절반 크기 변형으로 바꿔 봐도(963→475 KB) 체감이
1.27s→0.78s 로 크게 달라지지 않았다. **파일을 줄여도 대기 시간은 그대로다.**

---

## 요청: Cloudinary 에 올려서 쓰기

### 무엇이 좋아지나

1. **표시 크기로 받을 수 있다** — URL 에 `w_200` 처럼 넣으면 그 크기로 온다.
   지금은 40px 자리에 1426px 원본을 받고 있다.
2. **포맷 자동 변환** — `f_auto` 로 WebP 지원 기기엔 WebP 를 준다(실측 408 KB
   PNG → 20 KB WebP).
3. **CDN 응답이 빠르다** — 위 실측대로 대기 0.09s 대.
4. **캐시를 길게 걸 수 있다** — 반환 URL 에 버전(`/v{ts}/`)이 박혀 오므로 이미지를
   교체하면 URL 이 바뀐다. 그래서 `max-age=2592000, immutable`(30일)을 안전하게
   쓸 수 있다.
5. **비율 크롭이 서버에서 된다** — `ar_60:101,c_fill` 같은 옵션으로 카드 비율에
   맞춰 잘라 줄 수 있어, 앱에서 잘림을 신경 쓰지 않아도 된다.

### 무료 티어로 충분하다

무료 = 월 25 크레딧 (1 크레딧 = 저장 1GB | 대역폭 1GB | 변환 1,000회)

| 항목 | 사용량 | 크레딧 |
|---|---|---|
| 저장 (챔피언 173 + 선수 102 + 팀 10 = 285개, 원본 약 49 MB) | 0.05 GB | **0.05** |
| 변환 (285개 × 2변형 = 570회, 최초 1회만) | 570회 | **0.57** |
| 대역폭 (DAU 1,000명 × 20장/일 × 30일 × 18 KB) | 10.3 GB | **10.3** |

**DAU 2,000명 수준까지 여유가 있다.** 저장·변환은 사실상 무시할 수준이고
대역폭만 변수인데, 엣지 캐시가 적중하면 실제 사용량은 이보다 훨씬 적다.

참고로 지금도 같은 트래픽이 나가고 있다 — 다만 408 KB 짜리로 나가고 있어서
유저 체감만 느린 상태다.

### 구현 — 다운로드가 필요 없다

Cloudinary 업로드 API 의 `file` 파라미터는 **원격 URL 을 그대로 받는다.**
서버가 이미지를 내려받아 다시 올릴 필요 없이 주소만 넘기면 된다. 기존
`CloudinaryUploadClient` 에 URL 오버로드 하나만 추가하면 세 종류 모두 같은
방식으로 처리할 수 있다.

```java
// CloudinaryUploadClient — 기존 upload() 와 서명·엔드포인트 동일, file 파트만 URL 문자열
public String uploadFromUrl(String sourceUrl, String publicId, boolean overwrite) {
    // ... 기존 upload() 와 동일한 params / signature ...
    body.part("file", sourceUrl);   // ← MultipartFile 대신 원격 주소
    // ...
}
```

붙일 지점은 세 곳이다. 모두 이미 동기화 로직이 있는 자리라 저장 직전에 한
단계만 끼우면 된다.

| 대상 | 파일 | 현재 코드 |
|---|---|---|
| 선수 | `PlayerService.java:71` `syncLckPlayerImages()` | `player.setImageUrl(imageUrl)` |
| 챔피언 | `ChampionDataService.java:121` | `buildSplashImageUrl(...)` 로 URL 조립 |
| 팀 | 팀 이미지 동기화 지점 | — |

```java
// 예: PlayerService.syncLckPlayerImages()
try {
    String secureUrl = uploadClient.uploadFromUrl(sourceUrl, "players/" + player.getId(), true);
    player.setImageUrl(withDeliveryTransform(secureUrl));
} catch (Exception e) {
    // Cloudinary 실패가 동기화 전체를 멈추면 안 된다 — 원본이라도 남긴다
    log.warn("Cloudinary 업로드 실패, 원본 URL 로 대체: {}", player.getName(), e);
    player.setImageUrl(sourceUrl);
}
```

확인한 점:

- `public_id` 를 `players/{id}` 로 두면 백오피스 업로드와 같은 규칙이라 자산이
  하나로 유지되고, `overwrite=true` 라 고아 자산이 쌓이지 않는다.
- `setImageUrl()` 은 `imageLocked` 면 no-op 이므로 백오피스 수동 지정은 그대로
  보호된다. 다만 그 경우 업로드가 헛돌므로 잠긴 선수는 건너뛰는 편이 낫다.
- 동기화는 백오피스 수동 트리거(`POST /api/v3/players/sync-images`)라 사용자
  요청 경로에는 영향이 없다.
- 챔피언은 `Champion.updateImageUrl()` 이, 팀도 같은 형태의 갱신 메서드가 이미
  있어 선수와 같은 패턴으로 붙일 수 있다.

### 변환 옵션 제안

```
선수·팀 로고   f_auto,q_auto,w_200,c_limit
챔피언 픽·밴   f_auto,q_auto,w_200,ar_60:101,c_fill
```

챔피언은 앱에서 60×101 세로 칸에 그리므로 `ar_60:101,c_fill` 로 서버에서
잘라 주면 앱이 비율을 맞출 필요가 없다. (현재 내려오는
`splash-art/centered` 는 1280×720 **가로형**이라 앱에서 좌우가 잘리며 확대된다.
코드 주석에는 "고화질 세로 크롭용"으로 되어 있는데 실제와 다르다.)

### 더 간단한 대안: fetch 활성화

업로드 없이 원격 URL 을 감싸는 방식(`/image/fetch/{원격URL}`)도 있다. URL 치환만으로
끝나 가장 간단한데, 현재 계정에서 **401** 이 난다(Fetched URL 기본 비활성).
콘솔에서 켤 수 있다면 이쪽이 훨씬 빠른 적용이다.

```
https://res.cloudinary.com/{cloud}/image/fetch/f_auto,q_auto,w_200/{원본URL}
```

---

## 함께 봐주시면 좋을 것

### `/images/**` 정적 리소스가 캐시를 금지한다

```
$ curl -sI https://api.nar.kr/images/players/Kiin_김기인.webp
cache-control: no-cache, no-store, max-age=0, must-revalidate
```

`src/main/resources/static/images/players/` 에 선수 이미지 65개가 있고
(`PlayerImageMigrationService` 가 채운다) 39 KB WebP 로 가볍지만, 이 헤더 때문에
앱이 디스크 캐시에 저장하지 못하고 매번 다시 받는다.

API 응답(JSON)에는 타당하지만 정적 이미지에는 맞지 않는다. Spring Security 의
기본 헤더가 정적 리소스에도 적용된 것으로 보인다. `PublicEndpointCacheControlTest`
가 검증하듯, 핸들러가 `Cache-Control` 을 지정하면 Security 가 덮어쓰지 않는다.

```java
registry.addResourceHandler("/images/**")
        .addResourceLocations("classpath:/static/images/")
        .setCacheControl(CacheControl.maxAge(Duration.ofDays(7)).cachePublic());
```

다만 파일명이 고정(`Kiin_김기인.webp`)이라 길게 걸면 교체가 반영되지 않는다.
위 Cloudinary 전환이 적용되면 이 경로 자체를 안 쓰게 되므로 우선순위는 낮다.

### 선수 이미지 URL 이 `http://` 로 나간다

```json
"playerImageUrl": "http://static.lolesports.com/players/..."   // 선수
"teamImageUrl":   "https://static.lolesports.com/teams/..."    // 팀 (정상)
```

선수만 평문이다. iOS 는 ATS 로 평문 HTTP 를 막고, 지금은 호스트가 301 로
https 에 넘겨줘서 살아 있다 — 그 리다이렉트가 이미지 한 장마다 왕복 한 번이다
(0.82 s → 1.26 s). 앱에서 https 승격으로 우회해 두었고, Cloudinary 전환이
적용되면 자연히 사라진다.

---

## 앱에서 한 것

**적용 완료**

- 평문 `http://` → `https://` 승격 (리다이렉트 왕복 제거)
- 챔피언 이미지 URL 을 `/splash-art/centered` → `/portrait` 로 치환
  (963→475 KB, 종횡비도 카드에 맞음). **서버가 주는 URL 을 앱이 교정하는
  임시 조치이므로, Cloudinary 전환이 적용되면 이 코드는 제거할 예정이다.**

**시도했다가 되돌린 것**

- `memCacheWidth` 로 디코딩 크기 제한 — 다운로드 용량은 그대로라 체감이
  바뀌지 않고 화질만 나빠졌다.

---

## 재현 방법

```bash
# 챔피언 10장 동시 요청 (Flutter 와 같은 UA)
python3 - <<'EOF'
import urllib.request, time, concurrent.futures as cf
UA={'User-Agent':'Dart/3.12 (dart:io)'}
def one(u):
    r=urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=60)
    return len(r.read())
ids=[103,84,166,142,201,53,64,157,238,412]
for v in ['splash-art/centered','portrait']:
    urls=[f'https://cdn.communitydragon.org/latest/champion/{i}/{v}' for i in ids]
    t=time.time()
    with cf.ThreadPoolExecutor(max_workers=10) as ex: sizes=list(ex.map(one,urls))
    print(f'{v:24} {sum(sizes)//1024:5d}KB  {time.time()-t:.2f}s')
EOF

# 선수 이미지 호스트 분포
curl -s "https://api.nar.kr/api/auth/onboarding/players?year=2026" \
  | python3 -c "import sys,json,collections; d=json.load(sys.stdin); \
    print(collections.Counter((p.get('imageUrl') or '(없음)').split('/')[2] if '://' in (p.get('imageUrl') or '') else '(없음)' for p in d))"

# 팀 로고 원본 크기
curl -sI "https://static.lolesports.com/teams/1726801573959_539px-T1_2019_full_allmode.png" | grep -i content-length
```

문의 사항 있으면 알려주세요.
