# 소셜 로그인 흐름 정리

이 문서는 warding 앱의 소셜 로그인(카카오/네이버/구글)이 **지금 어떻게 동작하도록 만들어져 있는지**, **어디서 막혀 있는지**, **무엇을 결정해야 하는지**를 정리한 것입니다.

---

## 1. 큰 그림: OAuth 로그인은 누가 무엇을 하나

소셜 로그인은 **앱 / 백엔드 / 소셜 제공자(카카오 등)** 세 주체가 주고받습니다.
warding은 **백엔드가 OAuth를 주도하는 구조**입니다. 앱은 직접 카카오와 통신하지 않습니다.

```
┌─────────┐        ┌──────────────┐        ┌─────────────────┐
│  Flutter │        │   백엔드      │        │  카카오/네이버/   │
│   앱     │        │ api.nar.kr   │        │  구글 (제공자)    │
└────┬────┘        └──────┬───────┘        └────────┬────────┘
     │                    │                         │
  ① 로그인 버튼 탭          │                         │
     │  브라우저 세션으로     │                         │
     │  아래 URL 오픈        │                         │
     │  api.nar.kr/oauth2/authorization/kakao         │
     │───────────────────>│                         │
     │                    │  ② 카카오 로그인 페이지로    │
     │                    │     302 리다이렉트         │
     │<───────────────────┼────────────────────────>│
     │                    │                         │
     │         ③ 사용자가 카카오 로그인 + 동의           │
     │<──────────────────────────────────────────────│
     │                    │                         │
     │                    │  ④ 카카오가 인가코드를      │
     │                    │     백엔드 콜백으로 전달     │
     │                    │  api.nar.kr/login/oauth2/code/kakao
     │                    │<────────────────────────│
     │                    │                         │
     │                    │  ⑤ 백엔드가 인가코드로      │
     │                    │     토큰 발급 + 회원 처리    │
     │                    │                         │
     │  ⑥ 백엔드가 "프론트엔드 콜백 주소"로 302 리다이렉트  │
     │     (성공: 토큰 전달 / 실패: error 전달)         │
     │<───────────────────│                         │
     │                    │                         │
  ⑦ 앱이 콜백 URL에서 토큰을 꺼내 저장                   │
     │                    │                         │
```

**핵심 포인트:** 앱이 하는 일은 딱 2개입니다.
- ① 시작 URL을 브라우저로 연다
- ⑦ 백엔드가 마지막에 돌려보내는 콜백 URL에서 토큰을 꺼낸다

②~⑥은 전부 백엔드와 카카오가 알아서 합니다.

---

## 2. 지금 앱에 구현되어 있는 것

### 사용 패키지
| 패키지 | 역할 |
|---|---|
| `flutter_web_auth_2` | 보안 브라우저 세션을 열고, 정해진 콜백 스킴으로 돌아오면 URL을 잡아챔 |
| `flutter_secure_storage` | 발급받은 토큰을 안전하게 저장 |
| `http` | (추후) 토큰 갱신·API 호출용 |

### 파일 구조
| 파일 | 역할 |
|---|---|
| `lib/config/api_config.dart` | API 호스트, OAuth 시작 URL, 콜백 스킴 정의 |
| `lib/services/auth_service.dart` | OAuth 흐름 실행 → 콜백 URL에서 토큰 추출 → 저장 |
| `lib/screens/login_screen.dart` | 로그인 버튼 3개를 각 provider의 `_signIn()`에 연결 |

### 현재 코드가 기대하는 흐름
1. 카카오 버튼 탭 → `AuthService.signInWithProvider('kakao')` 호출
2. `flutter_web_auth_2`가 `https://api.nar.kr/oauth2/authorization/kakao` 를 브라우저 세션으로 오픈
3. 백엔드가 마지막에 **`warding://login-callback?accessToken=...&refreshToken=...&isOnboarded=...`** 형태로 리다이렉트한다고 **가정**
4. 앱이 그 URL의 쿼리 파라미터에서 토큰을 꺼내 `flutter_secure_storage`에 저장

### 플랫폼 설정
- **Android**: `AndroidManifest.xml`에 `warding` 스킴을 받는 `CallbackActivity` 등록 완료
- **iOS**: `flutter_web_auth_2`는 `ASWebAuthenticationSession`을 쓰므로 별도 설정 불필요

---

## 3. 지금 막혀 있는 지점 (실제로 일어난 일)

### 문제 A — 카카오 동의항목 미설정 (KOE205)
카카오 로그인 시 `KOE205` 에러:
> 설정하지 않은 동의 항목: `profile_nickname`, `account_email`

→ 백엔드가 요청하는 scope가 **카카오 개발자 콘솔에 활성화되어 있지 않음**.
→ **해결:** 카카오 콘솔에서 해당 동의항목을 "사용함"으로 설정하거나, 백엔드 scope 설정에서 제거.
   (`account_email`은 보통 "선택 동의"로 해야 검수 없이 통과)

### 문제 B — 콜백이 앱이 아니라 웹 주소로 감 ⚠️ (가장 근본적인 문제)
실제로 로그인 후 이동한 주소:
```
https://nar.kr/oauth/callback?error=oauth_failed
```

여기서 두 가지가 드러납니다:
1. `error=oauth_failed` → ⑤단계에서 백엔드 OAuth 처리가 실패함 (문제 A와 연관 가능성 큼)
2. 리다이렉트 주소가 **`https://nar.kr/oauth/callback`** (웹 주소) 임 → 앱이 기대한 `warding://login-callback` 이 아님

**즉, 백엔드는 지금 "웹 프론트엔드"로 리다이렉트하도록 고정되어 있습니다.**
앱의 `flutter_web_auth_2`는 `warding://` 스킴을 기다리는데 그게 영영 안 오므로,
**설령 로그인이 성공해도 앱은 토큰을 받지 못합니다.**

---

## 4. 결정해야 하는 것

### 결정 1 — 백엔드가 성공 시 토큰을 어떻게 넘기는가?
지금은 실패(`?error=...`)만 확인됨. **성공 시 콜백 URL 형태를 반드시 확인해야 함.**
(예: `?accessToken=...&refreshToken=...` 인지, 아니면 쿠키/세션인지)
→ 백엔드의 OAuth success handler 코드 확인 필요.

### 결정 2 — https 주소를 앱이 받게 할 방법
백엔드가 `https://nar.kr/oauth/callback` 로 리다이렉트하는 걸 유지한다면,
그 https URL을 앱이 가로채려면 아래 중 하나가 필요합니다.

| 방법 | 내용 | 백엔드 수정 | 도메인 파일 호스팅 | 비고 |
|---|---|:---:|:---:|---|
| **A. App Links / Universal Links** | OS가 `https://nar.kr/oauth/callback`을 warding 앱이 처리하도록 등록 | 불필요 | **필요** (`assetlinks.json`, `apple-app-site-association`) | 가장 깔끔. 웹 프론트와 URL 충돌 시 처리 필요 |
| **B. 커스텀 스킴** | 백엔드가 모바일일 땐 `warding://login-callback`로 리다이렉트 | **필요** | 불필요 | 현재 앱 코드가 이 방식 기준. 설정 가장 단순 |
| **C. WebView 가로채기** | 앱 내 웹뷰로 진행하다 콜백 URL을 가로챔 | (토큰 전달 형태에 따라) | 불필요 | 구글은 웹뷰 로그인 차단 → 비권장 |

### 추천
- nar.kr 도메인에 `.well-known/` 파일을 올릴 수 있다면 → **A (App Links/Universal Links)**
- 그게 어렵고 백엔드 수정이 쉽다면 → **B (커스텀 스킴)**

---

## 5. 다음 할 일 (체크리스트)

- [ ] **백엔드**: 카카오 콘솔 동의항목 활성화 또는 scope 정리 → KOE205 해결
- [ ] **백엔드**: 카카오 콘솔 Redirect URI에 `https://api.nar.kr/login/oauth2/code/kakao` 등록 확인
- [ ] **백엔드**: 서버 로그에서 `oauth_failed`의 실제 예외 원인 확인
- [ ] **백엔드**: OAuth **성공 시** 콜백 URL에 토큰을 어떤 형태로 싣는지 확인 (결정 1)
- [ ] **공통**: 위 결정 2에서 A / B 중 방식 선택
- [ ] **앱**: 선택한 방식에 맞춰 `auth_service.dart` / 플랫폼 설정 수정
- [ ] **앱**: 로그인 성공 후 온보딩 여부에 따라 화면 분기 (`login_screen.dart`의 TODO)

---

## 6. 용어 정리

| 용어 | 설명 |
|---|---|
| **인가 코드(authorization code)** | 카카오가 백엔드에 주는 1회용 코드. 이걸로 백엔드가 토큰을 교환함 |
| **Access Token** | API 호출 시 인증에 쓰는 토큰. 수명이 짧음 |
| **Refresh Token** | Access Token이 만료되면 새로 발급받을 때 쓰는 토큰. 수명이 김 |
| **콜백(callback) URL** | OAuth 흐름이 끝난 뒤 되돌아오는 주소 |
| **커스텀 스킴** | `warding://...` 처럼 앱 전용으로 등록한 URL 스킴 |
| **App Links / Universal Links** | `https://...` 주소를 특정 앱이 열도록 OS에 등록하는 기능 (Android / iOS) |
| **KOE205** | 카카오 에러. 콘솔에 설정 안 된 동의항목을 요청했을 때 발생 |
