---
name: run-webview
description: 웹뷰 전환 화면(커뮤니티 글 상세·공지)을 로컬 Next 서버 + iOS 시뮬레이터로 띄워 브리지 동작을 확인한다. 브리지·웹 화면을 수정한 뒤 검증할 때 사용한다.
---

# 웹뷰 화면 실행 & 브리지 확인

웹 서버와 앱을 **둘 다** 띄워야 한다. 순서가 중요하다 — 서버가 먼저다.

## 1. 웹 서버 띄우기

```bash
cd apps/web
pnpm exec next build && pnpm exec next start -p 3210
```

개발 중이라 자주 고친다면 `pnpm dev` 가 낫다(기본 3100 포트).
단, **SSR 성능을 보려면 `next start`** 를 써야 한다 — `dev` 는 매 요청 컴파일한다.

살아 있는지 확인:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3210/community/post/114
```

> 글 id 는 바뀐다. 404 가 나오면 살아 있는 id 를 찾는다:
> ```bash
> curl -s 'https://api.nar.kr/api/mobile/community/posts?size=5' \
>   | python3 -c "import json,sys; print(json.load(sys.stdin)['posts'][0]['id'])"
> ```

## 2. 진입점 만들기

앱에는 아직 웹뷰 화면으로 가는 버튼이 없다. 임시 진입점을 만든다
(**커밋하지 않는다** — 확인이 끝나면 지운다).

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

`WEBVIEW_HOST` 로 로컬 서버를 가리킨다. 기본값은 운영(`https://nar.kr`)이라
**반드시 넘겨야** 로컬을 본다.

```bash
DEVICE=$(xcrun simctl list devices booted -j \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; \
    print([x['udid'] for v in d.values() for x in v][0])")

cd apps/mobile
fvm flutter run -d "$DEVICE" \
  -t lib/webview_probe.dart \
  --dart-define=WEBVIEW_HOST=http://localhost:3210
```

> 시뮬레이터가 안 떠 있으면 `run-warding` 스킬의 1번 절차로 먼저 띄운다.
> 실기기는 `localhost` 가 기기 자신을 가리키므로 **맥의 LAN IP** 를 넣는다
> (`ipconfig getifaddr en0`).

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
curl -s -H 'Cookie: warding_jwt=<토큰>' http://localhost:3210/community/post/114 | grep -c "내가 좋아요함"
```

> 백엔드는 **잘못된 토큰에도 200** 을 준다. 응답 코드로는 토큰이 실제로
> 쓰였는지 알 수 없으니, 헤더 전달은 `packages/api` 의 `client.test.ts` 가
> 로컬 HTTP 서버로 검증한다.

## 6. 정리

```bash
pkill -f "flutter run"
pkill -f "next start -p 3210"
rm -f apps/mobile/lib/webview_probe.dart
```
