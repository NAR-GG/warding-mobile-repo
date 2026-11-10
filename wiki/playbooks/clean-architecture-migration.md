---
type: Playbook
title: 기능 하나를 Clean Architecture 로 옮기는 절차
description: feature 단위 구조 위에 data/domain/presentation 계층을 적용하는 순서와 실제로 겪은 함정.
tags: [architecture, migration, playbook]
timestamp: 2026-11-10T00:00:00Z
---

# 목적

`features/{기능}/` 아래를 `data`·`domain`·`presentation` 세 계층으로 나눈다.
구조 전환(폴더 이동)은 2026-11-10 에 27 개 기능 전부 끝났고, 이 문서는 그 위에
**계층과 인터페이스를 넣는** 작업을 다룬다.

목적은 둘이다.
1. **테스트** — repository 인터페이스가 있으면 `mocktail` 로 Mock 이 된다. 전에는 구현을
   `implements` 해야 해서 테스트마다 Fake 를 손으로 썼다(49 개).
2. **실패 처리 강제** — `Either<Failure, T>` 를 쓰면 `try/catch` 를 빠뜨릴 수 없다.

# 진행 상황

**API 를 타는 repository 23 개가 대상이고 2 개가 끝났다.** 로컬 저장소 전용 7 개는 대상이
아니다(아래 기준 참고).

| 완료 | 날짜 |
|---|---|
| `my_review`, `shorts` | 2026-11-10 |

남은 21 개는 아래 "순서" 를 따른다.

# 목표 구조

```
features/{기능}/
├── data/
│   ├── models/        DTO (fromJson 을 갖는다)
│   ├── mappers/       DTO → Entity. 추상화하지 않는다
│   └── repositories/  {X}RepositoryImpl — 예외를 Failure 로 바꾸는 유일한 지점
├── domain/
│   ├── entities/      순수 Entity. JSON 을 모른다
│   ├── repositories/  {X}Repository (abstract interface class)
│   └── usecases/      ★ 아래 조건에 맞을 때만 만든다
└── presentation/
    ├── viewmodels/    ChangeNotifier 유지
    ├── models/        UI State — Entity → 화면 표현, Failure → 문구
    ├── screens/
    └── widgets/
```

## UseCase 는 함부로 만들지 않는다

처음 `my_review` 에 UseCase 2 개를 만들었는데 파라미터만 옮기는 통과 계층이었다.
**다음 중 하나에 맞을 때만 만든다.**

- 여러 repository 를 조합한다 (`Future.wait` 로 묶는 지점)
- 로직이 복잡해 ViewModel 이 비대해진다
- 같은 조합이 여러 ViewModel 에서 재사용된다

해당 기능: `home`(repository 13 개, 조합 5 곳), `community`, `subscription`, `schedule`.
그 외에는 **ViewModel 이 repository 인터페이스를 직접 쓴다.**

## DataSource 도 기본은 만들지 않는다

repository 구현 하나만 쓰는 HTTP 호출이면 Impl 안에 둔다. 분리하면 파일 하나와 호출 한
단계만 늘어난다 — 교체 가능성도 Mock 필요도 없는 계층은 추상화하지 않는다.

## 로컬 저장소 전용 repository 는 대상이 아니다

**다음 7 개는 그대로 둔다.**

```
core/infrastructure/preference/  calendar_week_start · filter · notice ·
                                 onboarding · spoiler · team
features/community/data/         community_draft_repository
```

이 작업의 두 목적을 **이미 충족**하기 때문이다.

- **테스트** — `extends Mock implements X` 는 인터페이스가 아니어도 된다. 실제로
  `MockFilterPreferenceRepository extends Mock` 로 이미 테스트하고 있다. 게다가
  `FlutterSecureStorage` 를 주입받으므로 저장소 자체도 갈아끼울 수 있다.
- **실패 강제** — `Either` 로 감쌀 실패 분기가 없다. `load()` 는 실패를 내부에서 흡수하고
  기본값으로 떨어진다(`CalendarWeekStart.monday`). 호출부가 알아야 할 실패가 아니라
  "설정을 못 읽었으면 기본값" 이 맞는 동작이다. 여기에 `match` 를 강요하면 호출부마다
  의미 없는 분기가 생긴다.

판별 기준: **네트워크를 타지 않고 실패가 기본값으로 수렴하면 그대로 둔다.**

## 인프라끼리 쓰는 repository 도 대상이 아니다

`core/infrastructure/device/device_repository.dart` — 호출부가 ViewModel 이 아니라
`auth_service`·`fcm_service` 다. `registerDevice` 는 비로그인·스토리지 잠금 상황에서
**조용히 건너뛰고 다음 기회에 등록**하며 반환형이 `Future<void>` 라 호출부가 결과를 쓰지
않는다.

여기에 `Either` 를 씌우면 호출부에 의미 없는 `match` 만 생긴다. 같은 이유로
`ad_repository`·`live_activity_push_token_repository` 도 호출부를 먼저 확인한다 —
ViewModel 이 결과로 화면을 바꾸지 않으면 그대로 둔다.

**기준: 실패가 사용자에게 보이지 않고 호출부가 결과를 쓰지 않으면 그대로 둔다.**

## DTO/Entity 분리도 생략할 수 있다

모델이 중첩 클래스로 깊으면 복제 비용이 이득을 넘는다. `CategoryTree` 는 클래스 5 개
90 줄이라, DTO·Entity·Mapper 를 다 만들면 260 줄이 되는데 얻는 것은 "서버 필드명 변경이
mapper 까지만 번진다" 하나뿐이다.

**트리 구조가 서버 스펙과 1:1 이고 파생 로직이 없으면 기존 모델을 그대로 쓴다.** Interface
와 `Either` 만 적용한다 — 그 둘이 이 작업의 실제 이득이다.

반대로 분리하는 편이 나은 경우: 파생 getter 가 있다(`hasMore`), 필드가 많아 서버 변경이
잦다, 한 Entity 를 여러 응답이 조립한다.

# 절차

## 1. 소유권·호출부를 먼저 센다

```bash
# 이 repository 를 어느 기능이 쓰나
grep -rl "features/{기능}/data/{x}_repository" lib --include="*.dart" \
  | sed -E 's|lib/features/([a-z_]+)/.*|\1|' | sort -u
```

**`home`·`splash` 는 소비처로 세지 않는다.** 집계·초기화 화면이라 거의 모든 기능을 당긴다.
→ 자세한 기준은 [폴더 구조](/architecture/folder-structure.md)의 "소유자 판단 기준".

호출부 수가 곧 작업량이다. 5 곳이면 연쇄 수정이 5 번 일어난다.

## 2. Entity 와 DTO 를 가른다

기존 모델에 `fromJson` 이 있으면 그것이 DTO 다.

```
data/models/{x}_dto.dart       기존 모델 복사 → 클래스명에 Dto 접미사
domain/entities/{x}.dart       fromJson 제거한 순수 타입
data/mappers/{x}_mapper.dart   static toDomain(dto)
```

도메인 관심사(`hasMore` 같은 파생 getter)는 **Entity 로 옮긴다.** DTO 는 서버 응답 모양만
안다.

## 3. Interface → Impl

```dart
// domain/repositories/{x}_repository.dart
abstract interface class XRepository {
  Future<Either<Failure, Y>> fetchY({...});   // Query: fetch~
  Future<Either<Failure, Unit>> deleteY({...}); // Command: 동사
}
```

Impl 은 `core/data/failure_mapper.dart` 의 `toFailure(e, op: '...')` 를 쓴다. 같은
`switch` 를 30 개 repository 에 복제하지 않는다.

2xx 가 아니면 `ApiStatusException(statusCode, endpoint:)` 를 던지고 `catch` 에서 변환한다 —
상태 코드가 있어야 401·403 을 `UnauthorizedFailure` 로 가를 수 있다.

## 4. DI 등록

`core/di_container.dart` 에 한 줄 추가한다.

```dart
di.registerLazySingleton<XRepository>(XRepositoryImpl.new);
```

기존 `XRepository.instance` 싱글턴은 지우고 호출부를 `di<XRepository>()` 로 바꾼다.
ViewModel 생성자는 테스트용으로 주입을 받아 둔다.

```dart
XViewModel({XRepository? repository}) : _repo = repository ?? di<XRepository>();
```

**주의 — 기본값을 `di<X>()` 로 바꾸면 주입하지 않는 기존 테스트가 전부 깨진다.**
`GetIt: ... is not registered` 로 **생성 자체가 터지는데 런타임 오류라 `analyze` 가 잡지
못한다.** 실제로 `ShortsRepository` 를 바꿨을 때 111 개가 한꺼번에 깨졌다 — 화면 테스트들이
repository 를 주입하는 대신 HTTP 클라이언트만 가짜로 갈아끼우기 때문이다.

`test/flutter_test_config.dart` 가 모든 테스트 전에 `configureDependencies()` 를 부르므로
이제는 한 곳에서 해결된다. 개별 테스트에 추가하지 않는다.

## 5. ViewModel 의 try/catch 를 Either 분기로

```dart
final result = await _repo.fetchY();
result.match(
  (failure) => _failure = failure,
  (data) { ... },
);
```

`finally` 로 정리하던 코드는 `match` 뒤로 내린다. **`gen`/`_disposed` 가드 위치를 옮기지
않는다** — 원래 `try` 안에서 `return` 하던 것을 `match` 앞으로 빼야 한다.

**치환으로 `try` 블록을 지울 때 닫는 중괄호를 같이 지웠는지 확인한다.** 고아 `}` 가
남으면 클래스 구조가 깨져서 **그 파일을 쓰는 모든 곳에 "메서드가 정의되지 않았다" 가
번진다** — `home_viewmodel` 에서 에러가 2 개에서 216 개로 늘어난 적이 있다. 에러 수가
갑자기 뛰면 문법 오류를 먼저 본다(원인 메서드가 아니라 엉뚱한 파일에 에러가 찍힌다).

## 6. 호출부를 전부 확인한다

`analyze` 가 잡지 못하는 회귀가 있다. 반환형이 `void` → `bool` 로 바뀌면 호출부의
`try/catch` 가 **조용히 죽은 코드**가 된다.

```bash
grep -rn "\.{메서드}(" lib --include="*.dart"   # 직접 눈으로 본다
```

실제로 `my_review` 에서 삭제 실패 스낵바가 영원히 안 뜨는 상태가 됐었다.

## 7. 테스트

- 손으로 쓴 Fake → `class _MockX extends Mock implements XRepository {}`
- 명명 인자는 `any(named: 'page')` 로 스텁한다
- `Future<T>` 를 돌려주던 Fake 는 `Right(...)`/`Left(...)` 로 바꾼다
- **실패 경로 테스트를 새로 추가한다** — 이게 이 작업의 핵심 이득이다
  (`my_review` 는 4 개 → 7 개가 됐고 네트워크·401·부분 실패를 처음 덮었다)
- DTO 파싱 테스트는 `test/features/{기능}/data/` 로 옮긴다
- **정규식으로 스텁을 일괄 치환하지 않는다.** 한 테스트 파일에 전환된 repository 와 아직
  전환 안 된 repository 의 스텁이 섞여 있어서, `thenAnswer`·`thenThrow` 를 통째로 바꾸면
  건드리면 안 되는 쪽까지 깨진다(`match_detail_rating_test` 에서 에러가 13 → 30 개로 늘었다).
  **대상 repository 변수명으로 좁혀서** 치환한다 — `rating.fetchGameRatings` 처럼.
- 다중행 스텁을 `Right(...)` 로 감쌀 때 닫는 괄호를 빠뜨리기 쉽다. 치환 후 `analyze` 가
  "Expected to find ';'" 를 내면 그것이다.
- **다중행 스텁은 정규식으로 감싸지 말고 괄호를 세서 닫는다.** `match_detail` 에서 정규식을
  쓰다가 에러가 17 → 195 개로 폭증했다(`git checkout` 으로 되돌렸다). 여는 괄호 위치부터
  depth 를 세어 대응하는 닫는 괄호를 찾고 그 뒤에 `)` 를 넣는 방식이 안전하다.

```python
# 여는 괄호에서 depth 를 세어 짝을 찾는다
depth = 0
j = open_pos
while j < len(text):
    if text[j] == '(': depth += 1
    elif text[j] == ')':
        depth -= 1
        if depth == 0: break
    j += 1
text = text[:open_pos] + "Right(" + text[open_pos:j+1] + ")" + text[j+1:]
```

- **`git checkout <테스트파일>` 로 되돌리면 그 파일의 import 경로 치환도 함께 날아간다.**
  되돌린 뒤 `analyze` 가 "Target of URI doesn't exist" 를 내면 그것이다 — 경로 치환을
  다시 적용한다. 치환 실패를 되돌릴 때는 **그 파일만** 되돌리고, 경로 수정은 별도로
  다시 하는 편이 혼동이 적다.
- 스텁이 2~3 줄이면 정규식을 쓸 이유가 없다. 줄 전체를 문자열로 찾아 바꾼다.

## 8. 검증

```bash
fvm flutter analyze    # FVM 3.44.0 을 쓴다. PATH 의 flutter 는 pubspec 을 못 읽는다
fvm flutter test
```

기능 하나가 끝날 때마다 커밋한다. 중간 상태에서도 빌드가 통과해야 한다.

**검증과 커밋을 같은 명령에 묶지 않는다.** `analyze && commit` 으로 붙이면 결과를 보기
전에 커밋이 실행된다 — 실제로 "2 issues found" 를 그대로 커밋한 적이 있다. 둘을 나눠
실행하고, `analyze` 가 "No issues found", `test` 가 "All tests passed!" 를 낸 것을
**눈으로 확인한 뒤** 커밋한다.

# 실제로 겪은 함정

| 증상 | 원인 | 대응 |
|---|---|---|
Entity 이름 충돌 | `player_rating` 에 이미 `MyRating` 이 있었다 | Entity 를 `MyReviewItem` 으로 |
지운 메서드를 다른 기능이 쓰고 있었다 | `grep` 을 `X.instance.` 로 좁혀서 놓쳤다 | 메서드명으로 전체 검색 |
스낵바가 안 뜸 | 반환형이 바뀌어 `catch` 가 죽은 코드가 됐다 | 6 번 참고 |
유닛 테스트가 바인딩 오류로 죽음 | `appStrings` 가 navigator context 를 거친다 | `try/catch` 로 fallback |
`sed` 치환이 안 먹음 | 긴 이름(`MyRatingPage`)을 짧은 이름(`MyRating`)보다 먼저 치환해야 한다 | Python 으로 순서 지정
테스트 111 개가 `GetIt is not registered` 로 깨짐 | 기본값을 `di<X>()` 로 바꿨는데 테스트가 주입을 안 한다. `analyze` 는 못 잡는다 | `test/flutter_test_config.dart` 가 전역으로 등록한다 (4 번 참고)
`match_list` 만 돌려 보고 "통과" 라고 보고 | 하위 디렉터리 테스트만 확인했다 | **커밋 전에 반드시 `fvm flutter test` 전체를 돌리고 마지막 줄을 확인한다** |

# 순서

대상은 **API 를 타는 repository 23 개**다(로컬 저장소 7 개는 위 기준으로 제외).
그중 2 개가 끝났다. repository 를 공유하는 것끼리 묶어 각 단계 끝에서 빌드·테스트를 통과시킨다.

| 단계 | repository | 소유 기능 | UseCase |
|---|---|---|---|
| ✅ | `my_review_repository` | `my_review` | 없음 |
| ✅ | `shorts_repository` | `shorts` | 없음 |
| 1 | `category_repository` | `match_list` | 없음 |
| 1 | `profile_image_repository` | `profile_edit` | 없음 |
| 1 | `device_repository` | `@core/device` | 없음 |
| 2 | `notice_repository` | `notice` | 없음 — **캐시·in-flight 합류·타임아웃** |
| 2 | `standings_repository` | `home` 소유 | 없음 |
| 3 | `rating_repository` | `player_rating` | 없음 — 호출부 4 곳 |
| 3 | `match_detail_repository`, `match_subscription_repository` | `match_detail` | 없음 |
| 4 | `onboarding_repository` | `onboarding` | 없음 — 호출부 많음 |
| 4 | `player_repository` | `player` | 없음 |
| 5 | `schedule_repository` | `schedule` | **있음** |
| 6 | `subscription_repository` | `subscription` | **있음** |
| 6 | `member_notification_repository`, `quiet_hours_repository` | `@core/notification` | 없음 |
| 7 | `community_repository`, `community_image_repository`, `community_report_repository` | `community` | **있음** |
| 7 | `community_activity_repository` | `my_community_activity` | 없음 |
| 8 | `home_api_sources` | `home` | **있음** |
| 8 | `ad_repository`, `live_activity_push_token_repository` | `@core` | 없음 |

**8 번이 마지막인 이유**는 `home` 이 나머지 전부를 소비하기 때문이다. 먼저 하면 아직 안 바뀐
repository 와 바뀐 것이 섞인다.

화면만 있는 기능(`guide`·`cheer_ad`·`notification`·`login`·`splash`·`withdraw`·
`account_setting`·`my_subscription_setting`·`calendar_setting`·`match_list_setting`)은
자기 repository 가 없어 계층 작업이 없다. 다른 기능의 Interface 를 쓰게 되면 그때 호출부만
바뀐다.

# 관련

- 구조: [폴더 구조](/architecture/folder-structure.md)
- 파일 위치: [파일 생성 규칙](/architecture/file-conventions.md)
- 계층 책임: [MVVM 패턴](/architecture/mvvm.md)
- 새 기능 추가: [새 기능 추가 플레이북](/playbooks/add-feature.md)

# Citations

[1] [CLAUDE.md — 폴더 구조·파일 생성 규칙](../../CLAUDE.md)
