# 애플 로그인 추가

## 배경

현재 로그인 화면(`login_screen.dart`)은 카카오·네이버·구글 3개 소셜 로그인을 제공한다.
`AuthService`가 각 SDK에서 받은 소셜 토큰을 백엔드(`POST /api/auth/mobile/{provider}`)로 보내
자체 JWT를 발급받는 동일한 패턴을 쓴다.

여기에 **애플 로그인**(iOS 전용)을 같은 패턴으로 추가한다.

이 저장소는 모바일 앱(`warding-mobile-repo`)이며 백엔드는 별도 저장소다.
백엔드에 애플 로그인 검증 엔드포인트(`/api/auth/mobile/apple`)가 아직 없으므로,
이번 작업은 **클라이언트 구현 + 백엔드 계약 명시**까지만 다루고, 실제 백엔드 구현은 범위 밖이다.

## 범위

- iOS에서만 애플 로그인 버튼 노출 (`Platform.isIOS`). Android는 대상 아님.
- 신규 패키지: `sign_in_with_apple` (Apple 공식 유지 Flutter 플러그인).

## 백엔드 계약 (가정 — 백엔드 팀 확인 필요)

기존 구글 로그인과 동일한 형태로 가정한다.

```
POST {apiBaseUrl}/auth/mobile/apple
Content-Type: application/json
Body: { "idToken": "<Apple identityToken (JWT)>" }

Response (200): { accessToken, refreshToken?, isOnboarded }
```

- 구글이 `idToken`을 바디 키로 쓰는 것과 동일하게, 애플의 `identityToken`도 `idToken` 키로 보낸다.
- 백엔드가 이 계약과 다르게 구현하면 `ApiConfig.appleLoginUrl` / `bodyKey`만 맞춰 수정하면 된다.

## 클라이언트 구현

### `pubspec.yaml`
- `sign_in_with_apple` 최신 안정 버전 추가.

### `ios/Runner/Runner.entitlements`
- `com.apple.developer.applesignin` 키를 `Default` 값으로 추가.
- (코드 밖 작업, TODO로 남김) Apple Developer 포털에서 App ID에 "Sign In with Apple" capability 활성화 + 프로비저닝 프로파일 재생성 필요.

### `lib/config/api_config.dart`
- `appleLoginUrl` getter 추가: `$apiBaseUrl/auth/mobile/apple`.

### `lib/repository/auth/auth_service.dart`
- `signInWithApple()` 메서드 추가 (기존 `signInWithGoogle()`과 동일한 구조):
  1. `SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName])` 호출.
  2. 사용자가 취소하면(`SignInWithAppleAuthorizationException`, code `canceled`) `AuthCancelledException`을 던진다 (다른 소셜 로그인과 동일하게 처리).
  3. 받은 `identityToken`이 없거나 비어있으면 예외.
  4. `_exchangeWithBackend(ApiConfig.appleLoginUrl, identityToken, bodyKey: 'idToken')` 호출해 기존 JWT 교환 로직 재사용.
- `signOut()`: 애플은 클라이언트에서 무효화할 세션이 없으므로 별도 처리 불필요.

### `lib/styles/app_colors.dart`
- `appleBg = Color(0xFFFFFFFF)` 추가.
- 글자색은 구글 버튼과 동일하게 기존 `gray100`(검정) 재사용 — 새 토큰 추가하지 않음.
- (다크 배경(`narDark800`)에서는 애플 공식 가이드가 흰색/아웃라인 버튼을 권장하므로, 구글 버튼과 톤을 맞춘 흰 배경 버튼으로 통일.)

### `lib/screens/login/login_screen.dart`
- `Platform.isIOS`일 때만 애플 버튼을 렌더링.
- 배치 순서: 카카오 버튼 **위**, 맨 위 (App Store 심사 가이드라인 4.8 — 다른 소셜 로그인이 있으면 애플 로그인도 동등하거나 더 눈에 띄게 제공해야 함).
- 아이콘: 별도 svg 에셋 없이 Flutter 내장 `Icon(Icons.apple, color: AppColors.gray100)` 사용.
- 라벨: `'Apple 로그인'` (기존 `'카카오 로그인'`, `'네이버 로그인'`, `'Google 로그인'`과 동일한 네이밍 패턴).
- `_signIn(registrationId)`의 `switch`에 `'apple' => await AuthService.instance.signInWithApple()` 분기 추가.

## 데이터 흐름

```
(iOS && 버튼 탭) → _signIn('apple')
  → AuthService.signInWithApple()
    → SignInWithApple.getAppleIDCredential(...)
      취소 → AuthCancelledException (스낵바 없이 종료, 기존 패턴과 동일)
      성공 → identityToken 추출
        → _exchangeWithBackend(appleLoginUrl, identityToken, bodyKey: 'idToken')
          → AuthResult{jwt, isOnboarded} 저장 + 반환
  → (login_screen 공통 후처리는 기존과 동일) FCM 토큰 등록 → 온보딩 동기화 → 화면 전환
```

## 에러 처리

- 사용자 취소: `AuthCancelledException` → 스낵바 없이 조용히 종료 (기존 카카오/네이버/구글과 동일).
- `identityToken` 누락: `Exception('애플 로그인 응답에 identityToken이 없습니다')` → 로그인 화면에서 스낵바로 표시 (기존 에러 처리 경로 재사용, `login_screen.dart` 수정 없음).
- 백엔드 교환 실패(4xx/5xx): 기존 `_exchangeWithBackend`의 에러 처리 그대로 재사용.

## 테스트

- 기존 카카오/네이버/구글 로그인과 마찬가지로 네이티브 SDK 호출을 감싸는 코드라 단위 테스트 대상 로직이 거의 없음 (저장소에 기존 auth 테스트 없음 — 동일 기조 유지).
- 검증은 실기기/시뮬레이터 수동 테스트로 한다 (Xcode에서 capability 활성화 후).

## 범위 밖

- 백엔드 `/api/auth/mobile/apple` 실제 구현 (별도 저장소, 백엔드 팀 작업).
- Android 애플 로그인 지원 (Service ID·Redirect URI 등 웹 기반 OAuth 추가 설정 필요, 이번 요청 범위 아님).
- Apple Developer 포털에서의 capability 활성화·프로비저닝 프로파일 재발급 (계정 작업, 코드로 불가능).
