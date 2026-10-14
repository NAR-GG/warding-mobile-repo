# Spec: 릴리즈 빌드·스토어 제출 자동화

Intent: [intent.md](./intent.md)
warding-docs: 해당 없음 (화면 기능이 아니라 개발 쪽 CI 작업이다)

## Summary

지금 릴리즈는 전부 로컬 수동이다. `shorebird release ios` / `shorebird release android`
를 직접 돌리고, 나온 ipa 를 Transporter 로, aab 를 Play Console 로 손수 올리고, 태그도
빌드 직전에 손으로 찍는다. 테스트 CI(`ci-flutter-test.yml`)와 릴리즈 직전 e2e
(`e2e-release-check.yml`)는 있지만 **빌드·배포 CD 는 하나도 없다.**

이 수동 절차에는 이미 한 번 사고가 났다. 1.0.3 iOS 가 `shorebird release` 가 아닌
`flutter build ipa` 로 나가서, 그 빌드를 설치한 유저는 다음 스토어 릴리즈까지 코드 푸시
패치를 받을 수 없었다. 사람이 매번 올바른 명령을 고르는 구조라 같은 실수가 다시 날 수 있다.

`release/<version>` 태그를 밀면 e2e → 빌드 → TestFlight·Play 내부테스트 업로드까지
한 번에 도는 워크플로우를 추가한다. 사람은 태그를 찍는 결정과 **심사에 올리는 결정**만
하고, 그 사이의 손 작업은 기계가 한다.

## Requirements

1. `release/*` 태그를 push 하면 릴리즈 파이프라인이 돈다.
2. 태그 이름의 버전과 `pubspec.yaml` 의 `version` 이 다르면 **빌드 전에 실패**한다.
   (CLAUDE.md 태그 규칙이 `release/<pubspec의 version 그대로>` 이므로 이를 기계가 검증한다.)
3. e2e(`integration_test/`)가 먼저 돌고 **통과해야** 빌드로 넘어간다. 실패하면 빌드하지 않는다.
4. 빌드는 **반드시 `shorebird release`** 로 한다. `flutter build ipa` / `flutter build appbundle`
   은 쓰지 않는다. 워크플로우에 그 명령이 들어가지 않는 것으로 구조적으로 보장한다.
5. iOS 는 TestFlight 에, Android 는 Play 내부 테스트 트랙에 업로드한다.
6. **심사 제출은 릴리즈 파이프라인에서 분리한다.** 릴리즈 파이프라인은 업로드에서 끝나고,
   심사 제출·Play production 승격은 **버튼으로 실행하는 별도 워크플로우**
   (`submit-for-review.yml`)가 맡는다. 발동 시점을 사람이 고른다.
7. 파이프라인의 각 단계 결과를 Discord 로 알린다 (기존 두 워크플로우와 같은 웹훅).
8. 실패하면 어느 단계에서 깨졌는지 로그를 아티팩트로 남긴다.

## Design / Approach

### 트리거와 전체 흐름

```
release/1.0.34+79 태그 push
   ↓
[1] verify   (ubuntu)  — 태그 ↔ pubspec 버전 일치, analyze, test
   ↓
[2] e2e      (macos)   — integration_test/ 실행. 실패 시 여기서 중단
   ↓
[3] build-ios (macos)  ─┐  shorebird release ios   → TestFlight 업로드
    build-android(ubuntu)┘  shorebird release android → Play 내부테스트 업로드
   ↓
[4] notify             — Discord 결과 알림 (릴리즈 파이프라인은 여기서 끝)
   ↓
[사람] TestFlight 에서 확인 → 괜찮으면 아래를 버튼으로 실행
   ↓
submit-for-review.yml (workflow_dispatch)
   submit-ios     — 빌드 처리 대기 → deliver submit_build
   submit-android — 내부테스트 → production 승격 (단계적 출시)
```

`[3]` 의 두 잡은 서로 의존이 없어 병렬로 돈다. `[4]` 는 둘 다 성공해야 돈다.

### e2e 를 릴리즈 잡 안에 넣는 방법

기존 `e2e-release-check.yml` 은 `workflow_dispatch` 전용이다. 이 워크플로우에
`workflow_call` 트리거를 **추가**해서 릴리즈 파이프라인이 `uses:` 로 호출한다.
복사해 두 벌로 만들지 않는다 — e2e 시나리오가 늘어날 때 한쪽만 고치는 일을 막는다.

기존 수동 실행(`workflow_dispatch`)도 그대로 남긴다. 릴리즈와 무관하게 e2e 만 돌려보고
싶은 경우가 있고, 기존 에스컬레이션 동작(실패 시 문서 자동 초안)도 유지된다.

### iOS 서명

현재 `ios/Runner.xcodeproj` 는 `CODE_SIGN_STYLE = Automatic` 이고
`PROVISIONING_PROFILE_SPECIFIER` 가 비어 있다. 자동 서명은 Xcode 가 Apple 계정에
로그인한 상태를 전제하므로 **헤드리스 CI 에서 돌지 않는다.**

**1.0.33+79 를 실제로 뽑아 보고 확인한 것:** 그 빌드는
`Cloud Managed Apple Distribution` 인증서로 서명됐다(`build/ios/ipa/DistributionSummary.plist`).
Xcode 가 그때그때 Apple 에서 받아 쓰는 방식이라 **개인 키가 로컬에 없어 .p12 로 내보낼 수
없다.** 실제로 이 맥의 키체인에는 `Apple Development` 하나뿐이고 배포 인증서가 없으며,
`~/Library/MobileDevice/Provisioning Profiles` 도 비어 있다.

따라서 CI 용 배포 인증서와 프로파일은 **포털에서 새로 발급해야 한다**(기존 것을 내보내는
게 아니다). 로컬 Xcode 빌드는 지금처럼 클라우드 자동 서명을 계속 쓰면 되고, 둘은 공존한다.
발급 절차는 `plan.md` 의 "사람이 직접 해야 하는 선행 작업" 에 적었다.

App Store Connect API 키(.p8)로 배포 인증서와 프로비저닝 프로파일을 CI 에서 받아 쓰고,
**Release 구성만** Manual 서명으로 바꾼다. Debug/Profile 구성은 Automatic 그대로 둬서
로컬 Xcode 개발 흐름에 영향이 없게 한다.

**주의: 프로파일이 2개 필요하다.** 이 앱은 Runner 외에 앱 익스텐션
(`WardingScheduleWidget`)이 있다.

| 타깃 | 번들 ID |
|---|---|
| Runner | `com.nar.wardingapp` |
| WardingScheduleWidget | `com.nar.wardingapp.WardingScheduleWidget` |

둘 중 하나라도 빠지면 아카이브 단계에서 실패한다. (`RunnerTests` 는 아카이브에
포함되지 않으므로 프로파일이 필요 없다.)

iOS 번들 ID 는 `com.nar.wardingapp` 이고 **Android 패키지명은 `com.warding.app` 로 다르다.**
두 플랫폼의 식별자를 섞지 않는다.

수출 규정 준수는 `ios/Runner/Info.plist` 에 `ITSAppUsesNonExemptEncryption = false` 가
이미 있어서 심사 제출이 그 질문에서 멈추지 않는다.

### Android 서명

`android/app/build.gradle.kts` 는 `rootProject.file("key.properties")` 가 있을 때만
release 서명을 쓰고, 없으면 debug 서명으로 떨어진다. `key.properties` 와 `*.jks` 는
`.gitignore` 에 있어 레포에 없다.

CI 에서는 keystore 를 base64 Secret 으로 넣고 워크플로우가 `key.properties` 와 `.jks` 를
복원한다. **복원 실패를 조용히 넘기면 debug 서명으로 빌드되어 스토어가 거부하는 aab 가
나오므로**, 복원 직후 두 파일의 존재를 확인하고 없으면 즉시 실패시킨다.

### gitignore 된 시크릿 파일 복원

서명 키 외에도 **네이버 Client Secret 파일이 양 플랫폼 모두 `.gitignore` 에 있어 CI
체크아웃에 없다.** 이것을 복원하지 않으면 릴리즈가 나가지 않는다.

| 플랫폼 | 파일 |
|---|---|
| iOS | `ios/Flutter/Secrets.xcconfig` (`NAVER_CLIENT_SECRET`) |
| Android | `android/app/src/main/res/values/naver_secrets.xml` (`naver_client_secret`) |

iOS 쪽은 `Release.xcconfig` 가 `#include?` 로 읽어서 **파일이 없어도 조용히 넘어가고**
`NidClientSecret` 이 빈 값으로 빌드된다. 1.0.14+21 때 이것 때문에 네이버 로그인만 침묵
실패한 사고가 있었고, 그 뒤 프로젝트에 "Release 면 빈 값일 때 빌드를 실패시키는" 가드
스크립트가 들어갔다. 그래서 CI 가 이 파일을 복원하지 않으면 아카이브 단계에서 그 가드에
걸려 멈춘다 (조용히 깨진 빌드가 나가지는 않는다).

Android 쪽에는 그런 가드가 없다. 없으면 리소스 참조가 깨져 빌드가 실패하거나, 네이버
로그인만 안 되는 aab 가 나올 수 있어 워크플로우가 직접 빈 값을 확인하고 중단한다.

`key.properties` 와 이 두 파일은 **heredoc 으로 쓰지 않는다.** YAML 블록 스칼라 안에서
heredoc 을 쓰면 들여쓰기가 그대로 파일 내용에 들어가 `storePassword=` 앞에 공백이 붙고,
닫는 `EOF` 도 0번 칼럼이 아니어서 heredoc 이 끝나지 않는다. `printf` 로 쓴다.

### Flutter 버전은 누가 정하는가

**빌드 잡에 Flutter 를 따로 설치하지 않는다.** `shorebird` 가 자기 Flutter 리비전을
들고 와서 빌드하기 때문이다 — 1.0.33+79 를 실제로 뽑아 보니 shorebird 의 **3.44.6** 으로
빌드됐다(`Building iOS app with Flutter 3.44.6`). 빌드 잡에서 `flutter-action` 으로
3.44.0 을 깔아 두면 "깔려는 있지만 빌드에는 안 쓰이는" 버전이 생겨 혼란스럽고, 두 버전이
어긋난 것을 못 보고 지나치게 된다.

`FLUTTER_VERSION` 은 `verify` 잡(analyze·test)에서만 쓴다. `ci-flutter-test.yml` 과 같은
값으로 맞춰, PR 에서 통과한 테스트가 릴리즈 때도 같은 조건에서 돌게 한다.

**빌드 잡에는 별도 값(`SHOREBIRD_FLUTTER_VERSION`)을 쓴다.** `shorebird-release` 액션은
`flutter-version` 이 **필수 입력**이고 항상 `--flutter-version` 으로 넘긴다. 빈 값을 주면
`Version  not found` 로 빌드가 바로 죽는다(1.0.33+81 첫 시도에서 실제로 밟았다).

값은 **`3.44.6` 로 고정**한다. `latest` 로 두면 Shorebird 가 기본 버전을 올릴 때 빌드가
조용히 다른 Flutter 로 넘어간다. 지금까지 나간 릴리즈(+74 ~ +80)가 전부 3.44.6 이라 같은
값을 쓴다. 올릴 때는 로컬에서 먼저 빌드해 보고 바꾼다.

### 버전 관리

`pubspec.yaml` 의 `version` 이 단일 출처다. 워크플로우는 버전을 **고치지 않고 검증만** 한다.
빌드 번호 자동 증가는 넣지 않는다 — 올리는 쪽이 pubspec 과 태그 양쪽을 바꾸면 커밋이
두 벌로 갈리고, 지금 태그 규칙("빌드 번호를 올려 다시 뽑으면 태그도 새로 찍는다")이
사람이 버전을 정하는 것을 전제한다.

### 필요한 Secrets

| 이름 | 용도 |
|---|---|
| `SHOREBIRD_TOKEN` | `shorebird release` 인증 (`shorebird login:ci` 로 발급) |
| `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_P8` | App Store Connect API 키 — TestFlight 업로드 |
| `IOS_DIST_CERT_P12` / `IOS_DIST_CERT_PASSWORD` | 배포 인증서 |
| `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` | Android 릴리즈 서명 |
| `IOS_PROFILE_RUNNER` / `IOS_PROFILE_WIDGET` | 프로비저닝 프로파일 2개 (앱 본체·위젯 익스텐션) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console 업로드·트랙 승격 |
| `NAVER_CLIENT_SECRET` | 네이버 로그인 — 양 플랫폼 시크릿 파일 복원 (위 "gitignore 된 시크릿 파일 복원" 참고) |
| `DISCORD_PR_WEBHOOK_URL` | 결과 알림 (**이미 있다**) |

`DISCORD_PR_WEBHOOK_URL` 외에는 전부 새로 등록해야 한다. 이 중 Apple·Google 콘솔에서
사람이 직접 발급해야 하는 것이 있어, 워크플로우를 머지해도 Secrets 가 채워지기 전에는
돌지 않는다.

## Decisions

- **트리거는 `release/*` 태그 push 다.** CLAUDE.md 의 기존 태그 규칙을 그대로 발동
  조건으로 쓴다. 지금 손으로 찍는 태그가 그대로 트리거가 되고, shorebird 가 커밋을
  남기지 않아 생기던 "이 릴리즈가 어느 코드였나" 역추적 문제도 같이 해결된다.
  `main` push 트리거는 쓰지 않는다 — 커밋마다 스토어 빌드가 나가면 안 된다.
- **심사 제출을 릴리즈 파이프라인에서 떼어내 별도 수동 워크플로우로 뺀다.** 처음에는
  릴리즈 파이프라인 안에서 제출까지 하려 했지만, 다른 프로젝트들이 어떻게 하는지 조사해
  보고 바꿨다.
  - **Apple 공식 레퍼런스 워크플로우**(`Apple-Actions/Example-macOS`)와 **Shorebird 공식
    fastlane 가이드**가 모두 TestFlight 에서 멈춘다. 표준 패턴이 `submit_for_review: false` 다.
  - `deliver submit_build` 에는 **CI 가 재시도로 넘을 수 없는 블로커**가 있다. 다른 빌드가
    이미 심사 중이면 제출이 거부된다(fastlane#12551). 빌드 번호를 잘못 고르는 버그도
    보고돼 있다(fastlane#21477).
  - 심사 제출은 되돌리기 어려운 일방향 동작이라, CLAUDE.md 가 릴리즈를 "태그를 찍고
    사람이 확인하는 의도적 행위" 로 다루는 것과도 결이 맞는다.
  - **다만 제출 자체를 손으로 하라는 뜻은 아니다.** 블로커에 걸렸을 때 릴리즈 파이프라인
    전체가 빨간불이 되는 것이 문제이지, 제출 작업을 기계가 하는 것은 그대로 이득이다.
    그래서 `submit-for-review.yml` 로 분리해 **발동 시점만 사람이 고르게** 했다.
    한국 Flutter 사례(velog, tksuns12)도 "TestFlight·내부테스트까지 자동, 그 뒤는 수동
    승격" 으로 같은 구조다.
- **Shorebird 공식 액션(`shorebirdtech/shorebird-release@v1`)을 쓴다.** 직접
  `run: shorebird release` 하지 않는다. Shorebird 가 릴리즈를 CI 에서 돌리는 것을 공식
  권장하고 전용 액션을 제공한다.
- **macOS 러너 이미지를 고정한다(`macos-15`).** 러너 이미지 업데이트가 .p12 import 를
  깨뜨려 "No valid code signing certificates were found" 가 나는 사례가 보고됐는데
  (actions/runner-images#13884), 하필 Flutter + `shorebird release ios` 환경이었다.
  서명이 걸린 잡이라 이미지 변경을 우리가 통제한다.
- **iOS 서명은 ASC API 키 + Manual 서명으로 한다.** `fastlane match` 는 인증서 전용
  private 레포를 하나 더 만들어 관리해야 하는데, 지금은 개발자가 혼자라 그 레포가
  주는 "팀 간 서명 공유" 이득이 없다. 팀이 늘면 그때 match 로 옮긴다.
- **e2e 는 릴리즈 잡 안에서 먼저 돌린다.** "릴리즈 직전 e2e 수동 실행" 규칙이 사람의
  기억에 의존하던 것을 구조적으로 강제한다. macOS 러너 비용이 릴리즈마다 들지만,
  릴리즈 빈도(최근 기준 주 1~2회)에서 감당할 수 있다.
- **버전 자동 증가는 넣지 않는다.** 위 "버전 관리" 참고.
- **릴리스 노트는 레포에서 파일로 관리한다**(`distribution/`). 콘솔에서 손으로 적으면
  릴리즈 때마다 빠뜨리기 쉽고, 무엇을 내보냈는지 기록이 남지 않는다. 파일로 두면
  릴리즈 PR 에서 코드와 같이 리뷰되고 git 히스토리에 남는다. Play 500자 제한은
  업로드 전에 워크플로우가 검사한다.
- **릴리즈 알림은 전용 Discord 채널로 보낸다**(`DISCORD_RELEASE_WEBHOOK_URL`).
  PR 알림과 섞이면 묻힌다. DAU 집계가 이미 같은 방식으로 채널을 나눠 쓴다.
  Secret 이 없으면 기존 PR 채널로 폴백해, 등록 전에도 알림이 사라지지 않는다.
- **기존 `e2e-release-check.yml` 에 `workflow_call` 을 추가해 재사용한다.** e2e 정의를
  두 벌로 복사하지 않는다.

## Out of scope

- **`shorebird patch` 자동화.** 과금이 패치 **설치 수** 기준(Free 5,000/월)이라 발행
  횟수 × MAU 로 비용이 늘어난다. 자동화보다 "언제 패치를 낼지" 판단이 먼저라 이번에는
  다루지 않는다. 릴리즈 빌드 자동화와 독립적으로 뒤에 붙일 수 있다.
- **릴리즈 브랜치 전략 변경.** 구버전 릴리즈에 패치를 낼 때 릴리즈별 브랜치가 필요해질
  수 있지만, 지금 구버전 패치는 드물다. 실제로 필요해질 때 태그에서 브랜치를 딴다.
- **심사 제출을 릴리즈 파이프라인 안에서 자동 실행하는 것.** 제출 자체는
  `submit-for-review.yml` 로 자동화했지만, 태그 push 로 자동 발동시키지는 않는다.
  위 Decisions 참고.
- **설명·키워드·스크린샷 코드 관리.** **릴리스 노트는 `distribution/` 에서 코드로
  관리한다**(아래 Decisions 참고). 다만 설명·키워드·스크린샷은 콘솔에 올라가 있는 것을
  그대로 쓴다 — `deliver` 가 `metadata/` 에 있는 파일만 덮어쓰므로 `release_notes.txt`
  만 두면 나머지는 건드리지 않는다.
- **단계적 출시 자동 승격.** `submit-for-review.yml` 이 production 에 올리는 것까지는
  하지만, 10% → 50% → 100% 로 비율을 올리는 것은 콘솔에서 사람이 한다. 크래시·ANR
  지표를 보고 판단할 일이라 자동화 대상이 아니다.
- **빌드 번호 자동 증가.** 위 Decisions 참고.

## Open questions

- **나중에 Play production 승격을 자동화한다면 단계적 출시 비율을 얼마로 둘지.** 업계
  통념은 1~10% 에서 시작하는 것이다. 지금 DAU 가 400~600 대라 10% 면 40~60 명인데,
  이 표본으로 이상을 잡아낼 수 있을지는 `mixpanel-daily-dau.yml` 집계를 더 보고 정한다.
- **릴리즈 실패 시 에스컬레이션을 붙일지.** 기존 두 워크플로우는 실패 시 Anthropic API 로
  문서 초안을 만든다. 릴리즈 실패는 대부분 서명·자격 문제라 문서보다 알림이 적합해
  이번에는 Discord 알림만 넣었다. 운영해 보고 판단한다.
