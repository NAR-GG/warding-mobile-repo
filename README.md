# warding

LCK 등 e스포츠 팬을 위한 모바일 앱. Flutter로 만들었다.

## 시작하기

Flutter 3.x 설치 후:

```bash
flutter pub get
flutter run          # 실행
flutter test         # 테스트
```

## 프로젝트 구조

MVVM 구조를 따른다. 상세 규칙(폴더 배치, 색상 토큰, UI 스케일)은 `CLAUDE.md` 참고.

| 폴더 | 역할 |
|------|------|
| `lib/model/` | 데이터 모델 |
| `lib/repository/` | API 통신 (기능별 하위 폴더) |
| `lib/viewmodel/` | 화면 상태·로직 (ChangeNotifier) |
| `lib/screens/` | 화면 UI (기능별 폴더) |
| `lib/components/` | 전역 공용 위젯 |
| `lib/styles/` | 디자인 토큰 (AppColors) |

## 협업 규칙

1. main에 직접 push할 수 없다. 모든 변경은 PR로 머지한다. (ruleset으로 강제됨)
2. PR 제목은 `feat:` / `fix:` 접두사로 시작한다. PR 제목이 그대로 릴리즈 노트가 된다.
3. `pubspec.yaml`의 version은 기능 PR에서 올리지 않는다. 릴리즈 직전 버전 bump PR에서만 올린다.

## 릴리즈

버전의 진실은 `pubspec.yaml`의 `version: X.Y.Z+N` 하나다.
`X.Y.Z`는 스토어 표시 버전, `+N`은 versionCode라 스토어 제출마다 반드시 +1 한다.

스토어 제출 순서:

```bash
# 1. pubspec version 올리는 PR 머지 (예: 1.0.1+4)
# 2. 제출한 커밋에 태그
git tag v1.0.1+4 && git push origin v1.0.1+4
# 3. GitHub Release 생성 — 릴리즈 노트는 PR 제목에서 자동 생성
gh release create v1.0.1+4 --generate-notes
```

릴리즈 담당 1명이 bump·태그·release 생성까지 소유한다.
