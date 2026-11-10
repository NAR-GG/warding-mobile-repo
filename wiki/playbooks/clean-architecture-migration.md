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

## 8. 검증

```bash
fvm flutter analyze    # FVM 3.44.0 을 쓴다. PATH 의 flutter 는 pubspec 을 못 읽는다
fvm flutter test
```

기능 하나가 끝날 때마다 커밋한다. 중간 상태에서도 빌드가 통과해야 한다.

# 실제로 겪은 함정

| 증상 | 원인 | 대응 |
|---|---|---|
Entity 이름 충돌 | `player_rating` 에 이미 `MyRating` 이 있었다 | Entity 를 `MyReviewItem` 으로 |
지운 메서드를 다른 기능이 쓰고 있었다 | `grep` 을 `X.instance.` 로 좁혀서 놓쳤다 | 메서드명으로 전체 검색 |
스낵바가 안 뜸 | 반환형이 바뀌어 `catch` 가 죽은 코드가 됐다 | 6 번 참고 |
유닛 테스트가 바인딩 오류로 죽음 | `appStrings` 가 navigator context 를 거친다 | `try/catch` 로 fallback |
`sed` 치환이 안 먹음 | 긴 이름(`MyRatingPage`)을 짧은 이름(`MyRating`)보다 먼저 치환해야 한다 | Python 으로 순서 지정 |

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
