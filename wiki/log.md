# Bundle Update Log

## 2026-11-23 (3)

* **커뮤니티 알림함을 웹으로 옮겼다**(열한 번째). **브리지가 하나 줄었다** —
  커뮤니티 헤더의 벨이 `requestNavigate('notification')` 로 네이티브를
  부르던 것이 웹 안의 이동(`<Link>`)이 됐다. `NotificationBell` 주석이
  "그 화면이 웹으로 오면 `WebLink` 로 바뀐다" 고 예고한 그대로다.
* **이번엔 네이티브 스크린샷을 먼저 찍고 만들었다.** 지난 평점 화면에서
  Dart 코드만 보고 옮겼다가 챔프 카드를 통째로 빠뜨린 것을 되풀이하지
  않으려는 것이다. 알림 카드는 이 계정에 커뮤니티 알림이 0건이라 **같은
  카드를 쓰는 마이구독 피드**를 띄워 대조했다.
* **솔랭 문구를 서버 title/body 대신 다시 조립한다**(Dart 와 같은 이유 —
  서버 문구가 한국어 고정이라 로케일을 못 맞춘다). 옮기면서 세 가지를
  틀렸다가 테스트로 잡았다.
  - **`로`/`으로` 를 하드코딩**했다. 받침에 따라 갈려야 해서
    (`자야로`·`갈리온으로`) `particleEuro` 를 같이 옮겼다.
  - **1분 미만 경기 시간을 생략하지 않았다.** `0분` 은 정보가 아니라
    오해를 만든다는 Dart 주석이 있다.
  - **승패 없음 판정을 `win === null && kda === null` 로 했다.** Dart 는
    `win` 하나로만 가른다.
* **아이콘을 `<img>` 가 아니라 CSS 마스크로 칠한다.** 네이티브는
  `ColorFilter` 로 전부 `narText` 한 색으로 칠하는데, svg 원본의 stroke 가
  파일마다 다르다(`white`·`#373A40`·`#CED4DA`) — `<img>` 로는 그 색을 못
  바꿔 3개가 다른 색으로 나온다.
* **좌스와이프 삭제를 포인터 이벤트로 구현했다**(네이티브 `Dismissible`).
  **세로 스크롤을 막지 않는 것이 핵심이다** — 가로 이동이 세로보다 확실히
  클 때만 드래그로 보고, 그 전에는 브라우저 스크롤에 맡긴다.
* **알림 카드를 `widgets/` 가 아니라 화면 안에 뒀다.** 네이티브는 알림함과
  마이구독이 같은 카드를 쓰지만 웹은 아직 알림함뿐이라, 올렸더니 steiger 가
  "참조가 하나뿐인 슬라이스" 로 잡았다. 마이구독이 웹으로 오면 올린다.

## 2026-11-23 (2)

* **내 평점·선수 평점을 웹으로 옮겼다**(아홉·열 번째). **둘을 한 묶음으로 옮긴
  이유가 브리지다** — 내 평점의 '리뷰보기' 가 선수 평점으로 가는데, 그쪽이
  네이티브로 남으면 `navigate` 에 **파라미터를 실어야 한다**(지금은 이름만
  받는다). 둘 다 웹이면 `<Link>` 한 줄로 이어지고 브리지가 필요 없다.
* **URL 이 네이티브 인자 8개를 대신한다.** `PlayerRatingScreen` 은 팀명·진영·
  세트 목록 등 8개를 받아야 했는데, 웹은 `gameId`·`participantId` 둘이면
  상세가 나머지를 스스로 받는다. 진입점이 인자를 알 필요가 없어졌다.
* **선수 평점은 비회원 조회가 열려 있다**(실측 HTTP 200). 본문·분포·한줄평이
  토큰 없이 SSR 되고, 로그인했을 때만 `myRating` 이 채워진다. **토큰이 있으면
  캐시하지 않는다** — `myRating` 이 사용자마다 달라 공유 캐시에 담으면 남의
  "내 평점" 이 보인다.
* **쓰기(작성·수정·삭제)가 처음 웹으로 왔다.** 그동안 옮긴 화면은 전부 읽기
  전용이었다. 서버 액션으로 처리하고 `revalidatePath` 로 두 화면을 같이
  갱신한다 — 상세에서 지우면 내 평점 목록의 누적 건수도 바뀐다.
* **`navigate('login')` 을 추가했다 — 브리지에서 새로 는 유일한 것이다.**
  웹에 로그인 화면이 없다(카카오·네이버 SDK 가 네이티브에 있다). **돌아오면
  쿠키를 다시 심고 웹을 reload 한다** — 안 하면 토큰이 생겼는데 화면은
  비로그인 SSR 결과 그대로라, 로그인하고 돌아와도 버튼이 또 로그인으로 보낸다.
* `packages/ui` 에 `StarRating`·`ConfirmDialog` 를 추가했다(Dart 원본이
  `core/ui/` 다). 별은 **회색 별 위에 노란 별을 비율만큼 클립해 덮는다** —
  Dart 가 반 별 마스크를 피한 이유(반투명하게 뭉개진다)가 그대로 적용된다.
* **SVG `width` 속성에 `calc()` 를 못 쓴다.** 속성은 raw number 만 받아서,
  스케일을 먹이려면 CSS `style` 로 줘야 한다 — 안 그러면 기기 폭이 달라져도
  별만 고정 크기로 남는다.

## 2026-11-23

* **광고 안내를 웹으로 옮겼다**(여덟 번째). 본문이 공지 상세와 같은
  백오피스 공지(`slug=ad-guide`)라 렌더러를 그대로 쓴다 — 네이티브도
  `AdGuideScreen` 이 `NoticeDetailScreen` 을 재사용하던 구조였다.
  진입점 둘(마이페이지 '광고 안내', 응원 광고 상세의 '상세 보기')이 전부
  인자 없는 `const AdGuideScreen()` 이라 치환이 기계적이었다.
  **정적 프리렌더로 떨어진다**(5분 revalidate) — 사용자별 데이터가 없어
  콜드스타트 SSR 비용이 없다.
* **본문 렌더러를 `widgets/notice-body` 로 올렸다.** 소비처가 공지 상세·광고
  안내 둘이 됐다. `packages/ui` 가 아닌 이유는 Dart 원본이
  `features/notice/` 안이기 때문이다 — 기능 폴더 안의 위젯은 공용 자리에
  두지 않는 규칙이 웹에서도 같다.
* **가로 스크롤 스트립이 세로로 쌓이던 것을 고쳤다.** 묶음 판정이 **바로 다음
  줄**만 봐서, 에디터가 이미지 사이에 넣는 빈 줄에 끊겼다. Dart 는 빈 줄을
  건너뛰는데(`_buildContent`) TS 포팅에서 그 부분이 빠졌다. 이미지 3장이
  각자 스트립 하나씩이 되어 세로로 쌓였다 — **빌드·타입 체크는 통과하고
  화면에서만 드러난다.**
* **`calc(n * var(--scale) * 1px)` 이 무효였다.** `--scale` 이 이미 px 단위라
  (`clamp(320px, 100vw, 430px) / 375`) 한 번 더 곱하면 px² 이 되어 선언이
  통째로 버려진다. 지정 폭 274 를 무시하고 원본 375 로 그려졌다.
  공지 상세를 옮길 때부터 있던 버그고(현재 공지 본문에 스트립을 쓰는 글이
  없어 드러나지 않았다), CLAUDE.md 함정 표에 이미 적혀 있던 항목이다.

## 2026-11-20 (7)
* **로드 실패를 처리한다.** `onWebResourceError` 를 안 받고 있어서, 네트워크가
  끊기면 `onPageFinished` 가 오지 않고 **스켈레톤이 영원히 떠 있었다.**
  이제 실패하면 "다시 시도" 안내(`LoadError`)를 보이고 `retry()` 로 다시
  로드한다. **메인 문서 실패만 막는다**(`isForMainFrame`) — 이미지 하나가
  404 라고 화면을 에러로 덮으면 안 된다.
* **탭 진입 시 검정 빈 화면을 네이티브 스켈레톤으로 바꿨다.** 워밍업이 끝나기
  전에 탭을 누르면 불투명 검정이 덮여 있었다 — **웹 스켈레톤은 웹뷰가 로드돼야
  그려지므로 이 구간을 덮을 수 없다.** 네이티브가 그려야 한다(기존
  `post_list_item_skeleton.dart` 재사용).
* **웹 스켈레톤이 안 보이는 이유를 숫자로 확인했다** — 상세 진입 시
  **등장 5ms → 실데이터 13ms, 지속 8ms**. 1프레임(16ms)도 못 채운다.
  **동작은 정상이고 서버가 빠를 뿐이다.** 최소 노출 시간을 넣어 일부러
  느리게 만들지 않기로 했다 — 배포 환경(콜드스타트·LTE)에서는 수백 ms 라
  제 역할을 한다. 로컬에서 안 보이는 것은 **빠르다는 증거**다.

## 2026-11-20 (6)
* **브리지에 능력 목록(capability)을 넣었다.** 웹은 배포 즉시 전원에게 가지만
  앱은 스토어 심사와 사용자 업데이트를 기다린다 — 웹이 새 메시지를 쓰면
  구버전 앱은 그걸 모른다. 네이티브가 `kBridgeCapabilities` 로 선언하고 웹이
  `isSupported()` 로 묻는다.
* **조사한 네 사례가 모두 같은 모양이었다** — Hotwire Native(UA 에
  `bridge-components: [...]`), 토스(`isMinVersionSupported` + 각 API 의
  `.isSupported()`), 당근 metabridge(스키마에 `minimumSupportAppVersion` 필수),
  Capacitor(`cap.PluginHeaders` + `UNIMPLEMENTED`).
  **메서드명에 `v2` 를 붙이는 곳은 한 곳도 없었다.** 판정 단위는 메서드다.
* **기본값은 웹 폴백이다**(Hotwire 의 핵심 규칙). 모르면 `isSupported()` 가
  false 라 구버전 앱도 새 웹도 안전한 쪽으로 떨어진다. `share` 는 네이티브에
  구현이 없어 **선언하지 않는다** — 선언이 곧 계약이다.
* **조용한 무시를 없앴다.** `bridge_handler.dart` 의 `case null` 이 로그만
  찍고 끝냈는데(Stage A 의 유일한 silent failure), 이제 웹에 `unsupported`
  를 되돌린다. Stage C 는 이미 `ok:false` 를 주고 있었다.
* **버전 문자열로 분기하지 않는다.** `appVersion` 은 로그·문의 대응용이다 —
  `1.0.9` vs `1.1.0` 처럼 자릿수를 독립 비교하다 틀리는 사고가 흔하다(실제
  공개 장애 사례가 그것이다).
* **환경 조립을 `BridgeEnv.current()` 한 곳으로 모았다.** 웹뷰 화면이 둘(push
  용·탭 워밍업)이라 각자 만들면 한쪽이 필드를 빠뜨린다 — 실제로 능력 목록을
  넣을 때 탭 경로가 빠져 있었다.
* **미룬 것 2개** — UA/쿠키로 SSR 분기(화면이 1~2개라 깜빡임 표면이 작고
  `webview_flutter` UA API 검증이 선행), CI 배포 가드(**iOS 입력이 약하다** —
  스토어 라이브 버전 조회 경로가 미검증이고 **버전별 사용자 채택률 API 를
  찾지 못했다**).

## 2026-11-20 (5)
* **웹뷰 워밍업으로 탭 전환을 즉시로 만들었다.** 앱 시작 때 웹뷰를 만들어
  `/community` 를 로드·하이드레이션까지 끝내 두고, 탭에서는 그 컨트롤러를
  그대로 쓴다(`app/bridge/webview_warmup.dart`).
* **원인을 숫자로 갈랐다**(실측 2026-11-20, iOS 시뮬레이터):

  | 구간 | 시간 |
  |---|---|
  | 서버 HTML 수신 | **13ms** |
  | 쿠키 심기 | 330ms |
  | WKWebView 생성 | ~400ms |
  | JS 하이드레이션 | ~800ms |

  **서버는 범인이 아니었다.** 나머지가 전부 네이티브·브라우저 초기화라,
  웹을 아무리 가볍게 해도 매번 새로 만드는 한 줄지 않는다.
* **우리 화면 코드는 3KB 고 나머지 800KB 는 React 런타임이다.** 클라이언트
  컴포넌트를 **하나라도** 쓰면 전부 딸려온다 — 더보기 버튼을 빼도 똑같다.
  그래서 JS 를 줄이는 대신 **미리 실행**하는 쪽을 택했다.
* **스켈레톤이 안 보이는 이유도 확정했다.** HTML 전체가 13ms 에 한 번에 와서
  (스켈레톤과 실데이터가 4ms 간격) 그릴 틈이 없다. 느린 400ms·800ms 는
  **웹 바깥**이라 웹이 덮을 수 없다. 스켈레톤은 정상 동작하지만 로컬에서는
  의미가 없다 — 배포 환경(콜드스타트·LTE)에서 제 역할을 한다.
* **탭 진입 시 `reload()` 를 부르지 않는다.** 들어올 때마다 전체를 다시
  받으면 로드·하이드레이션을 또 치러 워밍업 이득을 반납한다(실측: 탭마다
  1.4~2.1초 재로드). 갱신은 웹의 `revalidate: 15` 가 맡는다.
* **쿠키는 같은 값이면 다시 심지 않는다.** `setCookie` 가 314ms 다(플랫폼
  채널). 도메인 단위라 한 번이면 모든 웹뷰 화면에 걸린다.
* **링크를 `<a>` 에서 Next `<Link>` 로 바꿨다.** 전체 문서 로드는 브라우저가
  새 문서를 받는 동안 이전 화면을 그대로 둬서 `loading.tsx` 가 안 뜬다 —
  스켈레톤이 있어도 보이지 않는다. 번들을 아끼려 `<a>` 를 썼는데 워밍업으로
  React 가 이미 로드돼 그 이유가 사라졌다.
* **빠져 있던 것 3개를 채웠다** — 무한 스크롤(더보기 버튼 → `IntersectionObserver`
  자동 로드, 바닥 200px 전), 글쓰기 FAB, 알림 벨(미읽음 배지).
  **알림함 화면은 아직 네이티브**라 벨을 누르면 브리지로 넘긴다.

## 2026-11-20 (4)
* **커뮤니티 탭을 웹뷰로 바꿨다.** 이제 앱에서 커뮤니티를 누르면 네이티브
  화면이 아니라 `/community` 웹뷰가 열린다 — 프로브 없이 실제 경로로 쓴다.
* **네이티브 커뮤니티 코드는 지우지 않았다**(`community_screen.dart` 외
  36파일). 되돌릴 길을 남겨 둔 것이다 — 웹 배포가 막히면 `tab_navigation.dart`
  두 줄만 되돌리면 된다.
* **탭 셸을 따로 만들었다**(`app/bridge/webview_tab_screen.dart`). 탭 화면만
  이걸 쓰고, 상세·공지처럼 push 로 열리는 화면은 `WebViewScreen` 을 그대로
  쓴다 — 거긴 탭이 없어야 한다. **웹은 본문만 그리고 탭은 네이티브가 그린다**
  (웹뷰가 탭까지 그리면 두 겹이 되고, 탭 전환이 웹 라우팅이라 홈·일정으로
  못 간다).
* **흩어져 있던 진입점 4곳을 정리했다.** 홈("커뮤니티 전체")과 구독 화면이
  `CommunityScreen()` 을 직접 짓고 있었는데, `replaceWithTabScreen` 창구를
  쓰게 바꿨다 — 같은 분기가 네 군데 있으면 한 곳을 빠뜨린다.
* Flutter analyze·테스트 978개 통과.
* **UI 를 Dart 코드와 대조해 7곳 맞췄다** — 헤더(공용 `DetailHeader` 사용,
  가운데 "전체 게시판", 우측 임시·등록), placeholder 문구, 빈 화면 4줄 예약,
  조작 버튼 위치(이미지 위 우상단 원형 26px 3개), 텍스트 블록 버튼 제거.
  **제목(H) 토글은 네이티브에도 UI 가 없어** 웹에서도 뺐다 — 한쪽에만 있으면
  같은 글이 플랫폼마다 다르게 보인다.

## 2026-11-20 (3)
* **블록 에디터를 붙였다** — 텍스트 사이에 사진을 끼우고, 블록마다 제목
  토글(H)·이동(▲▼)·삭제(✕)가 붙는다. 본문이 `bodyFormat: 'BLOCKS'` 로
  나간다. 번들 3.46 → 4.39 kB.
* **불변식: 맨 위와 맨 아래는 항상 텍스트 블록이다.** 이미지가 첫 블록이
  되면 그 위에 커서를 둘 자리가 없어 **"사진 위에 첫 줄 쓰기" 가 막힌다** —
  Dart 가 1.0.23 사용자 피드백으로 적어 둔 실제 사고다. 눈으로는 "왜 안
  써지지" 로만 보여서 **조작 로직을 순수 함수로 떼고 테스트 18개로 덮었다**
  (`lib/blocks.ts`).
* **사진은 커서 위치에서 텍스트를 쪼개 끼운다.** 커서 주변 빈 줄은 걷어낸다 —
  "글 쓰고 엔터 → 사진" 이 이미지 위아래 공백으로 남으면 안 된다(블록 간격이
  이미 여백을 준다). 끼운 뒤에는 항상 이어서 쓸 텍스트 블록이 따라오고
  거기로 포커스가 간다.
* **업로드가 끝난 뒤에 블록으로 들어간다.** 올리는 중인 사진을 블록에 미리
  넣으면 그 상태가 드래프트에 섞여, 복원했을 때 이어갈 수 없는 항목이 된다.
  진행 중인 것은 "사진 N장 올리는 중…" 으로 따로 보여 준다.
* **빈 텍스트 블록은 서버로 안 나간다**(`toBodyJson` 이 걷어낸다). 불변식
  때문에 생긴 앞뒤 빈 블록이 그대로 가면 상세 화면에 빈 줄이 생긴다.
  제목이 아닐 때 `style` 을 싣지 않는 것도 Dart `toJson` 과 같다.
* 실측: 제목 토글(14.5 → 16px), 블록 JSON 저장
  (`[{"type":"text","text":"..."}]`), 등록 버튼 활성 조건.

## 2026-11-20 (2)
* **글쓰기 1단계를 옮겼다** — 제목·본문(평문)·사진·임시저장. 블록 에디터·
  투표 작성·링크 프리뷰는 다음이다.
* **백엔드는 서명만 발급하고 파일은 받지 않는다**(스펙 확인). 바이너리는
  브라우저가 Cloudinary 로 직접 올린다 — **백엔드 변경 0** 이고 Next Server
  Action 한도(기본 1MB)·Vercel Functions 한도(4.5MB)를 아예 비껴간다.
  폰 사진은 장당 3~5MB 라 중계했으면 바로 걸렸다.
  CORS 는 Cloudinary 가 임의 Origin 을 반사해 설정이 필요 없다(실측: preflight 200).
* **리사이즈는 브라우저가 한다**(긴 변 1600 / 품질 0.85 — Dart `image_picker`
  와 같은 값). **Cloudinary 의 incoming transformation 으로는 대체 불가** —
  변환이 파일 도착 **뒤**라 업로드 대역폭이 안 줄어든다(공식 문서 확인).
* **iOS canvas 면적 한도(4096²)를 가드한다.** 넘으면 예외가 아니라 **빈
  이미지가 조용히** 나온다(MDN). 요즘 폰 사진이 이 한도에 닿는다.
  **EXIF 회전은 직접 하지 않는다** — 브라우저가 이미 적용해서 또 돌리면
  이중 회전이 된다.
* **라이브러리를 쓰지 않았다.** 다운로드 1위(browser-image-compression)가
  3년 8개월째 릴리스가 없고, 소스상 **iOS·Safari 에서 `createImageBitmap` 을
  의도적으로 건너뛴다** — 우리 타깃에선 어차피 구식 폴백 경로다.
* **임시저장은 localStorage + 이미지는 URL 만.** 사진이 고르는 즉시 업로드되어
  드래프트가 순수 문자열이 된다 — IndexedDB·Blob·쿼터 문제가 통째로 사라지고,
  네이티브가 로컬 경로를 저장해 생기던 "사진이 조용히 사라지는" 문제도 없다.
* **보존 기간을 화면에 적었다 — "최대 7일".** Safari 가 추적 방지가 켜진
  상태에서 7일간 클릭·탭이 없는 origin 의 스크립트 생성 데이터를 지운다
  (MDN 원문 확인, 서버 쿠키는 예외). 네이티브(Keychain)보다 짧은 것은
  **감수한 선택**이다 — 백엔드에 드래프트 API 가 없다(경로 144개 중 0건).
  7일 경계는 테스트로 못박았다.
* **Android 파일 선택을 붙였다.** `setOnShowFileSelector` 가
  `webview_flutter_android` 에만 있고 재수출되지 않아 플랫폼 패키지를 직접
  의존한다(공식 권장 방식). **안 붙이면 Android 에서 `<input type="file">` 이
  아무 반응도 하지 않는다** — iOS 는 WKWebView 가 자체 처리한다.
* **알아둘 것: dev 서버를 띄운 채 `pnpm build` 를 돌리면 깨진다.** `.next` 를
  덮어써서 청크가 404 가 된다(두 번 겪었다). `.next` 를 지우고 재시작하면 된다.

## 2026-11-20
* **답글 대상 지정 UI 를 붙였다.** 모든 댓글(최상위·답글 양쪽)에 "답글" 버튼이
  있고, 누르면 입력창 위에 "N님에게 답글" 과 취소(×)가 뜬다 — 안 그러면
  답글 버튼을 눌렀는지 아닌지 화면에 남지 않는다(Dart 와 같은 이유).
* **목록과 입력창을 `CommentSection` 이 감싼다.** 답글 대상을 공유해야 해서다.
  답글 버튼이 클라이언트 핸들러를 필요로 하는 탓에 목록도 클라이언트로
  내려왔다 — 서버 컴포넌트에서 `onClick` 을 넘기면 런타임에 터진다.
  번들 3.95 → 4.94 kB.
* **답글에 답글을 달아도 `replyToCommentId` 만 넘긴다.** 서버가 최상위를 찾아
  붙이고 `@닉네임` 도 채운다 — 1단 구조 계산이 서버 몫이라 앱이 추측하면
  두 구현이 어긋난다.
* 실측: 답글 버튼 4개(댓글 전부), 대상 표시·취소 동작, 긴 닉네임 말줄임.

## 2026-11-19 (6)
* **투표하기를 붙였다.** 투표 가능 조건은 Dart `_canVote` 와 같다 — 마감 전이고,
  복수 선택이면 아직 안 고른 것, 단일 선택이면 아예 미투표일 때만 누를 수 있다.
  누를 수 없는 선택지는 **버튼으로 만들지 않는다**(비활성 버튼이 남아 있으면
  누를 수 있어 보인다).
* **서버가 투표 후 상태를 통째로 돌려주므로 그 값으로 교체한다.** 분포가 막
  공개되는 경우(투표 뒤에 `resultsVisible` 이 켜진다)까지 한 번에 반영된다 —
  낙관적 업데이트를 하면 그 전환을 손으로 흉내내야 한다.
* **로그인 상태의 실제 투표는 검증하지 않았다.** 단일 선택은 **되돌릴 수 없어서**
  (서버 계약) 운영 데이터를 바꾸게 된다. 비로그인 분기만 확인했다 —
  "로그인이 필요합니다" + 참여 수 21명 그대로.
* **뒤로가기는 웹 쪽이 정상이다 — 실측했다.** 가짜 브리지를 심고 버튼을 눌러
  `{"stage":"a","type":"back"}` 이 나가는 것을 확인했다. 프로브에서 안 눌리는
  것처럼 보였다면 **되돌아갈 화면이 없어서**다 — `WebViewScreen` 을 홈으로
  띄우면 `maybePop()` 이 pop 할 대상이 없다. 실제 앱은 목록에서 push 하므로
  다르다(프로브에 앞 화면을 두면 재현되지 않는다).

## 2026-11-19 (5)
* **브리지 쿠키로 토큰이 웹까지 온다 — 실측했다.** 로그인한 시뮬레이터에서
  웹뷰를 띄우고 SSR 쪽에서 찍어 확인했다(`token present: true, len: 214`).
  쓰기 액션 전체의 전제가 이것이라 추측으로 넘기지 않았다.
* **상세에 좋아요·스크랩·댓글 작성을 붙였다.** 번들 1.89 → 3.28 kB(액션 행과
  입력창만 클라이언트고 본문·댓글은 그대로 서버 컴포넌트다).
* **서버 계약 3개를 실제 토큰으로 확인했다** — 좋아요 `{liked, likeCount}`
  35→36→35 원복, 스크랩 `{scrapped}`, 비로그인 401. **본문 없는 POST 에
  `Content-Type` 을 붙이지 않아도 정상 동작한다**(앞서 확실하지 않다고
  적었던 부분이다).
* **댓글 등록 후 `revalidatePath` 로 다시 그린다.** 새 댓글을 클라이언트가
  끼워 넣지 않는 이유는 **서버가 멘션 대상과 답글 위치(`parentId`)를 정하기**
  때문이다 — 앱이 추측해 그리면 새로고침했을 때 자리가 달라진다.
* **토큰을 액션 인자로 넘기지 않는다.** 서버가 쿠키에서 읽는다 — 인자에 넣으면
  번들과 네트워크에 토큰이 노출된다. 비로그인은 서버에 401 을 받으러 가지 않고
  바로 `unauthorized` 를 돌려준다.
* **아직 없는 것** — 답글 대상 지정 UI, 댓글 수정·삭제, 투표하기, 신고·차단,
  네이티브 로그인 화면을 여는 브리지(Stage A `navigate` 가 미구현이라 지금은
  "로그인이 필요합니다" 안내만 띄운다).

## 2026-11-19 (4)
* **글 상세에 댓글·투표를 채웠다.** 읽기까지다 — 좋아요·스크랩·댓글 작성·
  투표하기·신고는 다음 단계다(로그인 상태 검증이 필요하다).
* **번들이 안 늘었다**(1.89 kB 그대로). 댓글·투표가 전부 서버 컴포넌트다.
  글과 댓글은 **병렬로 부른다** — 댓글이 글에 의존하지 않아 줄세우면 왕복이
  두 번 쌓인다. 댓글만 실패하면 글은 그대로 보여준다.
* **답글은 1단까지만 접는다.** `parentId` 가 항상 최상위 댓글을 가리키므로
  (답글의 답글도 같은 층) 트리를 재귀로 그리지 않는다. 누구에게 한 말인지는
  `@닉네임`(`mentionNickname`)이 알린다. 실측 응답으로 이 계약을 테스트에
  박았다.
* **지워진 댓글도 행을 남긴다.** 서버가 `status` 를 VISIBLE 이 아닌 값으로
  주면서 `body`·`author` 를 null 로 비운다 — 답글이 달린 댓글이 통째로
  사라지면 대화가 끊긴다. 매퍼가 null 을 빈 문자열로 메우지 않는 이유다.
* **투표 분포는 `resultsVisible` 일 때만 그린다.** 비공개면 `voteCount` 가
  null 인데 0 으로 메우면 "0표" 로 보여 실제로 아무도 안 고른 것과 구분이
  안 된다(실측: 글 47번이 비공개 상태다).
* **본문 분기 기준은 `bodyFormat` 이다 — 블록 수가 아니다.** 블록 수로
  갈랐더니 투표만 있고 본문이 없는 글(`body: '[]'`)이 평문 분기로 떨어져
  `[]` 가 날것으로 보였다(실측, 글 47번). Dart `isBlocks` 와 같게 고쳤다.
* **`text-overflow: ellipsis` 는 flex 컨테이너의 텍스트 노드에 안 걸린다.**
  긴 닉네임이 잘리기만 하고 `…` 가 안 나왔다(실측) — 블록 컨테이너의 인라인
  콘텐츠에만 적용된다. 닉네임을 `<span>` 으로 감싸 거기에 걸었고, 같은 구조인
  목록 카드도 함께 고쳤다.

## 2026-11-19 (3)
* **커뮤니티 검색을 옮겼다**(`/community/search`). 네 번째 전환 화면이다.
  서버가 검색·목록 응답을 **같은 모양으로 준다**(실측: `posts`·`nextCursor`·
  `boardViewer`, 글 필드 14개 동일) — `PostList` 타입과 매퍼를 그대로 썼다.
* **목록에 더보기를 붙였다.** Server Action 이 다음 페이지를 받아 **그려진
  JSX** 를 돌려준다 — 데이터를 돌려주면 카드와 포맷터가 클라이언트 번들로
  들어가, 첫 페이지를 SSR 로 그려 얻은 이득을 두 번째부터 반납한다.
  번들은 122 B → 762 B 로만 늘었다.
* **자동 로드(IntersectionObserver)를 쓰지 않는다.** Dart 목록은 바닥 200px
  전에 자동으로 당기지만, 그러려면 목록 전체가 클라이언트 상태여야 한다.
  조작감 차이를 받아들이고 번들을 지키는 쪽을 택했다.
* **검색 카드를 `shared/ui/PostCard` 로 내렸다.** FSD 에서 page 끼리는 서로
  import 할 수 없다. `packages/ui` 가 아닌 이유는 따로다 — 거기는 `core/ui/`
  의 짝인데 이 카드의 Dart 원본은 기능 폴더 안이다.
* **검색은 2자 미만을 부르지 않는다** — 서버가 400 을 준다(실측). 디바운스
  350ms 도 Dart 와 같은 값이다(LIKE 스캔이라 한 글자마다 쏘면 서버 CPU 를
  태운다). 늦게 온 응답이 최신 결과를 덮지 않게 요청에 순번을 매긴다.
* **커뮤니티 남은 범위를 조사했다** — 상세는 **보통**(사진 핀치줌 뷰어·외부
  링크 열기·키보드 스크롤 보정·pop 결과 반환을 브리지로 다시 깔아야 한다),
  쓰기는 **어려움**(갤러리 접근·로컬 경로 선업로드·`flutter_secure_storage`
  드래프트가 전부 네이티브 전제라 모델부터 재설계). 쓰기 전에 결정이
  필요한 것 2개 — 브라우저 canvas 리사이즈(안 하면 아이폰 원본 수 MB 가
  그대로 올라간다), 기기에 쌓인 드래프트 마이그레이션 여부.

## 2026-11-19 (2)
* **커뮤니티 글 목록을 세 번째 전환 화면으로 옮겼다**(`/community`). 상세가 이미
  웹이라 목록 → 상세가 **브리지를 거치지 않고 웹 안에서 이어진다**(`<a href>`
  한 줄). 클라이언트 컴포넌트가 0개라 라우트가 **122 B** 다.
* **웹이 가져간 것은 목록 본문뿐이다.** 하단 탭·알림 벨·검색·글쓰기 FAB 는 앱
  셸이라 네이티브에 남는다 — 웹뷰가 탭을 그리면 네이티브 탭과 두 겹이 된다.
  팀별 3탭은 네이티브 쪽에서 보류 상태(`boardTeamId=null` 고정)라 웹도 탭이 없다.
* **목록 항목은 상세와 다른 타입이다**(`PostSummary` ≠ `PostDetail`). 서버가
  목록에는 `bodyPreview` 만 주고 `body`·`viewer`·`poll` 을 주지 않는다. 한
  타입으로 합치면 상세 화면이 "있을 수도 없을 수도" 를 매번 분기하게 된다.
* **무한 스크롤은 아직 없다.** `nextCursor` 를 받아 두기만 한다 — 커서를
  따라가려면 클라이언트 컴포넌트가 필요해서, SSR 이득을 먼저 재고 정한다.
* **`packages/ui` 의 경계를 못박았다 — Dart 원본이 `core/ui/` 면 올리고
  `features/*/widgets/` 면 올리지 않는다.** `PostListItem` 을 공용으로 올리려다
  잡았다. 한 기능 전용 위젯을 공용 자리에 두지 않는 규칙이 웹에서도 같다.
* **상대 시간 포맷터(`timeAgo`)는 `apps/web` 안에 뒀다.** Dart
  `ratingTimeAgo` 의 복제고, 소비처가 웹 1곳뿐이라 `packages/` 로 올리지 않는다.
  커뮤니티가 웹으로 가도 Dart 쪽은 남는다 — 선수 평점이 같은 함수를 쓴다.
  날짜 표기가 **로컬 타임존 기준**이라 테스트 픽스처를 로컬 시각으로 만들었다
  (UTC 로 못박았더니 `TZ=Pacific/Honolulu` 에서 하루 밀렸다).
* **Flutter+Next 모노레포 선례를 파일 기준으로 다시 찾았다**(키워드 검색은
  거의 못 찾았다). 공존 레포 2건 확인 — `tutur3u/platform`(스타 54) ·
  `MITOM06/platform`. **둘 다 `packages/` 에 Dart 가 읽는 것이 0개다.** 토큰을
  Dart+CSS 로 동시 생성하거나 브리지 규약을 양쪽에 짝으로 둔 레포는 못 찾았다.
  GitHub 코드 검색은 `filename:` 을 여러 개 주면 **AND 가 아니라 OR 로 풀린다**
  — 단일 조건으로 후보를 모으고 `git/trees` 로 검증하는 2단계만 유효했다.

## 2026-11-19
* **앱 실행 명령을 루트 `pnpm` 으로 모았다** — `pnpm app:local` · `pnpm app:prod`.
  **Flutter 에는 `package.json` 의 `scripts` 같은 것이 없다**(`pubspec.yaml` 에
  스크립트 섹션이 없고 `dart run` 은 Dart 파일 실행이다). 그래서 셸 스크립트를
  쓰는데, 웹은 `pnpm` 이고 앱만 다른 곳이면 명령을 두 군데서 찾게 된다.
* `app:*` 은 `tool/run.sh` 로 **위임만 한다** — Flutter 는 turbo 그래프 밖이라
  (Dart 를 모른다) 캐시 이득이 없다. `apps/mobile/` 안에서 작업 중이면
  `./tool/run.sh local` 을 직접 불러도 같다.

## 2026-11-18 (3)
* **앱 환경 전환을 `tool/run.sh local|prod` 로 만들었다.** 매번
  `--dart-define=WEBVIEW_HOST=...` 를 치지 않게 한 것이다.
* **flavor 를 쓰지 않기로 했다 — 실제 앱 8개를 조사한 결과다.** dev/prod 분리에
  flavor 를 쓴 앱은 **0개**였고, flavor 를 쓰는 3개(aves·Musify·ente)는 전부
  **번들ID가 갈리는 배포 채널**(Play/F-Droid) 문제였다. aves 는 dimension 이름이
  아예 `"store"` 다. 결정적인 것은 ente 인데, flavor 와 dart-define 을 **동시에**
  쓰면서 flavor 는 배포 채널로 고정하고 환경만 `--dart-define endpoint=...` 로
  바꾼다 — 두 축을 의도적으로 분리했다.
* **이 레포에서 flavor 가 특히 비싼 이유.** `shorebird release`·`patch` 네 곳에
  `--flavor` 를 붙여야 하는데 **그건 태그를 밀어야 검증된다**. iOS scheme·
  xcconfig 수동 작업도 따라온다. URL 한 줄 때문에 치를 비용이 아니다.
* Flutter 공식 문서가 두 갈래라는 것도 확인했다 — flavors 문서는 flavor 로 API
  URL 까지 바꾸라 하고, **CD 문서는 같은 목적에 `--dart-define` 을 권한다.**
  이 레포는 `HOME_MOCKS` 로 이미 후자를 쓰고 있어 같은 축에 얹었다.
* **기본값이 운영이라 플래그를 빼먹어도 안전하다.** 릴리즈·패치 워크플로우가
  dart-define 을 안 넘기는 것도 확인했다 — 둘 다 기본값이라 일관성이 깨지지 않는다.

## 2026-11-18 (2)
* **브리지 Stage A·B·C 를 전부 구현하고 시뮬레이터에서 웹뷰를 띄웠다.** 규약을 양쪽에
  짝으로 둔다 — `apps/web/src/shared/bridge/protocol.ts` ↔
  `apps/mobile/lib/app/bridge/bridge_protocol.dart`. 코드 생성이 없으므로 한쪽을
  고치면 반드시 다른 쪽도 보도록 주석에 명시했다.
* **인증 토큰은 쿠키로 넘기기로 했다.** 세 방식을 비교했는데 URL 쿼리는 접근 로그·
  리퍼러에 남고, 로드 후 JS 주입은 SSR 시점에 토큰이 없어 좋아요·스크랩 상태가 한
  박자 늦게 채워지며 깜빡인다. 쿠키면 **첫 요청부터 Next 서버가 토큰을 들고** API 를
  부른다. 한계는 `webview_flutter` 쿠키 API 에 `httpOnly` 가 없어 JS 로 읽힌다는
  것이고, 서드파티 스크립트를 넣으면 전제가 깨진다고 적어 뒀다.
* **로그인 상태에서는 캐시하지 않는다**(`cache: 'no-store'`). `viewer` 가 사용자마다
  달라 공유 캐시에 담으면 **남의 좋아요 상태가 보인다**.
* **Stage B·C 응답이 같은 통로로 들어온다.** 네이티브가 JS 를 실행할 창구는
  `window.__wardingReceive` 하나뿐이라, 봉투에 `id` 가 있으면 Stage C 응답, 없으면
  브로드캐스트로 가른다. Stage C 는 10초 타임아웃을 걸어 네이티브가 조용히 죽어도
  Promise 가 영원히 걸리지 않게 했다.
* **`server-only` 가 테스트에서도 던지는 것을 겪었다.** 번들러 밖(tsx·node --test)
  에서는 "클라이언트에서 import 됐다" 로 보기 때문이다. `--conditions=react-server`
  로 돌려 해결했고, 그 플래그가 없으면 `client.ts` 를 테스트할 수 없다.
* **`Authorization` 헤더가 실제로 붙는지 로컬 HTTP 서버로 확인했다** — 토큰이 있으면
  `Bearer ...`, 없거나 빈 문자열이면 헤더 자체를 안 붙인다. 백엔드가 잘못된 토큰도
  200 을 주므로 **응답 코드로는 검증할 수 없었다.**
* **steiger 가 또 두 건을 잡았다** — 세그먼트에 공개 API 가 없는 것과 내부 모듈을
  직접 import 한 것. 그 과정에서 `index.ts` 가 `server-only` 모듈을 re-export 하면
  **클라이언트가 상수만 쓰려 해도 빌드가 깨지는** 함정을 발견해 상수를 별도 파일로
  뺐다.
* `webview_flutter` 를 직접 의존으로 올렸다(전이 의존만으로는 import 가 깨진다).
  **패치로 못 나가는 변경**이라 스토어 재제출이 필요하고, 패치 가드가 이를 차단한다.

## 2026-11-18
* **공지 상세를 웹으로 옮겼다 — 두 번째 전환 화면.** 선정 근거는 실측이다: 진입점
  7곳(커뮤니티 글 상세 6곳 다음), 비회원 조회 HTTP 200, **목록 응답이 본문까지 주므로
  상세 API 가 필요 없다**, 실시간 요소 없음. 경기 상세가 진입점 13곳으로 가장 많지만
  `Timer.periodic` 폴링과 라이브 스트림이 있어 1순위에서 제외했다.
* **가장 큰 이득은 마크다운이다.** Flutter 는 `# ## ### -` 4개 문법과 인라인
  `**굵게**`·링크를 **손으로 파싱한다**(124줄). 웹은 같은 문법만 지원하는 파서를
  `_pages/notice/lib/` 에 두고 테스트 10개로 고정했다 — 범용 라이브러리를 쓰면 양쪽이
  다른 문법을 지원해 같은 공지가 다르게 보인다.
* **`steiger`(FSD 공식 린터)를 CI 에 걸었다.** 바로 `_app/ui/` 를 잡아냈다 —
  `app` 레이어에는 `ui` 세그먼트를 두지 않고 `layout`·`styles`·`config` 처럼
  **목적별**로 쓴다. 자동 검증이 없으면 규칙은 반드시 썩는다.
* **`index.server.ts` 패턴을 도입했다.** `packages/api` 를 `warding-api`(타입·순수
  함수) ↔ `warding-api/server`(fetch, `import 'server-only'`)로 갈랐다. 클라이언트
  컴포넌트에서 서버 경로를 당겨 보니 **실제로 빌드가 깨진다** — 타입이 아니라 번들러가
  막는다. 지금 `PostBody` 는 서버 컴포넌트지만 이미지 뷰어가 붙으면 클라이언트가 되고,
  그때 `fetchPostDetail` 이 번들로 새는 것을 미리 막았다.
* **`export *` 를 전부 이름 지정 re-export 로 바꿨다.** 무엇이 공개되는지 `index.ts`
  만 보고 알 수 있어야 한다.
* **`_app` 레이어를 만들었다.** `themeColor` 가 `#141517` 로 하드코딩돼 있었는데
  `<meta name="theme-color">` 는 CSS 변수를 못 쓰는 자리다. 토큰 생성기가
  `colors.json` 을 내보내게 하고 거기서 끌어온다. CI 가 그 생성물도 검증한다.

## 2026-11-17 (5)
* **`screens/` 를 공식 이름인 `src/_pages/` 로 고쳤다.** 직전 커밋에서 "Next 의
  `pages/` 와 충돌하니 `screens/`" 로 정했는데, **FSD 공식 Next 가이드는 접두사를
  붙여 `_app`·`_pages` 로 쓰라고 안내한다**(공식 린터도 그 이름을 인식한다).
  관례를 기억으로 정한 것이 틀렸고 1차 출처로 바로잡았다.
* **충돌 회피책 3개를 실측했고 전부 빌드가 깨진다.** (1) 루트에 `pages/` 를 두면
  Next 가 라우트로 인식해 "default export 없음" 으로 실패, (2) 라우트를 `src/app`
  으로 내리면 Next 15 가 타입 검증기 상대경로를 잘못 생성, (3) `pageExtensions` 로
  좁히면 App Router 라우트가 전부 사라지고 404 만 남는다. **`app/` 을 루트에 남기고
  FSD 레이어만 `src/` 로 내리면** 셋 다 피한다 — 공식 트리가 그 모양인 이유다.
* **라우트를 re-export 한 줄로 바꿨다**(공식 패턴). 화면 조립은 `_pages/{화면}/ui/`
  가 갖는다 — 라우트에 두면 `app/` 이 다시 두꺼워진다.
* `lib/bridge.ts` 를 `src/shared/` 로 옮겨 FSD 의 shared 레이어에 맞췄다.
* **외부 사례 조사로 세 가지를 더 확인했다.** (1) 공식 경고 박스는 "쓰는 라우터와
  무관하게 `app`·`pages` 를 **둘 다** 개명하라" 이고, 이 지침은 2026-06에 바뀐
  최신본이다. (2) **`views`·`screens` 로 바꾸면 공식 린터(Steiger)가 레이어를 인식하지
  못한다** — 커스텀 레이어명을 지원하지 않아서다. 실사용 레포 중 `views` 를 쓰는
  사례가 있으나 공식 근거가 없다. (3) **루트에 빈 `pages/` 를 두는 구 방식은
  폐기됐다** — Next 16 빌드 실패와 `next/navigation` 훅 시그니처 변경 때문이다.
* **`_app` 레이어는 만들지 않았다.** 공식 트리에서 `_app` 은 API 라우트 구현을 담는
  자리인데 지금 API 라우트가 0개고 전역 설정은 `app/layout.tsx` 에만 있다. 생기면
  만든다.

## 2026-11-17 (4)
* **웹 내부 구조를 FSD 로 얕게 정렬했다.** `app/` 은 라우팅·전역만 남기고 화면 조립
  컴포넌트를 분리했다(이때 쓴 `screens/` 이름은 다음 항목에서 `_pages` 로 정정). Atomic Design 은 경계가 주관적이라 분류에
  시간이 들고 토큰이 이미 값 단일 출처라 쓰지 않는다. DDD 는 비즈니스 규칙이 전부
  서버에 있어 과하다. FSD 는 의존 방향이 한 방향이라 Flutter 쪽 규칙과 같은 사고
  모델이 된다.
* **`pages/` 대신 `screens/`** — Next 에서 `pages/` 는 레거시 라우터 디렉터리라
  그 이름을 쓰면 라우팅이 꼬인다.
* **`entities` 레이어를 두지 않기로 했다.** 서버 응답을 아는 코드를 `packages/api`
  한 곳에 모은다 — 타입(`types.ts`)과 매퍼(`mappers.ts`)가 붙어 있어야 서버 형식이
  바뀔 때 한 군데만 고친다. 나누면 같은 변경이 두 곳으로 번진다.
* **`features` 레이어도 지금은 만들지 않는다.** 좋아요·스크랩처럼 사용자 행동과 상태가
  생길 때 만든다. 읽기 전용 화면뿐인 지금 7개 레이어를 다 만들면 빈 폴더가 소음이 된다.

## 2026-11-17 (3)
* **`packages/api` 를 만들고 첫 웹뷰 화면(커뮤니티 글 상세)을 SSR 로 띄웠다.**
  Flutter 와 타입을 *공유*하는 게 아니라 **웹 전용** 클라이언트다 — 코드생성이 없어
  Dart 를 생성할 수 없다. 대신 **Dart 모델의 널 판단을 복제한다**(같은 응답에서 두
  플랫폼이 다른 화면을 그리면 안 된다). `Result<T>` 반환·`Failure` 5분류·타임아웃 15초가
  전부 Flutter 쪽과 같다.
* **설계를 실측으로 검증했다.** 비회원 조회 HTTP 200(SSR 의 전제), 스펙↔실제 응답 필드
  누락·추가 0건, 서버가 보낸 HTML 에 제목·작성자·조회수·좋아요가 전부 들어 있다.
* **`viewer` 널 판단이 틀린 것을 실측 응답으로 잡았다.** "비회원이면 null" 로 설계했는데
  비회원 조회에서도 서버가 객체를 준다(전부 false). Dart 도 `CommunityPostViewer._empty`
  로 메워 non-null 로 쓰고 있었다. **타입 체크는 런타임 응답을 보지 않으므로** 매퍼
  회귀 테스트를 붙였다(9건, PR마다 실행).
* **OpenAPI 스펙의 `required` 를 그대로 믿지 않기로 했다.** 글 상세는 스펙상 required 가
  0개라 전부 optional 로 읽히지만 실제로는 대부분 온다. Dart 의 실전 기준을 따른다.
* **본문 이미지가 두 번 그려지던 것을 고쳤다.** `body` 블록과 `images` 배열에 같은
  이미지가 오는데 둘 다 그렸다. Flutter `post_block_renderer.dart` 가 블록만 쓰므로
  같게 맞췄다 — text·image·link·embed 4종이고 모르는 타입은 건너뛴다.
* **없는 글(404)을 "서버 장애" 와 분리했다.** 재시도해도 소용없는 실패라 안내가 다르다.
* Node 내장 타입 스트리핑이 확장자 없는 상대 import 를 못 풀어 `tsx` 를 테스트에만 쓴다 —
  소스에 `.ts` 확장자를 붙이면 소비처(`apps/web`)에 tsconfig 플래그를 강요하게 된다.

## 2026-11-17 (2)
* **`packages/ui` 를 만들었다 — 웹 공용 React 컴포넌트.** 웹뷰 전환 범위를 "컨텐츠성
  화면만" 에서 **"목록·상세·폼까지 웹, Flutter 는 셸만"** 으로 넓히기로 하면서, UI 공유의
  성격이 바뀌었다 — Dart 와 React 가 같은 코드를 쓰는 게 아니라 **화면이 옮겨가는 만큼
  React 쪽이 유일한 구현이 된다.** 그래서 직전에 "불가" 로 판단했던 `ui-components` 를
  뒤집었다. 받아들인 것은 오프라인 동작과 네이티브 수준 전환 속도, 얻는 것은 레이아웃
  변경에 스토어 심사가 필요 없다는 점이다(Shorebird 패치가 과금으로 막힌 지금 유일한
  수단이다).
* **첫 3개는 Dart 위젯에서 수치를 옮기고 실제 렌더로 대조했다.** `BoardBadge`·`Button`
  (variant 6)·`DetailHeader`. 375 뷰포트에서 버튼 34×110.5·radius 8·14px, 배지 padding
  2/6·radius 4·11px, 헤더 34 + padding 18.5/20/22·18px — 전부 Dart 명세와 일치한다.
* **빌드는 통과하는데 실행해야 드러나는 함정 3개를 겪었고 전부 문서에 남겼다.**
  (1) `calc(34px * var(--scale))` — `--scale` 이 px 단위라 `px * px` 가 되어 선언이 통째로
  무효다. 콘솔도 조용하고 화면이 무너져야 안다. (2) 서버 컴포넌트가 `onClick` 을 넘기면
  런타임 500 — 라이브러리에 `'use client'` 를 붙여도 안 풀리고 **경계는 호출부**에 있어야
  한다. (3) 전역 `* { padding: 0 }` 이 버튼 padding 을 덮는다 — `@import` 는 맨 앞으로
  끌어올려져 순서로 못 이기므로 리셋을 좁혔다.
* **구독 버튼 폭을 고정값으로 옮기려다 Dart 구현을 잘못 읽었다.** 주석의 "한국어 64" 는
  결과값이고 실제로는 `TextPainter` 로 두 라벨을 재서 더 긴 쪽에 맞춘다. CSS 는 더 긴
  라벨을 `::before` 로 숨겨 깔아 폭을 잡는 방식으로 같은 거동을 냈다 — 로케일이 늘어도
  CSS 를 고치지 않는다.
* `pnpm typecheck` 를 turbo 그래프에 넣고 `ci-web-build.yml` 이 빌드 전에 돌린다.

## 2026-11-17
* **Flutter 를 루트에서 `apps/mobile/` 로 내려 `apps/` + `packages/` 표준 모노레포가 됐다.**
  그 전에는 Flutter 가 루트를 차지하고 Node 쪽만 하위에 있는 비대칭 구조였다 — 앱이 둘인데
  한쪽만 특별 대우를 받았다. 웹뷰 전환 spec 이 이것을 Out of scope 로 둔 근거("워크플로우
  전면 수정이 따라오고 태그를 밀어야 검증된다")를 실측으로 다시 재 보니, 경로 참조는
  워크플로우 6개에 36곳이고 cwd 를 바꿔야 하는 것은 13곳이었다. analyze·test·iOS 빌드·셸
  회귀로 대부분 검증돼서 뒤집었다. **검증되지 않는 범위는 `shorebird release`·`patch` 실행과
  스토어 업로드뿐이고, 남은 위험으로 받아들였다.**
* **셸 회귀 테스트가 치환 오탐 1건을 잡았다.** `patch-deploy-test.sh` 의 입력 문자열 중
  줄바꿈(`\n`) 뒤에 있던 `ios/Runner/Info.plist` 가 접두어 없이 남아, 네이티브 변경 차단
  가드가 통과해 버렸다. 태그를 밀어야 도는 워크플로우라 눈으로는 못 봤을 자리다.
* **`packages/design-tokens/` 로 토큰을 패키지화하고 turbo 를 넣었다.** `pnpm build` 가
  토큰 → 웹 순서를 보장한다(`apps/web` 이 `workspace:*` 로 의존 선언).
* **turbo 캐시가 패키지 밖 생성물을 잃는 함정을 발견해 막았다.** `outputs` 는 패키지 밖을
  캐시하지 못하는데, 생성기가 `apps/mobile/` 에 Dart 를 직접 쓰면 **캐시 적중 시 그 파일이
  사라진 채 `FULL TURBO` 로 성공이 보고된다**(실측 재현). 생성(`build`, 캐시됨)과
  복사(`sync:dart`, `cache: false`)를 분리하고 `turbo-cache-test.sh` 로 PR마다 3가지를
  검증한다 — 복원 여부, 캐시 적중 여부, 소스 변경의 Dart 반영 여부.
* **`Nx` 는 넣지 않기로 했다.** Nx 의 강점(프로젝트 그래프 기반 affected, 플러그인 추론)은
  JS/TS import 그래프에서 나오는데 JS 패키지가 2개뿐이고 실제 빌드 주체는 Flutter 다.
* **`packages/` 에 `shared-types`·`shared-api`·`ui-components` 를 만들지 않았다.** 후보 4개를
  실측했고 전부 "한쪽만 존재"였다 — 공통 원인은 **Flutter 가 코드생성을 쓰지 않는 것**이다
  (openapi·json_serializable·freezed 전부 없음). "선언 하나를 두 언어가 읽는" 형태는
  토큰에서만 성립한다. 근거 표는 웹뷰 전환 spec 에 남겼다.
* **문서 정리.** `docs/` 를 `wiki/` 로 합쳤다(policies·references). `scripts/`·
  `wiki/sync_github.py` 를 `tools/` 로 옮기고 산출물 경로를 고쳤다. `INDEX.md` 의 intent
  표가 7개 중 2개만 적혀 낙후돼 있던 것과, `AGENTS.md` 를 "CodeRabbit 용"이라 적은
  부정확한 설명(`.coderabbit.yaml` 에 그런 설정이 없다)을 고쳤다.
* **현행 문서가 가리키는 없는 파일 6건을 정정했다.** `fcm_service`·`standings_group_label`·
  `user_profile`·`solo_rank_rules` 는 2026-11-16 전환으로 위치가 바뀐 것이고,
  `home_sources` 는 섹션별로 쪼개져 사라졌고, `team_chip_rail` 은 죽은 코드로 삭제됐다
  (`shared-components.md` 의 개선 제안이 무효가 돼 그렇게 표시했다). `log.md`·`plans/`·
  `specs/` 의 옛 경로는 **과거 기록이라 그대로 뒀다.**
* **지우지 않은 것도 기록한다.** 미참조 에셋 16개(오브젝트·스펠·룬 아이콘)는 경기 상세·팀
  통계 화면용 선반입이다 — 서버에 `heralds`·`voidGrubs` 필드가 이미 있고 화면만 없다.
  `subscription` 의 알림 카드 3개도 "붙이기만 하면 되는 미완성"이라 주석에 명시돼 있다.
  `integration_test/` 는 `test/` 로 합치지 않았다 — `IntegrationTestWidgetsFlutterBinding`
  이 기기 타깃을 요구해서 `flutter test` 로는 못 돌고, 폴더 분리가 그대로 안전장치다.

## 2026-11-16 (3)
* **`core/ui` 오배치 3개를 정리했다.** `subscribe_bell`·`win_loss_text`(player 전용)를
  내리고, `mypage_card_section` 을 `core/ui/settings_card_section.dart` 로 올렸다 — 설정
  화면 4곳이 쓰는데 `mypage` 가 소유해서 남의 폴더를 보던 상태였다. 클래스명도
  `MypageCard*` → `SettingsCard*`. `core/ui` 48 → 47개.
* **외부 위젯 참조 37건을 분류해 전부 정당하다고 판단했다.** 같은 도메인 계열
  (match_day ← match_list 4건, league_icon 3곳), 의도적 공유 기능(solo_rank·my_players),
  배너 제공 구조(cheer_ad_banner 4곳), 화면을 띄우므로 소유가 맞는 것
  (login/guest_lock_overlay — `core/ui` 로 올리면 역참조), 주석에 의도가 명시된 것
  (notification_feed_card — "마이구독 피드와 알림함이 같은 카드를 그리도록 여기로 뺐다").
* **DTO 를 일괄 분리하지 않기로 하고 기준을 문서화했다.** 우아한형제들 글의
  `DTO → Entity → UI State` 3단 중 지금은 3기능만 그 형태다. 전환하지 않는 근거는
  `fromJson` 호출이 repository 구현(31파일)에서만 일어난다는 실측이다 —
  `presentation` 2건은 로컬 임시저장이고 `core`·`app` 은 0건이라 서버 형식이 화면으로
  새지 않는다. 97클래스를 만들어 얻는 것은 "Entity 에서 `fromJson` 이 사라지는 것" 뿐이고
  비용은 194클래스·4,000줄 + 테스트 fixture 115건이다. **새 모델은 처음부터 분리**하고,
  로컬 저장 직렬화(`Team.fromStorage`)는 서버 DTO 와 구분한다.
* **우아한형제들 글과의 격차를 한 절로 정리했다** — 7개 규칙 중 4개 준수(repository
  인터페이스 분리·Either·di_container·fetch 네이밍), 3개 의도적 차이(BLoC 미사용·
  UseCase 1개·DTO 부분 적용). 각각의 실측 근거를 적었다.
  [폴더 구조](/architecture/folder-structure.md)의 "우아한형제들 글과의 격차" 참고.

## 2026-11-16 (2)
* **`core` 에서 도메인 개념을 전부 빼냈다** (114 → 75파일). `core/domain/`(모델 9) 과
  `core/infrastructure/`(21파일) 를 해체했다 — 폴더 이름뿐 아니라 내용도 도메인이었다
  (마이구독 알림 피드 API·알림 잠자기 설정·실시간 경기 카드 제어·선호 팀 저장).
  `features/auth/`·`features/notification/`·`features/live_activity/` 를 신설하고,
  preference 7개와 ad 는 각 소유 기능으로, 모델 4개(schedule_match·team·
  calendar_week_start·team_notification_subscription)도 소유 기능으로 내렸다.
  `auth_service` ↔ `device_repository` 는 상호 참조라 한 묶음으로 옮겼다.
  **`core` 에 남는 것은 기술뿐** — ui(48)·util(17)·config(5)·error(3)·theme(1)·data(1).
  `api_status_exception` 은 `core/error/`, `team_logo_directory` 는 `core/ui/` 로 갔다
  (공용 위젯 2개가 쓰는 URL 캐시다).
* **`core` → `features`·`app` 참조가 0건이 됐다.** `di_container` 를 `app/` 으로 옮겨
  마지막 예외도 없앴다 — 조사한 레포 4개 전부 DI 를 앱 셸에 둔다.
* **판단 기준이 뒤바뀌었다.** 전에는 "소비처 2곳 이상 → `core`" 였는데 그 규칙이 `core`
  안을 도메인으로 채웠다. 이제 **"어느 도메인인가"가 먼저**다 — `auth_service` 는 20개
  기능이 쓰지만 인증 도메인이라 `features/auth/` 다. 조사한 레포 5개는 인프라를 공유
  위치에 두는데(5/5) 그 관행을 따르지 않았다. 대가는 `features/auth/` 가 20기능이 참조하는
  기능이 된 것이고, 얻은 것은 `core` 를 열었을 때 경기·팀·알림이 보이지 않는 것이다.
  순수 함수·포맷터(`match_status`·`rating_mapping`)와 공용 위젯(`team_logo`)은 도메인
  이름이어도 `core` 에 남는다 — 모델도 repository 도 없어서 성격이 다르다.
  [폴더 구조](/architecture/folder-structure.md)의 "core 에 도메인 개념을 두지 않는다" 참고.

## 2026-11-16
* **Entity 레벨(domain)의 역방향 참조를 없앴다.** `solo_rank_rules`(domain)가
  `solo_rank_sources`(data)를 참조하던 한 건이다 — 모델 5개
  (`SoloRankSnapshot`·`WorldsSoloSnapshot`·`WorldsTodayRecord`·`CheerResult`·
  `CheerRejected`)가 파싱 로직 없는 순수 모델인데 `data/` 에 있었다. 모델은
  `domain/solo_rank_snapshot.dart`, 소스 계약 3개는 `domain/repositories/` 로 올렸고
  `data/` 에는 구현만 남았다. 이제 `features/*/domain` → `data`·`presentation`·`app` 과
  `lib/domain` → `features`·`app` 전부 0건이다.
* **Entity 레벨이 어디인지 문서화했다.** `lib/domain/`(12) + `features/*/domain/`(36) = 46개가
  그 자리인데, 실제 비즈니스 규칙을 가진 것은 5개뿐이다(솔랭 분류·커뮤니티 글쓰기 권한·
  이용규칙·달력 격자·조용한 시간대). 나머지는 DTO 에 가깝다 — 이 앱의 규칙 대부분이
  백엔드에 있어서 정상이고, UseCase 가 1개뿐인 것도 같은 이유다.
  예외 1건으로 `quiet_hours` 가 `TimeOfDay` 를 쓴다(값 타입이라 그대로 둔다).
  [폴더 구조](/architecture/folder-structure.md)의 "Entity 레벨은 어디인가" 참고.

## 2026-11-13 (5)
* **뉴스·평점을 각 기능으로 옮겨 홈을 비웠다.** "백엔드 대기 중" 으로 보고 보류했던 둘인데
  실제로는 `ApiReviewSource`·`ApiNewsSource` 가 실 API(`/mobile/ratings/recent`,
  `/home/news`)를 부르고 릴리즈도 그걸 쓴다 — 목업은 `HOME_MOCKS` 뒤에만 있었다. 평점은
  `player_rating` 기능이 있어 거기로, 뉴스는 `features/news/` 를 신설했다. 같은 작업에서
  솔랭 API 소스도 옮겼다 — 솔랭을 독립시킬 때 `home_api_sources.dart` 의
  `ApiSoloRankSource`·`ApiWorldsSoloSource`·`ApiCheerSource` 를 놓쳤다.
  `home_sources.dart`(434줄)·`home_api_sources.dart`(245줄)가 사라지고
  `home_models.dart` 는 `HomeShortsVideo` 하나만 남았다.
  **홈 ViewModel 이 직접 쓰는 repository·소스가 0개가 됐다** (1141 → 469줄).
  공유 헬퍼 `minutesSince` 를 `core/util/server_time.dart` 로 올렸다 — 솔랭 종료·평점
  작성·뉴스 발행 세 곳이 쓴다. 테스트 955 → 965.

## 2026-11-13 (4)
* **`app/` 을 5파일로 줄이고 폴더로 갈랐다.** `live_activity_logo_prefetcher`·
  `live_match_activity_controller` 는 화면을 띄우지 않으므로(Screen·Navigator 참조 0건)
  앱 셸이 아니었다 — 기능 repository 를 쓰는 것이 유일한 이유였는데 반환 타입이 전부
  `lib/domain/` 공용 모델이라 훅 5개로 끊어 `core/infrastructure/live_activity/` 로 내렸다.
  남은 5개는 `app/deeplink/`(푸시·위젯 진입)·`app/navigation/`(경기 상세 창구·탭 전환)·
  `app_hooks.dart`(조립)로 나눴다. 클래스명은 유지했다 — `FcmService` 는 딥링크만 하는 게
  아니라 토큰 등록도 하고, `HomeWidgetService` 는 App Group 설정도 한다.
  판별 기준을 한 줄로 고정했다: **"기능 2개 이상의 화면이나 구현을 알아야 하나"**.
* **공용 컴포넌트와 앱 셸의 배치를 실제 앱 4개로 검증했다**(nowinandroid·compass_app·
  Immich·AppFlowy). 같은 위치에 두는 레포 0개, 라우터·탭을 앱 셸에 두는 레포 4/4.
  공용 폴더가 feature 를 참조하는 사례 2개(AppFlowy `lib/shared/`, Immich
  `lib/widgets/common/`)는 둘 다 부채로 취급해 순수 패키지로 이동 중이다. 지금 `core/ui`
  52개는 features·app·domain 참조 0건이라 그 오염이 없다. 다음 개선은 빌드 단위 격리 —
  4개 중 3개가 디자인 시스템을 모듈·패키지로 떼어 역참조를 컴파일 에러로 막는다.
  [폴더 구조](/architecture/folder-structure.md)의 "app/ 과 core/ui/ 는 왜 다른 자리인가" 참고.
* 옮긴 모델에서 `Home` 접두어를 뗐다 — `HomeLiveSoloPlayer`→`LiveSoloPlayer`,
  `HomeFinishedSoloPlayer`→`FinishedSoloPlayer`, `HomeLeagueChip`→`LeagueChip`(26파일).

## 2026-11-13 (3)
* **홈 섹션 8개를 각 기능으로 내렸다.** 홈 ViewModel 이 1141줄로 섹션 9개를 직접 들고
  있었고, 그중 7개는 이미 대응 기능이 있는데도 홈이 그 repository 를 직접 불러서 다른
  화면에서 같은 섹션을 쓸 수 없었다. 커뮤니티·공지배너·벨배지·오늘경기·구독선수·솔랭·
  쇼츠·순위표를 각 기능의 `presentation/viewmodels/` 로 옮기고, 홈은 getter 위임만 남겼다
  (1141 → 501줄). 직접 쓰는 repository 는 뉴스·평점 2개(백엔드 대기)뿐이고 `di_container`
  import 도 필요 없어졌다. 순위표는 대응 기능이 없어 `features/standings/` 를 신설했다
  (모델·repository 5파일도 `home/` 에서 함께 옮겼다). 테스트 897 → 955 — 섹션 로직이 홈
  안에 묶여 검증할 수 없던 규칙들을 각 VM 에 붙였다. 자세한 원칙은
  [폴더 구조](/architecture/folder-structure.md)의 "집계 화면은 섹션을 조합만 한다" 참고.
* **응원팀 결정 규칙을 UseCase 로 뺐다** — `features/home/domain/usecases/
  get_preferred_team.dart`. repository 3개를 조합하고 폴백 순서가 규칙인데 ViewModel 안에
  있어 테스트가 없었다. 반대로 홈의 섹션 로더들은 UseCase 로 빼지 않았다 — 실측하니
  대부분이 repository 1개만 쓰고 나머지는 경쟁 조건 검사·로딩 플래그로, 화면 상태 관리라
  ViewModel 의 일이다.

## 2026-11-13 (2)
* **솔랭을 `features/solo_rank/` 로 독립시켰다** (6파일). `player`·`my_players` 가
  `features/home/` 을 17곳에서 당겨 쓰던 것을 0건으로 만들었다. 모델 2개
  (`HomeLiveSoloPlayer`·`HomeFinishedSoloPlayer`)·소스 3종(`SoloRankSource`·
  `WorldsSoloSource`·`CheerSource`)·규칙(`solo_rank_rules`)·응원 컨트롤러·위젯 2개가
  대상이다. `home_sources.dart` 434줄은 솔랭을 빼고 122줄(뉴스·평점만), `home_models.dart`
  201줄은 104줄이 됐다. 양쪽이 공유하던 `kHomeMocks` 는 `core/config/home_mocks.dart` 로
  올렸다 — `player_repository` 도 같은 플래그로 목업을 가르므로 홈 전용이 아니다.
  홈 레이아웃 전용 위젯 4개(`home_solo_parts`·`home_solo_rank_section`·`home_solo_states`·
  `home_worlds_solo`)는 `home` 만 쓰므로 그대로 뒀다. 클래스명의 `Home` 접두어는 93곳이라
  이 작업에 섞지 않았다(이동 실패와 이름 변경 실패를 가릴 수 없게 된다).
  analyze 통과, 테스트 902 통과.
* **응원팀 결정 규칙을 UseCase 로 뺐다** — `features/home/domain/usecases/
  get_preferred_team.dart`. repository 3개(`auth`·`onboarding`·`teamPreferences`)를
  조합하고 폴백 순서가 규칙인데 ViewModel 안에 있어 테스트가 없었다. 분리하고 5개를
  붙였다. 반대로 홈의 다른 섹션 로더 12개는 빼지 않았다 — 실측하니 10개가 repository
  1개만 쓰고 나머지는 경쟁 조건 검사·로딩 플래그·notify 로, 화면 상태 관리라 ViewModel 의
  일이다.
* **`home_widget_service` 1035줄을 책임 둘로 쪼갰다** — `app/home_widget_service.dart`
  259줄(위젯 탭 → 화면 열기) + `features/schedule/data/schedule_widget_writer.dart`
  809줄(위젯에 데이터 쓰기). `features → app` 역참조 18건 중 4건이 사라졌다(18 → 14).
  분할선은 static 가변 상태 5개가 전부 딥링크 영역에만 있다는 실측으로 정했다.

## 2026-11-13
* **`core/domain/` 을 `lib/domain/` 으로 올렸다** (모델 10개 + repository 인터페이스 2개,
  import 126 파일 수정). 도메인 모델이 기술 인프라(`core/`) 의 하위로 읽히던 것을 최상위
  형제로 바꿨다. 같은 작업에서 `core/domain/` 에 섞여 있던 기술 계약을 성격별로 분리했다 —
  `failure`·`failure_exception` → `core/error/`, `usecase` → `core/usecase/`.
  판단 근거는 실제 앱 5개 조사다: 공유 도메인 모델을 최상위 공유 위치에 두는 레포가 4
  (nowinandroid `core:model`, compass_app·Immich `lib/domain/models/`, LocalSend `lib/model/`),
  소유 feature 에 두는 레포가 1 (AppFlowy). "공유 위치는 도메인 중립이어야 한다" 를 지키는
  레포는 0/5 라서, `schedule_match` 처럼 명백한 도메인 개념이 `domain/` 에 있는 것이 정상이다.
  반대로 인프라 서비스는 5/5 전원 공유 위치이므로 `core/infrastructure/auth` 는 19개 기능이
  쓰더라도 `features/auth/` 로 내리지 않는다. `domain/` 은 `core/` 조차 import 하지 않는다
  (현재 `l10n` 생성물 외 참조 0건). analyze 통과, 테스트 897 통과.
  [폴더 구조](/architecture/folder-structure.md)의 "domain 이 최상위인 이유" 참고.

## 2026-11-10
* **`core → features` 역방향 참조를 없앴다** (66건 → DI 컨테이너 24건만 남김). 앱 셸 코드 6개를
  새 `lib/app/` 로 옮기고, 한 기능 전용 위젯·모델 9개를 그 기능으로 내렸다. core 가 화면·구현을
  알아야 하던 3곳은 훅(`AuthService.loginScreenBuilder`·`onSignedOut`,
  `TeamLogoDirectory.defaultLoader`)으로 바꾸고 `app/app_hooks.dart` 에서 연결한다. 반대로
  공용이던 `quiet_hours`·`team_logo_directory`·`parseServerTime` 은 core 로 올렸다. 같은 작업에서
  같은 폴더 상대 import 55건 중 `l10n` 생성물을 뺀 나머지를 `package:` 절대경로로 바꿨다.
  [폴더 구조](/architecture/folder-structure.md)의 "의존 방향" 참고.
* **repository 를 Interface + `Either<Failure, T>` 로 바꿨다** (API repository 23 개 중
  14 개 전환, 9 개는 기준에 따라 제외). 목적은 둘이었다 — repository 인터페이스가 있어야
  `mocktail` Mock 이 되고(전에는 테스트마다 Fake 를 손으로 썼다, 49 개), `Either` 를 쓰면
  `try/catch` 를 빠뜨릴 수 없다.
  * **테스트가 구체적으로 나아졌다.** `expect(..., throwsException)` 이
    `expect(failure, isA<ServerFailure>()); expect(failure.statusCode, 404)` 가 됐다 —
    전자는 네트워크 오류든 파싱 오류든 통과했다.
  * `core/` 에 `failure.dart`(sealed) · `failure_exception.dart` ·
    `data/failure_mapper.dart` · `di_container.dart`(get_it) 를 추가했다.
    `pubspec` 에 `get_it`·`fpdart` 가 늘었다 → **Shorebird 패치로 못 나간다.**
  * **제외 기준 5 개를 문서화했다.** 처음 30 개로 보였던 범위가 실측으로 절반이 됐다 —
    로컬 저장소 전용(실패가 기본값으로 수렴), 인프라끼리 쓰는 것(결과를 안 씀),
    인터페이스가 이미 있는 것(`player`·`home_api_sources`), 도메인 예외로 분기하는 것
    (커뮤니티 4 개는 `CommunityApiException` 의 `code`·`retryAfterSeconds` 로 409 를
    성공 처리한다), DTO/Entity 분리가 비용을 넘는 것(`CategoryTree` 90 줄 → 260 줄).
  * 절차·함정 14 개·판별 기준은
    [Clean Architecture 전환 플레이북](/playbooks/clean-architecture-migration.md) 에 있다.
    특히 `Future.wait` 인덱스 캐스팅은 **`analyze` 를 통과하고 런타임에 깨지는** 유일한
    패턴이라 따로 적어 뒀다.
* **feature 단위 폴더 구조로 전환했다** (기능 27개 전부).
  레이어가 최상위 축이어서 한 기능을 작업할 때 네 군데(`model`·`repository`·`viewmodel`·
  `screens`)를 오가야 했다. 실측으로 `community` 는 **45 파일이 4 곳에 흩어져** 있었고,
  `lib/model/` 은 37 개가 평면 배치라 `community_` 접두어 9 개가 알파벳 순으로 끼어 있었다.
  * 기능별로 `data`(repository·API 예외·전용 DTO) / `domain`(모델·규칙·상수) /
    `presentation`(screens·viewmodels·widgets) 세 레이어를 한 폴더에 모은다.
  * **상태 관리는 `ChangeNotifier` MVVM 을 유지한다.** `presentation/` 은 BLoC 을 전제한
    이름이지만 지금은 ViewModel 이 그 자리에 있다 — 나중에 바꿀 때 폴더는 그대로 쓴다.
    Flutter 공식 권고도 MVVM + Repository 라서 아키텍처 자체를 바꿀 이유가 없었다.
  * **import 를 `package:warding/...` 절대경로로 바꿨다.** 이게 핵심이다 — 상대경로라서
    `community` 를 옮기는 중 **540 건이 깨졌다**. 공용 폴더(`styles`·`util`·`components`·
    `l10n`) 참조까지 절대경로로 바꿔 뒀으므로, 다음 기능부터는 거의 `git mv` 로 끝난다.
  * **`my_community_activity` 가 별도 기능임을 발견했다.** `community_activity_repository`
    와 `community_my_activity` 모델은 접두어가 `community_` 지만 그 기능만 쓴다. 이름만
    보고 community 소유로 넣으면 남의 폴더를 들여다보게 된다.
  * 화면이 아닌 파일 3 개(`community_permission`·`community_rules`·`community_teams`)를
    `screens` 에서 `domain` 으로 옮겼다. 규칙·상수인데 화면 폴더에 있었다.
  * `core/{domain,infrastructure}` 는 만들어만 뒀다. 공유되는 것을 올릴 자리다 —
    `auth`(8 개 기능)·`preference`(7)·`onboarding`(5)·`rating`·`subscription`(각 4) 이
    후보지만, 이동 영향이 한 기능을 넘어가 별도로 판단한다.
  * **`lib/screens`·`viewmodel`·`model`·`repository` 최상위 폴더는 없어졌다.** 총 361 파일
    변경(이동 233 / import 수정 127). `community` 를 먼저 시범해 절대경로 전략을 확인한 뒤
    나머지 24 개를 한 번에 옮겼다 — 중간 상태를 길게 두면 "어떤 기능은 새 구조, 어떤 건
    옛 구조" 가 되어 그 위에 올릴 작업(웹앱 모노레포)이 더 헷갈린다.
  * `core/infrastructure` 9 개(`auth`·`preference`·`notification`·`fcm`·`ad`·`device`·
    `rating`·`team`·`live_activity`), `core/domain` 모델 12 개.
  * **`components`·`styles`·`config`·`util` 도 `core/` 아래로 모았다**
    (`core/ui`·`core/theme`·`core/config`·`core/util`). 처음엔 최상위에 뒀는데, 그러면
    `core/` 에 넣은 `team`(2 곳)보다 훨씬 더 공유되는 것들(`styles` 27 곳·`components`
    25 곳·`util` 22 곳·`config` 16 곳)이 밖에 남아 기준이 어긋났다. 규칙을 한 문장으로
    정리했다 — **기능 소유면 `features/`, 아니면 `core/`.** `l10n/` 은 `l10n.yaml` 이 경로를
    못박는 생성물이라 최상위에 남겼다.
  * **`core/` 배치를 한 번 재검토했다.** "presentation 만 있는 기능이 많다" 는 지적을 받아
    소비처를 다시 셌더니 기준을 잘못 적용한 것이 나왔다 — `rating` 은 4곳이 쓰지만
    `player_rating` 기능이 있으니 이름 매칭 규칙상 그쪽 소유였다. `team` repository(`home`
    1곳)·`onboarding_selection`(`onboarding` 1곳)·`quiet_hours`(`mypage` 1곳)·
    `game_rating`(`player_rating`)도 함께 내렸다. **`core/` 안에서의 참조는 소비처로 세지
    않는다**는 규칙도 명시했다 — `device` 는 기능 소비처가 0 이고 `auth_service`·
    `fcm_service` 만 쓰므로 `core/` 가 맞다.
  * `presentation` 만 있는 기능 13개는 그대로 뒀다. 데이터가 공용이거나(`mypage` →
    `core/domain/user_profile`) 애초에 자기 데이터가 없는 화면(`login`·`withdraw`·`guide`)
    이다. 빈 폴더는 구조가 아니라 소음이다.
  * **소유자 판단에서 `home` 을 소비처로 세지 않았다.** `home` 은 집계 화면이라 거의 모든
    기능을 당겨서, 그걸 세면 repository 20 개 중 15 개가 `core/` 로 가 버린다. 이름이 같은
    기능이 있으면 그 기능 소유로 봤다 — `notice` 는 `home` 도 쓰지만 `features/notice/data/`.

## 2026-11-09
* **DAU 알림에 앱 진입 경로를 넣었다.** "활성 사용자 1856" 만으로는 그 사용자들이
  푸시로 들어왔는지 런처로 켰는지 알 수 없었다. 두 축으로 나눠 보여준다.
  * **`app_open` 이벤트를 새로 심었다**(`AnalyticsEvent.appOpen`). 앱을 켤 때 한 번,
    `entry_point` 를 실어 쏜다 — `push`(종료 상태 푸시) / `widget`(홈 위젯 딥링크) /
    `launcher`(그 외). 기존 `page_view` 의 `entry_point` 는 **경기 상세·로그인에만**
    실려서, "푸시로 들어왔지만 경기 상세에 안 간 사용자" 의 경로를 알 수 없었다.
  * **선점 규칙**: 경로를 아는 쪽이 셋(FCM·위젯·스플래시)이라 각자 부르게 두고
    `Analytics.trackAppOpen` 이 **실행당 첫 호출만** 채택한다. 순서를 호출부들이
    맞추게 하면 경로가 늘 때마다 그 약속이 깨진다. 특히 스플래시가 `launcher` 로
    덮으면 푸시 유입이 통째로 0 이 되는데 숫자만 보면 "푸시로 오는 사람이 없다" 로
    읽혀 조용히 실패한다 — 회귀 테스트 7개로 고정했다.
  * 위젯 딥링크는 **보류(`_pendingWidgetUrl`)보다 먼저** 기록한다. 보류되면 실제
    내비게이션이 스플래시 뒤로 밀려 그때는 이미 늦는다.
  * 집계는 `app_open` 이 있으면 **그것만** 쓴다. `page_view` 와 섞으면 같은 사용자가
    `app_open=launcher` 와 `page_view=in_app` 으로 두 번 세어진다. 계측이 사용자에게
    닿기 전 과도기에는 `page_view` 로 떨어지고, 알림이 그때만 "부분 집계" 주석을 단다
    (`entry_from_app_open` 플래그).
  * 보조 축으로 **첫 화면 분포**(`first_pages`)를 함께 보여준다 — 그날 첫 `page_view`
    로 진입을 추론한다(`exit_pages` 의 거울). 화면을 한 번도 안 보고 끈 사용자는
    빠지는 근사치지만, 경로 미상이 많은 날 그 공백을 메운다.
  * jq 회귀 테스트 2 케이스 추가(`[8]`·`[9]`). `entry_points` 합 + 미상 = DAU 가
    성립하는지도 검증한다 — `versions` 와 같은 중복 집계 함정이 있다.

## 2026-10-31
* **업데이트 팝업을 필수 업데이트일 때만 띄운다.** 예전에는 스토어에 더 높은 버전만 있으면
  앱을 켤 때마다 띄웠다. 주 2회꼴(8/9~10/27 동안 24개 버전, 그중 15개는 Dart 만 바뀐 일반
  배포) 배포와 겹쳐 사용자는 거의 매번 팝업을 봤고, **팝업을 닫는 습관**이 생기면 정작
  올려야 하는 버전에서도 같이 무시된다.
  * 이제 스토어 설명 끝의 최소 버전 태그보다 설치 버전이 낮을 때만 띄운다(`upgrader` 의
    `belowMinAppVersion()` — 백엔드·새 의존성 없음). 태그가 없으면 팝업은 뜨지 않고 일반
    배포는 스토어 자동 업데이트에 맡긴다. 판단은 `core/util/update_prompt.dart` 에 있고,
    사용법은 [distribution/README](../distribution/README.md).
  * **태그 형식이 스토어마다 다르다** — App Store 는 `[:mav: x.y.z]`, Play 는
    `[Minimum supported app version: x.y.z]`. upgrader 가 양쪽에서 다른 정규식으로 찾는다.
    한쪽 형식을 양쪽에 쓰면 그 스토어에서는 태그가 없는 것과 같아져 **팝업이 아예 뜨지
    않는다** — 달아도 아무 일이 없으니 확인하기도 어렵다.
  * `isUpdateAvailable()`(스토어 버전 > 설치 버전)도 함께 본다 — **이미 최신인데 태그만
    높은 경우**에 받을 게 없는 팝업이 뜨는 것을 막는다. 다만 이 가드가 막지 못하는 게
    둘 있다: 태그를 **스토어에 아직 없는 버전**으로 적으면(태그 1.0.50 / 스토어 1.0.43 /
    설치 1.0.42) 올려도 태그에 못 닿아 팝업이 계속 뜨고, 10-27 사고처럼 표시 버전과
    바이너리가 어긋난 경우도 메타데이터만 보기 때문에 못 걸러낸다. 그래서 **태그는 반드시
    이미 출시된 버전 이하**로 적어야 하고, 후자의 방어는 릴리즈 파이프라인의 ASC 직접
    조회가 맡는다.
  * 회귀 테스트 8개 — 태그 없음/태그 미만/이미 최신인데 태그만 높음/태그를 미출시 버전으로
    적음/최신, 그리고 팝업 동작.

## 2026-10-30
* **업데이트 체크를 `splash_screen.dart` 밖으로 뺐다**(`core/util/update_prompt.dart`). 조회·팝업·
  스토어 이동을 주입 가능하게 해 테스트 5개를 붙였다. 10-27 사고(스토어 표시 1.0.41 /
  바이너리 1.0.39 → 무한 팝업)가 난 경로인데 테스트가 0개였다.
  * `durationUntilAlertAgain: Duration.zero` 를 걷어내 upgrader 기본값(3일)을 쓴다. 매 실행
    알림은 사용자가 팝업을 닫는 습관을 만들어, 정작 올려야 하는 버전에서도 같이 무시된다.
  * **"어떤 버전에 팝업을 띄울지" 는 아직 이 파일이 결정하지 않는다.** 그 판단을 스토어
    설명의 최소 버전 태그(`belowMinAppVersion()`)로 옮기는 작업은 별도로 진행 중이며,
    로직이 들어올 자리가 `checkForUpdate` 다.
* **패치도 태그를 밀면 자동으로 나간다**(`patch-deploy.yml`). `patch/<릴리즈 버전>/<번호>`
  태그 → verify → e2e → iOS·Android 패치 → Discord 알림.
  * **패치로 나갈 수 없는 변경을 파이프라인이 막는다.** 릴리즈 태그와 diff 해서 `ios/`·
    `android/`·`assets/` 변경이나 pubspec 의존성 변경이 섞였으면 중단한다. 이건 조용히
    실패하는 종류다 — 통과시키면 패치는 성공한 것처럼 나가고, 그 코드를 기대하는 Dart 가
    사용자 기기에서 깨진다.
  * **e2e 통과를 기다린다.** 릴리즈는 빌드와 병렬로 돌리고 업로드 직전에 결과를 보지만
    (macOS 러너가 비싸서), 패치는 올리면 심사 없이 바로 사용자에게 가므로 먼저 막는다.
  * 가드 로직은 `patch-deploy-test.sh`(24개 케이스)로 PR마다 검증한다. 태그를 밀어 봐야
    도는 워크플로우라 눈으로는 확인할 수 없다.
  * 패치는 업데이트 팝업을 띄우지 않는다(스토어 버전이 그대로다). Dart 만 바뀐 수정을
    되도록 패치로 내보내면 팝업 자체가 줄어든다.

## 2026-10-29
* **경기일정과 경기리스트를 한 화면으로 합쳤다.** 하단 네비 탭 2개(`경기일정`·`경기리스트`)가
  탭 1개(`경기`)가 되고, 캘린더와 경기 목록이 한 화면에 세로로 함께 놓인다.
  * **캘린더는 목록 스크롤에 따라 월간(6주) → 주간(1주) → 숨김 3단계로 줄어든다.**
    접거나 숨겨도 아래 목록은 그대로다 — 목록이 날짜에 종속되지 않은 연속 스크롤이라,
    캘린더 높이는 "얼마나 넓게 볼까"의 문제일 뿐이다. 전환 방법:
    * **목록을 내리면 한 단계씩 접힌다.** 더 보려고 스크롤하는 것 자체가 "목록을 넓혀
      달라"는 신호라 손잡이를 따로 누를 필요가 없다. 월간→주간 문턱(12px)은 하단 네비
      축소(`BottomNavShrinkController`)와 같은 값이고, **주간→숨김은 160px** 로 훨씬
      크다. 두 단계가 같은 문턱이면 한 번 쓸어내릴 때 둘이 연달아 터져 주간 캘린더가
      깜빡이고 사라진다. 각 단계를 넘을 때 누적량을 0 으로 되돌려, 한 플링이 두 칸을
      먹지 않게 했다.
    * **올릴 때는 숨김 → 주간까지만** 되돌린다. 월간으로 펴는 길은 손잡이 화살표뿐이다 —
      중간에서 조금 올린 것만으로 6주가 펼쳐지면 보던 자리가 통째로 밀려난다.
      예외로 **맨 위(스크롤 0)에 닿으면** 월간으로 되돌린다.
    * 캘린더 아래 **화살표 손잡이** 탭 — 월간이면 ▲, 주간이면 ▼ 로 돌아간다.
      숨김 단계에서는 접을 것이 없어 손잡이도 함께 사라진다.
    * 그 손잡이를 세로로 **드래그**.
    * 주간 줄이 화면에 없는 동안(월간·숨김)은 "보고 있는 주" 리포트가 `setState` 없이
      기준 날짜만 조용히 갱신한다. 주간으로 돌아오면 지금 보고 있는 주가 그대로 뜨고,
      그 사이 매 스크롤 프레임마다 재빌드하지는 않는다.
    * 헤더(월 라벨 옆)에도 화살표를 뒀다가 뺐다. 전환 대상인 캘린더의 경계에 붙어
      있어야 무엇이 접히는지 분명하고, 헤더에 요소가 하나 줄어 월 라벨·스포방지
      라벨이 서로를 밀어내 잘리던 것도 함께 해결됐다.
  * `CalendarMonthGrid` 에 `weekOfMonth` 를 더해 한 주만 그릴 수 있게 했다. 날짜 좌표는
    월간과 **같은 그리드 기준**이라 접을 때 그 주 행이 제자리에 남는다.
  * **캘린더 날짜 탭 → 아래 목록을 그 날짜로 스크롤한다.** 예전엔 날짜별 화면
    (`MatchDayScreen`)을 새로 띄웠는데, 그 목록이 이제 같은 화면에 이미 있다.
    경기 없는 날도 탭하면 선택이 옮겨간다(주간 모드에서 보는 주를 바꾸는 수단).
  * **시즌·리그·팀 필터와 정렬은 헤더 필터 버튼 뒤 시트로 옮겼다**(`ScheduleListFilterSheet`).
    상시 노출하던 줄들인데 캘린더와 세로를 나눠 쓰게 되어 자리가 없다. 스포방지 토글은
    헤더로 올라갔다.
  * 그 시트는 **경기 일정 필터 시트와 같은 드롭다운**을 쓴다. `filter_sheet.dart` 안에만
    있던 비공개 `_SelectField`·`_DropdownList`·`_DropdownItem` 을
    `core/ui/nar_select_dropdown_field.dart`(`NarSelectDropdownField`·`NarSelectOption`)
    로 끌어올려 둘이 공유한다 — 같은 버튼에서 열리는 같은 계열 시트라 드롭다운이 두
    종류로 보이면 안 된다. 셀렉트박스·체크 항목은 기존 `AppSelectBox`·`LabeledField`
    ·`NarFilterSheet` 조합 그대로다. 시즌·리그·정렬은 단일 선택(고르면 닫힘),
    팀만 다중 선택으로 열어 둔 채 토글한다.
  * 목록 본문은 `MatchListView` 로 떼어내 호스트 화면이 얹는다. VM 은 호스트가 들고 있다 —
    헤더(스포방지·필터 시트)와 목록이 같은 VM 을 봐야 해서다.
  * `MatchListScreen` 은 `ScheduleScreen` 을 띄우는 껍데기로 남겼다. 홈 '전체 대진' 등
    기존 진입 경로를 고치지 않아도 되게 하려는 것이다. `AppNavTab.matchList` 와 라우팅도
    마이구독과 같은 방식으로 남겨 뒀고, 하단 네비 목록에서만 뺐다.
  * 필터 시트의 '초기화'용으로 `MatchListViewModel.resetFilter` 를 더했다(정렬은 건드리지
    않는다 — 필터가 아니라 보기 방식이다).
  * 이 "따라가기"는 처음에 **스크롤을 먹통으로 만들었다.** 콜백이 스크롤 프레임마다
    불리는데 매번 `setState` + `displayMonth` 대입(→ `loadCalendar`)이 걸려, 목록을
    미는 동안 캘린더 `PageView` 가 프레임마다 새로 만들어졌다. 네 겹으로 막았다:
    월이 **실제로 바뀔 때만** 캘린더를 옮기고, 주(week) 추적은 **주간 모드일 때만**
    그나마 보는 주가 달라질 때만 `setState` 하고, 계산 자체를 **60px 이동마다**로
    throttle 하고, 자동 스크롤(`_autoScrolling`) 중에는 아예 건너뛴다.
    `setAnchorMonth` 의 첫 통지(= 이번 달)도 무시한다 — 진입 조회와 겹쳐 같은 목록을
    두 번 받던 경로다(테스트로 고정).
  * **캘린더를 자기 행 수만큼만 띄우면서 월 좌우 스와이프가 죽었던 것**을 고쳤다.
    `CalendarMonthGrid` 는 행 높이에 하한(`minRowHeight` 64)을 두는데, 부모가 그보다
    조밀한 높이를 주면 그리드가 부모를 넘어 `SingleChildScrollView` 가 켜지고 —
    **그 세로 스크롤뷰가 좌우 스와이프 제스처까지 가져간다.** 월간은 목록과 세로를
    나눠 쓰느라 48 로 그리므로 하한도 함께 낮출 수 있게 `minRowHeightOverride` 를
    더했다. 증상이 "스크롤이 먹통"으로 보여 원인이 레이아웃이 아니라 제스처 쪽이라는
    걸 알기 어렵다. 기존 `schedule_calendar_test.dart` 의 드래그 테스트가 이걸 잡았다.
  * **한 칸에 경기 칩이 두 개 보이게 했다.** 칩 높이 18 → 15(글자 8 은 그대로,
    위아래 여백만), dots 15 → 13, 날짜 줄 위아래 패딩 3 → 2. 그만큼 아낀 자리를
    칩에 돌려, 월간은 칸 56 에서 **칩 2개**, 주간은 64 에서 **칩 2개 + dots** 가
    들어간다. 월간을 62 로 올리면 주간처럼 dots 까지 들어가지만 그만큼 아래 목록이
    줄어 카드가 한 장도 온전히 안 보여서 56 에서 멈췄다.
  * 스켈레톤도 같은 규칙을 쓰게 맞췄다(`minRowHeightOverride`·고정 높이). 안 맞추면
    로딩이 끝나는 순간 칸 높이가 바뀌며 아래 목록이 통째로 밀린다 — 기존 스켈레톤
    회귀 테스트가 이걸 잡았고, "뷰포트를 꽉 채운다" 를 전제하던 테스트 2개는 이제
    캘린더가 자기 행 수만큼만 쓰므로 그 전제에 맞게 고쳤다.
  * **월간 행 높이 64 → 48.** 6주를 64 로 그리면 384 라 화면 세로 절반을 먹고 아래
    목록이 거의 안 남는다(캘린더가 화면을 통째로 쓰던 시절의 값). 주간은 한 줄뿐이라
    64 그대로 둔다 — 접었을 때 칸이 큰 편이 날짜를 고르기 쉽다.
  * **주간은 전용 위젯**(`ScheduleWeekCalendar`)으로 분리했다. 목록을 내려 다음 주
    경기로 넘어가면 캘린더가 **옆으로 미끄러지며** 그 주로 간다 — 값만 갈아끼우면 툭
    바뀌어 어느 방향으로 이동했는지 알 수 없다. 월간 `PageView` 를 재사용하지 않은
    이유: 그쪽은 페이지 단위가 '달'이고 정착·기준월 재배치 로직이 전부 그 전제 위에
    있어, '주' 축을 겹치면 두 단위가 한 컨트롤러를 두고 다툰다. 주간 상태에서 좌우로
    쓸면 전주/다음주로 넘어간다(예전에는 월 단위라 한 달씩 건너뛰었다).
  * **첫 진입에 오늘이 선택돼 있다**(`_selectedDate` 초기값). 들어오자마자 아무 날짜도
    안 골라진 상태면 주간으로 접었을 때 어느 주를 비출지 모호하다. 위젯 딥링크로 다른
    달에 진입한 경우엔 그 달에 오늘이 없으므로 선택을 비운다.
  * **앱 ↔ 홈 위젯 달을 양방향으로 맞춘다.** 앱에서 달을 바꾸면 `loadCalendar` 가
    `HomeWidgetService.updateCalendar` 로 위젯을 밀고(원래 있던 방향), 위젯에서
    prev/next 로 달을 넘기면 **앱 복귀 시** `_syncMonthFromWidget` 이 그 달로 당긴다
    (새로 추가 — 예전엔 진입 때 한 번뿐이라 백그라운드 중 위젯이 바뀌면 갈렸다).
    순환은 "양쪽 달이 같으면 전파 중단"으로 끊는다. 그 비교 기준도 '이번 달'에서
    **'앱이 지금 보고 있는 달'** 로 고쳤다 — 전자면 위젯이 이번 달로 돌아왔을 때
    앱이 다른 달에 머물러 있어도 못 따라간다.
  * **월 라벨이 안 뜨던 것**을 고쳤다. 라벨이 `_calendarProgress` 에만 의존했는데 그
    값은 월간 페이저가 갱신해 주는 거라, 주간으로 접히거나 스켈레톤·에러로 캘린더가
    교체되면 멈춘다. 정착 상태(`page == 0`)에서는 VM 의 월을 직접 쓰도록 했다.
  * **날짜 칸이 좌우 스와이프를 삼키던 버그.** 칸마다 생긴 탭 인식기가 제스처
    아레나에서 이겨 `PageView` 가 드래그를 못 받았다
    (월·주 이동이 통째로 무반응). 칸은 한 줄 높이(64)뿐이라 세로로 멀어질 여지도
    없어 아레나가 탭 쪽으로 기운다. `GestureDetector` 대신 `Listener` 로 '탭 다운 →
    12px 안에서 탭 업'만 직접 보는 `_TapOnly` 로 바꿨다 — 아레나에 참가하지 않으므로
    드래그는 그대로 부모에게 간다. 기존 테스트가 이걸 놓친 이유는 `onEmptyDateTap`
    을 안 넘겨서였다(= 칸에 인식기가 안 붙은 상태로만 검증). 테스트에 그 조건을 더했다.
  * **`setState() called during build` 로 제스처가 통째로 죽던 버그** (실기기에서만
    드러남). 캘린더를 `AnimatedSize` 로 감쌌더니 그 레이아웃이 같은 프레임에
    `PageController` 리스너를 깨우고, `_publishProgress` 가 빌드 도중
    `ValueNotifier` 를 갱신했다. 그걸 구독하는 헤더 월 라벨이 빌드 중 `setState` 를
    맞아 예외가 터지고, **그 프레임의 제스처 등록까지 함께 날아가** 월·주 좌우
    스와이프가 아무 반응이 없었다. 위젯 테스트는 `AnimatedSize` 없이 캘린더만 띄워서
    재현되지 않는다 — 시뮬레이터 로그를 보고서야 찾았다. 빌드 단계
    (`SchedulerPhase.persistentCallbacks`)면 `addPostFrameCallback` 으로 미룬다.
  * **전수 점검에서 더 잡은 것들**:
    * **목록이 스크롤 중 통째로 지워지던 버그.** 스크롤로 11월에 닿아 캘린더를 11월로
      옮기면, 그 통지가 다시 "11월부터 조회해라"로 돌아와 보던 목록이 날아가고 11/1
      부터 다시 받았다. 순간을 감싸는 플래그로는 못 막는다 — `displayMonth` setter 가
      동기 notify 뿐 아니라 `loadCalendar` 의 **비동기 notify** 도 일으켜서, 그때는
      플래그가 이미 꺼져 있다. '어느 달을 목록이 이미 안다'(`_monthFromList`)를
      기억하는 방식으로 바꿨다.
    * **'보이는 날짜'를 잘못 고르던 버그.** 위로 지나간 헤더가 하나도 없을 때
      `best ??= entry.key` 를 루프 안에서 돌려 맵 순회 순서에 의존했는데, 키는 헤더가
      **그려진** 순서로 꽂혀서 lazy 목록에서는 날짜순이 아니다. 지나간 것 중 가장
      아래 / 안 지나간 것 중 가장 위를 각각 거리로 고르도록 고쳤다.
    * **GlobalKey 충돌.** 자동 스크롤 대상 헤더의 `_todayHeaderKey` 를 날짜별 키 맵에
      겹쳐 넣어서, 대상이 바뀌면 두 날짜가 같은 키를 가리켰다. GlobalKey 는 한 위젯에만
      붙으므로 위치를 재면 엉뚱한 날짜가 나온다. 대상은 한 겹 더 감싸는 방식으로 분리.
    * 주간으로 접힌 채 캘린더가 로딩/에러면 **6주짜리 스켈레톤이 떠 캘린더가 벌어졌다**.
      접힘 상태에서는 한 칸 높이로 맞춘다.
    * 월 라벨이 주간에서 잘린 채 굳던 것 — 진행률은 월간 페이저가 갱신하는 값이라
      주간에서는 멈춰 있다. 주간에서는 아예 안 쓰고 헤더 기본 `Text` 로 떨어뜨린다.
    * `CalendarMonthGrid.weekOfMonth` 는 주간 전용 위젯이 생기며 죽은 코드가 돼 제거.
  * **진입 시에는 항상 월간으로 보인다.** 접힘 판정이 `ScrollUpdateNotification` 만
    보던 탓에, 진입 직후의 '오늘로 이동'(코드가 거는 jumpTo 40회)이 사용자 스크롤로
    세어져 화면에 들어오자마자 주간으로 접혔다. `ScrollStart` 의 `dragDetails` 로
    사용자 드래그를 확인하고 `ScrollEnd` 까지를 한 묶음으로 본다 — `dragDetails` 만
    보면 손을 뗀 뒤 미끄러지는 구간(fling)에서 접힘이 끊긴다.
  * **캘린더에서 날짜를 누르면 목록이 그 날짜로 간다.** 여기까지 오는 데 네 겹이
    걸렸고, 전부 시뮬레이터 로그를 보고서야 하나씩 드러났다:
    1. **다른 달** 날짜 → 재조회 중이라 목록이 비어 `scrollToDate` 가 그냥 돌아섰다.
       누른 날짜를 기억해 뒀다가(`_pendingScrollDate`) 재조회 후 간다.
    2. **같은 달 과거** 날짜 → 진입 조회가 `around=오늘` 이라 그 날은 아직 안 받은
       페이지에 있다. 그 날짜가 들어올 때까지 과거 페이지를 당긴다(`_loadUntilDate`).
    3. `_scrollToTarget` 의 '제자리걸음 탈출'이 **아래로만** 밀었다 — 과거 페이지가
       앞에 붙으면 대상이 위에 있어 영영 못 만나고 40프레임을 헛돈다.
    4. 어림 지점에 닿았는데 헤더가 아직 렌더 전이면 조금씩 훑어야 하는데, 위치로
       분기하니 `est` ↔ `est+120` 두 자리를 왕복했다(경계 조건: 한 칸 움직이면
       `diff.abs() < nudge` 가 곧바로 false). '몇 번째 훑는 중'(`_sweep`)을 들고
       `est + 120*n` 으로 벌려 나가게 고쳤다. 지금은 3프레임이면 닿는다.
    **경기 없는 날은 눌리지 않는다**(`onEmptyDateTap` 자체를 뺐다) — 갈 그룹이 없는데
    선택만 옮기면 "눌렀는데 아무 일도 안 난다"가 된다. 주간에서 주를 바꾸는 건 좌우
    스와이프가 맡는다.
  * **캘린더가 목록 스크롤을 따라간다.** 목록을 내려 11월 경기까지 가면 위 캘린더도
    11월로 넘어가고, 주간 모드면 그 날짜가 든 주를 비춘다. 지금 화면 맨 위에 걸린 날짜는
    **실제로 그려진 헤더의 렌더 위치를 재서** 고른다(`_reportVisibleDate`) — 어림
    높이로 역산하면 광고 배너처럼 높이를 모르는 항목 때문에 어긋나고, 그 어긋남이 월
    이동으로 그대로 드러난다. 캘린더↔목록이 서로를 따라가는 왕복은 `_followingList`
    빗장으로 끊었다. 스크롤로 고른 날짜에서 멀어지면 선택 강조를 놓아 준다
    (`clearSelectedDate`) — 안 그러면 주간 캘린더가 그 주에 붙박인다.
  * **월 라벨이 잘리던 것**(`2026.10` → `2026.1`)을 고쳤다. `CalendarMonthLabel` 은
    `TextPainter` 로 잰 폭을 `SizedBox` 로 고정하고 `ClipRect` 로 자르는데, 라벨 폰트
    `SF Pro Display` 는 **pubspec 에 싣지 않은 시스템 폰트**라 재는 시점의 폴백과 iOS 가
    실제로 그리는 글꼴이 달라 몇 px 어긋났다. `Text` 와 달리 `...` 없이 그냥 썰린다.
    여유를 더하는 미봉책을 쓰다가, 결국 **정착 상태에서는 자르지 않도록** 고쳤다 —
    폭 고정+클립은 스와이프 중 두 라벨을 겹쳐 그릴 때만 필요하고, 정착 상태에는
    겹칠 라벨이 없어 그냥 `Text` 로 그리면 된다. 정착 판정에 `page == 0` 을 쓰면 안
    된다(`PageController.page` 가 1e-8 같은 찌꺼기를 남겨 영영 겹침 경로를 탄다).
    테스트 환경은 측정·렌더 양쪽 다 폴백 글꼴이라 이 증상이 재현되지 않는다 —
    시뮬레이터에서 직접 보고서야 잡았다.
  * **목록 시작 달이 캘린더를 따라간다.** 캘린더를 10월로 넘기면 목록도 10/1 부터 다시
    시작한다(`MatchListViewModel.setAnchorMonth`). 월 경계에서 **끊지는 않는다** — 거기서
    계속 내리면 11월·12월로 평소처럼 이어진다. 서버에 종료일 파라미터가 없어
    (`/api/mobile/matches` 는 `from`/`around`/`before` 만 있다) 월 단위로 자를 수단이
    애초에 없기도 하다. 이번 달을 볼 때는 예전처럼 '오늘' 기준이다 — 월초부터 보여주면
    끝난 경기만 한 화면 차고 '오늘로 스크롤'도 의미가 없어진다. 다른 달일 때는 자동
    스크롤 대상도 '오늘'이 아니라 그 달 첫 경기다.
  * **헤더에서 월 라벨이 '2026…' 으로 줄던 것** — `Row` 안에 flex 자식을 둘 이상 두면
    남는 폭을 **그 수만큼 나눠 갖는다**. `Expanded`(라벨) + `Spacer`, 그다음엔
    `Expanded`(라벨) + `Flexible`(토글) 조합이 각각 라벨 폭을 반 토막 냈다. 지금은
    라벨만 `Expanded` 고 토글·필터는 내용 폭 그대로다. 한 줄에 셋을 넣으면 390 폭에서
    5.7px 넘쳐서, 스포방지 라벨을 'ON/OFF' 없이 **'스포방지'** 만 쓰도록 줄였다
    (상태는 옆 스위치로 읽는다 — `NarSpoilerToggle.showState`, 기본값은 기존대로 true
    라 경기상세 등 다른 사용처는 그대로다).
  * **헤더 정렬**: 월 라벨은 왼쪽, 스포방지·필터·응원팀은 오른쪽 끝. 월 라벨을
    `Flexible` 로만 두면 남는 폭을 다 가져가 오른쪽 묶음이 라벨 옆에 붙어 버려서,
    `Flexible`(loose) + `Spacer` 조합으로 바꿨다. 회귀 테스트를 붙였는데
    (`test/screens/schedule/schedule_header_test.dart`) **실제로 375 폭에서 17px
    overflow 를 잡아냈다** — `Flexible` 을 빼고 고정 폭으로 두면 영문 'Spoiler
    Prevention OFF' 라벨에서 넘친다. 테스트는 `MediaQuery` 만 바꾸면 안 되고
    (배치 폭은 테스트 캔버스 800 그대로다) `SizedBox` 로 폭을 함께 묶어야 재현된다.
  * **경기 카드 세로 여백을 줄였다**(높이 155 → 137). 캘린더와 세로를 나눠 쓰게 되니
    한 화면에 카드가 2장 남짓이라 한눈에 안 들어왔다. 아래 패딩 24 → 14, 헤더행↔스코어행
    간격 20 → 12. 좌우 16 은 시안 그대로 둔다 — 팀 로고·스코어 정렬이 걸려 있다.
    스켈레톤과 `_estimatedOffsetTo` 의 어림 높이도 같이 맞췄다(안 맞추면 '오늘로
    스크롤'이 어긋난다).
  * 계측: 두 화면이 한 라우트가 되며 `match_list` 의 `page_view` 는 사라진다. `schedule`
    의 `page_view` 가 `sort_order`·`spoiler_prevention` 까지 함께 싣는다.
## 2026-10-27
* **스토어에 "1.0.41 로 표시되지만 코드는 1.0.39" 인 빌드가 나간 사고를 수습하고, 같은 일이 조용히 반복되지 않게 막았다.**
  * **증상**: 전 사용자에게 업데이트 팝업이 매번 뜨는데 **업데이트 버튼을 눌러도 아무 일도 일어나지 않았다.** 앱 안의 버전은 1.0.39, 스토어 표시는 1.0.41.
  * **원인**: deliver 는 ASC 의 **버전 문자열·패치노트를 먼저 바꾸고 그다음에 빌드를 붙인다.** 10-26 03:42 에 1.0.39+89 가 심사 대기(`Waiting For Review`)로 들어가 있었고, 08:09 에 1.0.41 을 제출하자 ASC 가 **빌드 교체를 거부**했다(`Selecting build 1.0.41 (91)` 에서 끊김). 그래서 표시만 1.0.41 이고 바이너리는 빌드 89 인 버전이 그대로 승인·출시됐다. 설치본과 스토어본의 빌드 번호가 똑같이 89 라 iOS 가 "받을 것 없음" 으로 보고, upgrader 는 앱 버전(1.0.39)과 스토어 메타데이터(1.0.41)를 비교해 팝업을 무한 반복했다.
  * **왜 아무도 몰랐나**: 워크플로우가 초록불이었다. 옛 가드가 deliver 로그의 `is in (Waiting For Review|...)` 를 보고 중복 제출로 판단해 `exit 0` 했다. **그 문자열은 "같은 버전 두 번 제출"(넘겨도 됨)과 "다른 버전이 심사 줄을 잡아 빌드를 못 붙임"(사고)에 똑같이 나와서** 로그로는 구분할 수 없다.
  * **수습**: 설치된 바이너리가 89 라 `shorebird patch` 로는 못 고쳐(패치는 1.0.39+89 에 붙어야 하고 그러면 표시 버전을 못 바꾼다) **1.0.42+92 를 새로 냈다**(PR #422). 빌드 90·91 은 TestFlight 에만 있고 스토어에 나간 적이 없다. 패치노트는 1.0.41 용으로 쓴 내용을 그대로 뒀다 — 스플래시 광고 수정과 선수 페이지 개편이 이번에 처음 사용자에게 나가기 때문이다.
  * **재발 방지**: 로그 문자열 매칭을 버리고 `scripts/asc_version_state.py` 로 **ASC 에 직접 물어** 판정한다. 제출 **전**에는 줄에 선 버전이 빌드를 바꿔 끼울 수 있는 상태인지 보고 아니면 ASC 를 건드리기 전에 멈춘다. 제출 **후**에는 그 버전에 **실제로 붙은 빌드 번호**가 올리려던 번호와 같은지, 심사 줄에 들어갔는지 확인한다. 조회 실패는 앞뒤로 다르게 취급한다 — 제출 전엔 경고만 남기고 진행하지만(네트워크 문제로 릴리즈가 멈추는 쪽이 더 나쁘다), 제출 후엔 실패로 끝낸다(**검증하지 못한 제출을 성공으로 보고하는 것이 이 사고의 본질이다**).
  * 설계 배경은 [release-build-automation spec](../intent/release-build-automation/spec.md) 의 Decisions 참고.
* **Discord [심사 제출] 버튼을 한 번 눌렀는데 제출이 두 번 나가던 문제를 고쳤다.**
  * **원인**: Vercel 로그에 같은 POST 가 **네 번** 찍혀 있었다(약 5초 간격). **Discord 는 인터랙션 응답을 3초 안에 못 받으면 같은 요청을 재시도하는데**, 브리지가 응답 전에 GitHub dispatch 를 먼저 `await` 해서 재시도마다 제출이 한 번씩 더 나갔다. dispatch 자체는 ~25ms 다 — 그 함수가 19분 유휴 뒤 **콜드 스타트**로 3초를 넘긴 것이 방아쇠였다.
  * 원래 순서에도 이유가 있었다. 응답을 먼저 보내면 Vercel 이 `res.end()` 뒤 컨텍스트를 종료해 dispatch 가 끊겼다. **`waitUntil` 이 그 끊김의 정식 해법**이라, 순서를 되돌리면서 끊김도 같이 막았다.
  * **수정**: 지연 응답(`type 5`)으로 3초 안에 "..." 을 돌려주고 작업이 끝나면 그 메시지를 결과로 바꿔 쓴다. 여기에 **멱등성 가드**(`lib/once.js`)를 더했다 — 콜드 스타트는 우리 코드가 돌기 전에 예산을 먹으므로 응답을 먼저 보내도 재시도가 올 수 있어서다. `interaction.id` 를 키로 쓴다: Discord 는 재시도에 **같은 id**, 사용자가 진짜 두 번 누르면 **다른 id** 를 보내므로 재시도만 막고 의도한 재제출은 통과한다.
  * 캐시를 쓸 수 없으면 **통과시킨다** — 중복 방지가 안 되는 쪽이 제출이 막히는 쪽보다 낫고, 중복이 나가도 `submit-for-review.yml` 이 ASC 상태로 한 번 더 걸러낸다.
  * `/intent` 쪽도 같은 구조였어서 함께 고쳤다. 테스트 14개를 더했다(재시도 4연타 재현 포함).
  * 설계 배경은 [discord-release-approval spec](../intent/discord-release-approval/spec.md) 의 Decisions 참고.

## 2026-10-26
* **선수 페이지를 공용 컴포넌트로 다시 짰다**: 화면마다 같은 모양을 따로 짜 두던 것을 `lib/core/ui/` 로 모았다.
  * 챔피언 표의 솔랭순/월즈순 정렬 칩(`_SortChip`) → `NarChipMultiSelect.single`. 홈 리그 칩·내 선수 팀 칩과 같은 칩이 됐다(높이 34 pill). 처음엔 예전 크기(30)를 지키려고 `NarChipSize.compact` 를 더했다가, "다른 화면 칩과 똑같이 보이는 것"이 목적이라 되돌렸다 — 호출부가 하나뿐인 variant 는 남기지 않는다.
  * 팬 평점 → 선수 평점 상세의 `RatingDistributionSection` 을 그대로 쓴다(평균 32px + `NarStarRating` + "총 N명 참여" + 5→1 노랑 분포 바). 한줄평도 보라 숫자 배지 대신 `NarStarRating` 을 쓴다. 분포 섹션은 고정 폭(116/204/150)이라 카드 안에서 넘쳐서, 좌측은 `ConstrainedBox(maxWidth)` 우측·트랙은 `Expanded` 로 바꾸고 `padding` 파라미터를 더했다(기본값은 시안 20 그대로라 선수 평점 화면은 안 바뀐다).
  * `_SubscribeBell` → 새 `SubscribeBell`. 내 선수 화면에 거의 같은 코드가 있는데 아이콘 18/20, 배경 narDark500/600 처럼 상수만 어긋나 있었다.
  * `_StatsRow` → 새 `NarStatBox`/`NarStatRow`. `stretch` 로 두면 높이가 안 정해진 `ListView` 안에서 무한 높이가 돼 `start` 로 둔다.
  * `_MostRow` 승률 막대 → 새 `NarProgressBar`. 앱에서 `LinearProgressIndicator` 를 쓰던 유일한 두 곳이었고, 나머지 막대는 전부 `FractionallySizedBox` 방식이라 그쪽으로 맞췄다.
  * `_WinLoss` → 새 `WinLossText`. "N승 M패" 를 4개 화면이 저마다 다르게 칠하고 있었다.
  * `PlayerCard` 11곳 → 새 `NarCard`, `PlayerSectionTitle` → 새 `NarSectionTitle` 위의 얇은 껍데기, 솔랭 계정 칩의 지역 배지 → 이미 3개 화면이 쓰던 `RegionChip`(radius 3→4, 9px Pretendard→10px Open Sans).
  * "전체 N개 보기"·"더 보기" 버튼 2곳 → 새 `NarMoreButton`(카드 마지막 줄용 `.inCard` 변형 포함).
  * 첫 로딩 스피너 → `PlayerSkeleton`(실제 화면과 같은 순서·높이라 데이터가 들어올 때 레이아웃이 안 튄다).
  * `_StatGrid`·`_GameRow`·`_ChampionRow`·`_RecentCard`·`_MetCard` 등은 앱 어디에도 같은 모양이 없어 그대로 뒀다. 한줄평 평점 배지도 호출부가 하나뿐이라 올리지 않았다 — 호출부가 하나인 공용 컴포넌트는 재사용이 아니라 겉도는 층이다.
  * 홈 쪽 중복(`HomeSectionHeader`·`HomeListBox`·`_BellButton`·`_TodayStats`)은 이번 범위 밖이라 [공용 컴포넌트](/design/shared-components.md)에 남은 일로 적어 뒀다.

* **선수 페이지 티어 엠블럼을 디자인 에셋으로 바꿨다**: 솔랭 계정 칩의 티어 아이콘을 Community Dragon 미니 문장(원격 URL)에서 앱에 넣은 `assets/images/tiers/*.webp` 11종(아이언~챌린저 + 언랭)으로 교체했다. 네트워크를 안 타서 바로 뜬다. `rankedCrestUrl` → `rankedCrestAsset`(모르는 티어는 `unranked` 로 폴백). 엠블럼 위쪽에 투명 여백이 있어 가운데 정렬하면 옆 글자보다 떠 보여 2px 내렸다.
* **"팬 평점" 섹션 제목을 "월즈 평점"으로 바꿨다**(`playerWorldsRating` 신규). 경기별 기록 행의 작은 라벨은 한 판 단위라 "팬 평점" 그대로 둔다.

* **선수 페이지 목록 — 데이터 출처에 따라 방식을 갈랐다**:
  * **한줄평만 무한 스크롤**이다. 서버가 20개씩 주는 페이징(총 412개)이라 "전부 펼치기"가 불가능하다. 처음 6개를 보이고, 바닥 300 안쪽에 닿으면 이어 받는다.
  * **최근 솔랭·챔피언 표·경기별 기록은 5개 + "더 보기" 버튼**이다. `/solo-rank`·`/worlds` 로 이미 전부 받아 둔 목록이라, 조금씩 여는 것보다 한 번에 펼쳐 보는 게 편하다는 판단. 한때 무한 스크롤·고정 높이 내부 스크롤로 만들었다가 되돌렸다.
  * 무한 스크롤 구현 중 실제 버그를 하나 잡았다 — **콘텐츠가 화면보다 짧으면 `maxScrollExtent` 가 0이라 스크롤 리스너가 영영 안 불린다**(측정값 `max=0`). 그래서 매 프레임 뒤에 한 번 더 재서, 스크롤 여지가 없는데 더 받을 게 남았으면 바로 다음 장을 당긴다. 고친 뒤 `max=0 → 1366 → 3306` 으로 이어 붙는 걸 확인했다.
  * 한줄평 끝에는 "더 받을 게 남았다"는 로딩 표시를 둔다. 자리를 비워 두면 리스트가 바닥에 딱 맞아 더 내릴 수 없고, 그러면 다음 장을 못 받는다.
  * **페이지가 통째로 멈추는 버그를 잡았다.** "스크롤 여지가 없으면 바로 다음 장을 당긴다"를 **빌드마다** 포스트프레임 콜백으로 걸어 둔 게 화근이었다. 한줄평 조회가 실패하면 `allReviews` 가 null 인 채 `reviewsLoading` 이 false 로 돌아와 가드를 둘 다 통과 → 다시 호출 → `notifyListeners` → 리빌드 → 콜백 → … 로 메인 스레드를 잡아먹어 스크롤이 아예 안 됐다(실 API 에서 재현). 두 가지를 고쳤다 — ① 한 번 실패하면 `reviewsFailed` 로 더 시도하지 않는다, ② 확인을 빌드마다가 아니라 VM 알림에 한 프레임당 한 번만 예약한다(`_checkScheduled`). 회귀 테스트 2개를 `player_reviews_scroll_test.dart` 에 남겨 둔다.

## 2026-10-25 (6)
* **선수 페이지 "솔랭 vs 월즈 챔피언" 표에 최근 플레이 시각**: 솔랭·월즈 **각 열의 승패 아래**에 그쪽에서 마지막으로 한 시각을 `2시간 전`·`1일 전`(최근 솔랭 행과 같은 `ratingTimeAgo`)으로 둔다. 처음엔 이름 아래 하나만 뒀는데 둘 다 한 챔피언이면 어느 쪽 기준인지 알 수 없어서 열별로 나눴다. 서버 응답(`champions`)에는 날짜가 없지만 표가 솔랭 최근 20판 + 월즈 경기의 합집합이라, 이미 받은 `solo.games[].endedAt`·`worlds.matches[].playedAt` 에서 구한다(`PlayerViewModel.championLastPlayed(name, source)`). "최근순" 정렬은 넣지 않았다 — 솔랭순(판수)이 이미 최근 많이 한 챔피언을 위로 올린다.

## 2026-10-25 (5)
* **홈 "월즈 솔랭 중인 선수" 작은 카드**: 카드를 누르면 월즈 솔랭 화면 대신 그 **선수 페이지**로 간다(선수 id 가 없을 때만 월즈 솔랭 화면). 벨은 **바로 구독하지 않고** 선수 페이지 벨과 같은 **선수 구독 시트**(`showWorldsPlayerSheet`)를 띄워 솔랭 시작·종료 알림을 고르게 한다. 시트 데이터는 그 선수의 `PlayerViewModel` 을 잠깐 만들어 읽고, 닫으면 홈 구독 목록을 다시 읽는다. 구독 0명일 때 큰 월즈 카드의 "구독하기"도 같은 시트로 간다. 바로 구독하던 `HomeViewModel.subscribeWorldsPlayer` 는 지웠다.

## 2026-10-25 (4)
* **경기 일정을 기기 시간대로 보인다(해외 사용자 CX 문의)**: 일정·캘린더·경기 리스트가 한국 시간으로만 떠서 해외 사용자가 불편했다. 앱이 일정 API 3종에 `utcOffset`(분)을 보내고, 서버(nar-back-repo)가 그 오프셋으로 날짜 묶음과 `scheduledTime` 을 만든다. 옛 서버는 파라미터를 무시해 응답이 같으므로 앱이 먼저 나가도 안전하다. 기기 IANA 시간대 이름은 네이티브 플러그인 없이 못 읽어서 오프셋을 택했다(Shorebird 패치 가능). 자세한 건 [경기](/features/matches.md).

## 2026-10-25 (3)
* **선수 페이지 피드백 4건 + 경기 알림 끄기 흐름**: ① 팬 평점 카드를 시안 ⑧ 하단에 맞췄다(점수 배지·얇은 분포 막대·"한줄평 전체 N개 보기"). ② 한줄평을 누르면 그 판 평점 상세로, 전체 보기는 새 페이지 API 로 20개씩. ③ 상단 구독 벨: 실 API 경로는 정상이었다(시뮬레이터 로그인 토큰으로 `subscribed=true` 확인). 목업이 홈 "구독 선수 솔랭 중" 카드의 선수를 미구독으로 내려 앞뒤가 안 맞았던 것을 고쳤고, 벨은 바로 토글하지 않고 월즈 솔랭과 **같은 선수 구독 시트**를 연다(`PlayerSheetSource`). ④ 경기 알림을 **바로 끄지 않는다** — 구독 중이면 현재 설정으로 시트를 열어 변경하거나 "알림 끄기"로 해제한다. 경기 카드와 선수 페이지가 `runMatchAlarmFlow` 하나를 쓴다.

## 2026-10-25 (2)
* **선수 페이지 솔랭 탭에 "솔랭에서 만난 선수"를 붙였다**: `/solo-rank` 의 `metPlayers`(nar-back-repo #588)를 가로 카드로 그린다. 다음 경기 상대 팀 선수면 "다음 상대" 태그, 같은 편·상대 줄은 판수가 있을 때만, 카드 높이는 가장 긴 카드에 맞춘다. 옛 서버면 필드가 없어 빈 목록 → 섹션이 숨겨지므로 앱이 먼저 나가도 안전하다.

## 2026-10-25
* **선수 페이지를 만들었다(백엔드 대기, 목업으로 완성)**: 홈 솔랭 큰 카드·끝난 경기 칩·월즈 솔랭 타일에서 들어간다. 솔랭 중이면 홈 큰 카드와 응원 영역을 **같은 위젯·같은 컨트롤러**로 그려 홈과 응원 수가 함께 움직이고, 쉬면 프로필 줄 + 마지막 솔랭 한 판이다. 그 아래 다음 경기(경기 알림 벨은 경기 카드 흐름 재사용), 지표 줄, 월즈/솔랭 탭. 월즈 기록이 비면 "경기 기록 집계 중", 해외 팀 코드가 null 이면 팀 이름, Bo1 이면 "단판". 월즈 솔랭 타일은 원래 선수 시트를 열었는데 이제 선수 페이지로 가고, 시트(알림 토글)는 벨에만 남겼다. `scheduledAt` 은 `+09:00` 을 붙여 파싱하면 **UTC DateTime** 이 돼 그대로 포맷하면 9시간 이른 시각이 찍힌다 — 표시 전에 `toLocal()` 한다. 자세한 건 [선수 페이지](/features/player-page.md).

## 2026-10-23
* **광고 자리의 빈 칸을 없애고, 이미지가 준비된 뒤에만 광고를 그린다**: 팝업·배너가 **회색 사각형(+AD 뱃지)으로 떴다가 광고 이미지로 바뀌는** 게 보였다. 원인은 `AdRepository` 가 **응답(JSON)만 캐시하고 이미지는 미리 받지 않았다**는 것 — 응답이 오는 순간 `RegisteredAdCard` 를 그리고, `CachedNetworkImage` 가 그제서야 다운로드를 시작해 그 사이 `narDark500` placeholder 가 노출됐다. 전날 #407 이 같은 증상을 **빈 자리**(`AdLoadingSlot`)로 막았는데, 응답만 기다려서 회색 단계를 못 없앴고 광고 자리가 비어 보이는 문제가 남았다. 이번에는 **대기선을 응답 → 이미지 디코드까지** 옮겼다(`forPlacement` 가 `CachedNetworkImageProvider.resolve` 로 해석 완료를 기다린다 — 디스크만 채우면 디코드 한 프레임이 placeholder 로 샌다). 그래서 교체가 **'모집 배너 → 완성된 광고' 한 번**으로 끝나고, 빈 자리를 둘 이유가 사라져 `AdLoadingSlot` 을 걷어냈다. **자리마다 규칙을 다르게 뒀다** — 체류 시간이 짧으면 조용함이, 길면 노출이 이긴다. 팝업·홈 배너(수십 초)는 모집 배너를 즉시 그리고 준비되면 교체하지만, **스플래시(1~2초)는 첫 프레임에 정하고 끝까지 안 바꾼다**(`readyFor` 로 기다림 없이 캐시만 조회). 스플래시에서 교체를 허용해도 대개 실패한다 — 화면이 먼저 사라져서 늦게 도착한 이미지는 '전환만 보이고 끝나는' 최악이 된다. 대신 `warmUp(['splash','popup','home'])` 을 스플래시 `initState` 에 두어 **부팅 대기 시간(아무도 안 보는 구간)에 이미지를 받아** 둔다 — 홈 도착 시점엔 캐시에 있어 첫 프레임부터 광고고, 스플래시 몫은 **다음 실행**의 첫 프레임에 쓰인다(AdMob 도 *"Don't show an app open ad on the very first app start"* 로 같은 얘기를 한다). 이 구조는 AdMob 가이드의 *"ad is placed on top of the app's loading screen"* — 로딩 콘텐츠가 항상 깔려 있고 광고가 그 위에 올라온다 — 와 맞고, #407 이 택한 빈 자리 쪽이 패턴에서 벗어난 선택이었다. **이미지 타임아웃 5초를 새로 걸었다**(TopOn 스플래시 광고 기본값과 동일): 이 경로는 `CachedNetworkImageProvider` 라 `api_client` 의 15초 타임아웃이 **닿지 않아**, 안 걸어 두면 네트워크가 느릴 때 광고 자리가 **끝까지** 빈 칸으로 남았다. 넘기면 `null` 로 떨어뜨려 모집 배너로 대체한다 — 반쯤 그려진 광고보다 낫고, 광고를 띄우려고 자리를 오래 붙잡을 이유가 없다. 이미지 내려받기는 `_warming` 맵으로 URL 당 한 번만 돌려 스플래시·홈이 같은 자리를 두 번 그려도 요청이 겹치지 않고, 실패는 기억하지 않아 다음 그림 때 재시도된다. **리뷰(#408 CodeRabbit)에서 잡힌 버그 하나를 고쳤다** — `_ready` 는 싱글턴의 메모리 `Map` 이라 **앱을 켤 때마다 비어 있는데**, 스플래시는 첫 build 에서 `readyFor` 를 한 번만 읽고 안 바꾼다. 즉 "다음 실행의 첫 프레임에 쓰인다"는 전제가 성립하지 않아 **스플래시 광고가 영원히 안 뜨는** 상태였다(이미지를 디스크 캐시에 받아 둬도 `readyFor` 가 그걸 모른다). 광고 1건을 `shared_preferences` 에 적어 두고(`_rememberSplash`) `main` 의 초기화 묶음에서 `restoreSplash` 로 **첫 프레임 전에** 되살린다 — secure storage 가 아니라 `shared_preferences` 를 쓴 건 Keychain 이 기기 잠금에 걸려 느려질 수 있고 여기 담기는 건 비밀이 아니기 때문이다. 이미지가 아직 디스크에 있는지는 **확인하지 않는다**(확인하려면 비동기 조회가 한 번 더 들어가 첫 프레임을 늦추고, 캐시가 비었어도 받아오는 동안 회색 자리만 잠깐 보인다 — 스플래시는 탭도 안 되는 자리라 피해가 작다). 복원 실패·깨진 JSON 은 삼켜 모집 배너로 떨어진다(`main` 의 `Future.wait` 로 예외가 새면 첫 화면이 늦어진다). 이 버그는 **눈으로 안 보이는 종류**라 — 증상이 "원래부터 광고가 없었던 것" 과 구분되지 않는다 — 회귀 테스트 3개를 붙였고, 복원 한 줄을 지워 테스트가 실제로 잡는 것까지 확인했다.

## 2026-10-22 (5)
* **평점 화면이 집계에서 통째로 빠져 있었다 — 진입 3곳 중 2곳에 라우트 이름이 없었다**: 알림의 `평점 0` 과 "화면 TOP 5 에 `player_rating` 없음" 을 "기능이 안 쓰인다" 로 읽었는데, 확인해 보니 **별점은 쓰이고 있었다**(한줄평만 잘 안 쓴다). `review_submit_button_click` 은 한줄평 유무와 무관하게 저장 성공 시 찍히고 저장 경로도 `_openRatingSheet` → `saveMyRating` 하나뿐이라 계측은 온전했다 — 그래서 `평점 0` 은 "그날 아무도 저장하지 않았다" 는 사실이다. 그런데 **화면이 TOP 5 에 없던 건 별개의 버그**였다. `PlayerRatingScreen` 진입 경로가 홈·경기 상세·내가 쓴 리뷰 셋인데, **홈만 `RouteSettings(name:)` 을 붙이고 나머지 둘은 이름이 없었다.** observer 의 `_isPageRoute` 는 이름 없는 라우트를 **시트·다이얼로그로 보고 무시**하므로 (1) 그 두 경로의 `page_view(player_rating)` 이 아예 안 찍히고, (2) 더 고약하게 **돌아올 때 `didPop` 도 복귀로 안 세서 `prev_page` 가 옛 화면에 머문다** — 즉 평점 화면만 빠지는 게 아니라 그 다음 `page_view` 의 `prev_page` 까지 틀린다. 두 곳에 이름을 붙였다. **전수 조사해 보니 이름 없는 push 가 18곳(11개 화면)** 있다 — `LoginScreen` 5곳, `PostDetailScreen` 3곳, `CheerAdScreen` 2곳 등. 같은 증상이 그 화면들에도 있지만 이번 범위를 넘어서 손대지 않고 남겨 둔다. 회귀 테스트는 **소스 검사**로 했다 — 진입 세 곳이 각각 ViewModel·API 를 세워야 위젯 테스트가 돌아가는데 확인할 것은 "이름을 붙였나" 한 줄이라, 소스를 읽어 `PlayerRatingScreen` 을 띄우는 모든 `MaterialPageRoute` 에 `settings:` 가 있는지 보는 쪽이 싸고 세 경로를 한 번에 덮는다(괄호 균형으로 블록을 잘라 판정하고, 버그를 되살려 실제로 잡는 것까지 확인했다).

## 2026-10-22 (4)
* **월즈 솔랭 진입·알림 신청을 계측한다 — 내 선수와 합쳐져 있던 것을 갈랐다**: 월즈 솔랭은 `MyPlayersScreen(worlds: true)` 로 **내 선수와 같은 화면 코드**를 쓰는데, 라우트 이름도 둘 다 `my_players` 로 붙어 있어서 `page_view` 가 합쳐져 있었다 — 2026-10-21 알림의 `my_players 391` 은 **두 화면을 합친 수**였고 월즈 솔랭 진입을 따로 볼 방법이 없었다. `AnalyticsPage.worldsSolo`(`worlds_solo`)를 새로 두고 홈의 진입 경로(`_openWorlds`, 유일한 경로임을 전수 확인)만 바꿨다. 알림 신청은 **벨 → 선수 시트 → `setSubscribed`** 하나로 모이므로 ViewModel 한 곳에 심었다(벨은 바로 토글하지 않고 시트를 띄워 알림 토글을 고르게 한다). 기존 `subscribe_button_click` 을 재사용하고 — 새 이벤트를 만들면 구독 지표가 화면마다 갈라진다 — 이 화면만의 값인 **알림 토글(`alarm_start`·`alarm_end`)** 을 함께 싣는다. 사용자가 시작·종료 중 무엇을 원하는지는 여기서만 드러난다. 해제할 때는 토글이 의미가 없어 싣지 않는다. **API 성공 후에 찍는다** — 이 메서드는 화면을 먼저 바꾸고 실패하면 되돌리는 구조라(낙관적 갱신), 클릭 시점에 찍으면 구독되지 않은 것이 성공으로 집계된다(구독 설정 화면과 같은 규칙, 설계 25번). `is_on` 은 토글 **후** 값이다. 집계에는 `worlds_subscribe` 를 더해 알림 **신청(ON)만** 따로 센다 — 전체 `subscribe` 에 묶으면 구독 설정 화면 수치에 섞여 이 화면의 신호가 안 보인다. 테스트: jq 3개 추가(총 38개, 해제·타화면 구독이 안 섞이는 것까지), Dart 2개 추가 — 두 화면이 **다른 page 값**이라는 것을 값으로 박았다(같은 화면 코드를 재사용하는 구조라 나중에 누가 라우트 이름을 다시 합치기 쉽고, 그러면 집계가 조용히 되돌아간다).

## 2026-10-22 (3)
* **DAU 알림이 거짓말하던 꼬리말과 123% 퍼널을 고쳤다**: 2026-10-21 자 알림이 **"1.0.32+71 이상만 집계"** 를 달고 나갔는데, `app_version` 이 **어떤 릴리즈에도 안 들어간 상태**여서 1049명 전원이 "버전 미상" 이었다(`git tag --contains` 가 비어 있었다 — 최신 릴리즈 1.0.37+87 은 10-21 태그, `app_version` 머지는 10-22). 그 문구는 측정값이 아니라 하드코딩된 추측이었고, 사실과 어긋난 채로 매일 나가고 있었다. 이제 **데이터로 말한다** — 아무도 버전을 안 보내면 "아직 집계 안 됨 — `app_version` 을 심은 빌드가 사용자에게 도달하기 전이다" 로 **이유**를 적는다(`lines` 가 내던 "없음" 은 집계가 깨진 것처럼 읽힌다). 꼬리말은 버전 상세를 중복하지 않고, 전원 버전 미상일 때만 "계측 미도달 구버전이 섞여 있을 수 있다" 를 남긴다(구버전은 우리 이벤트를 아예 안 보내므로 **다른 지표의 해석도 달라진다**). 이 과정에서 **빈 꼬리말 → Discord 400** 경로를 발견해 embed 쪽에서 막았다 — `app_version` 이 퍼지고 DAU ≥ 30 이 되면 경고가 둘 다 사라져 빈 문자열이 되는데, Discord 는 빈 footer 를 거부한다. 함께 **로그인 퍼널의 합이 123%** 였던 것(`로그인 100% / 비회원 23%`)을 설명했다 — 집계 오류가 아니라 두 버튼이 **같은 화면에 있어 배타적이지 않다**(로그인 실패·되돌아 나와 비회원으로 시작하는 경로). `login_and_guest` 로 겹친 사용자를 세서 "(둘 다 누른 N명 중복)" 을 적는다. 겹침이 0이면 표시하지 않는다. 회귀 검사 5개 추가(총 35개) — 겹침 집계와 "겹침 없으면 0"(허위 경고 방지)까지.

## 2026-10-22 (2)
* **A/B 실험 기반을 Mixpanel 피처 플래그로 깔았다 (Firebase A/B 대신)**: Firebase A/B 테스트를 검토했는데 **GA4(Google Analytics) 가 필수**였다 — 승패를 GA4 지표로만 판정하므로, 방금 Mixpanel 에 P0 26행을 심은 상태에서 **같은 이벤트를 GA4 에 다시 계측**해야 했다(`firebase_analytics`·`firebase_remote_config` 2개 추가 + 이중 계측). 반면 Mixpanel 이 2025년에 [실험·피처 플래그를 Free 플랜에 개방](https://mixpanel.com/blog/experiments-feature-free-growth-plans/)했고 Flutter SDK 가 공식 지원 대상인데, 결정적으로 **이미 설치된 `mixpanel_flutter` 2.14.0 안에 그 API 가 들어 있었다** — 새 의존성 0개, 이중 계측 0개, 네이티브 변경이 없어 Shorebird 패치로도 나갈 수 있다. 식별도 `identify(memberId)` 로 서버 회원 ID 에 이미 묶여 있다(Firebase 는 FID 라 Mixpanel 과 키가 달라 결과 대조가 어렵다). `Analytics` 에 래퍼 4개를 더했다 — `flag<T>`(값), `flagEnabled`(스위치), `loadFlags`(재평가), `tagExperiment`(실험군을 super property 로). 설정에서 기본값 두 개를 바꿨다: **`prefetchFlags: false`** (기본 `true` 는 init 때 바로 평가해서 **익명 ID 기준 변형이 로그인 후와 갈린다** — `identify` 뒤에 `loadFlags` 를 직접 부른다), **`variantLookupPolicy: persistenceUntilNetworkSuccess`** (기본 `networkOnly` 는 캐시를 안 써서 네트워크가 느리면 fallback 이 나가고, 앱을 켤 때마다 같은 사용자가 다른 값을 봐 실험이 오염된다). SDK 의 `identify()` 가 플래그를 **자동 재평가하지 않는다**는 것을 플러그인 소스로 확인해 `Analytics.identify` 안에서 `loadFlags` 를 잇고, 호출부 2곳은 그대로 뒀다. 로그아웃(`reset`)도 새 익명 ID 기준으로 재평가하되 **`experiment_*` super property 는 복원하지 않는다** — 이전 사용자의 실험군을 물려주면 데이터가 섞인다(`app_version` 과 반대 처리라 주석에 이유를 남겼다). `getVariantValue` 가 `dynamic` 을 주므로 타입 가드를 뒀고, **플랫폼 채널이 숫자를 JSON 으로 실어 와 `int`↔`double` 이 어긋나는 경우만 변환**한다(그냥 버리면 실험이 조용히 안 걸린다). **Free 한도는 MEU(실험 참여 사용자) 1,000/월인데 DAU 가 이미 1,260 이라, 전체 사용자를 넣으면 한도를 넘긴다** — 콘솔 타겟팅으로 모집단을 좁혀야 한다(특정 화면 진입자 등). 넘으면 과금이 아니라 배정이 멈춘다. 디버그 빌드는 트래킹이 꺼져 있어 **플래그도 같이 죽어 항상 fallback** 이므로, 시뮬레이터 확인은 `MIXPANEL_DEBUG=true` 가 필요하다. 아직 **실험은 붙이지 않았다**(기반만). 첫 후보는 응원 광고 가격 상수 3개(`cheer_ad_screen.dart:11-13`) — 분기 코드가 거의 없고 모집단이 그 화면 진입자로 좁아져 MEU 한도에 맞는다.

## 2026-10-22
* **`app_version` super property + 온보딩 단계별 이탈·이탈 화면·버전 분포**: 전날 DAU 알림이 화면·퍼널을 전부 0 으로 뱉었는데, 원인이 "집계 버그" 인지 "계측 미도달 구버전" 인지 **데이터로 가를 방법이 없어** 원시 이벤트를 직접 까 봐야 했다(2026-10-20 export 가 `$ae_session`·`$ae_updated`·`$ae_first_open` 3종 3073건으로 전부 자동 이벤트였다 — 계측 #391 이 그날 머지돼 사용자 빌드에 없었다). 그 진단 비용을 없애려고 **`app_version` 을 super property 로 등록**한다(`Analytics.init`). 기기에 저장돼 이후 모든 이벤트에 자동으로 붙으므로 **이벤트가 늘지 않아 과금 영향이 없다**(Mixpanel 과금은 이벤트 수 기준, 무료 1M/월 대비 현재 9.2%). **소급 적용이 안 되는 게 핵심** — 이벤트는 보낸 시점의 프로퍼티로 영구 저장돼서, 지금 심지 않으면 과거 데이터는 영영 버전을 모른다. 형식은 `api_client.dart` 의 `X-App-Version` 과 같은 `version+build` 로 맞췄다(서버 로그와 같은 키로 대조해야 한다). **함정 하나**: `reset()` 이 super property 도 함께 지운다(플러그인 문서 명시). 재등록하지 않으면 로그아웃·탈퇴 이후 이벤트가 버전을 잃어 버전별 집계에서 그 사용자들만 조용히 빠진다 — 게다가 `reset()`·`registerSuperProperties` 둘 다 MethodChannel 이라 **await 없이 부르면 재등록이 reset 을 앞질러** 방금 심은 값이 지워진다. 내부에서 순서를 잡고 호출부 시그니처(`void`)는 유지했다. 집계 쪽에는 **이미 보내고 있던 데이터만으로** 세 가지를 더했다 — `section_view` 로 **온보딩 단계별 도달**(league→team→player→notification; "완료/포기" 두 숫자로는 어디서 떨어지는지 몰랐다), 사용자별 마지막 `page_view` 로 **이탈 화면**, 그리고 **버전 분포**(버전은 `ours` 가 아니라 전체에서 센다 — 계측 없는 구버전은 자동 이벤트만 보내 ours 로 세면 아예 안 보인다). notification 단계는 권한 기허용 사용자가 화면을 안 그리고 통과해 `section_view` 가 누락되므로(설계 21번) 그 구간 이탈이 과대평가되고, 보정할 이벤트가 없어 **알림에 매번 주석을 붙인다**. 작업 중 `onboarding_steps` 가 전부 0 이 나오는 버그를 겪었다 — `map(select(.x == .))` 의 `.` 이 단계 이름이 아니라 순회 중인 이벤트를 가리켰다. jq 는 이런 스코프 오류를 **빈 결과로 조용히 삼켜서** 0 이 사실인지 버그인지 구분이 안 된다. 그래서 기대값을 박은 회귀 테스트(`mixpanel-dau-summary-test.sh`, 23개 검사)를 만들고 CI 에 Flutter 없이 도는 별도 잡으로 붙였다(버그를 되살려 테스트가 실제로 잡는 것까지 확인했다).

## 2026-10-21
* **DAU 알림을 사용 지표 요약으로 고도화 — 추가 API 호출 0회**: 매일 09:00 에 오던 알림이 DAU·전일 대비·이벤트 수 세 숫자뿐이었다. 원인은 데이터가 없는 게 아니라 **버리고 있었다**는 것이다 — 워크플로우가 이미 하루치 **원시 이벤트 export 전체**를 받아 놓고 `distinct_id` 유니크 개수 하나만 세고 끝냈다. 같은 파일에 P0 계측(#391)의 `location_page`·`step`·`permission_result` 가 전부 들어 있어서, **같은 응답을 다시 읽는 것만으로** 화면 TOP 5·로그인/온보딩 퍼널·참여·이탈 신호를 더했다. 402 로 막힌 조회(Query) API 를 건드리지 않으므로 레이트 리밋(시간당 60회)도 그대로다. 판단이 필요했던 지점들 — **자동 이벤트(`$ae_*`)는 화면·퍼널에서 빼고 DAU 에선 센다**(`$ae_session` 이 찍혔으면 앱을 켠 것이고 그게 활성 사용자의 정의인데, 화면 집계에 섞으면 행동 숫자가 부푼다), **퍼널은 고유 사용자 수로 센다**(이벤트 수로 세면 로그인 화면을 두 번 본 한 사람이 전환율을 100% 넘긴다), **참여는 반대로 행동 횟수**다(한 명이 경기 카드를 5번 누른 게 참여의 실체라 유니크로 접으면 정보가 사라진다), **온보딩 완료는 `step=notification` 인 `next_button_click`** 이다(마지막 단계에서 버튼이 '와딩 시작하기' 로 바뀌고 같은 핸들러가 완료를 처리한다 — 완료 전용 이벤트가 따로 없다). 전일 집합과의 차집합으로 재방문을 가르는데, **"신규" 가 아니라 "그 외" 로 적는다** — 손에 있는 게 이틀치뿐이라 첫 설치인지 그제 이후 복귀인지 구분할 수 없고, 신규라고 쓰면 실제보다 유입이 많아 보인다. ⚠️ 주의 블록(알림 권한 분포·탈퇴)은 **내용이 있을 때만** 붙인다(매일 "탈퇴 0건" 이 박혀 있으면 눈이 그 줄을 건너뛰어 정작 1건 뜬 날에도 안 보인다). 분모가 0이면 비율을 쓰지 않고, 표본이 작으면(`DAU < 30`) 꼬리말 경고를 전환율까지 확장한다. 집계·렌더링 jq 는 YAML 인라인 heredoc 에서 **별도 파일 2개**(`mixpanel-dau-summary.jq`·`mixpanel-dau-embed.jq`)로 뺐다 — heredoc 안의 jq 는 문법 오류가 매일 09:00 실 실행으로만 드러나고, 파일이면 `jq -sf` 로 로컬 검증이 된다(그래서 체크아웃 스텝이 추가됐다). 빈 하루·전일 조회 실패·자동 이벤트만 있는 하루를 샘플 JSONL 로 검증했고, embed 는 335/6000자·7/25필드로 Discord 제약 안에 있다(화면 목록은 `[0:5]` 로 구조상 길이가 묶인다).

## 2026-10-16
* **홈 평점 최신순 → 평점 상세의 라인 마커가 안 뜨던 것을 고쳤다**: 상세 헤더(`PlayedChampCard`)의 라인 아이콘·라벨이 `widget.player.position` 만 보는데, 홈 평점 한줄평 타일에서 들어오는 경로는 그 값을 **`position: ''` 으로 넘기고 있었다**. `/api/mobile/ratings/recent` 응답에 `role` 이 없어 `HomeReviewItem` 자체에 포지션 필드가 없는 탓이다. 빈 문자열은 `laneAssetPath` 에서 매칭에 실패해 **회색 placeholder 사각형 + 빈 라벨**이 됐다(경기 상세·내가 쓴 리뷰 경로는 각각 `player.position`·`positionFromRole(role)` 을 채워 보내 정상이었다). 고치는 방법이 둘이었는데 — 홈 쪽 응답에 `role` 을 추가해 받아 넘기거나, 상세 화면이 스스로 채우거나 — **후자를 골랐다**: 평점 상세 응답(`RatingPlayerDetail`)이 이미 `role` 을 주고 있어 백엔드 변경 없이 끝나고, 앞으로 포지션을 안 넘기는 호출부가 또 생겨도 같은 증상이 재발하지 않는다. 판단 규칙은 `resolvePosition`(`core/util/rating_mapping.dart`)으로 뺐다 — 호출부 값이 있으면 그대로, 비어 있으면 상세 `role` 을 `positionFromRole` 로 변환한다. 상세가 로드되기 전 짧은 순간은 여전히 placeholder 고, 로드되면 라인 아이콘이 붙는다. `RatingRepository` 가 클라이언트 주입이 없는 싱글턴이라 화면 전체 위젯 테스트는 실제 HTTP 를 타므로, 규칙만 단위 테스트 3개로 덮었다.

## 2026-10-14
* **릴리즈 자동화를 실제로 켰다 — Secret 14개 등록 + Discord 배포 봇**: 워크플로우만 있고 꺼져 있던 자동화를 실제로 동작하는 상태로 만들었다. Shorebird 토큰·ASC API 키·iOS 배포 인증서와 프로파일 2개·Android keystore·Play 서비스 계정·네이버 시크릿까지 **14개를 등록하면서 각각 CI 와 같은 방식으로 검증**했다. 그 과정에서 세 가지 함정을 미리 밟았다 — **`.p12` 는 `openssl pkcs12 -export -legacy` 로 만들어야 한다**(OpenSSL 3 기본 암호화는 macOS `security` 가 못 열어 "MAC verification failed" 로 죽는다), **iOS 배포 인증서는 새로 발급해야 한다**(기존 것은 Cloud Managed 라 개인키가 Apple 에 있어 `.p12` 로 못 꺼낸다 — 한도 3개가 차서 가장 오래된 것을 폐기했다), **Android keystore 는 `upload-keystore.jks` + alias `upload`** 다(레포에 jks 가 2개인데 틀린 쪽으로도 빌드는 성공해서 Play 업로드에서야 드러난다). 함께 **배포 전용 Discord 봇**을 `/intent` 봇과 분리해 만들었다. Vercel 프로젝트는 새로 만들지 않고 기존 것에 엔드포인트(`api/discord/release.js`)만 더했다 — 다만 앱마다 서명 검증 공개키가 달라 엔드포인트 자체는 나눠야 한다. 릴리즈 알림에 **[✅ 심사 제출]·[✏️ 패치노트 수정]·[취소]** 버튼이 붙고, 제출은 **2단계 확인**을 거친다(되돌릴 수 없는 동작이라 실수 클릭을 막는다). **일반 채널 웹훅으로는 버튼을 못 보낸다**는 Discord 제약 때문에 봇 토큰으로 메시지를 보낸다. 패치노트는 `distribution/` 에서 파일로 관리하고, 빌드 후 **커밋 로그를 Anthropic API 로 요약한 초안**이 알림에 함께 온다(사용자가 체감할 변경이 없으면 억지로 지어내지 않고 그렇다고 알린다). 첫 실행에서 **`shorebird-release` 액션의 `flutter-version` 이 필수 입력**이라는 것과 **`main-pr-only` ruleset 때문에 bot 도 직접 push 를 못 한다**는 것을 발견해 각각 고쳤다(패치노트는 PR 로 올린다). e2e 는 캐시(Flutter SDK·pub·CocoaPods)와 시뮬레이터 부팅 병렬화로 줄였다 — 테스트 1개에 20분이 걸리고 있었고 캐시가 하나도 없었다.
* **릴리즈 빌드·스토어 업로드 자동화 (아직 켜지지 않음)**: `release/<pubspec version>` 태그를 밀면 검증 → e2e → 빌드(iOS·Android 병렬) → TestFlight·Play 내부테스트 업로드까지 도는 `release-deploy.yml` 과, 버튼으로 심사에 올리는 `submit-for-review.yml` 을 추가했다. 출발점은 두 배포 사고다 — **1.0.3** 은 `flutter build ipa` 로 나가 코드 푸시가 막혔고, **1.0.14+21** 은 gitignore 된 `Secrets.xcconfig` 가 빠져 네이버 로그인만 침묵 실패했다. 둘 다 "빌드 환경이 사람 손에 달려 있다"는 같은 원인이라, 올바른 명령과 시크릿 복원을 워크플로우에 박아 구조적으로 막는다. **심사 제출은 릴리즈 파이프라인에서 분리**했다 — 다른 빌드가 이미 심사 중이면 Apple 이 제출을 거부하는데(fastlane#12551) CI 가 재시도로 못 넘어서, 묶어 두면 빌드·업로드가 멀쩡해도 파이프라인 전체가 빨간불이 된다. Apple 공식 레퍼런스와 Shorebird 공식 가이드도 TestFlight 에서 멈춘다. **1.0.33+79 를 실제로 뽑아 보고 세 가지를 바로잡았다**: Android 서명 키가 `warding-release.jks` 가 아니라 **`upload-keystore.jks` + alias `upload`** 였고(틀린 키로도 빌드는 성공해 Play 업로드에서야 거부된다), iOS 배포 인증서는 **Cloud Managed 라 .p12 로 내보낼 수 없어 새로 발급**해야 하며, `manageAppVersionAndBuildNumber: false` 가 필요하다(Shorebird 공식 가이드에도 필수로 나온다 — Xcode 가 빌드 번호를 바꾸면 패치 대상 버전이 어긋난다). 빌드 잡에는 Flutter 를 따로 깔지 않는다 — shorebird 가 자기 리비전(3.44.6)으로 빌드한다. macOS 러너는 `macos-15` 로 고정했다(러너 이미지 업데이트가 .p12 import 를 깨뜨린 사례가 하필 Flutter+shorebird 환경에서 보고됐고, 우리 e2e 가 지금 그 `macos-26-arm64` 로 돈다). **Apple·Google Secrets 가 등록되기 전까지는 돌지 않으며, CLAUDE.md 의 수동 절차가 유효하다.** 설계·결정 배경은 `intent/release-build-automation/` 의 intent·spec·plan 에 있다.
* **하단 버튼 두 개를 앱 공용 `CommonButton` 으로 통일**: `BottomActionBar` 가 자기 버튼(높이 52·radius 10·w700 16, 색은 사용처가 `color`/`gradient` 로 주입)을 직접 그리던 것을 걷고, 안에서 `CommonButton` 을 쓴다. 바가 맡는 일은 하단 고정과 뒤에 깔리는 배경 막뿐이다. **응원 광고 신청**(`CheerAdScreen`)은 경기리스트 설정의 '완료' 와 같은 `CommonButtonVariant.light`(솔리드 `narButton1Bg`), **광고 안내**(`AdGuideScreen` → `NoticeDetailScreen`)는 경기 일정 필터 시트의 '조회' 와 같은 `CommonButtonVariant.primary`(브랜드 그라데이션)다. 전체 폭 버튼 규격이 공용 버튼 쪽으로 맞춰지면서 높이 52 → **50**, radius 10 → 16, 폰트 w700 16 → w400 18 로 바뀌고 `scrollInset` 도 114 로 따라 줄었다. `color`·`textColor`·`gradient` 파라미터는 `variant` 하나로 대체했다.

## 2026-10-13
* **응원 광고 팝업은 '오늘 하루 보지 않기' 를 눌러야 멈춘다 + 배너 폭 조정 + AD 뱃지**: 팝업이 "하루 한 번·실행당 한 번"이라 한 번 뜨고 나면 그날은 다시 못 보는 데다, 실행당 한 번을 막는 `_shownThisSession` 이 전역이라 핫 리로드로도 안 풀려 확인이 어려웠다. 이제 **그냥 닫으면 다음 홈 진입에 또 뜨고**, `오늘 하루 보지 않기` 를 눌렀을 때만 그날치를 건너뛴다. 하단 버튼을 `닫기`·`자세히 보기` 에서 **`오늘 하루 보지 않기`(왼쪽)·`닫기`(오른쪽)** 로 바꾸고, 신청 화면(`CheerAdScreen`)으로는 **배너 카드를 직접 눌러** 들어간다 — 광고 자리 자체가 버튼이라 '자세히 보기' 를 따로 둘 이유가 없다(`cheerAdPopupConfirm` 문구 삭제). 저장 키도 `cheer_ad_popup_shown_date` → `cheer_ad_popup_dismissed_date` 로 바꿔, 옛 "띄웠음" 기록이 "그만 보겠다"로 읽히지 않게 했다(기존 사용자는 한 번 더 보게 된다). 세션 플래그를 없애고 겹침 방지용 `_showing` 만 남겼다. 가이드 팝업이 뜬 세션에서 건너뛰는 규칙과 디버그에서 날짜 제한을 무시하는 동작은 그대로다. 함께 `CheerAdBanner` 에 `horizontalPadding`(기본 16)을 두고 자리별로 좌우 여백을 달리한다 — **홈 20**(다른 홈 섹션들이 전부 `horizontal: 20 * scale` 이라 그 선에 맞춘다), **경기 리스트·경기 상세 8**(목록 카드보다 넓게 빼 광고 자리를 키운다). 함께 **둥근 `AD` 뱃지**를 광고 자리 오른쪽 위에 붙였다 — 모집 배너(배너·스플래시·팝업 세 슬롯 공통)와 백오피스 등록 광고 이미지 **둘 다**. 스토어 심사(App Store 3.2.2 / Play 광고 정책)가 광고임을 알아볼 수 있게 표시하도록 요구하고, 실제 광고 쪽이 표시가 더 필요한데 그 경로는 `CheerAdBannerCard` 를 거치지 않아 따로 얹어야 했다. 색은 `narAdBadgeBg`(검정 60%)·`narAdBadgeText`(흰색 80%) 토큰을 새로 뒀다 — 사진 위에 올라가도 읽혀야 해서다. 테스트 5개 추가(기본 여백, 전체 폭, 홈 20/경기 8 정렬, 960×300 비율, 세 슬롯 AD 뱃지).

* **광고 자리 문구·예시 사진 교체 + 스플래시·팝업에도 등록 광고를 띄운다**: 모집 배너 문구를 "우리 선수 응원 광고 신청 / 와딩 앱에 응원 메시지를 올려드려요" → **"와딩 광고 신청 / 전하고 싶은 메시지를 와딩 앱에 올려보세요"** 로 바꿨다. 제목이 선수 응원에 묶여 있어 광고 살 사람을 좁혔고, 부제까지 '응원'을 반복했다. 새 용도(브랜드 홍보 등)를 약속하지 않으면서 주어만 넓히는 쪽을 골랐다 — 상세 페이지·가격표가 아직 응원 광고 기준이라 "응원부터 브랜드 홍보까지" 식으로 쓰면 그 문서들과 어긋난다. 상세 페이지(`cheerAdHeadline`)는 그대로 둔다(거기까지 온 사람에겐 구체적인 쪽이 낫다). 예시 사진 3개(`assets/images/cheer_ad/*.png`)를 새 디자인 목업으로 갈고 자리별 `focus`·`zoom` 을 다시 잡았다. 스플래시는 폰 목업 전체를 쓰면 로고가 같이 들어와(가로로 납작한 1.5:1 칸에 세로로 긴 목업을 욱여넣는 구조라 크롭으로는 안 풀렸다) **광고 부분만 잘라낸 332×230 이미지**로 바꾸고 `focus`·`zoom` 을 없앴다. `OverflowBox` 의 `maxWidth` 가 `area.maxWidth` 로 묶여 있어 zoom > 1 이 먹지 않던 것도 고쳤다. 그리고 **스플래시·팝업도 백오피스 등록 광고를 띄운다** — 두 자리는 `CheerAdBannerCard` 를 직접 써서 `AdRepository` 를 아예 안 거쳤는데, `CheerAdScreen` 은 스플래시 6만·팝업 4만으로 팔고 있어 "팔지만 띄울 경로가 없는" 상태였다. 등록 광고 렌더를 `RegisteredAdCard` 로 빼서 다섯 자리가 같이 쓰고, 스플래시는 `CheerAdSlotView`, 팝업은 `_PopupAdCard` 가 조회를 맡는다(등록 광고는 광고주 주소로, 모집 배너는 신청 화면으로 — 탭 동작이 달라 자리마다 따로 둔다). **서버가 아직 `splash`·`popup` 을 거절하므로**(`Ad.PLACEMENTS` 가 배너 3곳만 허용) 실제 노출은 백엔드 반영 후다. 광고가 없으면 지금처럼 모집 배너가 나와 순서에 상관없이 안전하다. 요청 문서는 warding-docs `features/ad-placements-splash-popup/spec.md`. **에셋이 바뀌어 코드 푸시로는 못 나가고 스토어 빌드가 필요하다**(1.0.33+76).
* **응원 광고 자리 도입**: 홈·경기 리스트·경기 상세의 `AdvertiserBanner` 를 회색 `CheerAdBanner`("우리 선수 응원 광고 신청", 오른쪽에 자리별 예시 사진)로 바꾸고, 누르면 가격 타일 3개가 있는 `CheerAdScreen` → 하단 `상세 보기` → 기존 `AdGuideScreen`(백오피스 공지 `ad-guide` + 구글폼)으로 잇는다. 스플래시 하단에 같은 카드를 두고 대기를 600ms→3.5초로 늘렸다. 홈 진입 팝업(`maybeShowCheerAdPopup`)은 하루(KST) 한 번·실행당 한 번이고 가이드 팝업이 뜬 세션에서는 건너뛴다(디버그에선 하루 제한 무시) — 이 노출 규칙은 같은 날 '오늘 하루 보지 않기' 기준으로 바뀌었다(위 항목). 광고 안내 화면은 `NoticeDetailScreen(landing: true)` 로 작성자·날짜 줄을 빼고 제목·본문 크기를 조정했다. 경기 리스트 광고는 3그룹마다에서 8그룹마다(3번째 그룹 앞부터)로 줄였다. 카드 비율은 광고 규격(배너 960×300, 스플래시 1080×720, 팝업 1080×1440). 가격은 `CheerAdScreen` 에 하드코딩(배너 2만·팝업 4만·스플래시 6만, 오픈 50% 할인)이라 백오피스 공지 가격과 이중 관리다.

## 2026-10-10
* **AdMob 제거, 광고주 모집 배너로 교체**: 홈 순위표 아래와 경기리스트 날짜 사이(3번째 날짜마다)의 `InlineBannerAd` 를 `AdvertiserBanner`("와딩 후원하기" 문구와 브랜드 그라데이션, 탭하면 고객센터 문의 폼)로 바꿨다. `google_mobile_ads`·`app_tracking_transparency` 의존성, `AdsBootstrap`(UMP·ATT·SDK 초기화), `AdConfig`, Info.plist 의 `GADApplicationIdentifier`·`NSUserTrackingUsageDescription`·`SKAdNetworkItems`, AndroidManifest 의 AdMob 앱 ID 를 걷었다. 네이티브 변경이라 Shorebird 패치로는 못 나가고 스토어 빌드가 필요하다. 설계는 warding-docs `features/ad-sales`.

## 2026-10-09
* **홈 솔랭 카드 응원 버튼**: 진행 중 카드 하단에 응원 영역(총 숫자·`+N`·응원하기)을 붙이고, 탭을 모아 `count` 로 한 번에 보내는 `SoloCheerController` 를 추가했다. 끝난 경기 칩에 응원 합계를 붙인다. 백엔드 응원 API 머지·배포 뒤에 머지한다. 자세한 내용은 [홈](/features/home.md).

## 2026-10-07
* **e2e 워크플로우가 "취소"를 "실패"로 알리던 것 수정**: `e2e-release-check.yml` 의 Discord 알림이 `if [ "$STATUS" = "success" ]` 하나로 갈라져, `job.status` 가 `cancelled` 일 때도 🔴 **"릴리즈 직전 e2e 실패"** 로 나갔다. 옛 커밋을 돌던 run 을 새 커밋 푸시 후 취소하는 건 정상적인 운영 동작인데, 그때마다 아무도 안 깨뜨린 릴리즈가 막힌 것처럼 보인다(실제로 2026-10-06·10-07 취소분 2건이 그렇게 나갔다). `cancelled` 분기를 따로 두어 ⚪ "취소됨"(회색)으로 보낸다. `escalate` job 은 `if: failure()` 라 취소 시 애초에 돌지 않아 문서 자동생성까지 가지는 않았다 — 손대지 않았다. 같은 패턴을 쓰는 워크플로우가 더 있는지 확인했고 이 파일 하나뿐이다.
* **마이구독을 나갈 때 알림을 전부 읽음 처리 — 홈 벨 배지가 "보면 사라지게"**: 2026-10-01에 배지 **범위**를 벨 목적지와 맞췄지만(읽는 묶음 = 세는 묶음), 정작 그 화면에 **범위 전체를 읽음으로 넘기는 경로가 없었다.** 마이구독은 카드를 **개별로 탭할 때만** `markRead`를 불러서(`subscription_screen.dart:220`), 알림 목록을 눈으로 다 확인하고 나와도 탭하지 않은 건은 미읽음으로 남고 홈 벨 배지가 그대로였다. `SubscriptionFeedViewModel.markAllReadOnExit`를 추가해 화면 `dispose`에서 부른다. **진입이 아니라 이탈 시점인 이유:** 진입 즉시 읽음으로 넘기면 머무는 동안 미읽음 강조(보라색 오버레이+점)가 전부 사라져 "무엇이 새로 왔는지"를 구분할 수 없다 — 그래서 이 메서드는 `markAllRead`와 달리 목록 상태를 낙관적으로 고치지 않고 서버만 호출한다(화면이 사라지는 시점이라 보여줄 UI도, 실패 시 복구할 대상도 없다. 다음 진입 때 서버 값을 그대로 받는다). 미읽음이 0이면 호출하지 않고, 실패는 조용히 넘긴다(`dispose`에서 불려 `await`할 수 없어 `unawaited`로 띄운다 — ViewModel의 `_notify`에 `_disposed` 가드가 있어 안전하다). **처음엔 `dispose`에서 `unawaited`로 띄웠다가 되물렀다**(CodeRabbit 리뷰 지적): "돌아오면 `HomeViewModel`이 새로 만들어져 미읽음을 다시 센다"는 것까진 맞지만 **순서 보장이 없었다.** `dispose`는 `pushReplacement`가 새 화면을 만든 **뒤에** 불리므로, 홈의 미읽음 조회(GET)와 읽음 처리(POST)가 같은 프레임에서 경쟁한다 — GET이 먼저 끝나면 옛 미읽음 수를 받아 **배지가 그대로 남는다.** 읽음 처리를 화면 전환 **전에** `await`하는 `SubscriptionScreen._leaveTo`로 옮겨 해결했다(하단 네비 5개 탭 전환이 모두 이 경로를 쓴다). 응답이 느릴 때 탭이 먹통으로 느껴지지 않게 2초 타임아웃을 두고, `dispose` 쪽 호출은 이 전환을 거치지 않는 이탈(안드로이드 뒤로가기 등)용 보완책으로 남겼다. **두 번째 지적도 유효했다**: 건너뛰기 조건이 `_unreadCount == 0` 이었는데 이 값은 0에서 시작하고 생성자의 `load()`는 `await`되지 않아, **목록이 뜨기 전에 나가면 서버에 미읽음이 있어도 요청을 통째로 건너뛰었다**(50건을 받는 피드라 느린 망에서 충분히 생길 수 있다). `_loadedOnce` 플래그를 두어 "아직 못 받음"과 "받아보니 0건"을 구분하고, 건너뛰는 건 후자일 때뿐이다. 조회가 **실패**한 경우도 전자로 취급해 요청을 보낸다. 알림함(`NotificationScreen`, `group=COMMUNITY`)에는 적용하지 않고 수동 "모두 읽음" 버튼을 유지했다. `group`을 그대로 넘기므로 나중에 알림함에 붙여도 범위는 자동으로 맞는다. 테스트 6개 추가(API 호출·목록 미변경, 조회 후 0건이면 미호출, **조회 전엔 0이어도 호출**, **조회 실패 시에도 호출**, 실패 시 예외 없음, group 전달). Dart만 바뀌어 코드 푸시로 나간다.
* **Mixpanel DAU 일일 요약을 Discord 로 보낸다**: `.github/workflows/mixpanel-daily-dau.yml` 이 매일 09:00 KST 에 어제 DAU 와 전일 대비 증감을 Discord 로 쏜다(`workflow_dispatch` 로 날짜를 지정해 수동 실행도 가능). **Segmentation Query API 가 아니라 Insights Query API 를 쓴다** — Segmentation 은 Mixpanel 이 유지보수 모드로 돌려 신규 사용을 권장하지 않는다. Insights 는 대시보드에서 만든 리포트를 `bookmark_id` 로 조회하는 방식이라, 보고 싶은 지표가 바뀌면 워크플로우가 아니라 **리포트만 고치면 된다**(쿼리 정의가 코드 밖에 있다는 뜻이기도 해서, 리포트를 지우면 조용히 깨진다 — 실패 시 Discord 로 알린다). 응답의 `series` 는 `{계열명: {ISO날짜: 값}}` 라 계열이 하나라고 가정하지 않고 전부 합산한다(리포트에 브레이크다운을 걸어도 총합이 맞게). Secret 이 하나라도 비면 실패가 아니라 건너뛴다 — 설정 전에 매일 실패 알림이 쌓이지 않게 한다. **전제: 지금 앱에는 `Analytics.track()` 호출부가 0건이라** 커스텀 이벤트가 없다. 자동 이벤트(`trackAutomaticEvents: true`)와 로그인 식별만 들어오므로 당장 의미 있는 건 활성 사용자·버전 분포 정도다. 퍼널·섹션 사용률을 보려면 이벤트부터 심어야 한다. **수치를 읽을 때 주의:** Mixpanel 이 처음 들어간 건 `1.0.32+71` 이라, 그 이전 버전을 쓰는 사용자는 **아예 집계되지 않는다.** 스토어 배포 직후에는 업데이트 침투율이 낮아 DAU 가 실제 사용자 수보다 작게 잡히고 증감률도 크게 출렁인다(표본이 작을 때 1~2명이 비율을 흔든다 — Play Console 크래시율에서 사용자 1명이 3.28% 로 보인 것과 같은 현상). 침투율이 안정될 때까지는 추세만 보는 게 맞다.

## 2026-10-06
* **순위표 기본 선택 리그를 서버 `defaultLeague` 로**: 앱이 `_selectedLeague = 'LCK'` 를 박아 두고 서버가 주는 `defaultLeague` 를 **파싱만 하고 안 썼다**(`ScheduleFilterOptions.defaultLeague` 를 읽는 곳이 없었다). 지금은 서버도 `LCK` 를 줘서 결과가 같지만, 서버가 그 칩을 안 주거나 점선으로 내리면 **선택된 칩이 목록에 없는 상태**가 돼 순위표가 빈 채로 열린다. 이제 `defaultLeague` 를 따르고, 그게 고를 수 없는 칩이면 첫 번째 live 칩으로 떨어뜨린다. 사용자가 직접 고른 뒤에는 칩 목록을 다시 받아도 덮지 않는다(`_leagueTouched`).
* **순위표 칩의 라벨·순서를 서버 값 그대로 쓰게 했다**: 리그 메타를 서버에서 받기로 해 놓고 정작 **표시명과 순서는 앱이 덮어쓰고 있었다.** (1) `_chipLabel(l.code)` 가 서버 `name` 을 버리고 코드로 라벨을 만들었다(월즈만 '월즈' 한글) — 이제 `l.name` 을 쓰고 비었을 때만 폴백한다. (2) `_chipOrder = ['LCK','LPL','LEC','LCS','WORLDS']` 로 이 5개를 앞으로 당기고 새 리그만 뒤에 붙이는 고정 순서가 있었다 — 통째로 지우고 **서버 순서를 그대로** 쓴다(ALL·`standings: null` 만 걸러낸다). 둘 다 백엔드가 바꿔도 앱 배포 전엔 반영이 안 되던 자리였다. 남은 월즈 하드코딩은 폴백 경로뿐이다 — `_fallbackLeagueChips`(서버 메타 못 받을 때), `league_icon.dart` 번들 아이콘(서버 `iconUrl` 우선), `ApiConfig.fallbackLeagueCodes`(첫 실행·오프라인).
* **순위표 형식 분기를 리그 코드에서 응답 기반으로 바꿨다 (대진 UI 잠금 해제)**: `selectedLeague == 'WORLDS'` 하드코딩이라 **월즈가 아닌 리그는 어떤 응답을 받아도 대진을 못 그렸다.** 월즈 칩은 출시 보류로 `live: false` 라서, 이미 구현해 둔 토너먼트 UI(`_WorldsKnockout` — 스위스 버킷 + 8강/4강/결승 + 연결선 `CustomPaint`)에 **사용자가 도달할 경로가 0개인 죽은 코드**였다. 이제 **응답에 `bracket` 이 실려 왔는지로만** 분기한다(`StandingsResult.hasBracket`). 실려 오면 `toWorldsStandings()` 로 옮겨 **기존 대진 UI를 그대로 재사용**한다 — 형식은 warding-docs `features/home/spec.md` 에 선제시했고(백엔드 회신 대기), 서버가 아직 안 주므로 지금은 기존 동작과 100% 동일하다. **처음엔 `reason: "BRACKET_ONLY"` 로 분기했다가 되물렀다**: 백엔드 소스(`nar-back-repo` `StandingsService`)를 열어 보니 그 값은 "스위스·토너먼트 포맷이라서"가 아니라 `SCOPES`(현재 LCK·ASIAN_GAMES·DEMACIA_CUP)에 **없는 리그 전부**에 붙는 기본값이었다(`scope == null → unsupported(league, "BRACKET_ONLY")`). 엔드포인트 응답만 보고 WORLDS·MSI 가 그 값을 준다는 걸 포맷 신호로 잘못 읽은 것이다. 그대로 뒀으면 LPL·LEC·EWC 같은 미등록 리그까지 대진으로 취급했을 것이다(지금은 그 리그들이 `standings: null` 이라 칩이 없어 실제 피해는 없었다). 데이터 유무를 신호로 삼으면 백엔드가 reason 체계를 바꿔도 앱이 안 흔들린다. 곁들여: ① 스위스·녹아웃 중 **한쪽만 있으면 전환 버튼을 숨긴다**(`worldsHasBothViews`) — 누르면 빈 화면으로 가기 때문. ② 리그를 바꾸면 옛 대진을 즉시 버린다. ③ `_isStandingsSupported` 의 월즈 코드 예외를 없애고 `supported || hasBracket` 로 바꿨다. ⑤ 헤더 부제의 월즈 전용 하드코딩 문구("2025 · 스위스 스테이지")를 서버 `scopeLabel` 로 교체 — 대진이 월즈 전용이 아니게 되면서 다른 대회에서 틀려진다. **ASIAN_GAMES 가 녹아웃에 들어가면 이 경로를 탄다.**
* **대진 노드가 2px 넘치던 레이아웃 버그 수정**: `_nodeHeight = 68` 이 팀 로우 높이를 배지(20) 기준으로 잡았는데 실제로는 **팀 코드 텍스트의 라인 박스**(13px Pretendard, 22 남짓)가 결정한다. 월즈 오버플로우 테스트가 `skip: true` 라(칩 비활성이라 도달 불가) 아무도 못 잡고 있었다. 72 로 올리고, ASIAN_GAMES 대진으로 8강~결승 전체를 그리는 오버플로우 회귀 테스트를 추가했다. 이 값은 연결선 좌표(`centerY`)에도 쓰여서 상수로 유지한다.
* **ASIAN_GAMES 순위표에서 국기 이미지가 안 뜨던 버그 수정**: 순위표 배지(`TeamCodeBadge`)가 응답의 `imageUrl` 을 **버리고** 사전(`TeamLogoDirectory`)만 봤다. 프로팀 로고 크기를 통일하려는 기존 결정이었는데(두 소스의 여백·비율이 달라 배지가 들쭉날쭉했다), 사전은 온보딩 **팀** 목록이라 **국가대표가 없다** — ASIAN_GAMES 는 국기(`https://api.nar.kr/images/flags/kor.png`, 응답에 정상적으로 실려 온다. 실측 200 image/png)가 순위표 응답에만 있어서 8개국 배지가 전부 빈 원이었다. `fallbackImageUrl` 파라미터를 추가해 **사전을 먼저 보고 거기에 없을 때만** 응답 이미지를 쓴다 — 프로팀은 사전 값이 이기므로 기존 통일성 결정이 유지되고, 사전에 없는 팀만 백엔드가 준 이미지로 뜬다. 같은 이유로 응답 이미지를 버리고 있던 **홈 커뮤니티 작성자 배지**(`CommunityAuthor.teamImageUrl`)에도 같은 폴백을 걸었고(사전에 없는 팀의 작성자 배지가 비었다), `TeamLogo` 에도 대칭으로 파라미터를 뒀다. 나머지 호출부(오늘 경기·경기 상세·마이페이지 등)는 이미 서버 URL 을 직접 넘기고 있어 손댈 게 없었고, 솔랭·한줄평·쇼츠 모델은 애초에 팀 이미지 필드가 없어 사전이 유일한 소스다.
* **순위표 그룹 이름이 서버 코드(`LEGEND`·`A`)로 그대로 보이던 것 수정**: 그룹 헤더는 `name.isEmpty ? '레전드 그룹' : name` 이었는데 서버가 **빈 문자열이 아니라 코드**를 준다(실측: LCK `LEGEND`·`RISE`, ASIAN_GAMES `A`·`B`). 그래서 폴백이 한 번도 안 걸리고 헤더에 "LEGEND" 가 그대로 떠 있었다. `standingsGroupLabel`(`lib/core/util/standings_group_label.dart`)을 만들어 아는 코드는 한국어 그룹명으로, 한두 글자 기호는 `stageGroup` 을 붙여 "그룹 A" 로, 처음 보는 값은 그대로 둔다(모르는 리그가 열려도 빈칸보다 서버 값이 낫다). 헤더·더보기 라벨이 같은 함수를 쓴다.
* **순위표 "더보기" 라벨의 그룹 이름을 서버 응답에서 가져오게 함**: 카드 하단 펼치기 버튼이 `homeStandingsExpandMore` = "라이즈 그룹 {count}팀 더보기" 로 그룹 이름까지 박아 둬서, 레전드·라이즈가 아닌 리그에서 틀린 이름이 떴다 — warding-docs `features/home/spec.md` 기준 ASIAN_GAMES 도 `groups` 2개("그룹 스테이지", nar-back-repo#547로 열렸다)라 이미 실제로 어긋나는 조건이었다. `StandingGroup.name` 은 서버가 이미 내려주고 그룹 **헤더**는 그 값을 쓰고 있었는데(`main.name.isEmpty ? ... : main.name`) 버튼 라벨만 하드코딩이었다. 이제 숨은 그룹이 하나면 서버 이름을 넣어 "〈그룹 이름〉 N팀 더보기", 둘 이상이면 이름 나열 대신 `homeStandingsExpandMoreGroups` = "M개 그룹 N팀 더보기" 로 줄인다(그룹이 3개 이상인 리그에서 버튼이 한 줄을 넘기지 않게). 서버가 이름을 빈 문자열로 주면 기존 "라이즈 그룹" 폴백을 유지해 LCK 동작은 그대로다. `HomeFakeApi.standingsGroups` 를 추가해 그룹 2개 이상 응답을 테스트에서 만들 수 있게 하고, 위젯 테스트 4개(서버 이름 사용·그룹 개수로 축약·빈 이름 폴백·그룹 1개면 버튼 없음)를 더했다.

## 2026-10-05
* **리그 메타를 서버에서 받게 연결(순위표 칩·알림 벨·아이콘)**: 백엔드 nar-back-repo#548 이 `/mobile/schedules/filters` 의 `LeagueOption` 에 `standings`·`alarm`·`iconUrl` 을 추가했다(warding-docs#11 요청). `FilterLeague` 가 세 필드를 파싱하고, 받은 값은 `LeagueMeta`(`lib/core/util/league_meta.dart`)에 보관한다 — 경기 카드 알림 벨(`match_card`)과 리그 아이콘(`leagueIconWidget`: 서버 PNG URL 우선, 없으면 번들)이 이걸 쓴다. 홈 순위표 칩은 `HomeViewModel._loadLeagueChips` 가 서버 `standings` 로 만든다(null=숨김·false=점선·true=선택 가능, `supported:false` 리그는 점선). 서버가 메타를 안 주면(`alarm` 필드 없음 = 구버전) 기존 하드코딩 값으로 폴백한다. **동작 변화:** 서버가 LPL·LEC·LCS·WORLDS 에 `null` 을 줘서 이 칩 4개가 사라지고, ASIAN_GAMES 칩이 새로 생긴다.
* **Mixpanel SDK 세팅**: `mixpanel_flutter` 를 추가하고 `lib/core/util/analytics.dart`(`Analytics`) 래퍼를 만들었다. 프로젝트 토큰(US 데이터 센터)은 Sentry DSN 처럼 코드 기본값으로 두고 `--dart-define=MIXPANEL_TOKEN=...` 로 덮어쓸 수 있다(릴리즈 명령에 플래그를 안 붙여도 켜진다). 디버그 빌드에서는 init 을 건너뛰어 모든 호출이 무시된다(운영 데이터 오염 방지) — 시뮬레이터는 release 모드를 못 돌리므로 동작 확인은 `flutter run --dart-define=MIXPANEL_DEBUG=true` 로 디버그에서 켜서 한다. `main()` 의 시작 초기화 `Future.wait` 에 `Analytics.init()` 를 넣었고, Sentry 사용자 설정과 같은 지점에서 로그인 시 `identify(memberId)`, 로그아웃 시 `reset()` 을 부른다. 네이티브 플러그인이라 코드 푸시로는 못 나가고 스토어 재배포가 필요하다.
* **모든 API 요청에 `X-App-Version` 헤더를 붙임**: 서버 로그에 앱 버전이 없어 "배포 후 업데이트 비율"과 버전별 오류를 잴 수 없었다. 요청 경로가 `core/util/api_client.dart` 하나라 `VersionedClient`(`http.BaseClient` 래퍼)로 한 번만 붙인다. 버전(`<버전>+<빌드>`)은 `main.dart` 시작 때 `loadAppVersion()` 이 한 번 읽어 두고 요청 경로에서는 기다리지 않는다 — 요청마다 플랫폼 채널을 `await` 하면 위젯 테스트(가짜 비동기)에서 요청이 끝나지 않아 타임아웃 타이머가 남아 테스트 7개가 깨졌다. 읽기 실패 시 헤더만 빠진다. **이 조회는 시작 `Future.wait` 에 넣지 않고 `unawaited` 로 띄운다** — 거기 넣으면 플랫폼 채널이 응답하지 않을 때 첫 화면이 최대 8초(그 묶음의 타임아웃) 늦어지는데, 로그용 헤더가 그만한 값이 아니다. 조회 전 요청은 헤더 없이 나가고 끝난 뒤부터 실린다. `VersionedClient` 는 `close()` 를 재정의해 감싼 클라이언트까지 닫는다(`http.BaseClient.close` 기본 구현은 아무것도 안 해서, 안 두면 안쪽 연결 풀이 남는다). Dart 만 바뀌어 코드 푸시로 나간다. 단 패치는 릴리즈 버전을 그대로 보고하므로 패치 번호는 구분하지 못한다.

## 2026-10-02
* **홈 솔랭 카드: 1초 타이머가 섹션 전체를 매초 다시 그리던 것 수정**: 경과 시간 카운트업 타이머가 틱마다 `setState(() {})` 로 솔랭 섹션 전체(챔피언 스플래시·선수 사진 3장·`PageView`·끝난 경기 칩 줄)를 재구성했다. 게다가 조건이 `soloState == active` 였는데 **끝난 경기만 있어도 active** 라(`HomeViewModel.soloState`), 카운트업할 대상이 하나도 없는 흔한 상태에서도 매초 돌았다 — 빌드 메서드에 카운터를 심어 실측하니 두 경우 모두 10초에 섹션 빌드 10회였다. (1) 타이머 조건을 `soloLive.isNotEmpty` 로 바꿔 진행 중 카드가 있을 때만 돌리고, (2) 틱을 `ValueNotifier` 로 바꿔 `ValueListenableBuilder` 로 감싼 경과 시간 텍스트만 갱신하게 하고, (3) `WidgetsBindingObserver` 를 붙여 백그라운드에서는 타이머를 끈다(솔랭 5초 폴링이 `pauseSoloPolling` 으로 멈추는 것과 같은 맥락 — 폴링은 멈추는데 이 타이머만 계속 돌고 있었다). 재측정 결과 두 경우 모두 10초에 0회.
* **라이브 액티비티 고착 카드 정리 스캔: 포그라운드 복귀마다 수십 건 API 를 쏘던 것 수정**: `dismissStaleCards` 가 `AppLifecycleState.resumed` 마다 쓰로틀 없이 돌았다. 하는 일은 구독 경기 ID 조회(인증) → 그 경기들 상태 전부 조회 → 부족하면 오늘·어제 구독팀 경기까지 추가 조회로, 주석에 적힌 실측이 "20개 기준 약 6초" 다. 알림 보러 잠깐 나갔다 와도 매번 전부 다시 돌았다(홈 화면은 `resumeRefreshInterval` 30초 가드가 있는데 여기는 없었다). (1) 네이티브에 `hasActiveActivities`(`Activity<MatchLiveAttributes>.activities` 가 비었는지)를 추가해 **떠 있는 카드가 없으면 경기 조회를 통째로 건너뛴다** — 카드가 없는 쪽이 훨씬 흔해 평소 복귀 비용이 네이티브 호출 한 번으로 줄었다. (2) 30초 쓰로틀을 두되 `force: true` 로 우회할 수 있게 했다. 조회 실패 시 `false`(스캔 건너뜀)라 구버전 네이티브에서도 안전하다. **네이티브 변경이라 코드 푸시로는 못 나가고 스토어 재배포가 필요하다.**
* **경기 상세 라이브 폴링은 건드리지 않았다**: 같이 점검했는데 `lastNotifyWasPoll` 플래그로 폴링 알림을 이미 걸러내고 있었다(주석에 "라이브 시청 중 화면 전체가 5초마다 리빌드되며 렉으로 느껴지던 원인" 이력까지 기록돼 있다). 홈 화면 위젯 갱신도 앱 시작 시 1회뿐이라 문제없다.
* **리그 목록을 서버(필터 API)에서 받아 앱·위젯이 함께 따라가게 함**: `league=ALL` 을 실제 리그 코드로 펼치는 목록이 Dart(`ApiConfig._allRealLeagueCodes`, 13개)와 **Swift 위젯**(`TodayMatchesFetcher.allRealLeagueCodes`, 11개) **두 곳에 복사**돼 있었고, 이미 어긋나 있었다 — `ASIAN_GAMES`·`DEMACIA_CUP` 이 Swift 쪽에만 빠져서 **그 리그 경기만 있는 날 홈 위젯이 "경기 없음" 으로 비었다**(앱에서는 보이는데 위젯만). 홈 화면에서 두 번 겪은 것과 같은 원인인데, Dart 만 고치고 Swift 사본은 아무도 안 고쳤다. 네이티브라 코드 푸시로도 못 고친다. 새 API 를 만들지 않고 **이미 있는 `/mobile/schedules/filters` 응답의 리그 목록을 재사용**한다(`ApiConfig.updateLeagueCodes`). 받은 목록은 App Group 의 `widget_all_league_codes` 로 내려보내 Swift 가 읽는다(`HomeWidgetService.saveLeagueCodes`). 양쪽 모두 하드코딩 목록을 **폴백으로 남겼다** — 첫 실행·오프라인에서 목록이 비면 경기 조회 자체가 실패하기 때문이다. 이제 백엔드에 리그가 추가되면 앱·위젯이 자동으로 따라간다.
* **Data Dragon 버전 고정(15.13.1)으로 신챔 아이콘이 안 나오던 버그 수정**: 챔피언 **아이콘** URL 에는 패치 버전이 들어가는데 `ChampionImage._ddragonVersion` 이 `15.13.1` 로 박혀 있었다(최신 16.19.1). 그 버전에 없는 챔피언은 CDN 403 이라 **유나라·자헨 아이콘이 빈칸**이었다(검증: 15.13.1 에서 Yunara·Zaahen → 403, Mel·Ambessa → 200). 스플래시 아트는 경로에 버전이 없어 영향이 없고 아이콘만 해당된다. 앱 시작 시 `versions.json` 의 첫 항목(최신)을 받아 쓰도록 바꿨다(`ChampionImage.refreshDdragonVersion`) — 백엔드 작업 없이 신챔에 자동 대응한다. 조회 실패·비정상 응답(`x.y.z` 형식 아님)이면 기존 상수로 폴백하고, 예외를 던지지 않아 호출부가 기다리지 않아도 된다.
* **경기 리스트 시즌 목록을 서버(필터 API)에서 받게 함**: `MatchListViewModel.seasons` 가 `['2025', '2026']` 으로 박혀 있었다. 해가 바뀌면 새 시즌이 선택지에 없고, 선택할 수 없으니 그 연도를 `seasonYear` 로 **요청하지도 못한다** — 서버에 데이터가 있어도 앱이 물어보질 않고, 아무 에러도 안 나서 알아채기 어렵다. 처음엔 기기 시계로 "작년, 올해" 를 계산하도록 고쳤는데, 백엔드 DTO(`MobileScheduleFilterResponse`)를 확인해 보니 **`/mobile/schedules/filters` 가 `seasons`(year·split·label)를 이미 내려주고 있었다** — 앱 모델이 그 필드를 파싱조차 하지 않아 받아놓고 버리던 상태였다(prod 실응답: `2026 Split 1/2/3`, `2025 Split 3`). 서버 값을 쓰도록 바꾸고(`ScheduleFilterOptions.seasonYears`), 기기 시계 계산은 응답 전·오프라인용 폴백(`fallbackSeasons`)으로 남겼다. 시즌 필터는 연도 단위라(`seasonYear`·`fetchTree(year:)`) 연도만 중복 제거해 쓴다 — 스플릿까지 쓰려면 필터 UI 자체를 바꿔야 한다(미적용). 선택 중이던 시즌이 서버 목록에 없으면 가장 최근 시즌으로 되돌린다.

## 2026-10-01
* **홈 알림 배지: 알림을 읽어도 배지가 사라지지 않던 버그 수정**: 배지는 `group=COMMUNITY`로 미읽음을 셌는데, 벨이 여는 화면은 2026-09-29부터 알림함이 아니라 마이구독 탭이고 그 피드(`SubscriptionFeedViewModel`)는 `group` 없이 전체를 읽음 처리한다 — **읽는 알림과 세는 알림이 서로 다른 묶음**이어서 마이구독에서 다 읽어도 COMMUNITY 미읽음은 그대로 남았다. 게다가 COMMUNITY 알림을 실제로 읽음 처리하는 화면(`NotificationScreen`)은 진입 경로가 그 벨 하나뿐이었어서, 벨 목적지를 바꾼 뒤로는 앱 안에서 배지를 지울 방법이 아예 없는 상태였다. 배지를 벨 목적지와 같은 전체 범위로 맞춰 해결(`HomeViewModel.refreshUnreadNotifications`에서 `group` 인자 제거). 같은 실수가 반복되지 않게 "벨 목적지를 바꾸면 배지 범위도 맞춘다"는 주석을 `home_screen.dart`·`home_viewmodel.dart` 양쪽과 wiki에 남겼다.
* **홈 솔랭: 챔피언 배경 이미지가 일부 챔피언만 나오던 버그 수정**: 원인이 둘이었다. (1) 백엔드가 `LivePlayer`·`FinishedPlayer`에 `championImageUrl`을 주는데 앱이 이 필드를 **완전히 무시**하고 챔피언 이름으로 URL을 짜맞추고 있었다(FCM 모델도 파싱만 해두고 쓰는 곳이 없음). (2) 그 URL 조립이 틀렸다 — Data Dragon 경로엔 표시명이 아니라 키가 들어가야 하는데 `championToEn`의 영어 **표시명**을 그대로 넣어서, 공백·아포스트로피·`.`·`&`가 있는 챔피언은 CDN이 403을 주고 배경만 빈 채로 남았다(`Lee Sin`, `Kai'Sa`, `Dr. Mundo` 등). 공식 데이터(16.19.1, 173명) 대조 결과 **21명이 깨져 있었고** 단어 하나인 챔피언만 우연히 동작해서 "몇 개는 나오고 몇 개는 안 나오는" 증상이 됐다. 수정: 응답의 `championImageUrl`을 1순위로 쓰고 없을 때만 이름 폴백(`HomeLiveSoloPlayer.championImageUrl` 추가), 그리고 `championSplashUrl`이 **내부에서** 키 변환을 하도록 바꿔 모든 호출부가 함께 고쳐지게 했다 — 다른 호출부(`played_champ_card.dart`)는 한국어명을 그대로 넘기고 있어 거기선 모든 챔피언이 깨져 있었다. 키 변환은 새로 만들지 않고 `champion_image.dart`에 이미 있던 예외표(173명 전부 검증 통과)를 `ChampionImage.ddragonKeyOf`로 공개해 재사용했다.
* **쇼츠: 영상 위 세로 스와이프 먹통·전체화면에서 못 빠져나오던 버그 수정**: `youtube_player_iframe`의 `enableFullScreenOnVerticalDrag`/`autoFullScreen` 기본값(둘 다 true)이 이미 전체화면 세로 피드인 이 화면과 충돌했다 — 플레이어 위 세로 드래그를 패키지가 "전체화면 진입" 제스처로 먼저 가로채 다음 영상으로 넘기는 `PageView` 스와이프가 영상 위에서 먹지 않았고, 전체화면 진입 뒤에는 패키지 내부 `PopScope`가 시스템 뒤로가기·X 버튼의 pop을 "전체화면 탈출"로만 소비해 화면을 닫을 수 없었다. 둘 다 꺼서 1차 해결(`shorts_embed.dart`). 그런데도 영상 위 세로 스와이프가 여전히 안 먹혀 `gestureRecognizers`에 `VerticalDragGestureRecognizer`를 등록했지만 역시 무효 — 디버그 로그(`Listener`+`onPageChanged`)로 찍어 보니 포인터 이벤트는 Flutter까지 들어오는데 `PageView`가 드래그를 못 가져가고 있었다. 근본 원인은 유튜브 iframe 문서 자체가 세로로 스크롤 가능해서, 네이티브 WebView(iOS WKWebView) 내장 스크롤뷰가 그 드래그를 Flutter 제스처 아레나보다 먼저 가로채던 것 — `runJavaScript`로 iframe 문서(`html`/`body`)를 `overflow: hidden`·`position: fixed`로 고정해 내장 스크롤뷰가 움직일 여지 자체를 없애 실기기에서 최종 해결. 이 고정 과정에서 `body` 기본 마진 때문에 영상 하단·오른쪽에 흰 선이 보이던 것도 `margin: 0`·`inset: 0` 추가로 같이 수정.
* **홈 쇼츠: "응원 팀" 전환 시 안내 문구가 깜빡이던 것을 스켈레톤으로 교체**: `HomeViewModel.setShortsFilter`가 필터만 바꾸고 바로 알림을 쏴서, 응원팀 조회가 끝나기 전 중간 상태(`hasPreferredTeam=false`)가 "마이페이지에서 응원팀을 설정하면..." 안내로 그대로 그려졌다가 조회 완료 후 실제 결과로 바뀌는 깜빡임이 있었다. `shortsLoading` 플래그를 추가해 필터 전환~재조회 완료까지는 안내 대신 `_ShortsCard`와 같은 자리를 차지하는 스켈레톤 덱을 보여준다.
* **홈 순위표: "전체 경기" 링크를 월즈 전용에서 모든 리그로 되돌림**: 월즈 재비활성화(출시 보류) 작업 때 "전체 대진" 버튼을 `isWorlds` 조건부로 만들어 뒀는데, 월즈 칩이 다시 `live:false`라 이 버튼에 영원히 도달할 수 없었다. 리그와 무관하게 항상 보이는 "전체 경기" 버튼(경기 리스트로 이동)으로 되돌렸다. l10n 키를 `homeStandingsWorldsSeeAllBracket`에서 범용 `homeStandingsSeeAllMatches`로 교체.
* **홈 커뮤니티·평점 섹션 텍스트 크기 축소**: mockup.html 기준(`.post .ti` 14px, `.post .me` 11px, `.rv .c` 13.5px, `.rv .m` 11px)보다 커 보이던 글 제목·한줄평 본문(16→14)과 메타 텍스트(13→11)를 맞춰 줄였다.
* **홈 솔랭 폴링: 조회가 5초 넘게 걸리면 카드가 멈추고 요청이 쌓이던 버그 수정**: `Timer.periodic(5초)`가 이전 `_loadSolo()` 응답을 기다리지 않고 다음 틱을 쏘는 구조였다. 솔랭 API 응답이 폴링 간격(5초)보다 오래 걸리면, 다음 틱이 `_soloGen`을 먼저 올려 버려서 느리게 돌아온 응답까지 전부 "세대 불일치"로 버려지고 솔랭 카드가 갱신을 멈추는데, 동시에 5초마다 새 요청만 계속 쌓이는 문제가 있었다(CodeRabbit 리뷰 지적). `_soloPollInFlight` 플래그로 이전 조회가 끝나기 전엔 새 틱을 건너뛰도록 수정.
* **경기 리스트·필터: 데마시안컵(DEMACIA_CUP) 리그 아이콘 추가 + 알림 버튼 노출**: ASIAN_GAMES 추가 선례(2026-09-24/29)와 같은 패턴 — `assets/icons/leagues/demacia-cup.svg` 아이콘 추가, `lib/core/util/league_icon.dart`의 `_leagueIcons` 맵에 등록(경기 리스트 리그 헤더·필터 시트·경기 상세 Total Kills 영역이 모두 이 맵 하나를 공유해 재사용), `ApiConfig._allRealLeagueCodes`(league=ALL 펼침 목록)에도 추가해 이 리그만 있는 날 "오늘의 경기"가 조용히 비는 버그를 사전 차단. `MatchCard._isAlarmEligibleLeague` 화이트리스트(LCK·MSI·EWC·KeSPA·ASIAN_GAMES)에도 추가해 데마시안컵 경기에 알림 벨 버튼이 뜨게 함.
* **홈 순위표: 월즈(롤드컵) 카드 구현 — 스위스 전적 버킷 + 토너먼트 대진 (칩은 비활성 유지)**: 리그 테이블(`StandingsResult`)과 형식이 달라 전용 모델(`WorldsStandings`·`WorldsBracketRow`·`WorldsKnockoutRound`·`WorldsMatch`)을 새로 두고, warding-docs `features/home/mockup.html`의 `bodySwiss()`/`bodyTree()` 시안을 따라 스위스 스테이지 전적 버킷(3-0~0-3, 진출/탈락 색 구분)과 토너먼트 대진(8강→4강→결승, 라운드 간 브래킷 연결선·오늘 경기 강조·결승 그라디언트 테두리)을 카드 하단 버튼으로 전환하게 구현(`HomeViewModel.worldsView`/`toggleWorldsView`). 백엔드가 월즈를 지원하지 않고 포맷도 리그 테이블과 달라, `StandingsRepository.fetchWorldsStandings()`는 `HOME_MOCKS` 게이트 뒤의 목업만 반환한다. 코드는 완성했지만 **리그 칩은 출시 보류로 다시 `live: false`** — 사용자에게는 아직 안 보인다(LPL·LEC·LCS와 같은 비활성 점선 칩). 리그 칩 코드값은 `ApiConfig`의 리그 코드 체계와 맞춰 `'월즈'`에서 `'WORLDS'`로 변경해 뒀다(라벨은 한글 유지) — 나중에 켤 때는 `live: true`만 뒤집으면 된다.
* **홈 평점 한줄평: 독립 섹션 신설 + 백엔드 연동**: nar-back-repo#542 배포로 `GET /api/mobile/ratings/recent`가 열려 `ApiReviewSource`를 추가하고 `defaultReviewSource()` 기본값을 `EmptyReviewSource`에서 교체. 평점을 커뮤니티 섹션의 탭(최신/평점 토글)에서 떼어내 커뮤니티 섹션 바로 아래 독립 섹션(`HomeReviewSection`)으로 신설 — 커뮤니티와 같은 레이아웃(헤더 + 부제 "최신순" + `HomeListBox`, 커뮤니티 `_ListBox`를 공용화)을 쓰고 최대 5건만 보여준다(`HomeViewModel.reviews`). `HomeCommunitySort`에서 `review`를 제거하고 커뮤니티 기본 정렬은 `latest`로 바꿈. 한줄평이 없으면 `HomeReviewSection`이 섹션 전체(헤더 포함)를 그리지 않는다.

## 2026-10-02
* **홈 섹션 스켈레톤 UI**: 순위표·오늘 경기·오늘 끝난 경기(솔랭 카드 아래 칩 줄)·커뮤니티·평점 한줄평·뉴스에 첫 로드 스켈레톤을 추가했다. `HomeViewModel`에 섹션별 첫 로드 대기 플래그(`todayMatchesLoading`·`standingsLoading`·`communityLoading`·`reviewsLoading`·`newsLoading`)를 두고 실패해도 해제한다. 공통 `NarSkeleton` 컴포넌트 신설(기존 3개 스켈레톤은 그대로).

## 2026-09-30
* **쇼츠 앱 내 재생(전체화면 세로 피드)**: 카드 탭 시 유튜브 앱 대신 `ShortsFeedScreen`을 연다. `youtube_player_iframe` 추가(네이티브 → 스토어 릴리스 필요), `ShortsRepository.fetchShortsPage(page)`·`StoryVideo.channelProfileUrl` 추가, 무음·±1 WebView·오류 자동 스킵·필터(전체/내 팀). iOS 시뮬레이터 검증, Android·실기기 미확인.
* **홈 쇼츠: 내 선수 제거·응원팀 기반 내 팀·카드 10개·세로 썸네일**: `shorts-player-requirements` 결정안 3단계 반영. `HomeShortsFilter.player`·`matchedPlayer`·`_PlayerTag`·문자열 매칭을 걷어내고 "전체"는 순수 최신순, "내 팀"은 마이페이지 응원팀(`teamCode` 쿼리 + 응답 `teamCode`로 재확인)으로 바꿈. 카드는 10개, 썸네일은 `oardefault.jpg` 우선·서버 썸네일 폴백. `intent/youtube-shorts/intent.md` 갱신.

## 2026-09-29
* **홈 UI 다듬기 — 순위표·하단 네비·쇼츠·솔로 랭크 배지**: (1) 순위표 팀 로고를 키우고(28→직접 조정) 승-패·세트 득실 컬럼 사이 8px 간격 누락분 추가(mockup CSS 그리드 gap과 맞춤). (2) 하단 네비를 홈 화면에서도 다른 탭처럼 스크롤 시 축소되게 `BottomNavShrinkController` 연결, 활성 탭 칩의 `minWidth: 105` 고정폭 제거하고 패딩을 `vertical 12·horizontal 16`으로 변경. (3) 쇼츠 "전체/내 선수/내 팀" 필터 칩 간격을 8→6으로 좁힘(`NarChipMultiSelect`에 `gap` 파라미터 추가, 다른 칩 줄은 기본값 8 유지). (4) 쇼츠 영상 썸네일의 팀 코드 텍스트 배지("KT")를 팀 로고 이미지로 교체, 제목·조회수 텍스트를 조금 키우고 두껍게. (5) 솔로 랭크 카드의 "솔로 랭크"·"OO 플레이 중" 배지 점을 오늘 경기 LIVE 배지와 같은 1.2초 깜박임 애니메이션으로 통일 — `NarLiveDot`에 `color` 파라미터를 추가해 재사용(기존 정적 `_Dot` 제거).
* **홈 오늘 경기: 새 리그(ASIAN_GAMES) 낀 날 섹션 통째로 사라지던 버그 수정**: `league=ALL`을 실제 리그 코드로 펼치는 `ApiConfig._allRealLeagueCodes`가 하드코딩 목록이라 백엔드에 새로 추가된 `ASIAN_GAMES`를 못 따라가 빠져 있었다. 그 리그 경기만 있는 날(2026-09-29)은 홈 "오늘의 경기"가 항상 빈 걸로 나왔다 — 목록에 추가해 해결. 배지에 `ASIAN_GAMES...` 원본 코드가 그대로 잘려 보이는 표시 문제는 별도(미결 항목에 기록).
* **홈 솔랭: 진행 중 0명 + 끝난 경기 있음일 때 조용한 행이 사라지던 것 수정**: 스펙 변경(아래 항목)을 처음 구현할 때 조용한 행을 끝난 경기 줄로 통째로 대체했는데, "조용한 행이 없어지면 안 된다, 위에 그대로 뜨고 그 아래에 끝난 경기 줄이 이어져야 한다"는 피드백으로 두 UI를 함께 보여주도록 수정.
* **홈 끝난 경기 줄: 선수 사진·"+N명" 칩 제거**: 원형 아바타를 팀 로고(`TeamCodeBadge`)에서 선수 사진(`playerImageUrl`, `_Face` 재사용)으로 바꿈. `HomeFinishedSoloPlayer`·`ApiSoloRankSource._finished()`에 `playerImageUrl` 추가. 소식 없는 선수 수를 알려주던 "+N명" 칩(`_HiddenCountChip`)은 없앰 — 실제로 끝난 경기가 있는 선수 칩만 보여줌. `spec.md` "결정"에 반영.
* **홈 솔랭 카드 잔손질**: 큰 카드의 경과 시간을 서버 `startedAt` 기준으로 매초 기기 시계 카운트업(`HomeSoloRankSection`의 1초 타이머). 카드 테두리를 `foregroundDecoration`으로 맨 위에 그려 챔피언 스플래시·선수 사진에 가려 끊겨 보이던 문제 수정. 선수 사진을 시안(`mockup.html` `.hero .ph`, 176×214)만큼 키움.
* **홈 오늘 경기 없을 때 간격 두 배 버그 수정**: `HomeTodayMatchesSection`이 오늘 경기 0건이면 통째로 사라지는데 앞뒤 `SizedBox(28)`가 둘 다 남아 순위표 위 간격이 두 배였다. 섹션과 그 앞 간격을 묶어 같이 없앰.
* **홈 솔랭: 진행 중 0명이어도 끝난 경기가 있으면 보여줌(스펙 변경)**: 원래 진행 중 0명이면 무조건 한 줄 조용한 행이었는데, 그 안의 "마지막 경기" 텍스트가 잘리는 문제를 고치다 보니 끝난 경기 목록 자체가 아예 안 보인다는 피드백으로 이어짐. `soloState`를 "진행 중·끝난 경기 둘 다 0명일 때만 noneActive"로 바꾸고, 진행 중 0명 + 끝난 경기 있음이면 큰 카드(스와이프) 없이 끝난 경기 줄(+N명·구독 전체)부터 보여줌. 조용한 행의 "마지막 경기" 보조 텍스트는 이제 도달 불가라 제거. `spec.md` "상태" 표·"결정"에 반영.
* **홈 → 내 선수 뒤로가기 시 솔랭 새로고침**: 홈은 앱 복귀(30초 스로틀)에만 새로고침돼서, 내 선수 화면에서 선수 상태가 바뀐 걸 보고 돌아와도 홈은 그 이전 스냅샷을 유지했다. `HomeViewModel.refreshSoloOnReturn()` 추가, `_openMyPlayers`가 알림함과 같은 방식(`await push` 뒤 targeted 새로고침)으로 호출.

## 2026-09-27
* **홈 솔랭·뉴스 백엔드 연결**: `ApiSoloRankSource`(`/api/mobile/me/solo-rank`)·`ApiNewsSource`(`/api/home/news`)를 기본 소스로. `HOME_MOCKS` 기본값을 꺼짐으로 바꿈. 평점 한줄평은 백엔드 #542 배포 전이라 빈 소스 유지. 커뮤니티 인기순 칩 제거. [홈](/features/home.md) 갱신.
* **홈 오늘 경기 "일정 전체" 중복 제거**: 헤더 링크와 스트립 마지막 카드가 같은 화면에 두 번 보이던 걸 헤더 링크 하나로 정리. 경기가 없으면 섹션 전체를 숨김. `ScheduleRepository`에 `resetCacheForTesting()` 추가(테스트 간 날짜별 캐시 오염 방지).
* **홈 솔랭 조용한 행에 선수 얼굴**: 솔랭 중인 선수가 없을 때 구독 선수 사진 4명을 겹쳐 보이고(넘치면 +N), 글은 구독 수 / 마지막 경기 두 줄로 나눔(시안 `.quiet`).
* **홈 오늘 경기 카드 시안 반영**: `mockup.html`의 `.mc` 기준으로 재작성 — 로고 24(원 없는 `TeamLogo`, 로고 없으면 둥근 네모에 코드), 코드 14·점수 16, 진 팀 흐림, LIVE 배지에 깜박이는 점, 카드 높이 110.
* **홈 뉴스 썸네일**: `HomeNewsArticle.hasThumbnail`을 `thumbnailUrl`로 바꾸고 뉴스 행에 기사 썸네일 이미지를 그림(없으면 빈 자리).
* **홈 팀 배지 로고화**: `TeamCodeBadge`가 팀 코드 텍스트 대신 로고 이미지를 그림. 코드만 오는 자리는 `TeamLogoDirectory`로 조회, 실패 시 텍스트 폴백.

## 2026-09-24
* **홈 화면 완료(spec v29)**: 홈이 앱 진입 화면이 됨(스플래시·로그인·온보딩 완료 → `HomeScreen`). 솔랭·오늘 경기·순위표·커뮤니티·콘텐츠 5섹션과 내 선수 화면 추가. 솔랭·평점·뉴스는 목업(`SoloRankSource`·`ReviewSource`·`NewsSource`), 백엔드 대기.
* **Creation**: [홈](/features/home.md) 개념 문서 추가.
* **홈 최종 리뷰 수정**: 솔랭·평점·뉴스 목업을 `HOME_MOCKS` 게이트(기본값 `kDebugMode`) 뒤로 옮김 — 릴리즈 빌드는 빈 소스, 빈 뉴스·한줄평이면 해당 탭을 숨김. 순위 칩·쇼츠 sort 문구 정정.
* **홈 새로고침·탭 전환**: 앱 복귀 시 새로고침(30초 스로틀)과 섹션별 최신 응답 우선 가드 추가. "커뮤니티 전체"가 탭 루트를 쌓지 않게 `pushReplacement`로 변경.
* **솔랭 분류 공용화**: 홈 솔랭 항목을 실제 구독 선수로 거르고, 홈·내 선수 화면이 `SoloRankClassification`(`solo_rank_rules.dart`) 하나를 쓰도록 통일.
* **홈 잔손질**: 배너 닫기 경쟁 조건 수정, 쇼츠 팀 매칭을 낱말 경계로, 쇼츠는 https 주소만 연다, 오늘 경기 LIVE 판정을 `isLiveMatchStatus`로, `SoloRankSnapshot.subscribedTotal` 제거, 내 선수 줄 key 를 playerId 로.

## 2026-06-22
* **#11 완료**: 비회원 온보딩 로컬 저장 + 로그인 동기화. `OnboardingSelection` 모델·`OnboardingPreferenceRepository`·`OnboardingSyncService` 추가, `OnboardingViewModel`·`login_screen` 연동.

## 2026-06-21
* **Initialization**: warding 프로젝트 지식 번들 생성 (OKF v0.1).
* **Creation**: [개요](/overview.md), [아키텍처](/architecture/), [디자인](/design/), [기능](/features/), [플레이북](/playbooks/), [레퍼런스](/references/) 디렉토리 구성.
* **Note**: 진행 상황·TODO는 [GitHub 프로젝트 보드](/references/github-project.md)와 [CLAUDE.md](../CLAUDE.md)를 단일 출처로 한다.
* **Automation**: `gen_viz.py`(시각화), `sync_github.py`(보드→`references/github-project.md` 동기화) 추가. `.md` 편집 시 viz 자동 재생성(훅), `/sync-github`로 보드 갱신.
