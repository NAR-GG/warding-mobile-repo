# Plan: 릴리즈 빌드·스토어 제출 자동화

## Context

- Intent: 없음 (Spec 부터 시작했다)
- Spec: [spec.md](./spec.md)

## Changes

| 파일 | 내용 |
|---|---|
| `.github/workflows/release-deploy.yml` | 신규. `release/*` 태그 push → 검증 → e2e → 빌드(iOS·Android 병렬) → TestFlight·Play 내부테스트 업로드 → Discord 알림. **심사 제출은 사람이 한다** |
| `.github/workflows/e2e-release-check.yml` | `workflow_call` 트리거 추가. 기존 `workflow_dispatch` 수동 실행과 에스컬레이션 동작은 그대로 유지한다 |
| `ios/ExportOptions-ci.plist` | 신규. CI 아카이브 전용 수동 서명 설정 (프로파일 2개: 앱 본체·위젯 익스텐션) |
| `intent/release-build-automation/spec.md` | 신규. 설계·결정 배경 |

프로젝트의 `CODE_SIGN_STYLE = Automatic` 은 **건드리지 않는다.** 로컬 Xcode 개발 흐름을
그대로 두고, CI 아카이브만 `ExportOptions-ci.plist` 로 수동 서명한다.

## 사람이 직접 해야 하는 선행 작업 (Secrets 등록)

**이 작업 없이는 워크플로우가 머지돼도 돌지 않는다.** 아래는 Apple·Google 콘솔에서
직접 발급받아야 한다. 바이너리 파일은 전부 base64 로 변환해 넣는다
(`base64 -i <파일> | pbcopy`).

### Shorebird
- `SHOREBIRD_TOKEN` — **Shorebird Console → Account → API Keys** 에서 발급한다.
  `shorebird login:ci` 는 API 키로 대체되어 폐기 예정이므로 쓰지 않는다
  (Shorebird 가 공지한 마이그레이션 기한은 2026년 9월이다).

### iOS
1. **App Store Connect API 키** (ASC → 사용자 및 액세스 → 통합 → 앱 스토어 커넥트 API)
   - TestFlight 업로드만 하므로 `App Manager` 까지는 필요 없다. 업로드 권한이면 된다.
   - `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (.p8 파일을 base64)
   - **.p8 은 한 번만 내려받을 수 있다.** 잃으면 키를 새로 만들어야 한다.
2. **배포 인증서** (Apple Distribution) — ⚠️ **지금 이 맥에는 없다. 새로 만들어야 한다.**
   - `IOS_DIST_CERT_P12` (.p12 를 base64), `IOS_DIST_CERT_PASSWORD`
   - **1.0.33+79 릴리즈를 실제로 뽑아 보고 확인한 사실이다.** 그 빌드는
     `Cloud Managed Apple Distribution` 인증서로 자동 서명됐다. Xcode 가 그때그때
     Apple 에서 받아 쓰는 방식이라 **개인 키가 로컬에 없고, 따라서 .p12 로 내보낼 수
     없다.** 키체인을 확인해도 `Apple Development` 하나뿐이고 배포 인증서는 없다
     (`security find-identity -v -p codesigning`).
   - 그래서 CI 용으로는 **Apple Developer 포털에서 Apple Distribution 인증서를 새로
     발급**해야 한다. CSR 을 만들어 올리고 받은 .cer 를 키체인에 넣은 뒤, 개인 키와
     함께 .p12 로 내보낸다. 이렇게 만든 인증서는 개인 키가 로컬에 있어 내보낼 수 있다.
   - 로컬 Xcode 빌드는 지금처럼 클라우드 자동 서명을 계속 써도 된다. 둘은 공존한다.
3. **프로비저닝 프로파일 2개** — App Store 배포용으로 각각 만든다.
   - `IOS_PROFILE_RUNNER` → `com.nar.wardingapp`
   - `IOS_PROFILE_WIDGET` → `com.nar.wardingapp.WardingScheduleWidget`
   - ⚠️ **이것도 지금 로컬에 하나도 없다** (`~/Library/MobileDevice/Provisioning Profiles`
     가 비어 있다). 자동 서명이 프로파일을 디스크에 남기지 않고 쓰기 때문이다. 위 2번에서
     만든 배포 인증서에 묶어 포털에서 새로 만들어야 한다.
   - `ExportOptions-ci.plist` 의 프로파일 **이름**(`Warding App Store` 등)을 포털에
     등록한 실제 이름과 글자까지 맞춰야 한다. 지금 들어간 이름은 가정값이라
     포털에서 확인해 고쳐야 한다.

### Android
- `ANDROID_KEYSTORE_BASE64` — **`android/upload-keystore.jks`** 를 base64.
  ⚠️ 레포에 jks 가 2개(`upload-keystore.jks`, `warding-release.jks`) 있는데, 실제
  스토어로 나가는 빌드는 **`upload-keystore.jks` + alias `upload`** 로 서명된다.
  1.0.33+79 를 직접 뽑아 aab 서명을 확인해(`CN=Changha.Jeon, OU=NAR.GG`) 이쪽이 맞는
  것을 확인했다. 다른 쪽을 넣으면 Play 가 업로드 키 불일치로 거부한다.
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`(= `upload`), `ANDROID_KEY_PASSWORD`
  — 로컬 `android/key.properties` 에 있는 값과 같게.
- `PLAY_SERVICE_ACCOUNT_JSON` — Google Cloud 서비스 계정 JSON **전문**.
  Play Console 에서 그 계정에 "앱 릴리즈 관리" 권한을 줘야 한다.

### 공통
- `NAVER_CLIENT_SECRET` — 로컬 `ios/Flutter/Secrets.xcconfig` 의 값과 같게.
  (양 플랫폼의 gitignore 된 시크릿 파일을 CI 가 이 값으로 복원한다.)

## Verification

- `flutter analyze && flutter test` — 이 변경은 Dart 코드를 건드리지 않아 영향이 없지만,
  레포 기본 게이트이므로 돌린다.
- **워크플로우 YAML 파싱** — `release-deploy.yml`·`e2e-release-check.yml` 둘 다
  파싱되고 잡 의존 그래프가 의도대로인지 확인했다.
- **`ios/ExportOptions-ci.plist`** — `plutil -lint` 통과.
- **시크릿 파일 생성 스니펫** — `key.properties`·`naver_secrets.xml`·`Secrets.xcconfig`
  를 더미 값으로 실제 생성해, 들여쓰기 군더더기 없이 각 형식으로 파싱되는지 확인했다
  (heredoc 대신 `printf` 를 쓴 이유).
- e2e (`integration_test/`): 이 변경은 spec 의 Requirements 를 바꾸지 않고 앱 동작도
  건드리지 않아 새 시나리오를 추가하지 않는다. 다만 이 워크플로우가 **기존 e2e 를
  릴리즈 게이트로 호출**하므로, 첫 릴리즈 때 e2e 잡이 정상 호출되는지 확인한다.
- **외부 도구 호출 규격을 공식 문서로 교차 확인했다.** 처음 작성한 것 중 아래가 틀려서
  고쳤다. 전부 "문법은 맞지만 아무 일도 하지 않는" 종류라 실행 전에는 드러나지 않는다.

  | 고친 것 | 왜 틀렸나 |
  |---|---|
  | `shorebird release ios -- --export-options-plist=…` → `--` 앞으로 옮김 | 이 플래그는 shorebird 가 직접 받는다. `--` 뒤는 `flutter build` 로 넘기는 자리라, 뒤에 두면 shorebird 가 서명 설정을 못 본다 |
  | `fastlane run app_store_connect_api_key` 다음에 `fastlane deliver` 호출 → `--api_key_path` 로 통합 | 두 명령이 별개 프로세스라 인증이 이어지지 않는다. 앞 명령은 in-process 상태만 세팅하고 끝난다 |
  | `fastlane deliver submit_for_review` → `fastlane deliver submit_build` | `submit_for_review` 는 서브커맨드가 아니라 플래그 이름이다. 이미 올라간 빌드를 심사에 올리는 서브커맨드는 `submit_build` 다 |
  | `r0adkll/upload-google-play@v1` → `@v1.1.5` | `@v1` 태그가 2019년에 멈춰 있다 |
  | `shorebird login:ci` → API 키 | `login:ci` 는 API 키로 대체되어 폐기 예정이다 |

  확인된 것: `.ipa` 경로(`build/ios/ipa/*.ipa`), `shorebirdtech/setup-shorebird@v1`,
  `SHOREBIRD_TOKEN` 을 env 로 넘기는 방식, `releaseFiles` 입력 이름,
  fastlane `rollout:0.1` 형식과 `version_code` 필요성.

### 실제 검증은 첫 릴리즈에서만 가능하다

워크플로우는 `release/*` 태그 push 로만 돌고, 스토어 업로드·심사 제출은 되돌리기가
어렵다. 그래서 머지만으로는 끝까지 검증되지 않는다. 첫 적용은 다음 순서로 한다.

1. Secrets 를 전부 등록한다.
2. **버전을 올리지 않은 상태로** 태그를 하나 찍어 `verify` 잡까지만 통과하는지 본다
   (버전 불일치로 일부러 실패시켜, 검증 스텝이 실제로 막는지 확인한다).
3. 실제 릴리즈 버전으로 태그를 찍어 끝까지 돌린다. 첫 회는 Actions 로그를 지켜보고,
   `submit` 잡 전에 멈춰야 하면 워크플로우를 취소한다.
4. 잘 돌면 CLAUDE.md 의 릴리즈 절차를 갱신한다 — "태그를 찍으면 TestFlight·내부테스트
   까지 자동, 심사 제출은 콘솔에서 수동". 자동화가 검증되기 전에는 고치지 않는다.
