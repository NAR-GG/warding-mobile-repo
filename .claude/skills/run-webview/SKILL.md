---
name: run-webview
description: 웹뷰 전환 화면(커뮤니티 글 상세·공지)을 로컬 Next 서버 + iOS 시뮬레이터로 띄워 브리지 동작을 확인한다. 브리지·웹 화면을 수정한 뒤 검증할 때 사용한다.
---

# 웹뷰 화면 실행 & 브리지 확인

## 먼저 — 시뮬레이터가 필요한가

**UI 만 고친다면 맥 브라우저로 보는 쪽이 훨씬 빠르다.** 개발자도구로 바로
만질 수 있고 앱을 띄울 필요가 없다.

```bash
pnpm web:dev
open http://localhost:3100/community/post/114
```

> 브라우저 반응형을 **375px** 로 맞추면 시뮬레이터와 거의 같다 — 치수가
> `calc(n * var(--scale))` 이고 `--scale` 이 375 기준이라서다.

**시뮬레이터가 필요한 경우는 브리지가 걸릴 때뿐이다** — 뒤로가기, 사진 뷰어,
로그인 상태(쿠키). 브라우저에서는 브리지가 없어 그 동작들이 무시된다.

아래는 그 경우의 절차다. 웹 서버와 앱을 **둘 다** 띄우고, 서버가 먼저다.

## 1. 웹 서버 띄우기

**UI 를 고치며 반복할 때** — 고치면 즉시 반영된다. 이쪽을 기본으로 쓴다.

```bash
pnpm web:dev
```

**첫 페인트 속도를 재려면** 프로덕션 빌드로 띄운다. `dev` 는 매 요청 컴파일해서
느리다.

```bash
pnpm web:build && pnpm --filter warding-web start
```

> **SSR 은 둘 다 똑같이 돈다.** `dev` 든 `start` 든 서버가 완성된 HTML 을
> 보낸다 — SSR 은 별도 모드가 아니라 이 앱의 기본 동작이다. 차이는 컴파일
> 시점뿐이다.

살아 있는지 확인:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/community/post/114
```

> 글 id 는 바뀐다. 404 가 나오면 살아 있는 id 를 찾는다:
> ```bash
> curl -s 'https://api.nar.kr/api/mobile/community/posts?size=5' \
>   | python3 -c "import json,sys; print(json.load(sys.stdin)['posts'][0]['id'])"
> ```

## 2. 진입점 만들기

앱에는 아직 웹뷰 화면으로 가는 버튼이 없다. 임시 진입점을 만든다
(**커밋되지 않는다** — gitignore 에 있다).

```bash
cat > apps/mobile/lib/webview_probe.dart <<'DART'
import 'package:flutter/material.dart';

import 'package:warding/app/bridge/webview_screen.dart';
import 'package:warding/app/navigation/webview_routes.dart';

void main() {
  runApp(
    MaterialApp(
      home: WebViewScreen(
        route: communityPostRoute,   // 공지는 noticeRoute
        params: const {'id': '114'}, // 위에서 찾은 id
      ),
    ),
  );
}
DART
```

## 3. 앱 실행

```bash
pnpm app:local -t lib/webview_probe.dart
```

`apps/mobile/` 안에서 작업 중이면 `./tool/run.sh local -t ...` 도 같다.

`local` 은 웹뷰가 `localhost:3100` 을 보게 한다. `prod` 면 배포된 웹을 본다
(인자를 생략해도 `prod` 다 — **기본값이 운영이라 빼먹어도 안전하다**).

> **flavor 를 쓰지 않는다.** 조사한 실제 앱 8개 중 dev/prod 분리에 flavor 를
> 쓴 곳은 0개였고, flavor 를 쓰는 3개는 전부 번들ID가 갈리는 배포 채널
> (Play/F-Droid) 문제였다. flavor 를 넣으면 `shorebird release`·`patch` 네
> 곳에 `--flavor` 를 붙여야 하고 **태그를 밀어야 검증된다.** Flutter 공식 CD
> 문서가 권하는 `--dart-define` 을 쓴다.

> 실기기는 `localhost` 가 기기 자신을 가리키므로 맥의 LAN IP 를 넣는다:
> `LOCAL_WEB_HOST=http://$(ipconfig getifaddr en0):3100 ./tool/run.sh local ...`

## 4. 브리지가 도는지 확인

실행 로그에 `[Bridge]` 가 찍힌다.

```
flutter: [Bridge] ready at 2026-11-18 13:11:16.778
```

- **`ready` 가 안 찍히면** 웹이 로드되지 않았거나 채널 이름이 어긋난 것이다.
  양쪽 `CHANNEL`/`kBridgeChannel` 이 같은지 본다.
- **화면이 까맣기만 하면** 가림막(`_ready == false`)이 안 걷힌 것이다 —
  같은 원인이다.

화면 확인:

```bash
xcrun simctl io "$DEVICE" screenshot /tmp/webview.png
```

## 5. 로그인 상태로 보기

쿠키는 네이티브가 `AuthService.instance.jwt` 를 읽어 심는다. **앱에 로그인돼
있어야** 좋아요·스크랩 상태가 보인다. 프로브는 로그인 화면을 거치지 않으므로,
이미 로그인한 시뮬레이터에서 띄우거나 정식 진입점이 생긴 뒤에 확인한다.

서버가 토큰을 쓰는지만 보려면 쿠키를 직접 넣어 본다:

```bash
curl -s -H 'Cookie: warding_jwt=<토큰>' http://localhost:3100/community/post/114 | grep -c "내가 좋아요함"
```

> 백엔드는 **잘못된 토큰에도 200** 을 준다. 응답 코드로는 토큰이 실제로
> 쓰였는지 알 수 없으니, 헤더 전달은 `packages/api` 의 `client.test.ts` 가
> 로컬 HTTP 서버로 검증한다.

## 6. 고친 뒤 뭘 다시 켜야 하나

앱은 **URL 을 띄우는 껍데기**다. 화면 내용은 전부 웹 서버가 만든다.

| 고친 것 | 할 일 |
|---|---|
| 웹 UI (`apps/web/`, `packages/ui`) | **없음** — 화면 새로고침만 (`web:dev` 기준) |
| 브리지 웹 쪽 (`shared/bridge/`) | 화면 새로고침만 |
| 브리지 Dart 쪽 (`app/bridge/`) | 앱 터미널에서 `r` (핫리로드) |
| `webview_routes.dart`·`api_config.dart` | 앱 터미널에서 `R` (핫리스타트) |
| `WEBVIEW_HOST` 를 바꿔야 할 때 | `flutter run` 을 다시 띄운다 |

> **`web:build && start` 로 띄웠다면 웹을 고쳐도 반영되지 않는다.** 고정된
> 빌드 결과를 서빙하기 때문이다. UI 를 반복해 고칠 거면 `web:dev` 를 쓴다.

## 7. 정리

```bash
pkill -f "flutter run"
pkill -f "next dev"; pkill -f "next start"
rm -f apps/mobile/lib/webview_probe.dart
```
