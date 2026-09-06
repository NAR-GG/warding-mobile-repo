# warding

[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-lightgrey.svg)](./LICENSE) [![Flutter](https://img.shields.io/badge/flutter-3.44.0-02569B?logo=flutter&logoColor=white)](./.fvmrc) [![Shorebird](https://img.shields.io/badge/shorebird-code%20push-6C47FF)](https://shorebird.dev) ![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)

warding는 LCK 등 e스포츠 팬을 위한 Flutter 기반 모바일 앱입니다. 경기 정보, 커뮤니티, 알림 등
팬 경험을 하나의 앱에 담기 위해 MVVM 아키텍처와 Shorebird 코드 푸시를 기반으로 개발되고
있습니다.

이 앱은 다음으로 만들어졌습니다:
- 📱 Flutter 기반 크로스플랫폼 (iOS / Android)
- 🏗️ MVVM 아키텍처 — ViewModel(`ChangeNotifier`) / View(`ListenableBuilder`) 분리
- 🔐 카카오·네이버·구글·Apple 소셜 로그인
- 🔔 Firebase 푸시 알림 + 홈 화면 위젯(`home_widget`)
- 🚀 Shorebird 코드 푸시 — 스토어 심사 없이 Dart 코드 핫픽스
- 🐞 Sentry 크래시·에러 모니터링

## 기술 스택

- **Flutter / Dart** - 크로스플랫폼 UI 프레임워크 (`sdk ^3.11.5`, `fvm`으로 `3.44.0` 고정)
- **ChangeNotifier + ListenableBuilder** - 상태 관리 (별도 상태관리 라이브러리 없이 Flutter 기본기 사용, MVVM)
- **http** - REST API 통신
- **flutter_secure_storage / shared_preferences** - 로컬 저장 (토큰은 secure storage, 비민감 설정은 shared_preferences)
- **firebase_core + firebase_messaging + flutter_local_notifications** - 푸시 알림
- **kakao_flutter_sdk_user / flutter_naver_login / google_sign_in / sign_in_with_apple** - 소셜 로그인
- **sentry_flutter** - 크래시·에러 모니터링
- **home_widget** - iOS/Android 홈 화면 위젯
- **flutter_svg / cached_network_image** - 이미지 처리
- **Shorebird** - 코드 푸시 배포 (스토어 심사 없이 Dart 코드 핫픽스)

## 시작하기

### 사전 요구사항

- Flutter 3.44.0 (`fvm use` 권장 — `.fvmrc`에 고정)

### 설치 및 실행

`.fvmrc`에 고정된 버전을 쓰려면 [fvm](https://fvm.app)을 먼저 설치합니다.

```bash
fvm install       # .fvmrc에 명시된 Flutter 3.44.0 설치
fvm use            # 현재 프로젝트에 적용
```

의존성 설치 후 실행합니다.

```bash
flutter pub get
flutter run          # 실행
flutter test         # 테스트
flutter analyze       # 정적 분석
```

## 아키텍처

**MVVM** 구조를 따른다. 상태와 로직은 ViewModel에, UI는 View에 둔다.

- **Model** (`model/`, `repository/`) - 데이터 모델 클래스와 데이터 소스(API)
- **ViewModel** (`viewmodel/`) - `ChangeNotifier`를 상속. 화면 상태·비즈니스 로직을 담당하고
  `notifyListeners()`로 통지. `BuildContext`에 의존하지 않고, 화면 전환은 콜백으로 View에 위임
- **View** (`screens/`) - UI만 담당. `ListenableBuilder`로 ViewModel을 구독하고, 사용자 이벤트는
  ViewModel 메서드 호출로 위임

### 프로젝트 구조

```
lib/
├── config/       앱 설정 (API URL, secure storage, 언어 등)
├── model/        데이터 모델 클래스
├── repository/   API 통신·데이터 소스 (기능별 하위 폴더)
├── viewmodel/    ViewModel (기능별 하위 폴더)
├── screens/      화면 (기능별 폴더)
├── components/   앱 전역 공용 위젯
├── styles/       디자인 토큰 (AppColors 등)
├── l10n/         다국어 리소스
└── util/         유틸리티
```

새 기능을 추가할 때 파일 위치·네이밍 규칙, 색상 토큰(`AppColors`) 사용 규칙, UI 비율
스케일(`scale`) 패턴은 `CLAUDE.md`를 참고한다.

## 상태 관리 전략

1. **화면 상태**: `ChangeNotifier` 기반 ViewModel + `ListenableBuilder`
2. **로컬 저장**: 토큰 등 민감 정보는 `flutter_secure_storage`, 그 외 설정은 `shared_preferences`
3. **폼**: 별도 라이브러리 없이 Flutter 기본 `Form`/`TextEditingController`

## 클라이언트 기본 설정

- `lib/config/api_config.dart` - API base URL 등 환경 설정
- `lib/config/secure_storage.dart` - 토큰 저장/조회 (Keychain 잠금 중 읽기 실패 등 함정으로 인해
  민감하지 않은 값은 `shared_preferences`로 분리해 둠)
- `lib/config/app_globals.dart` / `app_language.dart` - 전역 상태·언어 설정

## Contributing

협업 규칙(브랜치 전략, PR 컨벤션), API 스펙 갱신, 릴리즈 절차는
[CONTRIBUTING.md](./CONTRIBUTING.md), 아키텍처·폴더 규칙·색상 토큰은 `CLAUDE.md`를
참고하세요.

## Contributors

<a href="https://github.com/NAR-GG/warding-mobile-repo/graphs/contributors">
  <img alt="warding 기여자 목록" src="https://contrib.rocks/image?repo=NAR-GG/warding-mobile-repo" />
</a>

## License

Copyright (c) 2026 NAR. All rights reserved — see [LICENSE](./LICENSE) for details.
