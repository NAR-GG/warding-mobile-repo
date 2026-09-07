---
name: run-warding
description: warding Flutter 앱을 iOS 시뮬레이터에서 빌드·실행하고 화면을 스크린샷으로 확인한다. UI 변경을 눈으로 검증해야 할 때 사용한다.
---

# warding 앱 실행 & UI 확인

## 1. 시뮬레이터 준비

부팅된 시뮬레이터가 있는지 확인한다:

```bash
xcrun simctl list devices booted -j
```

부팅된 게 없으면 설치된 최신 iOS 런타임의 iPhone 시뮬레이터를 하나 띄운다:

```bash
DEVICE=$(xcrun simctl list devices available -j \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; \
    rt=[k for k in d if 'iOS' in k][-1]; \
    print([x['udid'] for x in d[rt] if 'iPhone' in x['name']][-1])")
xcrun simctl boot "$DEVICE"
open -a Simulator
```

## 2. 앱 실행

```bash
cd "/Volumes/Extreme SSD/Projects/teamProject/warding"
fvm flutter run -d "$DEVICE" &
```

빌드 로그에 `Flutter run key commands`가 보이면 앱이 뜬 것이다. 최초 빌드는 1~3분 걸릴 수 있다.

## 3. 화면 확인

```bash
xcrun simctl io "$DEVICE" screenshot /tmp/warding-screen.png
```

Read 도구로 `/tmp/warding-screen.png`를 열어서 실제로 확인한다. 탭 이동 등 조작이 필요한
시나리오는 사람에게 조작을 요청하거나, 진행 방법을 명확히 안내한다.

## 4. 종료

```bash
kill %1   # 백그라운드로 띄운 flutter run 종료
```
