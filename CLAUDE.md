# Warding 모바일 앱 - 개발 가이드

LCK 등 e스포츠 팬을 위한 Flutter 앱이다.

이 레포에 흩어진 문서 시스템 전체 지도는 [INDEX.md](./INDEX.md)를 참고한다.
새 기능을 시작할 때 의도·설계를 먼저 남기려면 [intent/](./intent/) 워크플로우를 쓴다.
단, warding-docs에 spec이 있는 기능은 intent를 만들지 않는다(기획 의도·제품 결정·미결이 거기 있다).
intent는 warding-docs에 없는 개발 쪽 작업(버그·리팩터링·CI 등)에 쓴다
(진입 기준은 `intent/loop-engineering-workflow/spec.md`의 "저장 구조" 표 참고. 모든 작업에
강제되지는 않는다).

## 한국어 문서 작성 지침

이 저장소를 여는 Claude Code 세션에는 `.claude/settings.json`의 `outputStyle`로
[fluent-korean](https://github.com/snflkd/fluent-korean)이 강제 적용된다. GitHub Actions가
Anthropic API를 직접 호출해 문서를 생성하는 `intent-autodraft.yml`, `spec-autodraft.yml`,
`ci-flutter-test.yml`, `e2e-release-check.yml`은 이 설정이 닿지 않으므로, 각 프롬프트에
지침 요약을 별도로 심어 뒀다. 프롬프트를 수정할 때 fluent-korean 원문과 어긋나지 않게 한다.

## 아키텍처: MVVM

상태와 로직은 ViewModel에, UI는 View에 둔다.

- **Model** (`model/`, `repository/`): 데이터 모델 클래스와 데이터 소스(API).
- **ViewModel** (`viewmodel/`): `ChangeNotifier`를 상속한다. 화면 상태와 비즈니스 로직을 담당하고 `notifyListeners()`로 변경을 통지한다.
  - `BuildContext`에 의존하지 않는다.
  - 화면 전환은 생성 시 주입받은 콜백(`onFinish` 등)으로 View에 위임한다.
- **View** (`screens/`): UI만 담당한다.
  - `ListenableBuilder`로 ViewModel을 구독한다.
  - 사용자 이벤트는 ViewModel 메서드 호출로 위임한다.
  - 화면 전환(`Navigator`)만 View에서 직접 처리한다.

예) 온보딩: `OnboardingViewModel`(ChangeNotifier)이 단계 이동·선택·권한 상태를 갖고,
`onboarding_screen.dart`와 `step/*` 위젯은 이를 구독해 렌더링만 한다.

## 폴더 구조

**feature 단위 구조다.** 기능별로 `data`·`domain`·`presentation` 세 레이어를 한 폴더에
모은다. 이전에는 레이어가 최상위 축(`model`·`repository`·`viewmodel`·`screens`)이어서
한 기능을 작업할 때 네 군데를 오가야 했다.

**규칙은 한 문장이다 — 기능 소유면 `features/`, 아니면 `core/`.**

```
apps/mobile/lib/
├── features/     기능별 32개
│   └── {기능}/
│       ├── data/           repository, API 예외, 그 기능 전용 DTO
│       ├── domain/         모델, 규칙·상수
│       └── presentation/
│           ├── screens/    화면 (멀티스텝은 step/, guide 는 page/)
│           ├── viewmodels/ ViewModel
│           └── widgets/    그 화면 전용 위젯
├── app/          앱 셸 — 기능 2개 이상의 화면·구현을 알아야 하는 코드
│   ├── deeplink/           외부(푸시·홈 위젯) → 앱 진입
│   ├── navigation/         화면 이동 (경기 상세 창구, 탭 전환)
│   ├── di_container.dart   인터페이스 ↔ 구현 등록
│   └── app_hooks.dart      core 에 비워 둔 자리를 채우는 조립
├── core/         기술만 — 도메인 개념이 없다
│   ├── ui/                 앱 전역 공용 위젯 48개
│   ├── util/               순수 함수·포맷터 17개
│   ├── config/             앱 설정 (API URL, 키 등)
│   ├── error/              Failure 계층, API 상태 예외
│   ├── theme/              디자인 토큰 (app_colors)
│   └── data/               예외 → Failure 매퍼
├── l10n/         생성물 (아래 참고)
├── main.dart     진입점
└── firebase_options.dart   생성물
```

**레포 루트는 `apps/` + `packages/` 표준 모노레포다.** 2026-11-17 에 Flutter 를 루트에서
`apps/mobile/` 로 내렸다 — 그 전에는 Flutter 가 루트를 차지하고 Node 쪽만 하위 폴더에
있는 비대칭 구조여서, 앱이 둘인데 한쪽만 특별 대우를 받았다.

```
warding-mobile-repo/
├── apps/
│   ├── mobile/                      Flutter 앱 (lib · ios · android · test · assets)
│   └── web/                         웹뷰용 Next.js 앱
├── packages/
│   ├── design-tokens/               토큰 단일 출처 (값)
│   │   ├── source/{common,theme}.json   사람이 고치는 곳
│   │   ├── build/                   생성물 (tokens.css · app_colors.dart)
│   │   ├── build.mjs                Dart·CSS 생성기
│   │   └── sync-dart.mjs            생성된 Dart → apps/mobile 복사
│   ├── ui/                          웹 공용 React 컴포넌트
│   │   └── src/                     빌드 없이 소스를 내보낸다 (Next 가 컴파일)
│   └── api/                         웹용 API 클라이언트
│       └── src/                     Result<T> 반환, 매퍼 + 회귀 테스트
├── tools/                           운영 스크립트 (api 스펙 동기화 등)
│   └── discord-bridge/              npm 으로 독립 운영 (워크스페이스 밖)
├── wiki/ · intent/ · distribution/  문서
├── turbo.json                       태스크 러너
└── pnpm-workspace.yaml              apps/* · packages/*
```

**Flutter 명령은 `apps/mobile/` 에서 돌린다.** `fvm flutter test` 를 루트에서 돌리면
pubspec 을 못 찾는다. 워크플로우도 그 스텝들에 `working-directory: apps/mobile` 이 붙어
있다(13곳).

`apps/mobile/lib/core/theme/app_colors.dart` 는 **생성물이다.** 색을 바꾸려면
`packages/design-tokens/source/theme.json` 을 고치고 `pnpm tokens:build` 를 돌린 뒤 둘 다
커밋한다 — CI(`ci-tokens.yml`)가 재생성해서 diff 가 비었는지 본다.

**토큰 생성은 2단계다 — `build` 와 `sync:dart`.** turbo 의 `outputs` 는 패키지 밖을
캐시하지 못한다. 생성기가 `apps/mobile/` 에 Dart 를 직접 쓰면, 캐시 적중 시 그 파일이
복원되지 않는데 turbo 는 `FULL TURBO` 로 성공을 보고한다(실측으로 재현했다). 그래서
생성은 패키지 안 `build/` 에 하고 — 그건 캐시된다 — Flutter 트리로의 복사만
`cache: false` 로 매번 돈다. `build/app_colors.dart` 를 커밋하는 이유도 이것이다(캐시
앵커). 이 함정은 눈에 보이지 않으므로 `.github/workflows/turbo-cache-test.sh` 가 PR마다
회귀 검증한다.

**태스크 러너는 turbo 다.** `pnpm build` 가 토큰 → 웹 순서를 보장한다 —
`apps/web` 이 `warding-design-tokens` 를 `workspace:*` 로 의존 선언해서 그래프가 잡힌다.
Flutter 는 turbo 그래프 밖이다(Dart 를 모른다). `pnpm typecheck` 도 같은 그래프를 탄다.
`packages/` 에 JS 패키지가 더 쌓이고 서로 import 하기 시작하면 Nx 를 재검토할 지점이지만,
지금은 turbo 로 충분하다.

**`packages/ui` 는 빌드하지 않는다.** 소스(`.tsx`)를 그대로 내보내고 Next 가
`transpilePackages` 로 컴파일한다 — 패키지마다 번들러를 두면 토큰 → UI → 웹으로 단계가
늘고, 그 중간 산출물을 또 캐시 앵커로 관리해야 한다(토큰 쪽에서 겪은 문제다).

**`packages/` 는 `design-tokens`(값) + `ui`(React 컴포넌트) 둘이다.**
웹뷰 전환이 **웹 중심**(목록·상세·폼까지 웹, Flutter 는 셸만)이라, 화면이 옮겨가는
만큼 `packages/ui` 가 점점 **진짜 단일 구현**이 된다. 지금은
`Badge`·`BoardBadge`·`Button`·`CommonButton`·`DetailHeader` 5개가 있다.

**`packages/ui` 는 `core/ui/` 의 짝이다.** Dart 원본이 `core/ui/` 면 올리고,
`features/*/presentation/widgets/` 면 올리지 않는다 — 한 기능 전용 위젯을 공용
자리에 두지 않는 규칙이 웹에서도 그대로다. 커뮤니티 목록의 `PostListItem` 이
`_pages/community-list/ui/` 에 있는 이유가 이것이다(Dart 원본이
`features/community/presentation/widgets/post_list_item.dart` 다).

**`packages/` 는 TS 전용이다. Flutter 는 `packages/ui`·`packages/api` 를 못 읽는다.**
Dart ↔ TS 가 실제로 공유하는 것은 `design-tokens` 의 **값**뿐이고, 그것도 코드가
아니라 JSON 한 벌에서 각 언어로 생성한 산출물이다. 포맷터·컴포넌트·브리지 규약은
전부 **복제**이고 주석으로 짝을 묶는다. 조사한 공개 레포 중 Flutter+Next 가
한 레포에 공존하는 곳은 2건 찾았지만(`tutur3u/platform`·`MITOM06/platform`),
**둘 다 `packages/` 에 Dart 가 읽는 것이 0개였다** — 패키지 레벨 공유까지 간
선례를 찾지 못했다.

**`packages/api` 는 웹 전용이다.** Flutter 와 타입을 공유하지 않는다 — 코드생성을
쓰지 않아(`pubspec.yaml` 에 openapi·json_serializable·freezed 가 없다) 스키마 254개를
Dart 로 뽑을 경로가 없다. 대신 **Dart 쪽 모델의 널 판단을 복제한다** — 같은 응답에서
두 플랫폼이 다른 화면을 그리면 안 되기 때문이다.

- `Result<T>` 를 돌려준다. Flutter 의 `Either<Failure, T>` 와 같은 계약이고,
  `Failure` 분류(`server`·`network`·`parse`·`unauthorized`·`noData`)도 같다.
- **OpenAPI 스펙의 `required` 를 그대로 믿지 않는다.** 커뮤니티 글 상세는 스펙상
  required 가 0개지만 실제로는 대부분 온다. Dart 모델이 실전 기준으로 정해 둔 널
  여부를 따르고, 어긋나면 매퍼 테스트가 잡는다.
- **매퍼 회귀 테스트가 PR마다 돈다**(`pnpm test`). 타입 체크는 런타임 응답을 보지
  않아서, `viewer` 를 null 가능으로 잘못 설계한 것을 실측 응답으로 잡았다.

**웹(`apps/web`)은 FSD 를 쓴다.** 구조는
[FSD 공식 Next.js 가이드](https://feature-sliced.design/docs/guides/tech/with-nextjs)를
따른다.

```
apps/web/
├── app/                  Next 라우트. 화면을 re-export 만 한다
└── src/
    ├── _pages/{화면}/
    │   ├── index.ts      공개 API
    │   └── ui/           화면 컴포넌트
    └── shared/           웹 전용 공용 코드 (브리지 등)
packages/ui               여러 화면이 쓰는 공용 컴포넌트
packages/api              서버 호출 + 도메인 타입 + 매퍼
```

- **`_pages` 의 밑줄은 공식 권장이다.** 공식 문서가 경고 박스로 못박는다 —
  "쓰는 라우터와 무관하게 `app`·`pages` FSD 레이어를 **둘 다** `_app`·`_pages` 로
  바꿔라." 공식 린터(Steiger)도 그 이름만 인식하므로 **`views`·`screens` 로 바꾸면
  안 된다.** 회피책 3개(루트 `pages/`, 라우트를 `src/app` 으로 이동,
  `pageExtensions`)를 실측했고 **전부 빌드가 깨진다** — 근거는
  [`_pages/README.md`](./apps/web/src/_pages/README.md).
- **세그먼트는 목적별(`config`·`layout`·`styles`·`api`·`model`·`lib`), 종류별
  (`components`·`hooks`·`providers`) 금지.** `_app/ui/` 를 만들었다가 린터가
  잡았다 — `app` 레이어에는 `ui` 세그먼트를 두지 않는다.
- **`steiger` 가 PR마다 레이어 규칙을 검증한다**(`pnpm lint:fsd`). 자동 검증이
  없으면 규칙은 반드시 썩는다.
- **서버 전용 코드는 `index.server.ts` 로 가른다.** 한 슬라이스에 클라이언트·서버
  모듈이 섞인 채 `index.ts` 하나로 내보내면, 클라이언트 컴포넌트가 그걸 import 하는
  순간 서버 전용 사이드이펙트가 클라이언트 번들로 번진다. `packages/api` 는
  `warding-api`(타입·순수 함수) ↔ `warding-api/server`(fetch) 로 갈라져 있고,
  서버 쪽에 `import 'server-only'` 가 걸려 **실수하면 빌드가 깨진다**(실측 확인).
- **`export *` 를 쓰지 않는다.** 무엇이 공개되는지 `index.ts` 만 보고 알 수 있어야
  하고, 내부 구현이 늘 때 조용히 새지 않는다.
- **`app/` 은 루트에 남긴다.** `src/app` 으로 내리면 Next 15 가 타입 검증기
  상대경로를 잘못 생성한다(실측).
- **라우트는 re-export 한 줄이다** —
  `export { CommunityPostPage as default } from '@/_pages/community-post';`
  조립을 라우트에 두면 `app/` 이 다시 두꺼워진다.
- **`entities` 레이어를 두지 않는다.** 서버 응답을 아는 코드를 `packages/api`
  한 곳에 모은다 — 타입(`types.ts`)과 매퍼(`mappers.ts`)가 붙어 있어야 서버
  형식이 바뀔 때 한 군데만 고친다.
- **`widgets` 는 "도메인을 아는 재사용 UI" 자리다.** 화면 2개 이상이 쓰면서
  서버 타입(`PostSummary` 등)을 아는 컴포넌트는 여기다 —
  `widgets/post-card` 가 목록·검색 양쪽에 쓰인다.
- **`shared` 에 도메인 타입을 넣지 않는다.** 한 번 어겼다가 되돌렸다 —
  카드를 `shared/ui` 에 뒀더니 그 레이어가 커뮤니티 글 구조를 알게 됐고,
  화면이 늘수록 모든 도메인을 아는 레이어가 된다. **steiger 는 이걸 잡지
  않으므로** 사람이 봐야 한다. 업로드 유틸처럼 구조만 같으면 되는 것은
  서버 타입을 import 하지 말고 **전송 규격을 따로 적는다**
  (`CloudinarySignature`).
- **`features` 는 아직 없다.** 필요해질 때 만든다.
- `packages/ui` 로 올리는 기준은 **화면 2개 이상 + Dart 원본이 `core/ui/`**.
  Dart 원본이 기능 폴더 안이면 `widgets` 로 간다.

**명령은 루트 `pnpm` 으로 모은다.** Flutter 는 `pubspec.yaml` 에 스크립트
섹션이 없어서(`package.json` 의 `scripts` 같은 것이 없다) 셸 스크립트를 쓰는데,
웹은 `pnpm` 이고 앱만 다른 곳이면 명령을 두 군데서 찾게 된다.

```bash
pnpm web:dev      # 웹 (로컬 Next 서버, 3100) — 고치면 즉시 반영
pnpm web:prod     # 웹 (프로덕션 빌드, 3100) — 실제 속도 확인용
pnpm app:local    # 앱 — 웹뷰가 로컬 서버를 본다
pnpm app:prod     # 앱 — 배포된 웹 (기본값)
```

**체감 속도를 볼 때는 `web:dev` 를 쓰면 안 된다.** dev 서버는 번들을 쪼개지
않고 HMR·소스맵을 전부 싣는다 — 실측(2026-11-20) 같은 화면이 **dev 1,899KB /
prod 111KB** 로 **17배** 차이였고 로드도 423ms 대 75ms 였다. "웹뷰가 느리다"
는 판단을 dev 에서 내리면 엉뚱한 곳을 고치게 된다.

`web:prod` 는 빌드까지 한 번에 하고, 포트가 막혀 있으면 **누가 쓰는지 보여
주고 물어본다**(직전에 띄운 dev 서버가 범인인 경우가 많은데 `EADDRINUSE`
스택만으로는 알 수 없다). 대신 **고쳐도 반영되지 않는다** — UI 를 반복해
고칠 때는 `web:dev` 다.

`app:*` 은 `apps/mobile/tool/run.sh` 로 위임만 한다 — Flutter 는 turbo 그래프
밖이라(Dart 를 모른다) 캐시 이득이 없다. `apps/mobile/` 안에서 작업 중이면
`./tool/run.sh local` 을 직접 불러도 같다.

**flavor 를 쓰지 않는다.** 조사한 실제 앱 8개 중 dev/prod 분리에 flavor 를 쓴
곳은 0개였고, flavor 를 쓰는 3개(aves·Musify·ente)는 전부 **번들ID가 갈리는
배포 채널**(Play/F-Droid) 문제였다 — aves 는 dimension 이름이 아예 `"store"` 다.
flavor 를 넣으면 `shorebird release`·`patch` 네 곳에 `--flavor` 를 붙여야 하고
**그건 태그를 밀어야 검증된다.** 대신 Flutter 공식 CD 문서가 권하는
`--dart-define` 을 쓴다 — `HOME_MOCKS` 가 이미 그 축이고, **기본값이 운영이라
플래그를 빼먹어도 안전하다.**

판별 기준 한 줄: **두 버전이 한 기기에 동시에 설치돼야 하면 flavor, 아니면
`--dart-define`.**

**웹 ↔ 네이티브 브리지는 Stage A·B·C 를 전부 쓴다.** 규약을 양쪽에 짝으로 둔다 —
`apps/web/src/shared/bridge/protocol.ts` ↔
`apps/mobile/lib/app/bridge/bridge_protocol.dart`. **코드 생성이 없으므로 한쪽을
고치면 반드시 다른 쪽도 본다.**

**웹은 즉시 배포되고 앱은 업데이트를 기다린다 — 그래서 능력 목록을 쓴다.**
새 브리지 메시지를 웹이 쓰기 시작하면 구버전 앱은 그걸 모른다. 네이티브가
`kBridgeCapabilities` 로 처리 가능한 메시지를 선언하고, 웹은 `isSupported()`
로 물은 뒤 **아니면 자체 구현으로 그린다**(Hotwire Native·토스·당근
metabridge·Capacitor 가 모두 이 모양이고, **메서드명에 `v2` 를 붙이는 곳은
없었다** — 판정 단위는 메서드다).

- **기본값은 웹 폴백이다.** 모르면 `isSupported()` 가 false 라 구버전 앱도
  새 웹도 안전한 쪽으로 떨어진다. `share` 가 그 선례다 — 네이티브에 구현이
  없어 선언하지 않는다.
- **메시지를 추가하면 `kBridgeCapabilities` 에도 추가한다.** 빠뜨리면 웹이
  미지원으로 보고 폴백을 그린다(조용히 깨지는 것보다 낫지만 기능은 안 나간다).
- **버전 문자열로 분기하지 않는다.** `appVersion` 은 로그·문의 대응용이다 —
  `1.0.9` vs `1.1.0` 처럼 자릿수를 독립 비교하다 틀리는 사고가 흔하다.
- **모르는 Stage A 메시지는 `unsupported` 로 웹에 되돌린다.** 전에는 조용히
  삼켜서, 웹은 보냈다고 믿고 사용자는 버튼이 안 먹는 이유를 몰랐다.

- **인증 토큰은 쿠키로 넘긴다.** 네이티브가 `WebViewCookieManager` 로 심고 Next
  서버가 `cookies()` 로 읽는다 — **첫 요청부터 토큰을 들고** API 를 불러 로그인
  상태까지 SSR 로 그려진다. URL 쿼리는 로그에 남고, 로드 후 JS 주입은 깜빡인다.
  `webview_flutter` 쿠키 API 에 `httpOnly` 가 없어 JS 로 읽히는 것이 한계다.
- **로그인 상태에서는 캐시하지 않는다**(`cache: 'no-store'`). `viewer` 가
  사용자마다 달라 공유 캐시에 담으면 남의 좋아요 상태가 보인다.
- **웹뷰 컨테이너는 하나다**(`core/ui/webview/`). 기능별로 복제하면 URL 만 다른
  파일이 수십 개가 된다. 어느 화면이 웹으로 갔는지는
  `app/navigation/webview_routes.dart` 가 단일 출처다.
- **탭 화면은 `app/bridge/webview_tab_screen.dart` 를 쓴다.** 하단 네비를
  네이티브가 그려 얹는다 — 웹뷰가 탭까지 그리면 두 겹이 되고, 탭 전환이 웹
  라우팅이라 다른 탭으로 못 간다. push 로 열리는 화면(상세·공지)은
  `WebViewScreen` 을 그대로 쓴다.
- **웹으로 간 화면의 네이티브 코드는 지우지 않는다.** 커뮤니티가 웹뷰로
  갔지만 `features/community/presentation/` 은 남아 있다 — 웹 배포가 막혔을
  때 `tab_navigation.dart` 의 분기만 되돌리면 복귀한다. 전환이 안정된 뒤에
  지운다.
- **쿠키를 심기 전에는 로드하지 않는다.** 토큰 없이 로드되면 SSR 이 비로그인
  화면을 그려 버려 전환의 이점이 사라진다.

**`packages/ui` 를 쓸 때 걸린 함정 3개를 적어 둔다 — 전부 빌드는 통과하고 실행해야
드러난다.**

| 함정 | 증상 | 규칙 |
|---|---|---|
| `calc(34px * var(--scale))` | 선언이 통째로 무효. 콘솔도 조용하다 | `--scale` 이 px 단위다. **단위 없이** `calc(34 * var(--scale))` |
| 서버 컴포넌트가 `onClick` 전달 | 런타임 500 `Event handlers cannot be passed` | 경계는 **호출부**에 둔다. 라이브러리에 `'use client'` 를 붙여도 안 풀린다 |
| 전역 `* { padding: 0 }` | 버튼 높이·여백이 무너진다 | `@import` 는 맨 앞으로 끌어올려지므로 순서로 못 이긴다. **리셋을 좁힌다** |

**빌드 타깃은 iOS·Android 뿐이다.** `windows/`·`linux/`·`macos/`·`web/` 은 `flutter
create` 가 만든 템플릿이었고 빌드에 쓰이지 않아 2026-11-17 에 지웠다. 다시 필요하면
`flutter create --platforms=<target> .` 로 되살린다.

**`domain/` 이 최상위인 이유.** 도메인 모델은 앱의 중심이라 기술 인프라(`core/`) 안에
종속되지 않는다. Flutter 공식 샘플 compass_app 의 `lib/domain/models/`, Immich 의
`lib/domain/models/`, nowinandroid 의 `core:model` 모듈과 같은 배치다. 조사한 실제 앱 5개 중
4개가 "여러 기능이 쓰는 도메인 모델을 공유 위치에 올린다" — `schedule_match` 가 6개 기능이
쓰면서도 `features/schedule/` 안에 없는 근거가 이것이다(compass_app 도 4개 화면이 쓰는
`ItineraryConfig` 를 `search_form` 안에 두지 않고 `domain/models/` 로 올렸다).

**의존 방향은 `app → features → core`·`domain` 한 방향이다.** `core/`·`domain/` 은
`features/`·`app/` 을 import 하지 않는다 (유일한 예외는 조립 지점인 `core/di_container.dart`
다 — repository 구현체를 등록하려면 알 수밖에 없다). `domain/` 은 `features/`·`app/` 을
import 하지 않는다 — 모델이 기능을 알면 방향이 뒤집힌다 (repository 인터페이스가 쓰는
`core/error/failure.dart` 는 예외다). 화면을 띄우거나 기능의 구현을 알아야 하는
코드는 둘 중 하나로 푼다.

- **앱 셸이면 `app/` 에 둔다. 판별은 한 줄 — "기능 2개 이상의 화면이나 구현을 알아야 하나".**
  푸시·홈 위젯 딥링크(`app/deeplink/`), 경기 상세로 가는 유일한 창구와 탭 이동
  (`app/navigation/`)이 여기 있다. 라우터·탭 네비게이션을 앱 셸에 두는 것은 조사한 실제
  앱 4개가 예외 없이 따르는 관행이다(nowinandroid `app/navigation/`, compass_app
  `lib/routing/`, Immich `lib/routing/`, AppFlowy `lib/startup/tasks/`).
- **화면을 안 띄우면 `app/` 이 아니다.** 기능 repository 를 쓰더라도 화면을 만들지 않으면
  그 도메인의 기능으로 내린다 — `live_activity_logo_prefetcher`·
  `live_match_activity_controller` 가 `features/live_activity/data/` 로 갔다.
- **core 가 필요로 하는 화면·구현은 훅으로 받는다.** `AuthService.loginScreenBuilder`·
  `AuthService.onSignedOut`·`TeamLogoDirectory.defaultLoader`·
  `LiveActivityLogoPrefetcher.teamTargetsLoader`·`LiveMatchActivityController` 의 로더 4개는
  core 쪽에 비워 둔 자리고, `app/app_hooks.dart` 의 `configureAppHooks()` 가 `main.dart`·
  `test/flutter_test_config.dart` 에서 채운다(둘 다 `apps/mobile/` 아래다). 새 훅을
  만들면 거기에 연결하는 것을 잊지 않는다. **훅이 비어 있을 때의 동작을 정해 둔다** — 화면 전환은 건너뛰고, 카드 정리는
  "모른다" 로 보고 멈춘다(잘못 지우는 것이 늦게 지우는 것보다 비싸다).
- 한 기능 전용 위젯은 `core/ui/` 에 두지 않는다 — `guide_popup` 은 `guide`, `cheer_ad_*` 는
  `cheer_ad` 가 소유한다.

**`core/` 밖에 남는 예외는 생성물과 진입점이다.** 생성물은 생성 도구가 경로를 정하므로
옮겨도 도구가 원래 자리에 다시 만든다.

| 대상 | 경로를 못박는 설정 |
|---|---|
| `apps/mobile/lib/l10n/` | `apps/mobile/l10n.yaml` 의 `arb-dir`·`output-dir` |
| `apps/mobile/lib/firebase_options.dart` | `apps/mobile/firebase.json` 의 `flutter.platforms.dart` 키 |

`firebase.json` 은 FlutterFire CLI 가 관리하므로 손으로 고치지 않는다.

**`core/` 에 도메인 개념을 두지 않는다.** 소비처가 몇 곳이든 "경기·팀·선수·알림·인증"
같은 이름이 붙으면 그 도메인의 기능으로 간다. 2026-11-16 에 `core/domain/`(모델 9) 과
`core/infrastructure/`(21파일) 를 전부 해체했다 — 폴더 이름뿐 아니라 내용도 도메인이었다
(알림 피드 API·잠자기 설정·실시간 카드·선호 팀 저장).

| 원래 위치 | 간 곳 | 이유 |
|---|---|---|
| `infrastructure/auth` + `device` + `domain/user_profile` | `features/auth/` | 상호 참조라 한 묶음. 20기능이 쓰지만 도메인이다 |
| `infrastructure/notification` 4 + 모델 4 + 인터페이스 2 + `fcm_notification_types` | `features/notification/` | 알림 도메인 |
| `infrastructure/live_activity` 4 | `features/live_activity/` | 실시간 카드 도메인 |
| `infrastructure/preference` 7 + `ad` | 각 소유 기능 | cheer_ad·guide·calendar_setting·notice·match_list_setting·schedule·onboarding |
| `domain/schedule_match`·`team`·`calendar_week_start`·`team_notification_subscription` | 각 소유 기능 | — |

**`core/` 에 남는 것은 기술뿐이다.** `ui`(공용 위젯 48) · `util`(순수 함수·포맷터 17) ·
`config` · `error`(Failure·API 상태 예외) · `theme` · `data`(예외→Failure 매퍼).

- **순수 함수·포맷터는 도메인 이름이어도 `core/util/` 이다.** `match_status(String)` 는
  문자열 판정이고 `rating_mapping` 은 수치 변환이다 — 모델도 repository 도 없어서 성격이
  다르다. 단 1기능만 쓰면 내린다(`dragon_type`·`gold_format`·`live_elapsed`·
  `standings_group_label`).
- **공용 위젯은 도메인 이름이어도 `core/ui/` 다.** `team_logo`·`team_code_badge` 는 "팀
  로고를 그리는 위젯"이고, `team_logo_directory` 는 그 위젯이 쓰는 URL 캐시다.
- **이름이 같은 기능이 있으면 그 기능 소유로 본다.** `rating` repository 는 4곳이 쓰지만
  `player_rating` 기능이 있어 `features/player_rating/data/` 에 둔다.
- **`home` 은 소비처로 세지 않는다.** 집계 화면이라 거의 모든 기능을 당겨서, 세면 대부분이
  공유 위치로 가 버린다.
- 여러 기능이 쓰는데 주 소유가 애매하면 **가장 본질적으로 쓰는 쪽**이다 —
  `filter_preference` 는 match_list·schedule·splash 가 쓰지만 필터를 정의하는 곳이
  `schedule` 이라 그쪽이다. 다른 기능이 그걸 참조하는 것은 허용한다.

**import 는 `package:warding/...` 절대경로로 쓴다.** 상대경로(`../../model/...`)는 파일을
옮길 때 대량으로 깨진다 — 이 전환에서 실측으로 540건이 났다. `export` 도 마찬가지다.

## 파일 생성 규칙

**새 기능은 `features/` 에 만든다.**

| 종류 | 위치 | 예 |
|------|------|-----|
| 화면 | `features/{기능}/presentation/screens/` | `features/community/presentation/screens/community_screen.dart` |
| 화면 전용 위젯 | `features/{기능}/presentation/widgets/` | `features/community/presentation/widgets/post_list_item.dart` |
| 단계별 화면 (멀티 스텝) | `features/{기능}/presentation/screens/step/` | `.../presentation/screens/step/team_step.dart` |
| ViewModel | `features/{기능}/presentation/viewmodels/` | `features/community/presentation/viewmodels/community_list_viewmodel.dart` |
| 모델·규칙·상수 | `features/{기능}/domain/` | `features/community/domain/community_remote_post.dart` |
| 리포지토리 | `features/{기능}/data/` | `features/community/data/community_repository.dart` |
| 여러 기능이 쓰는 모델·서비스 | 그 **도메인의 기능** | `features/auth/data/auth_service.dart` (20기능이 쓴다) |
| 앱 공용 위젯 | `core/ui/` | `core/ui/common_button.dart` |

- 파일명은 `snake_case`, 클래스명은 `PascalCase`.
- 한 화면에서만 쓰는 위젯은 그 기능의 `presentation/widgets/`에, 여러 기능에서 쓰면
  `apps/mobile/lib/core/ui/`에 둔다.
- **`data` 와 `domain` 의 구분**: `domain`은 그 기능의 개념(모델·규칙·상수), `data`는 그것을
  가져오는 수단(repository·API 예외)과 그 기능 전용 DTO다. `community_permission.dart`처럼
  화면이 아닌 규칙 파일은 `screens`가 아니라 `domain`에 둔다.
- **공유되는 기술 코드는 `core/` 로 올린다.** 단 도메인 개념이면 소비처가 몇 곳이든 그
  도메인의 기능에 둔다(위 "소유자 판단 기준" 참고). 다른 기능이 참조하는 것은 허용한다.
- **import·export 는 `package:warding/...` 절대경로.** 상대경로는 파일을 옮길 때 깨진다.
- **repository 는 `domain/repositories/` 에 인터페이스를 두고 `Either<Failure, T>` 를
  돌려준다.** `try/catch` 없이 실패 분기가 컴파일 단계에서 강제되고, 테스트에서
  `mocktail` Mock 을 쓸 수 있다. 예외를 던지던 때는 `catch` 를 빠뜨려도 아무도 몰랐다.
  판단 기준과 예외(로컬 저장소·도메인 예외를 쓰는 경우 등)는
  [Clean Architecture 전환 플레이북](./wiki/playbooks/clean-architecture-migration.md) 참고.
- **새 모델은 DTO 를 분리한다. 기존 모델은 서버 응답이 바뀔 때 전환한다.**

  ```
  features/{기능}/data/models/{x}_dto.dart      서버 응답 형식 그대로 + fromJson
  features/{기능}/data/mappers/{x}_mapper.dart  DTO → Entity 변환
  features/{기능}/domain/{x}.dart               Entity (fromJson 없음)
  ```

  선례는 `shorts`·`my_review`·`onboarding` 3개다. 나머지 모델(약 50개)은 Entity 가
  `fromJson` 을 직접 갖는다 — **일괄 전환하지 않는다.** `fromJson` 호출이 repository
  구현에서만 일어나므로(실측 `data/` 31파일, `presentation` 2건은 로컬 임시저장,
  `core`·`app` 0건) 서버 형식이 화면으로 새지 않고, 인터페이스가 이미
  `Either<Failure, Entity>` 로 변경을 흡수한다. DTO 를 97개 만들어 얻는 것은 "Entity
  파일에서 `fromJson` 이 사라지는 것" 뿐이라 비용이 맞지 않는다.

  **서버 응답과 화면 모델의 형태가 다를 때는 처음부터 분리한다** — 필드명이 다르거나,
  응답 하나를 여러 Entity 로 쪼개거나, 널 처리가 복잡한 경우다. 1:1 매핑이면 매퍼가
  필드 복사만 하므로 분리 이득이 없다.
- **로컬 저장 직렬화는 서버 DTO 와 구분한다.** `Team.fromStorage`·`toJson` 은 앱이 정한
  형식이라 Entity 에 둬도 외부 변경에 노출되지 않는다. 서버 응답은
  `TeamDto.fromJson` + `TeamMapper` 를 거친다.
- 이름이 공용처럼 보여도 한 기능만 쓰면 그 기능 안에 둔다 — `community_my_activity` 는
  접두어가 `community_` 지만 `my_community_activity` 기능만 쓰므로 그 기능의 `data/` 에 있다.

## 색상 / 디자인 토큰

모든 색은 `apps/mobile/lib/core/theme/app_colors.dart`의 `AppColors` 클래스에 정의한다.

- 위젯에 색을 **하드코딩하지 않는다**. 항상 `AppColors.xxx`를 참조한다.
- 디자인 시안의 토큰 이름을 그대로 쓴다 (`narText`, `narDark800`, `narButton1Bg` 등).
- 단색: `static const Color narText = Color(0xFFFFFFFF);`
- 그라데이션: `static const LinearGradient narBg = LinearGradient(...);`
- 필요한 색이 없으면 위젯에 박지 말고 먼저 `AppColors`에 추가한 뒤 참조한다.

## UI 작성 규칙

- **비율 스케일**: 디자인 시안 기준 폭은 375. 화면 폭을 모바일 범위(320~430)로 clamp 한 뒤
  375로 나눈 `scale` 값을 크기·간격·폰트 등 수치에 곱한다.
  ```dart
  final width = MediaQuery.of(context).size.width;
  final scale = width.clamp(320.0, 430.0) / 375;
  ```
  재사용 컴포넌트는 `scale` 파라미터를 받아 내부 수치에 곱한다.
- **폰트**: 기본 `Pretendard`, 일부 `Open Sans` (pubspec에 폰트 등록 필요).
- `line-height`가 폰트 크기보다 많이 작으면 `height` 대신 부모의 `alignment`로 정렬한다.

## 릴리즈 / 배포 (Shorebird)

### 자동 배포 (기본 경로)

**`release/<pubspec의 version>` 태그를 밀면 아래가 자동으로 돈다.**

```
git tag -a release/1.0.33+81 -m "release"
git push --follow-tags
```

```
[1] verify          태그 ↔ pubspec 버전 일치 · annotated 태그 확인 · analyze · test
[2] e2e ∥ build-ios ∥ build-android     e2e 와 빌드가 동시에 돈다 (약 22분)
                    빌드는 shorebird release 까지 하고, **업로드 직전에 e2e 결과를 본다**
                    e2e 가 실패하면 업로드하지 않고 멈춘다
[3] release-notes   커밋 로그로 패치노트 초안 생성 (Anthropic API)
[4] notify          #와딩-릴리즈-배포 채널에 결과 + 버튼
         ↓
    사람이 TestFlight에서 확인
         ↓
    Discord [✅ 심사 제출] → [네, 제출합니다]   ← 2단계 확인
         ↓
    App Store 심사 → 승인 즉시 자동 출시 / Play production 100% 출시
```

> Play 출시 비율은 `android_rollout` 기본값 100%다. 단계적으로 내보내려면 Actions 탭에서
> **"심사 제출 (수동)"** 에 비율을 지정해 실행한다(예: `0.1`). iOS 는 단계적 출시를 쓰지
> 않고, 심사 승인 즉시 전체 사용자에게 나간다(`automatic_release true`).

**심사 제출은 버튼을 누르기 전까지 나가지 않는다.** 태그만 밀면 TestFlight·내부테스트에서
멈추므로, 실수로 스토어에 공개될 일이 없다.

Discord를 못 쓰는 상황이면 Actions 탭의
**"심사 제출 (수동)"** 워크플로우를 직접 실행해도 된다.

> e2e 가 실패해 멈췄다면 **빌드 번호를 올려서 다시 밀어야 한다.** 업로드는 막혔지만
> `shorebird release` 는 이미 돌아서 그 버전이 Shorebird 에 등록돼 있다.

**패치노트는 `distribution/`에서 관리한다.** 릴리즈 전에 고쳐 두거나, 알림에 온 AI 초안을
**[✏️ 패치노트 수정]** 버튼으로 그 자리에서 손봐 제출할 수 있다. 규칙과 양식은
[distribution/README.md](./distribution/README.md) 참고.

> 주의: Play는 **태그를 미는 시점**에, iOS는 **심사 제출 시점**에 패치노트를 읽는다.
> 그래서 Discord에서 고친 내용은 iOS에만 반영되고, Play는 Console에서 고쳐야 한다.

설계 배경은 [intent/release-build-automation/](./intent/release-build-automation/)과
[intent/discord-release-approval/](./intent/discord-release-approval/)에 있다.

### 수동 배포 (비상 경로)

자동화가 막혔을 때 쓴다. 아래 규칙은 자동 배포에도 그대로 적용되며, 워크플로우가 이미
이 규칙대로 돌도록 짜여 있다.

**스토어 제출용 빌드는 반드시 `shorebird release`로 뽑는다. `flutter build ipa`/`flutter build appbundle` 금지.**
일반 빌드에는 Shorebird 업데이터가 안 들어가서, 그 빌드를 설치한 유저는 코드 푸시 패치를 영원히 못 받는다
(1.0.3 iOS가 이 실수로 나가서 다음 스토어 릴리즈 전까지 패치 불가였음).

**`shorebird release` 실행 전에 `e2e-release-check.yml`을 수동으로 돌려 통과를 확인한다**
(`gh workflow run e2e-release-check.yml` 또는 Actions 탭에서 직접 실행). PR마다 도는
`ci-flutter-test.yml`은 유닛/위젯 테스트(`flutter test`)만 돌리고, `apps/mobile/integration_test/`의
e2e는 iOS 시뮬레이터가 필요해 macOS 러너로 별도 워크플로우에 분리해 뒀다. 매 PR이 아니라
릴리즈 직전에만 도는 이유는 macOS 러너가 느리고 비싸기 때문이다.

e2e가 실패하면(릴리즈 직전 1회성 실행이라 "연속 실패" 개념 없이 곧바로) `ci-flutter-test.yml`과
같은 방식으로 실패 로그를 Anthropic API로 분석해 plan/spec/intent 중 적절한 등급의 문서
초안과 PR을 자동 생성한다. 코드 자동 수정은 하지 않고 다음 스텝 문서까지만 준비해 둔다.

```bash
# shorebird 는 pubspec 이 있는 곳에서 돌려야 한다
cd apps/mobile

# 스토어 릴리즈 (버전은 pubspec.yaml의 version 사용)
git tag -a release/1.0.13+20 -m "shorebird release ios+android"   # 빌드 직전에 (아래 태그 규칙)
shorebird release ios        # → apps/mobile/build/ios/ipa/*.ipa 를 Transporter로 업로드
shorebird release android    # → apps/mobile/build/app/outputs/bundle/release/*.aab 를 Play Console에 업로드
git push --follow-tags

# 제출 전 확인: 해당 버전이 목록에 있어야 shorebird 빌드가 맞음
shorebird releases list

# 출시 후 Dart 코드 핫픽스 (심사 불필요, 앱 재실행 2번이면 적용)
shorebird patch ios --release-version <pubspec의 version>
shorebird patch android --release-version <pubspec의 version>
```

### 릴리즈 태그 규칙

**`shorebird release` 실행 직전에 annotated 태그를 찍는다.** shorebird 는 업로드 시각만
저장하고 어느 커밋이었는지는 남기지 않는다. 태그가 없으면 "이 릴리즈가 어느 코드였나"를
업로드 시각으로 역추적해야 하는데, 커밋 시각 ≠ 빌드 시각이고 uncommitted 상태로 빌드했으면
아예 못 찾는다.

- 태그명은 `release/<pubspec의 version 그대로>`다. 예: `release/1.0.13+20`.
  조회는 언제나 "shorebird 가 말하는 버전 → 커밋" 방향이라 이름에 버전이 들어가야 한다.
- **`-a` 필수.** lightweight 태그는 자기 날짜가 없어 커밋 날짜로 대체되는데, 알고 싶은 건
  빌드 시각이다. annotated 는 태그를 찍은 시각을 따로 저장해 shorebird 의 `created_at` 과
  대조할 수 있다.
- 빌드 번호를 올려 다시 뽑으면 태그도 새로 찍는다. 옛 태그는 지우지 않는다. 어느 빌드가
  실제로 스토어에 나갔는지 구분하기 위해서다 (예: `+19` 는 폐기, `+20` 이 제출분).
- 날짜순으로 보려면:
  `git tag --sort=-creatordate --format='%(creatordate:short)  %(refname:short)  %(contents:subject)'`

**2026-09-29에 shorebird 패치를 재개했으나 10-19 이후 다시 미사용이다.** 과금이 패치 설치
수 기준(Free 5,000/월)인데 MAU 가 9,000 이라 한 번 내보내면 한도가 찬다. 마지막 패치는
`patch/1.0.34+84/1` 이고 그 뒤로 릴리즈만 나갔다 — **Dart 수정도 스토어 심사를 거치는
상태다.** 웹뷰 전환이 그 자리를 메우는 방향이다(→
[웹뷰 전환 intent](./intent/hybrid-webview-monorepo/intent.md)). 패치를 쓸 때는 직전에도
릴리즈와 같은 방식으로 태그를 찍는다 — `patch/<release version>/<번호>`, `-a` 필수. 번호는
같은 릴리즈 버전에 패치를 낼 때마다 1부터 순서대로 올린다.

**패치도 태그를 밀면 자동으로 돈다** (`patch-deploy.yml`). 릴리즈와 같은 방식이다.

```
git tag -a patch/1.0.42+92/1 -m "patch"
git push --follow-tags
```

```
[1] verify      태그 형식 · annotated · pubspec↔대상 버전 일치
                **패치로 나갈 수 없는 변경(네이티브·에셋·pubspec 의존성) 차단**
                analyze · test
[2] e2e         통과를 **기다린다** (릴리즈는 업로드 직전에 보지만, 패치는
                올리면 심사 없이 바로 사용자에게 가므로 먼저 막는다)
[3] patch-ios ∥ patch-android
[4] notify      #와딩-릴리즈-배포 채널에 결과
```

가드 로직은 `.github/workflows/patch-deploy-test.sh` 로 회귀 테스트하며 PR마다 돈다
(태그를 밀어 봐야 도는 워크플로우라 눈으로는 검증할 수 없다).

패치는 **업데이트 팝업을 띄우지 않는다** — 스토어 버전이 그대로이기 때문이다. Dart 수정을
스토어 릴리즈로 내보내면 팝업이 또 뜨고, 그게 쌓이면 사용자가 팝업을 닫는 습관을 들여
정작 올려야 하는 버전에서도 무시한다(`util/update_prompt.dart` 주석 참고). **Dart 만 바뀐
수정은 되도록 패치로 낸다.**

패치 규칙:
- 패치는 **Dart 코드만** 배포한다. 네이티브 플러그인 추가·에셋 추가·pubspec 네이티브 의존성 변경은 패치로 못 나가고 스토어 재제출이 필요하다.
- 구버전 릴리즈(예: 1.0.1+7)에 패치를 낼 때는 현재 main이 아니라 **그 릴리즈의 마지막 패치가 빌드된 시점의 커밋**을 worktree로 checkout 해서 픽스만 cherry-pick 한다. main으로 내면 그 사이 추가된 네이티브 의존성(sentry 등) 때문에 시작 크래시가 발생할 위험이 있다.
- 태그가 없던 시절 릴리즈는 `shorebird patches list --release-version <버전> --json`의 artifact `created_at`으로 역추적해야 한다. 태그 규칙이 이걸 없애려는 것이다.
- 과금은 **패치 설치 수** 기준이다(Free 5,000/월 — 위 "미사용" 서술 참고). 릴리즈 빌드 자체는 과금 대상이 아니므로, 패치를 안 쓰더라도 빌드는 계속 `shorebird release` 로 뽑아 비상구를 열어 둔다.

## 지식 번들 (wiki)

`wiki/`는 이 프로젝트의 지식을 OKF(Open Knowledge Format) 형식으로 정리한 번들이다.
마크다운 + YAML 프론트매터 개념 문서들의 그래프로, 아키텍처·디자인 규칙·기능 현황을 담는다.
`intent/`가 "결정 당시의 왜"를 남긴다면, `wiki/`는 "지금 코드가 실제로 어떻게 동작하는지"의
최신 스냅샷이다.

**동기화 규칙: 작업 중 다음이 바뀌면 번들도 함께 갱신한다.**

- **기능을 완료/변경**하면 → `wiki/features/{기능}.md`의 상태·내용을 갱신한다.
- **아키텍처·파일 규칙·디자인 토큰**이 바뀌면 → `wiki/architecture/` 또는 `wiki/design/`의 해당 개념을 갱신한다.
- **새 기능 영역**이 생기면 → `wiki/features/`에 개념 문서를 추가하고 `features/index.md`와 루트 `index.md`에 링크를 건다.
- 의미 있는 변경 후에는 `wiki/log.md` 맨 위에 `YYYY-MM-DD` 항목을 추가한다.
- 개념 문서는 프론트매터에 `type`(필수)을 두고, 다른 개념은 `[제목](/path/to/concept.md)` 형식의 번들-상대 링크로 연결한다.

진행 상황·이슈 번호의 단일 출처는 `wiki/references/github-project.md`와 이 `CLAUDE.md`다.

이 동기화는 자동 스크립트가 아니라 **작업 중 매번 스스로 판단해 적용하는 규칙**이다. 커밋이나
저장 시점에 강제로 검증되지 않으므로, 위 조건에 해당하는 변경을 할 때마다 놓치지 않는다.

## 기획·디자인 확정본: warding-docs

화면 기획(`spec.md`)과 디자인 목업(`mockup.html`)의 확정본은 별도 레포
[NAR-GG/warding-docs](https://github.com/NAR-GG/warding-docs)에 둔다. 그 레포의 `main`에
머지된 것만 확정본이고, PR 브랜치에 있는 것은 초안이다.

- 화면 기능을 구현하기 전에 `features/<slug>/spec.md`가 있는지 먼저 찾는다. 로컬 클론은
  뒤처져 있을 수 있으니 `main`을 직접 읽는다.
  ```bash
  gh api repos/NAR-GG/warding-docs/contents/features --jq '.[].name'
  curl -s https://raw.githubusercontent.com/NAR-GG/warding-docs/main/features/<slug>/spec.md
  ```
- spec의 **결정**은 그대로 따른다. **미결**에 걸린 부분은 추측해서 구현하지 않고 사용자에게 묻는다.
  spec 맨 위 상태가 "확정"이 아니면 초안이라는 것을 먼저 알린다.
- 목업의 `var(--narDark800)`는 `AppColors.narDark800`과 같은 토큰이다. 목업의 `assets/tokens.css`가
  `app_colors.dart`에서 자동 생성되기 때문이다. 목업의 px 값은 375 기준이라 `* scale`을 곱해 옮긴다.
- 목업 html은 수백 KB라 통째로 읽지 않는다. `spec.md`를 먼저 읽고, 필요한 화면의 구조와 CSS만 골라 본다.
- 구현하다가 spec과 다르게 가야 하면 코드보다 먼저 warding-docs에 spec 수정 PR을 올린다.
- 이 레포의 Intent → Spec → Plan에서 warding-docs는 **Spec 단계**에 붙는다.
  - Intent: 기획 의도 (Problem, Proposed outcome, Affected users and systems, Constraints, Open questions)
  - Spec: 구현용 spec (Summary, Requirements, Design / Approach, Decisions, Out of scope, Open questions).
    여기서 warding-docs의 `mockup.html`과 백엔드 전달 `spec.md`를 링크로 연결한다.
  - Plan: 실제 구현 계획 (Context, Changes, Verification)

## 요건 변경 시 intent/spec 동기화

Discord `/intent`를 거치지 않고 대화(채팅)로 바로 기능 변경을 요청받았을 때도 적용되는 규칙이다.

- 코드를 고치기 전에 `intent/<slug>/intent.md` 또는 `spec.md`가 그 기능 영역에 이미 있는지
  먼저 찾는다 (`intent/` 폴더를 기능 키워드로 검색).
- 있는데 이번 요청이 그 문서의 Requirements/Proposed outcome과 어긋나거나 이를 바꾸는
  변경이면, **코드를 고치기 전에** 해당 문서의 갱신 diff를 먼저 제시하고 사용자 확인을 받은
  뒤 코드를 고친다. 오탈자·자명한 원라이너 수준의 변경은 예외.
- 대응하는 intent/spec 문서가 아예 없는 기능이면 새로 만들 필요는 없다. 이 규칙은 기존
  문서와 코드가 어긋나는 것을 막기 위한 것이지, 모든 변경에 문서를 강제하는 게 아니다.
- 문서 갱신은 셀프 머지 가능한 일반 PR로도, 같은 기능 PR에 포함해도 된다. 이 규칙은
  "갱신을 빠뜨리지 않는 것"이 핵심이지 별도 PR을 강제하지 않는다.

## PR 작성 규칙

PR을 만들거나 본문을 고칠 때는 **항상 먼저 `.github/pull_request_template.md`를 읽고** 그 형식
(요약·관련 문서·테스트 방법·스크린샷·체크리스트)대로 본문을 쓴다. `gh pr create --body`로 본문을
직접 지어내지 않는다.

- 체크박스는 실제로 한 것만 체크한다. 못 한 항목(예: 시뮬레이터 확인)은 체크하지 않고 사유를 적는다.
- 해당 없는 섹션도 지우지 말고 "없음"으로 남긴다.
- intent/spec을 올리는 PR은 `.github/PULL_REQUEST_TEMPLATE/intent.md`, `spec.md`를 쓴다.

## 진행 상황

### 완료
- 카카오 로그인 (네이티브 앱 키, 패키지명 `com.warding.app`, 릴리즈 키스토어 서명 설정)
- 화면 폴더 구조 정리 (`screens/login·home·onboarding`)
- 온보딩 4단계 (선호 리그·팀·선수·알림 권한): MVVM 구조로 구현
- 온보딩 리그·선수 선택 그리드, 완료 API(`POST /api/auth/onboarding`)에 리그·팀·선수 연동
- 쇼츠 앱 내 재생: 홈 카드 탭 → 전체화면 세로 피드(`screens/shorts/`, 유튜브 IFrame 임베드·항상 무음). 네이티브 WebView라 스토어 릴리스 필요, Android·실기기 미확인
- 홈 화면 (앱 진입 화면, 5개 섹션·내 선수 화면): 일정·순위표·커뮤니티 글·공지·쇼츠·구독은 실데이터, 솔랭·평점·뉴스는 백엔드 대기(`apps/mobile/lib/core/config/home_mocks.dart` 가 플래그를 읽고, 섹션별 소스는 각 기능의 `data/` 에 있다). 목업은 `HOME_MOCKS` dart-define(기본값 `kDebugMode`) 뒤에 있어 디버그·시뮬레이터에서만 보이고, 릴리즈 빌드는 빈 소스(솔랭 조용한 행, 뉴스·평점 탭 숨김)가 나간다. 릴리즈에서 목업을 보려면 `--dart-define=HOME_MOCKS=true`

- 선수 페이지(`screens/player/`): 홈 솔랭 카드·끝난 경기 칩·월즈 솔랭 타일에서 진입. 화면은 `HOME_MOCKS` 목업으로 완성, 백엔드 `GET /api/mobile/players/{id}`(+`/worlds`, `/solo-rank`) 배포 후 실 API 확인 필요

### 다음 작업
- 솔랭·평점·뉴스 백엔드 연동(홈 소스 구현체 교체)
- 경기 페이지

### 남은 TODO
- `Pretendard` / `Open Sans` 폰트가 pubspec에 미등록되어 있어, 현재 fallback 폰트로 렌더링된다
- 비회원(JWT 없음)은 온보딩 완료 API를 호출하지 않는다. 선호 팀만 로컬에 캐싱하고, 리그·선수 로컬 저장은 아직 구현하지 않았다
- 알림 권한 '허용' 시 실제 권한 요청은 연결되어 있다. iOS 배포 시 `permission_handler` Podfile 매크로 설정이 필요하다
