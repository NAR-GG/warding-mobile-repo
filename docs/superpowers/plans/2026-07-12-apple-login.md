# 애플 로그인 추가 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 로그인 화면에 애플 로그인 버튼을 추가하고, 기존 카카오/네이버/구글과 동일한 패턴으로 `AuthService`를 통해 백엔드 JWT를 발급받는다.

**Architecture:** `sign_in_with_apple` 패키지로 네이티브 Apple ID 자격증명(identityToken)을 받고, 기존 `AuthService._exchangeWithBackend()`에 그대로 넘겨 백엔드 교환 로직을 재사용한다. View(`login_screen.dart`)는 `Platform.isIOS`일 때만 버튼을 렌더링하고 기존 `_signIn(registrationId)` 스위치에 분기 하나만 추가한다.

**Tech Stack:** Flutter/Dart, `sign_in_with_apple: ^8.1.0`, 기존 `flutter_secure_storage`/`http` 기반 `AuthService`.

## Global Constraints

- iOS에서만 애플 로그인 버튼을 노출한다 (`Platform.isIOS`). Android는 대상 아님.
- 백엔드 엔드포인트 `POST {apiBaseUrl}/auth/mobile/apple`는 아직 없음 — 이번 작업은 클라이언트 구현까지만 다루고, 계약은 `{ "idToken": "<identityToken>" }` → `{ accessToken, refreshToken?, isOnboarded }`로 가정한다 (구글과 동일 계약). 백엔드 구현은 범위 밖.
- 색은 하드코딩하지 않고 `AppColors`에 추가 후 참조한다 (CLAUDE.md 규칙).
- 파일명 `snake_case`, 클래스명 `PascalCase`.
- 네이티브 SDK를 감싸는 코드(`AuthService`의 각 `signInWithX()`)는 이 저장소에 기존 단위 테스트가 없다 (카카오/네이버/구글도 테스트 없음) — 이 관행을 그대로 따르고, 검증은 `flutter analyze` + 수동 실기기/시뮬레이터 테스트로 한다.

---

### Task 1: `sign_in_with_apple` 패키지 추가 + iOS entitlement 설정

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Runner/Runner.entitlements`

**Interfaces:**
- Consumes: 없음.
- Produces: `package:sign_in_with_apple/sign_in_with_apple.dart` import 가능 (Task 4에서 사용). `ios/Runner/Runner.entitlements`에 `com.apple.developer.applesignin` 키 존재 (Xcode 빌드 시 참조).

- [ ] **Step 1: `pubspec.yaml`에 의존성 추가**

`pubspec.yaml`의 `dependencies:` 블록에서 `image_picker: ^1.1.2` 줄 바로 아래에 추가:

```yaml
  image_picker: ^1.1.2
  sign_in_with_apple: ^8.1.0
```

- [ ] **Step 2: 패키지 설치**

Run: `flutter pub get`
Expected: `Got dependencies!` 출력, `pubspec.lock`에 `sign_in_with_apple` 항목 추가됨.

- [ ] **Step 3: iOS entitlement에 Sign In with Apple 추가**

`ios/Runner/Runner.entitlements` 전체를 아래로 교체:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: 정적 분석으로 확인**

Run: `flutter analyze`
Expected: 기존과 동일한 결과 (이번 변경으로 인한 새 에러 없음). `pubspec.yaml`/`entitlements`만 바꿨으므로 Dart 분석 결과는 변하지 않아야 한다.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Runner.entitlements
git commit -m "feat: sign_in_with_apple 패키지 및 iOS entitlement 추가"
```

---

### Task 2: `ApiConfig`에 애플 로그인 URL 추가

**Files:**
- Modify: `lib/config/api_config.dart:30-31` (구글 로그인 URL 다음 위치)

**Interfaces:**
- Consumes: `ApiConfig.apiBaseUrl` (기존).
- Produces: `ApiConfig.appleLoginUrl` (`String` getter) — Task 4에서 사용.

- [ ] **Step 1: `appleLoginUrl` getter 추가**

`lib/config/api_config.dart`에서 아래 블록(구글 로그인 URL 정의부) 바로 다음에 추가:

```dart
  /// 구글 idToken을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용).
  static String get googleLoginUrl => '$apiBaseUrl/auth/mobile/google';
```

다음 줄로 추가:

```dart

  /// 애플 identityToken을 백엔드로 보내 검증·자체 JWT 발급 (모바일 전용, iOS 전용).
  /// 구글과 동일하게 idToken 키로 전달한다: { "idToken": "<identityToken>" }.
  /// 백엔드에 아직 이 엔드포인트가 없다면, 팀과 계약을 맞춘 뒤 이 URL/키를 조정한다.
  static String get appleLoginUrl => '$apiBaseUrl/auth/mobile/apple';
```

- [ ] **Step 2: 정적 분석으로 확인**

Run: `flutter analyze lib/config/api_config.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/config/api_config.dart
git commit -m "feat: 애플 로그인 백엔드 URL 추가"
```

---

### Task 3: `AppColors`에 애플 버튼 배경색 추가

**Files:**
- Modify: `lib/styles/app_colors.dart:59-59` (구글 배경색 정의부 근처)

**Interfaces:**
- Consumes: 없음.
- Produces: `AppColors.appleBg` (`Color`, `0xFFFFFFFF`) — Task 5에서 사용. 글자색은 기존 `AppColors.gray100`을 재사용(구글 버튼과 동일 패턴이라 신규 토큰 없음).

- [ ] **Step 1: `appleBg` 색상 토큰 추가**

`lib/styles/app_colors.dart`에서 아래 줄을 찾는다:

```dart
  static const Color googleBg = Color(0xFFFFFFFF);
```

바로 다음 줄에 추가:

```dart
  static const Color googleBg = Color(0xFFFFFFFF);
  static const Color appleBg = Color(0xFFFFFFFF);
```

- [ ] **Step 2: 정적 분석으로 확인**

Run: `flutter analyze lib/styles/app_colors.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/styles/app_colors.dart
git commit -m "feat: 애플 로그인 버튼 배경색 토큰 추가"
```

---

### Task 4: `AuthService.signInWithApple()` 구현

**Files:**
- Modify: `lib/repository/auth/auth_service.dart`

**Interfaces:**
- Consumes:
  - `SignInWithApple.getAppleIDCredential({required List<AppleIDAuthorizationScopes> scopes})` → `Future<AuthorizationCredentialAppleID>` (패키지 `sign_in_with_apple`, `identityToken` 필드는 `String?`).
  - `SignInWithAppleAuthorizationException` (필드: `AuthorizationErrorCode code`, `String message`). 취소 시 `code == AuthorizationErrorCode.canceled`.
  - `ApiConfig.appleLoginUrl` (Task 2).
  - 기존 `_exchangeWithBackend(String loginUrl, String socialToken, {String bodyKey = 'accessToken'})`.
  - 기존 `AuthCancelledException`, `AuthResult`.
- Produces: `AuthService.instance.signInWithApple()` → `Future<AuthResult>` — Task 5(`login_screen.dart`)에서 호출.

- [ ] **Step 1: import 추가**

`lib/repository/auth/auth_service.dart` 최상단 import 블록에서 아래 줄:

```dart
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
```

다음 줄에 추가 (알파벳 순서 유지):

```dart
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
```

- [ ] **Step 2: `signInWithApple()` 메서드 추가**

`signInWithGoogle()` 메서드(현재 `auth_service.dart:75-105` 근처, `_loginWithKakao()` 정의 바로 위) 다음 줄에 추가:

```dart
  /// 애플 ID로 로그인 → 받은 identityToken을 백엔드로 전달 → 자체 JWT 저장.
  /// iOS 전용 (호출 측에서 Platform.isIOS 분기).
  Future<AuthResult> signInWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      rethrow;
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw Exception('애플 로그인 응답에 identityToken이 없습니다');
    }

    // 애플은 access token이 아닌 identityToken을 백엔드가 검증한다 (구글과 동일 방식).
    return _exchangeWithBackend(
      ApiConfig.appleLoginUrl,
      identityToken,
      bodyKey: 'idToken',
    );
  }

```

- [ ] **Step 3: 정적 분석으로 확인**

Run: `flutter analyze lib/repository/auth/auth_service.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/repository/auth/auth_service.dart
git commit -m "feat: AuthService에 애플 로그인 구현 추가"
```

---

### Task 5: 로그인 화면에 애플 로그인 버튼 연결

**Files:**
- Modify: `lib/screens/login/login_screen.dart`

**Interfaces:**
- Consumes:
  - `AuthService.instance.signInWithApple()` → `Future<AuthResult>` (Task 4).
  - `AppColors.appleBg` (Task 3), 기존 `AppColors.gray100`.
  - 기존 `SocialLoginButton`, `AuthCancelledException`.
- Produces: 없음 (최종 사용자 화면 변경).

- [ ] **Step 1: `dart:io` import 추가**

`lib/screens/login/login_screen.dart` 최상단, `import 'dart:async';` 다음 줄에 추가:

```dart
import 'dart:async';
import 'dart:io' show Platform;
```

- [ ] **Step 2: `_signIn`의 `switch`에 `apple` 분기 추가**

기존:

```dart
      final result = switch (registrationId) {
        'naver' => await AuthService.instance.signInWithNaver(),
        'google' => await AuthService.instance.signInWithGoogle(),
        _ => await AuthService.instance.signInWithKakao(),
      };
```

다음으로 교체:

```dart
      final result = switch (registrationId) {
        'naver' => await AuthService.instance.signInWithNaver(),
        'google' => await AuthService.instance.signInWithGoogle(),
        'apple' => await AuthService.instance.signInWithApple(),
        _ => await AuthService.instance.signInWithKakao(),
      };
```

- [ ] **Step 3: 애플 로그인 버튼을 카카오 버튼 위(맨 위)에 추가**

기존 `build()`의 아래 블록:

```dart
              const SizedBox(width: 316, child: EasyLoginDivider()),
              const SizedBox(height: 24),
              SocialLoginButton(
                backgroundColor: AppColors.kakaoBg,
```

다음으로 교체 (애플 버튼 + `SizedBox` 삽입, iOS에서만 노출):

```dart
              const SizedBox(width: 316, child: EasyLoginDivider()),
              const SizedBox(height: 24),
              if (Platform.isIOS) ...[
                SocialLoginButton(
                  backgroundColor: AppColors.appleBg,
                  foregroundColor: AppColors.gray100,
                  icon: const Icon(
                    Icons.apple,
                    size: 20,
                    color: AppColors.gray100,
                  ),
                  label: 'Apple 로그인',
                  onTap: () => _signIn('apple'),
                ),
                const SizedBox(height: 16),
              ],
              SocialLoginButton(
                backgroundColor: AppColors.kakaoBg,
```

- [ ] **Step 4: 정적 분석으로 확인**

Run: `flutter analyze lib/screens/login/login_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login/login_screen.dart
git commit -m "feat: 로그인 화면에 애플 로그인 버튼 추가 (iOS 전용)"
```

---

### Task 6: 수동 검증 (코드 작업 아님 — Xcode/Apple Developer 계정 필요)

**Files:** 없음 (설정/검증 전용 태스크).

**Interfaces:**
- Consumes: Task 1~5에서 완성된 애플 로그인 플로우 전체.
- Produces: 없음.

이 태스크는 에이전트가 자동으로 수행할 수 없다 (Apple Developer 포털 로그인, Xcode GUI, 실기기/시뮬레이터 필요). 사용자가 직접 수행한다.

- [ ] **Step 1: Apple Developer 포털에서 capability 활성화**

`developer.apple.com` → Certificates, Identifiers & Profiles → Identifiers → 앱의 Bundle ID(`com.warding.app`) → "Sign In with Apple" capability 체크 → 저장.

- [ ] **Step 2: Xcode에서 프로비저닝 프로파일 갱신**

Xcode에서 `ios/Runner.xcworkspace` 열기 → Runner 타겟 → Signing & Capabilities → 자동 서명이면 프로파일이 자동 갱신됨 (필요 시 "Sign In with Apple" capability를 Xcode에서도 `+ Capability`로 추가 — 이미 `Runner.entitlements`에 키가 있으므로 Xcode가 인식해야 하지만, 인식 못 하면 이 단계에서 GUI로 추가).

- [ ] **Step 3: 시뮬레이터/실기기에서 로그인 플로우 확인**

Run: `flutter run` (iOS 시뮬레이터 또는 실기기 대상)
확인 항목:
- 로그인 화면 맨 위에 흰색 "Apple 로그인" 버튼이 보인다.
- 버튼 탭 → 네이티브 Apple ID 인증 시트가 뜬다.
- 인증 완료 → (백엔드 엔드포인트가 아직 없다면) `_exchangeWithBackend` 호출이 404/미구현 에러로 실패하는 것을 스낵바로 확인 — 이는 예상된 동작이며, 백엔드 팀이 `/api/auth/mobile/apple`을 구현하면 정상 동작한다.
- 인증 시트에서 취소 → 스낵바 없이 조용히 로그인 화면에 머문다 (`AuthCancelledException` 처리 확인).

- [ ] **Step 4: 백엔드 팀에 계약 공유**

`docs/superpowers/specs/2026-07-12-apple-login-design.md`의 "백엔드 계약" 섹션을 백엔드 담당자에게 전달해 `/api/auth/mobile/apple` 구현을 요청한다.

## 범위 밖

- 백엔드 `/api/auth/mobile/apple` 실제 구현 (별도 저장소).
- Android 애플 로그인 지원.
- Apple Developer 포털 capability 활성화 자체 (Task 6에서 수동 안내만 제공).
