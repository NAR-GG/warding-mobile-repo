# 평점·리뷰 전체 연동 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 경기상세 "선수 평점" 탭·선수 평점 상세·마이페이지 "내 리뷰/평점" 세 화면을 백엔드 평점·리뷰 API에 MVVM으로 연동한다 (목업 제거).

**Architecture:** 접근 A — 경기상세 평점 탭 로드는 기존 `MatchDetailViewModel`에 흡수(세트별 탭 패턴), 독립 화면 2개는 새 VM `PlayerRatingViewModel`/`MyReviewViewModel` 신설. 조회 GET은 optional-auth(비회원 허용), 작성/삭제/내평가는 `authorizedRequest`(미로그인 시 로그인 유도).

**Tech Stack:** Flutter, `http`, `ChangeNotifier`(MVVM), `flutter_secure_storage`(JWT), 테스트는 `flutter_test` + `mocktail`(신규 dev dep, 코드생성 없음).

**Spec:** [docs/superpowers/specs/2026-06-16-review-rating-integration-design.md](../specs/2026-06-16-review-rating-integration-design.md)

---

## File Structure

**생성:**
- `lib/model/my_rating_list.dart` — `me/ratings` 응답 모델(`MyRatingList`/`MyRatingItem`/`MatchInfo`)
- `lib/util/rating_mapping.dart` — `teamSide→BadgeSide`, `role→포지션`, `DateTime→상대시간` 순수 함수
- `lib/viewmodel/player_rating/player_rating_viewmodel.dart` — 선수 평점 상세 VM
- `lib/viewmodel/my_review/my_review_viewmodel.dart` — 내 리뷰/평점 VM
- `test/util/rating_mapping_test.dart`
- `test/model/my_rating_list_test.dart`
- `test/viewmodel/match_detail/match_detail_rating_test.dart`
- `test/viewmodel/player_rating/player_rating_viewmodel_test.dart`
- `test/viewmodel/my_review/my_review_viewmodel_test.dart`
- `test/support/fake_rating_repository.dart` — mocktail mock 공유

**수정:**
- `pubspec.yaml` — dev_dependencies에 `mocktail` 추가
- `lib/config/api_config.dart` — `myRatingsUrl` 추가
- `lib/repository/rating/rating_repository.dart` — optional-auth GET + `fetchMyRatings`
- `lib/viewmodel/match_detail/match_detail_viewmodel.dart` — 평점 상태/로드 추가
- `lib/screens/match_detail/match_detail_screen.dart` — 평점 탭 실데이터 연동
- `lib/screens/match_detail/component/match_detail_team_rating_section.dart` — `PlayerRating`에 식별자 필드 추가
- `lib/screens/player_rating/player_rating_screen.dart` — VM 연동
- `lib/screens/my_review/my_review_screen.dart` — VM 연동

---

## Task 1: mocktail 추가 + 매핑 유틸 (TDD)

**Files:**
- Modify: `pubspec.yaml` (dev_dependencies)
- Create: `lib/util/rating_mapping.dart`
- Test: `test/util/rating_mapping_test.dart`

- [ ] **Step 1: mocktail dev dependency 추가**

`pubspec.yaml` 의 `dev_dependencies:` 블록(현재 `flutter_test` / `flutter_lints` 존재)에 추가:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4

  flutter_lints: ^6.0.0
```

Run: `flutter pub get`
Expected: `Got dependencies!` (mocktail 1.0.x 해석됨)

- [ ] **Step 2: 매핑 유틸 실패 테스트 작성**

Create `test/util/rating_mapping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_badge.dart';
import 'package:warding/util/rating_mapping.dart';

void main() {
  group('sideFromTeamSide', () {
    test('BLUE → blue, RED → red, 그 외 → blue', () {
      expect(sideFromTeamSide('BLUE'), BadgeSide.blue);
      expect(sideFromTeamSide('RED'), BadgeSide.red);
      expect(sideFromTeamSide('unknown'), BadgeSide.blue);
    });
  });

  group('positionFromRole', () {
    test('역할 코드를 한글 포지션으로 변환', () {
      expect(positionFromRole('TOP'), '탑');
      expect(positionFromRole('JUNGLE'), '정글');
      expect(positionFromRole('MID'), '미드');
      expect(positionFromRole('BOTTOM'), '원딜');
      expect(positionFromRole('SUPPORT'), '서폿');
    });

    test('알 수 없는 역할은 원본을 반환', () {
      expect(positionFromRole('FLEX'), 'FLEX');
    });
  });

  group('ratingTimeAgo', () {
    test('1분 미만은 방금', () {
      final now = DateTime(2026, 6, 16, 12, 0, 0);
      expect(ratingTimeAgo(DateTime(2026, 6, 16, 11, 59, 30), now: now), '방금');
    });

    test('분/시간/일 단위', () {
      final now = DateTime(2026, 6, 16, 12, 0, 0);
      expect(ratingTimeAgo(DateTime(2026, 6, 16, 11, 58), now: now), '2분 전');
      expect(ratingTimeAgo(DateTime(2026, 6, 16, 9, 0), now: now), '3시간 전');
      expect(ratingTimeAgo(DateTime(2026, 6, 14, 12, 0), now: now), '2일 전');
    });

    test('7일 이상은 YYYY.MM.DD', () {
      final now = DateTime(2026, 6, 16, 12, 0, 0);
      expect(ratingTimeAgo(DateTime(2026, 6, 1, 9, 5), now: now), '2026.06.01');
    });

    test('null 이면 빈 문자열', () {
      expect(ratingTimeAgo(null), '');
    });
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/util/rating_mapping_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:warding/util/rating_mapping.dart'` (컴파일 에러)

> 참고: 패키지명이 `warding` 가 아니면(`pubspec.yaml` 의 `name:` 확인) import 경로를 그 이름으로 맞춘다.

- [ ] **Step 4: 매핑 유틸 구현**

Create `lib/util/rating_mapping.dart`:

```dart
import '../components/nar_badge.dart';

/// 백엔드 teamSide('BLUE'/'RED') → UI 진영 뱃지.
BadgeSide sideFromTeamSide(String teamSide) =>
    teamSide.toUpperCase() == 'RED' ? BadgeSide.red : BadgeSide.blue;

/// 백엔드 role 코드 → 한글 포지션 라벨. 모르는 값은 원본 유지.
String positionFromRole(String role) {
  switch (role.toUpperCase()) {
    case 'TOP':
      return '탑';
    case 'JUNGLE':
      return '정글';
    case 'MID':
    case 'MIDDLE':
      return '미드';
    case 'BOTTOM':
    case 'BOT':
    case 'ADC':
      return '원딜';
    case 'SUPPORT':
    case 'UTILITY':
      return '서폿';
    default:
      return role;
  }
}

/// 작성 시각 → 상대 시간 표기. 7일 이상은 'YYYY.MM.DD'.
/// [now] 는 테스트용 주입(미지정 시 DateTime.now()).
String ratingTimeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '${time.year}.$m.$d';
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/util/rating_mapping_test.dart`
Expected: PASS (모든 테스트 통과)

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib/util/rating_mapping.dart test/util/rating_mapping_test.dart
git commit -m "feat: 평점 매핑 유틸 + mocktail dev 의존성 추가

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: me/ratings 모델 (TDD)

**Files:**
- Create: `lib/model/my_rating_list.dart`
- Test: `test/model/my_rating_list_test.dart`

- [ ] **Step 1: 모델 실패 테스트 작성**

Create `test/model/my_rating_list_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/my_rating_list.dart';

void main() {
  test('fromJson: 페이지·항목·매치정보 파싱', () {
    final json = {
      'ratings': [
        {
          'ratingId': 7,
          'gameId': '113990000000000001',
          'participantId': 3,
          'playerId': 42,
          'playerName': 'Faker',
          'playerImageUrl': 'https://img/faker.png',
          'teamSide': 'BLUE',
          'role': 'MID',
          'championName': 'Galio',
          'rating': 5,
          'comment': '역시 페이커',
          'createdAt': '2026-04-20T18:00:00',
          'updatedAt': '2026-04-20T18:00:00',
          'match': {
            'matchId': 'm-1',
            'gameOrder': 2,
            'leagueName': 'LCK 2025 스프링',
            'matchTitle': 'DNS vs T1',
            'blueTeamCode': 'DNS',
            'redTeamCode': 'T1',
            'matchDate': '2026-04-01T18:00:00',
          },
        },
      ],
      'page': 0,
      'size': 20,
      'totalElements': 3,
      'totalPages': 1,
    };

    final list = MyRatingList.fromJson(json);

    expect(list.totalElements, 3);
    expect(list.hasMore, isFalse);
    expect(list.ratings, hasLength(1));
    final item = list.ratings.first;
    expect(item.ratingId, 7);
    expect(item.playerName, 'Faker');
    expect(item.rating, 5);
    expect(item.comment, '역시 페이커');
    expect(item.match, isNotNull);
    expect(item.match!.leagueName, 'LCK 2025 스프링');
    expect(item.match!.gameOrder, 2);
  });

  test('fromJson: match 가 null 이고 다음 페이지가 있을 때', () {
    final json = {
      'ratings': [
        {
          'ratingId': 1,
          'gameId': 'g',
          'participantId': 1,
          'playerId': 1,
          'playerName': 'P',
          'playerImageUrl': '',
          'teamSide': 'RED',
          'role': 'TOP',
          'championName': 'C',
          'rating': 4,
          'comment': null,
          'createdAt': '2026-04-20T18:00:00',
          'updatedAt': '2026-04-20T18:00:00',
          'match': null,
        },
      ],
      'page': 0,
      'size': 20,
      'totalElements': 50,
      'totalPages': 3,
    };

    final list = MyRatingList.fromJson(json);
    expect(list.hasMore, isTrue);
    expect(list.ratings.first.match, isNull);
    expect(list.ratings.first.comment, isNull);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/model/my_rating_list_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:warding/model/my_rating_list.dart'`

- [ ] **Step 3: 모델 구현**

Create `lib/model/my_rating_list.dart`:

```dart
// 마이페이지 '내 리뷰/평점' 모델 (`GET /api/mobile/me/ratings`).

/// 내가 작성한 평가 전체 목록 응답.
class MyRatingList {
  const MyRatingList({
    required this.ratings,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<MyRatingItem> ratings;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory MyRatingList.fromJson(Map<String, dynamic> json) {
    return MyRatingList(
      ratings: (json['ratings'] as List<dynamic>? ?? const [])
          .map((e) => MyRatingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}

/// 내가 작성한 평가 한 건.
class MyRatingItem {
  const MyRatingItem({
    required this.ratingId,
    required this.gameId,
    required this.participantId,
    required this.playerId,
    required this.playerName,
    required this.playerImageUrl,
    required this.teamSide,
    required this.role,
    required this.championName,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
    this.match,
  });

  final int ratingId;
  final String gameId;
  final int participantId;
  final int playerId;
  final String playerName;
  final String playerImageUrl;
  final String teamSide;
  final String role;
  final String championName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final MatchInfo? match;

  factory MyRatingItem.fromJson(Map<String, dynamic> json) {
    final m = json['match'];
    return MyRatingItem(
      ratingId: json['ratingId'] as int? ?? 0,
      gameId: json['gameId'] as String? ?? '',
      participantId: json['participantId'] as int? ?? 0,
      playerId: json['playerId'] as int? ?? 0,
      playerName: json['playerName'] as String? ?? '',
      playerImageUrl: json['playerImageUrl'] as String? ?? '',
      teamSide: json['teamSide'] as String? ?? '',
      role: json['role'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      match: m == null ? null : MatchInfo.fromJson(m as Map<String, dynamic>),
    );
  }
}

/// 평가 대상 세트가 속한 매치 정보. 매핑이 없으면 null.
class MatchInfo {
  const MatchInfo({
    required this.matchId,
    required this.gameOrder,
    required this.leagueName,
    required this.matchTitle,
    required this.blueTeamCode,
    required this.redTeamCode,
    this.matchDate,
  });

  final String matchId;
  final int gameOrder;
  final String leagueName;
  final String matchTitle;
  final String blueTeamCode;
  final String redTeamCode;
  final DateTime? matchDate;

  factory MatchInfo.fromJson(Map<String, dynamic> json) {
    return MatchInfo(
      matchId: json['matchId'] as String? ?? '',
      gameOrder: json['gameOrder'] as int? ?? 0,
      leagueName: json['leagueName'] as String? ?? '',
      matchTitle: json['matchTitle'] as String? ?? '',
      blueTeamCode: json['blueTeamCode'] as String? ?? '',
      redTeamCode: json['redTeamCode'] as String? ?? '',
      matchDate: DateTime.tryParse(json['matchDate'] as String? ?? ''),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/model/my_rating_list_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/model/my_rating_list.dart test/model/my_rating_list_test.dart
git commit -m "feat: me/ratings 응답 모델 추가

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Repository optional-auth + fetchMyRatings

> 이 태스크는 HTTP 의존이라 유닛 테스트 대신 `flutter analyze` 로 검증한다.

**Files:**
- Modify: `lib/config/api_config.dart` (FCM 블록 위, 평점 URL 그룹 근처)
- Modify: `lib/repository/rating/rating_repository.dart`

- [ ] **Step 1: ApiConfig에 myRatingsUrl 추가**

`lib/config/api_config.dart` 의 `myRatingUrl(...)` 정의 바로 아래에 추가:

```dart
  /// 내가 작성한 평가 전체 목록 (페이지네이션, 인증 필요).
  static String myRatingsUrl({int page = 0, int size = 20}) =>
      '$apiBaseUrl/mobile/me/ratings?page=$page&size=$size';
```

- [ ] **Step 2: RatingRepository에 optional-auth GET 헬퍼 추가**

`lib/repository/rating/rating_repository.dart` 의 `_headers` 메서드 아래에 추가:

```dart
  /// 토큰이 있으면 인증 헤더를 실어 보내고(만료 시 자동 갱신), 없으면 무토큰 GET.
  /// 비회원도 조회할 수 있게 한다. (myRating/mine 은 토큰이 있을 때만 채워짐)
  Future<http.Response> _optionalAuthGet(String url) async {
    final token = await _auth.jwt;
    if (token == null || token.isEmpty) {
      return http.get(Uri.parse(url));
    }
    return _auth.authorizedRequest(
      (t) => http.get(Uri.parse(url), headers: _headers(t)),
    );
  }
```

- [ ] **Step 3: fetchGameRatings / fetchPlayerRating 를 optional-auth로 전환**

`fetchGameRatings` 본문의 `final response = await _auth.authorizedRequest(...)` 호출을 아래로 교체:

```dart
    final response = await _optionalAuthGet(
      ApiConfig.gameRatingsUrl(gameId, teamSide: teamSide),
    );
```

`fetchPlayerRating` 본문의 `final response = await _auth.authorizedRequest(...)` 호출을 아래로 교체:

```dart
    final response = await _optionalAuthGet(
      ApiConfig.playerRatingUrl(gameId, participantId, page: page, size: size),
    );
```

(나머지 statusCode 검사·파싱·debugPrint 라인은 그대로 둔다.)

- [ ] **Step 4: fetchMyRatings 추가**

`lib/repository/rating/rating_repository.dart` 상단 import 에 추가:

```dart
import '../../model/my_rating_list.dart';
```

`deleteMyRating` 메서드 아래(클래스 닫는 `}` 직전)에 추가:

```dart
  /// 내가 작성한 평가 전체 목록을 조회한다 (인증 필요, 페이지네이션).
  Future<MyRatingList> fetchMyRatings({int page = 0, int size = 20}) async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.myRatingsUrl(page: page, size: size)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Rating] 내평가목록 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('내 평가 목록 조회 실패 (${response.statusCode})');
    }
    return MyRatingList.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
```

- [ ] **Step 5: 분석 통과 확인**

Run: `flutter analyze lib/repository/rating/rating_repository.dart lib/config/api_config.dart`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/config/api_config.dart lib/repository/rating/rating_repository.dart
git commit -m "feat: 평점 조회 optional-auth 전환 + 내 평가 목록 API

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 공유 Mock + MatchDetailViewModel 평점 연동 (TDD)

**Files:**
- Create: `test/support/fake_rating_repository.dart`
- Modify: `lib/viewmodel/match_detail/match_detail_viewmodel.dart`
- Test: `test/viewmodel/match_detail/match_detail_rating_test.dart`

- [ ] **Step 1: 공유 mock 작성**

Create `test/support/fake_rating_repository.dart`:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:warding/repository/rating/rating_repository.dart';
import 'package:warding/repository/match/match_detail_repository.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockMatchDetailRepository extends Mock
    implements MatchDetailRepository {}
```

- [ ] **Step 2: MatchDetailViewModel 평점 테스트 작성(실패)**

Create `test/viewmodel/match_detail/match_detail_rating_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/game_rating.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/viewmodel/match_detail/match_detail_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

GameRatings _ratings(String gameId) => GameRatings(
      gameId: gameId,
      rateable: true,
      teams: const [],
      players: const [],
    );

void main() {
  late MockMatchDetailRepository match;
  late MockRatingRepository rating;

  setUp(() {
    match = MockMatchDetailRepository();
    rating = MockRatingRepository();
    // 챔피언픽·라이브이벤트는 이 테스트의 관심사가 아니므로 실패시켜도 됨
    // (VM이 개별 try/catch 로 흡수).
    when(() => match.fetchChampionPick(any())).thenThrow(Exception('skip'));
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('skip'));
  });

  test('load(): 현재 세트 gameId로 평점을 로드해 ratings에 채운다', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
          MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenAnswer((inv) async => _ratings(inv.positionalArguments.first as String));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();

    // 초기 세트는 최신 ENDED(gameOrder 2) → gameId 'g2'
    expect(vm.ratings, isNotNull);
    expect(vm.ratings!.gameId, 'g2');
    expect(vm.loadingRatings, isFalse);
    expect(vm.ratingsError, isNull);
  });

  test('selectSet(): 세트 전환 시 평점을 비우고 새 세트로 다시 로드', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
          MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenAnswer((inv) async => _ratings(inv.positionalArguments.first as String));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load(); // g2
    await vm.selectSet(1); // g1

    expect(vm.ratings!.gameId, 'g1');
  });

  test('평점 로드 실패 시 ratingsError 세팅', () async {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => const [
          MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
        ]);
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('boom'));

    final vm = MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
    await vm.load();

    expect(vm.ratings, isNull);
    expect(vm.ratingsError, isNotNull);
    expect(vm.loadingRatings, isFalse);
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/viewmodel/match_detail/match_detail_rating_test.dart`
Expected: FAIL — `ratingRepository` named 파라미터 없음 / `ratings`·`loadingRatings`·`ratingsError` getter 없음 (컴파일 에러)

- [ ] **Step 4: MatchDetailViewModel 확장**

`lib/viewmodel/match_detail/match_detail_viewmodel.dart` 상단 import 에 추가:

```dart
import '../../model/game_rating.dart';
import '../../repository/rating/rating_repository.dart';
```

생성자와 필드를 아래로 교체(기존 생성자 블록):

```dart
  MatchDetailViewModel({
    required this.matchId,
    MatchDetailRepository? repository,
    RatingRepository? ratingRepository,
  })  : _repository = repository ?? MatchDetailRepository.instance,
        _ratingRepository = ratingRepository ?? RatingRepository.instance;

  final String matchId;
  final MatchDetailRepository _repository;
  final RatingRepository _ratingRepository;
```

라이브 이벤트 상태 블록 아래(`String? get eventsError ...` 다음)에 평점 상태 추가:

```dart
  // ── 선수 평점 ──────────────────────────────
  GameRatings? _ratings;
  GameRatings? get ratings => _ratings;
  bool _loadingRatings = false;
  bool get loadingRatings => _loadingRatings;
  String? _ratingsError;
  String? get ratingsError => _ratingsError;
```

`selectSet` 에서 이전 세트 데이터 초기화 부분에 `_ratings = null;` 추가:

```dart
    _championPick = null;
    _liveEventsData = null;
    _ratings = null;
    _safeNotify();
```

`_loadCurrentSet` 의 `Future.wait` 에 `_loadRatings()` 추가:

```dart
  Future<void> _loadCurrentSet() async {
    await Future.wait([
      _loadChampionPick(),
      _loadLiveEvents(),
      _loadRatings(),
    ]);
  }
```

`_loadLiveEvents` 메서드 아래에 `_loadRatings` 추가:

```dart
  Future<void> _loadRatings() async {
    final gameId = currentGameId;
    _loadingRatings = true;
    _ratingsError = null;
    _safeNotify();
    try {
      if (gameId == null || gameId.isEmpty) {
        _ratings = null;
      } else {
        _ratings = await _ratingRepository.fetchGameRatings(gameId);
      }
    } catch (e) {
      debugPrint('[MatchDetailVM] load ratings failed: $e');
      _ratingsError = '선수 평점을 불러오지 못했어요';
      _ratings = null;
    } finally {
      _loadingRatings = false;
      _safeNotify();
    }
  }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/viewmodel/match_detail/match_detail_rating_test.dart`
Expected: PASS (3 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/viewmodel/match_detail/match_detail_viewmodel.dart test/support/fake_rating_repository.dart test/viewmodel/match_detail/match_detail_rating_test.dart
git commit -m "feat: MatchDetailViewModel 선수 평점 세트별 로드 연동

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: PlayerRatingViewModel (TDD)

**Files:**
- Create: `lib/viewmodel/player_rating/player_rating_viewmodel.dart`
- Test: `test/viewmodel/player_rating/player_rating_viewmodel_test.dart`

- [ ] **Step 1: 테스트 작성(실패)**

Create `test/viewmodel/player_rating/player_rating_viewmodel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/game_rating.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/viewmodel/player_rating/player_rating_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

PlayerRatingDetail _detail({
  required String gameId,
  required int participantId,
  int page = 0,
  int totalPages = 1,
  List<Review> reviews = const [],
  MyRating? myRating,
}) =>
    PlayerRatingDetail(
      gameId: gameId,
      rateable: true,
      player: RatingPlayerDetail(
        participantId: participantId,
        playerId: 42,
        playerName: 'Faker',
        playerImageUrl: '',
        teamSide: 'BLUE',
        role: 'MID',
        championName: 'Galio',
        kills: 4,
        deaths: 1,
        assists: 7,
      ),
      averageRating: 4.5,
      ratingCount: 23,
      distribution: const [],
      myRating: myRating,
      reviews: reviews,
      page: page,
      size: 20,
      totalElements: 40,
      totalPages: totalPages,
    );

Review _review(int id) => Review(
      ratingId: id,
      nickname: 'u$id',
      rating: 5,
      mine: false,
    );

const _games = [
  MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
  MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
];

PlayerRatingViewModel _vm(MockRatingRepository repo) => PlayerRatingViewModel(
      gameId: 'g1',
      participantId: 3,
      playerId: 42,
      games: _games,
      currentSet: 1,
      repository: repo,
    );

void main() {
  late MockRatingRepository repo;
  setUp(() => repo = MockRatingRepository());

  test('load(): 상세를 받아 detail·reviews 채움', () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(
              gameId: 'g1',
              participantId: 3,
              reviews: [_review(1), _review(2)],
            ));

    final vm = _vm(repo);
    await vm.load();

    expect(vm.detail, isNotNull);
    expect(vm.reviews, hasLength(2));
    expect(vm.loading, isFalse);
  });

  test('loadMoreReviews(): 다음 페이지를 누적', () async {
    when(() => repo.fetchPlayerRating('g1', 3, page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => _detail(
            gameId: 'g1',
            participantId: 3,
            page: 0,
            totalPages: 2,
            reviews: [_review(1)]));
    when(() => repo.fetchPlayerRating('g1', 3, page: 1, size: any(named: 'size')))
        .thenAnswer((_) async => _detail(
            gameId: 'g1',
            participantId: 3,
            page: 1,
            totalPages: 2,
            reviews: [_review(2)]));

    final vm = _vm(repo);
    await vm.load();
    expect(vm.reviews, hasLength(1));

    await vm.loadMoreReviews();
    expect(vm.reviews.map((r) => r.ratingId), [1, 2]);
  });

  test('selectSet(): 새 세트 평점목록에서 playerId로 participantId 재해석 후 로드',
      () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g1', participantId: 3));
    // 세트2의 평점목록: 같은 playerId(42)가 participantId 8로 존재
    when(() => repo.fetchGameRatings('g2', teamSide: any(named: 'teamSide')))
        .thenAnswer((_) async => GameRatings(
              gameId: 'g2',
              rateable: true,
              teams: const [],
              players: const [
                RatingPlayer(
                  participantId: 8,
                  playerId: 42,
                  playerName: 'Faker',
                  playerImageUrl: '',
                  teamSide: 'BLUE',
                  role: 'MID',
                  championName: 'Ahri',
                  averageRating: 4,
                  ratingCount: 10,
                  myRating: 0,
                ),
              ],
            ));
    when(() => repo.fetchPlayerRating('g2', 8,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g2', participantId: 8));

    final vm = _vm(repo);
    await vm.load();
    await vm.selectSet(2);

    expect(vm.currentSet, 2);
    expect(vm.detail!.gameId, 'g2');
    verify(() => repo.fetchPlayerRating('g2', 8,
        page: any(named: 'page'), size: any(named: 'size'))).called(1);
  });

  test('saveMyRating(): 저장 후 상세를 다시 로드', () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g1', participantId: 3));
    when(() => repo.putMyRating('g1', 3,
            rating: any(named: 'rating'), comment: any(named: 'comment')))
        .thenAnswer((_) async => const MyRating(ratingId: 9, rating: 5));

    final vm = _vm(repo);
    await vm.load();
    await vm.saveMyRating(5, '굿');

    verify(() => repo.putMyRating('g1', 3, rating: 5, comment: '굿')).called(1);
    // 저장 후 재로드: fetchPlayerRating 가 최소 2번 호출됨(초기+재로드)
    verify(() => repo.fetchPlayerRating('g1', 3,
        page: any(named: 'page'), size: any(named: 'size'))).called(2);
  });

  test('deleteMyRating(): 삭제 후 상세를 다시 로드', () async {
    when(() => repo.fetchPlayerRating('g1', 3,
            page: any(named: 'page'), size: any(named: 'size')))
        .thenAnswer((_) async => _detail(gameId: 'g1', participantId: 3));
    when(() => repo.deleteMyRating('g1', 3)).thenAnswer((_) async {});

    final vm = _vm(repo);
    await vm.load();
    await vm.deleteMyRating();

    verify(() => repo.deleteMyRating('g1', 3)).called(1);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/viewmodel/player_rating/player_rating_viewmodel_test.dart`
Expected: FAIL — `player_rating_viewmodel.dart` 없음

- [ ] **Step 3: PlayerRatingViewModel 구현**

Create `lib/viewmodel/player_rating/player_rating_viewmodel.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../model/game_rating.dart';
import '../../model/match_game.dart';
import '../../repository/rating/rating_repository.dart';

/// 선수 평점 상세 화면 상태·로직.
///
/// (gameId, participantId) 로 상세(헤더·평균·분포·내평점·리뷰)를 로드하고,
/// 리뷰 페이지네이션·세트 전환·내 평가 작성/삭제를 처리한다.
/// 세트 전환 시 게임마다 participantId 가 다르므로 [playerId] 로 재해석한다.
class PlayerRatingViewModel extends ChangeNotifier {
  PlayerRatingViewModel({
    required String gameId,
    required int participantId,
    required this.playerId,
    required this.games,
    required int currentSet,
    RatingRepository? repository,
  })  : _gameId = gameId,
        _participantId = participantId,
        _currentSet = currentSet,
        _repository = repository ?? RatingRepository.instance;

  final int playerId;
  final List<MatchGame> games;
  final RatingRepository _repository;

  String _gameId;
  int _participantId;

  int _currentSet;
  int get currentSet => _currentSet;

  PlayerRatingDetail? _detail;
  PlayerRatingDetail? get detail => _detail;

  final List<Review> _reviews = [];
  List<Review> get reviews => List.unmodifiable(_reviews);

  bool _loading = false;
  bool get loading => _loading;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;
  bool _submitting = false;
  bool get submitting => _submitting;
  String? _error;
  String? get error => _error;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  bool get hasMore => _detail?.hasMore ?? false;

  /// 첫 페이지 로드(또는 세트 전환 후 재로드).
  Future<void> load() async {
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final detail = await _repository.fetchPlayerRating(
        _gameId,
        _participantId,
        page: 0,
      );
      _detail = detail;
      _reviews
        ..clear()
        ..addAll(detail.reviews);
    } catch (e) {
      debugPrint('[PlayerRatingVM] load failed: $e');
      _error = '선수 평점을 불러오지 못했어요';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// 다음 리뷰 페이지를 누적한다.
  Future<void> loadMoreReviews() async {
    final current = _detail;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    _safeNotify();
    try {
      final next = await _repository.fetchPlayerRating(
        _gameId,
        _participantId,
        page: current.page + 1,
      );
      _detail = next;
      _reviews.addAll(next.reviews);
    } catch (e) {
      debugPrint('[PlayerRatingVM] loadMore failed: $e');
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  /// 세트 전환. 해당 세트 gameId 로 평점목록을 받아 같은 playerId 의
  /// participantId 를 찾은 뒤 상세를 다시 로드한다.
  Future<void> selectSet(int setNumber) async {
    if (setNumber == _currentSet) return;
    final game = games.where((g) => g.gameOrder == setNumber).firstOrNull;
    if (game == null || game.gameId.isEmpty) return;

    _currentSet = setNumber;
    _loading = true;
    _error = null;
    _detail = null;
    _reviews.clear();
    _safeNotify();

    try {
      final list = await _repository.fetchGameRatings(game.gameId);
      final player =
          list.players.where((p) => p.playerId == playerId).firstOrNull;
      if (player == null) {
        _error = '이 세트에는 해당 선수 기록이 없어요';
        _loading = false;
        _safeNotify();
        return;
      }
      _gameId = game.gameId;
      _participantId = player.participantId;
    } catch (e) {
      debugPrint('[PlayerRatingVM] selectSet failed: $e');
      _error = '세트 평점을 불러오지 못했어요';
      _loading = false;
      _safeNotify();
      return;
    }
    await load();
  }

  /// 내 평점·코멘트 작성/수정. 성공 시 상세 재로드.
  /// 호출 전 View 가 로그인 여부를 확인한다(미로그인 시 호출하지 않음).
  Future<void> saveMyRating(int rating, String? comment) async {
    _submitting = true;
    _safeNotify();
    try {
      await _repository.putMyRating(
        _gameId,
        _participantId,
        rating: rating,
        comment: (comment != null && comment.isEmpty) ? null : comment,
      );
      await load();
    } catch (e) {
      debugPrint('[PlayerRatingVM] save failed: $e');
      rethrow;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  /// 내 평점 삭제. 성공 시 상세 재로드.
  Future<void> deleteMyRating() async {
    _submitting = true;
    _safeNotify();
    try {
      await _repository.deleteMyRating(_gameId, _participantId);
      await load();
    } catch (e) {
      debugPrint('[PlayerRatingVM] delete failed: $e');
      rethrow;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }
}
```

> `firstOrNull` 은 `package:collection` 없이 Dart 3 의 `Iterable` 확장으로는 제공되지 않는다. 파일 상단에 `import 'dart:collection';` 가 아니라, 아래 한 줄을 파일 맨 끝에 추가해 로컬 확장으로 제공한다:

```dart
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/viewmodel/player_rating/player_rating_viewmodel_test.dart`
Expected: PASS (5 테스트)

- [ ] **Step 5: 커밋**

```bash
git add lib/viewmodel/player_rating/ test/viewmodel/player_rating/
git commit -m "feat: PlayerRatingViewModel (상세·리뷰 페이지네이션·세트전환·작성/삭제)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: MyReviewViewModel (TDD)

**Files:**
- Create: `lib/viewmodel/my_review/my_review_viewmodel.dart`
- Test: `test/viewmodel/my_review/my_review_viewmodel_test.dart`

- [ ] **Step 1: 테스트 작성(실패)**

Create `test/viewmodel/my_review/my_review_viewmodel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/my_rating_list.dart';
import 'package:warding/viewmodel/my_review/my_review_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

MyRatingItem _item(int id, DateTime created) => MyRatingItem(
      ratingId: id,
      gameId: 'g$id',
      participantId: id,
      playerId: id,
      playerName: 'P$id',
      playerImageUrl: '',
      teamSide: 'BLUE',
      role: 'MID',
      championName: 'C',
      rating: 5,
      createdAt: created,
    );

void main() {
  late MockRatingRepository repo;
  setUp(() => repo = MockRatingRepository());

  test('load(): 항목·누적 건수 채움', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(1, DateTime(2026, 4, 20))],
              page: 0,
              size: 20,
              totalElements: 3,
              totalPages: 1,
            ));

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();

    expect(vm.items, hasLength(1));
    expect(vm.totalElements, 3);
    expect(vm.loading, isFalse);
  });

  test('grouped: createdAt 기준 YYYY.MM.DD 로 묶고 최신 날짜 우선', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [
                _item(1, DateTime(2026, 4, 20, 10)),
                _item(2, DateTime(2026, 4, 19, 9)),
                _item(3, DateTime(2026, 4, 20, 8)),
              ],
              page: 0,
              size: 20,
              totalElements: 3,
              totalPages: 1,
            ));

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();

    final keys = vm.grouped.keys.toList();
    expect(keys, ['2026.04.20', '2026.04.19']);
    expect(vm.grouped['2026.04.20'], hasLength(2));
  });

  test('loadMore(): 다음 페이지 누적', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(1, DateTime(2026, 4, 20))],
              page: 0,
              size: 20,
              totalElements: 2,
              totalPages: 2,
            ));
    when(() => repo.fetchMyRatings(page: 1, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(2, DateTime(2026, 4, 19))],
              page: 1,
              size: 20,
              totalElements: 2,
              totalPages: 2,
            ));

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();
    await vm.loadMore();

    expect(vm.items.map((i) => i.ratingId), [1, 2]);
  });

  test('deleteRating(): 항목 제거 + 누적 건수 감소', () async {
    when(() => repo.fetchMyRatings(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async => MyRatingList(
              ratings: [_item(1, DateTime(2026, 4, 20))],
              page: 0,
              size: 20,
              totalElements: 1,
              totalPages: 1,
            ));
    when(() => repo.deleteMyRating('g1', 1)).thenAnswer((_) async {});

    final vm = MyReviewViewModel(repository: repo);
    await vm.load();
    await vm.deleteRating(vm.items.first);

    expect(vm.items, isEmpty);
    expect(vm.totalElements, 0);
    verify(() => repo.deleteMyRating('g1', 1)).called(1);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/viewmodel/my_review/my_review_viewmodel_test.dart`
Expected: FAIL — `my_review_viewmodel.dart` 없음

- [ ] **Step 3: MyReviewViewModel 구현**

Create `lib/viewmodel/my_review/my_review_viewmodel.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../model/my_rating_list.dart';
import '../../repository/rating/rating_repository.dart';

/// 마이페이지 '내 리뷰/평점' 상태·로직.
///
/// `me/ratings` 를 페이지네이션으로 로드하고, 작성일(createdAt) 기준
/// 'YYYY.MM.DD' 로 그룹핑한다. 삭제 시 목록과 누적 건수를 갱신한다.
class MyReviewViewModel extends ChangeNotifier {
  MyReviewViewModel({RatingRepository? repository})
      : _repository = repository ?? RatingRepository.instance;

  final RatingRepository _repository;

  final List<MyRatingItem> _items = [];
  List<MyRatingItem> get items => List.unmodifiable(_items);

  int _page = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  int get totalElements => _totalElements;

  bool _loading = false;
  bool get loading => _loading;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;
  String? _error;
  String? get error => _error;

  bool get hasMore => _page + 1 < _totalPages;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// 작성일 기준 'YYYY.MM.DD' → 항목들. 삽입 순서(최신 우선)를 유지한다.
  Map<String, List<MyRatingItem>> get grouped {
    final map = <String, List<MyRatingItem>>{};
    for (final item in _items) {
      final c = item.createdAt;
      final key = c == null
          ? '-'
          : '${c.year}.${c.month.toString().padLeft(2, '0')}.'
              '${c.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final result = await _repository.fetchMyRatings(page: 0);
      _items
        ..clear()
        ..addAll(result.ratings);
      _page = result.page;
      _totalPages = result.totalPages;
      _totalElements = result.totalElements;
    } catch (e) {
      debugPrint('[MyReviewVM] load failed: $e');
      _error = '내 평가를 불러오지 못했어요';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _loadingMore) return;
    _loadingMore = true;
    _safeNotify();
    try {
      final result = await _repository.fetchMyRatings(page: _page + 1);
      _items.addAll(result.ratings);
      _page = result.page;
      _totalPages = result.totalPages;
      _totalElements = result.totalElements;
    } catch (e) {
      debugPrint('[MyReviewVM] loadMore failed: $e');
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  /// 평가 삭제. 성공 시 목록에서 제거하고 누적 건수를 1 줄인다.
  Future<void> deleteRating(MyRatingItem item) async {
    await _repository.deleteMyRating(item.gameId, item.participantId);
    _items.removeWhere((e) => e.ratingId == item.ratingId);
    if (_totalElements > 0) _totalElements--;
    _safeNotify();
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/viewmodel/my_review/my_review_viewmodel_test.dart`
Expected: PASS (4 테스트)

- [ ] **Step 5: 커밋**

```bash
git add lib/viewmodel/my_review/ test/viewmodel/my_review/
git commit -m "feat: MyReviewViewModel (me/ratings 페이지네이션·날짜그룹·삭제)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 경기상세 선수 평점 탭 실데이터 연동

> UI 통합. `flutter analyze` + 앱 수동 확인으로 검증.

**Files:**
- Modify: `lib/screens/match_detail/component/match_detail_team_rating_section.dart` (PlayerRating 필드 추가)
- Modify: `lib/screens/match_detail/match_detail_screen.dart`

- [ ] **Step 1: PlayerRating 값객체에 식별자 필드 추가**

`lib/screens/match_detail/component/match_detail_team_rating_section.dart` 의 `PlayerRating` 클래스를 아래로 교체:

```dart
/// 한 선수의 평점 행 데이터.
class PlayerRating {
  const PlayerRating({
    required this.name,
    required this.position,
    required this.rating,
    required this.raterCount,
    this.championImageUrl,
    this.participantId = 0,
    this.playerId = 0,
    this.playerImageUrl,
  });

  /// 선수명(예: 'DuDu').
  final String name;

  /// 포지션 라벨(예: '탑', '정글', '미드', '원딜', '서폿').
  final String position;

  /// 평균 평점(0~5)과 참여 인원.
  final double rating;
  final int raterCount;

  /// 사용 챔피언 이미지 URL. 없으면 빈 박스.
  final String? championImageUrl;

  /// 평점 상세 진입에 필요한 식별자(목업 기본값 0).
  final int participantId;
  final int playerId;
  final String? playerImageUrl;
}
```

- [ ] **Step 2: match_detail_screen 에 매핑 헬퍼 추가**

`lib/screens/match_detail/match_detail_screen.dart` 상단 import 에 추가:

```dart
import '../../model/game_rating.dart';
import '../../util/rating_mapping.dart';
```

`_State` 클래스 내부(예: `_openPlayerRating` 위)에 헬퍼 추가:

```dart
  /// 평점목록 응답의 선수를 UI 행 모델로 변환한다.
  PlayerRating _toPlayerRating(RatingPlayer p) => PlayerRating(
        name: p.playerName,
        position: positionFromRole(p.role),
        rating: p.averageRating,
        raterCount: p.ratingCount,
        playerImageUrl: p.playerImageUrl,
        participantId: p.participantId,
        playerId: p.playerId,
      );

  /// 특정 진영의 팀 요약을 찾는다(없으면 0값).
  TeamRatingSummary _teamSummary(GameRatings? r, String side) {
    final teams = r?.teams ?? const <TeamRatingSummary>[];
    for (final t in teams) {
      if (t.teamSide.toUpperCase() == side) return t;
    }
    return TeamRatingSummary(
        teamSide: side, teamName: '', averageRating: 0, ratingCount: 0);
  }
```

- [ ] **Step 3: 평점 탭 빌드를 VM 데이터로 교체**

`lib/screens/match_detail/match_detail_screen.dart` 의 `if (_tabIndex == 2) MatchDetailPlayerRatingSection(... mock ...)` 블록 전체를 아래로 교체:

```dart
            // 선수 평점 탭: 배너+멀티셀렉터가 pinned 되는 슬리버 묶음을 직접 넣는다.
            if (_tabIndex == 2)
              SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) {
                    final r = _viewModel.ratings;
                    final blue = _teamSummary(r, 'BLUE');
                    final red = _teamSummary(r, 'RED');
                    final bluePlayers = (r?.players ?? const [])
                        .where((p) => p.teamSide.toUpperCase() == 'BLUE')
                        .map(_toPlayerRating)
                        .toList();
                    final redPlayers = (r?.players ?? const [])
                        .where((p) => p.teamSide.toUpperCase() == 'RED')
                        .map(_toPlayerRating)
                        .toList();
                    return CustomScrollView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        MatchDetailPlayerRatingSection(
                          setLabel: _currentSet,
                          blueTeamName: blue.teamName.isNotEmpty
                              ? blue.teamName
                              : (widget.match?.teamA.teamName ?? 'BLUE'),
                          redTeamName: red.teamName.isNotEmpty
                              ? red.teamName
                              : (widget.match?.teamB.teamName ?? 'RED'),
                          blueRating: blue.averageRating,
                          redRating: red.averageRating,
                          blueRaterCount: blue.ratingCount,
                          redRaterCount: red.ratingCount,
                          bluePlayers: bluePlayers,
                          redPlayers: redPlayers,
                          onPlayerTap: _openPlayerRating,
                          scale: scale,
                        ),
                      ],
                    );
                  },
                ),
              ),
```

> 참고: 기존 코드에서 평점 탭은 `if (_tabIndex == 2) MatchDetailPlayerRatingSection(...)` 형태로 sliver 를 직접 넣었다. `ListenableBuilder`(box widget)로 감싸야 하므로 위처럼 `SliverToBoxAdapter` + 내부 `CustomScrollView(shrinkWrap:true)` 로 sliver 묶음을 박스 안에 담는다. 동작/스크롤 확인은 Step 6 에서 한다.

- [ ] **Step 4: _openPlayerRating 에 식별자 전달**

`_openPlayerRating` 를 아래로 교체:

```dart
  /// 선수 평점 행 탭 시 호출. 선수 평점 상세 페이지로 이동한다.
  void _openPlayerRating(PlayerRating player, String teamName, BadgeSide side) {
    final gameId = _viewModel.currentGameId;
    if (gameId == null || gameId.isEmpty || player.participantId == 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerRatingScreen(
          player: player,
          teamName: teamName,
          side: side,
          sets: _sets,
          initialSet: _currentSet,
          gameId: gameId,
          participantId: player.participantId,
          playerId: player.playerId,
          games: _viewModel.games,
          currentSetNumber: _viewModel.currentSet,
        ),
      ),
    );
  }
```

> `PlayerRatingScreen` 의 새 파라미터(`gameId`/`participantId`/`playerId`/`games`/`currentSetNumber`)는 Task 8 에서 추가한다. 그 전까지 이 파일은 컴파일되지 않는다 — Task 7·8 은 한 단위로 작업하고 Step 6/Task8 Step4 에서 함께 analyze 한다.

- [ ] **Step 5: 미사용 import 정리**

`match_detail_screen.dart` 상단에 mock 으로 인해 필요했던 미사용 import 가 생기면 제거한다. (`flutter analyze` 가 unused_import 로 알려준다.)

- [ ] **Step 6: 분석 — Task 8 완료 후 함께 수행**

이 태스크 단독으로는 `PlayerRatingScreen` 시그니처 미변경 탓에 analyze 가 실패한다. Task 8 Step 4 에서 함께 `flutter analyze` 한다. **Task 7 커밋은 Task 8 과 합쳐 Task 8 Step 5 에서 수행한다.**

---

## Task 8: 선수 평점 상세 화면 VM 연동

**Files:**
- Modify: `lib/screens/player_rating/player_rating_screen.dart`

- [ ] **Step 1: 생성자 확장 + VM 보유**

`lib/screens/player_rating/player_rating_screen.dart` 상단 import 에 추가:

```dart
import '../../model/game_rating.dart';
import '../../model/match_game.dart';
import '../../repository/auth/auth_service.dart';
import '../../util/rating_mapping.dart';
import '../../viewmodel/player_rating/player_rating_viewmodel.dart';
import '../login/login_screen.dart';
import 'component/player_comment_section.dart';
```

> `login/login_screen.dart` 의 실제 경로/클래스명은 `lib/screens/login/` 에서 확인해 맞춘다. 로그인 화면 클래스명이 다르면 그 이름을 쓴다.

`PlayerRatingScreen` 생성자에 파라미터 추가(기존 필드 유지):

```dart
  const PlayerRatingScreen({
    super.key,
    required this.player,
    required this.teamName,
    required this.side,
    this.sets = const [],
    this.initialSet = '',
    required this.gameId,
    required this.participantId,
    required this.playerId,
    this.games = const [],
    this.currentSetNumber = 1,
  });

  // ... 기존 필드들 아래에 추가 ...
  final String gameId;
  final int participantId;
  final int playerId;
  final List<MatchGame> games;
  final int currentSetNumber;
```

- [ ] **Step 2: State 에서 VM 생성·로드·세트전환 연결**

`_PlayerRatingScreenState` 상단에 VM 필드 추가 + `initState`/`dispose`:

```dart
  late final PlayerRatingViewModel _vm = PlayerRatingViewModel(
    gameId: widget.gameId,
    participantId: widget.participantId,
    playerId: widget.playerId,
    games: widget.games,
    currentSet: widget.currentSetNumber,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }
```

세트 드롭다운 선택 핸들러에서 `_vm.selectSet` 호출하도록 변경한다. 기존 `_showSetSheet` 가 로컬 `_currentSet` 만 갱신한다면, 선택 결과에 다음을 추가:

```dart
    // 선택된 세트 라벨에서 숫자 추출 → VM 전환.
    final n = RegExp(r'\d+').firstMatch(selected);
    if (n != null) {
      _vm.selectSet(int.parse(n.group(0)!));
      setState(() => _currentSet = selected);
    }
```

- [ ] **Step 3: 작성/삭제 핸들러를 VM·로그인게이트로 교체**

`_openRatingSheet` 를 아래로 교체(로그인 게이트 포함):

```dart
  /// 평점·코멘트 남기기. 미로그인 시 로그인 화면으로 유도.
  Future<void> _openRatingSheet() async {
    final token = await AuthService.instance.jwt;
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final result = await showRatingCommentSheet(
      context: context,
      teamName: widget.teamName,
      playerName: widget.player.name,
      position: widget.player.position,
    );
    if (result == null) return;
    await _vm.saveMyRating(result.rating.round(), result.comment);
  }
```

`_confirmDeleteComment` 의 TODO 라인을 실제 호출로 교체:

```dart
    if (ok != true) return;
    await _vm.deleteMyRating();
```

- [ ] **Step 4: build 를 VM 구독으로 교체**

`build` 의 스크롤 본문(헤더 아래 `Expanded(child: SingleChildScrollView(...))`)을 `ListenableBuilder` 로 감싸 VM 상태를 사용하도록 한다. 핵심 매핑:

- `PlayedChampCard.kda` ← `_vm.detail?.player.kda ?? '-'`
- `RatingDistributionSection`:
  - `rating` ← `_vm.detail?.averageRating ?? widget.player.rating`
  - `raterCount` ← `_vm.detail?.ratingCount ?? widget.player.raterCount`
  - `distribution` ← 5→1점 순 퍼센트 정수 리스트. `_distPercents(_vm.detail)`(아래 헬퍼)
- 내 댓글 카드: `_vm.detail?.myRating` 가 null 이면 "평점 남기기" 버튼, 있으면 `MyCommentCard`(rating=myRating.rating, onEdit=_openRatingSheet, onDelete=_confirmDeleteComment)
- 리뷰 리스트: `_vm.reviews` 를 `PlayerComment` 로 매핑

`_PlayerRatingScreenState` 에 헬퍼 추가:

```dart
  /// 분포를 5→1점 순 정수 퍼센트 리스트로. 미로드 시 0 채움.
  List<int> _distPercents(PlayerRatingDetail? d) {
    final byScore = {for (final e in d?.distribution ?? const []) e.rating: e};
    return [5, 4, 3, 2, 1]
        .map((s) => (byScore[s]?.percentage ?? 0).round())
        .toList();
  }

  /// 리뷰를 코멘트 타일 모델로 변환.
  PlayerComment _toComment(Review r) => PlayerComment(
        username: r.nickname,
        timeAgo: ratingTimeAgo(r.createdAt),
        rating: r.rating,
        comment: (r.comment != null && r.comment!.isNotEmpty) ? r.comment : null,
      );
```

`build` 본문 교체 예시(헤더는 유지, Expanded 내부만):

```dart
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  final d = _vm.detail;
                  final my = d?.myRating;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 28 * scale),
                        PlayedChampCard(
                          teamName: widget.teamName,
                          playerName: widget.player.name,
                          position: widget.player.position,
                          kda: d?.player.kda ?? '-',
                          scale: scale,
                        ),
                        SizedBox(height: 16 * scale),
                        RatingDistributionSection(
                          rating: d?.averageRating ?? widget.player.rating,
                          raterCount: d?.ratingCount ?? widget.player.raterCount,
                          distribution: _distPercents(d),
                          scale: scale,
                        ),
                        SizedBox(height: 16 * scale),
                        if (my != null)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                            child: MyCommentCard(
                              username: '나',
                              timeAgo: '',
                              rating: my.rating,
                              onEdit: _openRatingSheet,
                              onDelete: _confirmDeleteComment,
                              scale: scale,
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                            child: NarButton(
                              variant: NarButtonVariant.set1,
                              label: '평점 남기기',
                              onPressed: (d?.rateable ?? false)
                                  ? _openRatingSheet
                                  : null,
                              scale: scale,
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 19.5 * scale),
                          child: PlayerCommentSection(
                            comments: _vm.reviews.map(_toComment).toList(),
                            scale: scale,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
```

> `NarButton`/`NarButtonVariant` import 가 없으면 추가한다. '평점 남기기' 디자인이 별도 버튼이면 기존 시안 위젯을 재사용한다(시안의 보라 그라데이션 "리뷰 남기기"는 `rating_comment_sheet` 내부 버튼이고, 상세 화면의 "평점 남기기"는 별도 진입 버튼).

- [ ] **Step 5: 분석 통과 + 커밋 (Task 7 동반)**

Run: `flutter analyze lib/screens/match_detail lib/screens/player_rating lib/util lib/viewmodel`
Expected: `No issues found!`

```bash
git add lib/screens/match_detail lib/screens/player_rating
git commit -m "feat: 경기상세 평점탭·선수 평점 상세 실데이터 연동

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: 앱 수동 확인**

경기상세 → 선수 평점 탭 진입 → 팀 평균·선수 행 실데이터 표시, 선수 탭 → 상세(KDA·분포·리뷰) 표시, 평점 작성/수정/삭제, 세트 드롭다운 전환 동작 확인. 미로그인 상태에서 "평점 남기기" → 로그인 화면 유도 확인.

---

## Task 9: 마이페이지 내 리뷰/평점 VM 연동

**Files:**
- Modify: `lib/screens/my_review/my_review_screen.dart`

- [ ] **Step 1: StatelessWidget → StatefulWidget + VM**

`lib/screens/my_review/my_review_screen.dart` 상단 import 에 추가:

```dart
import '../../model/my_rating_list.dart';
import '../../util/rating_mapping.dart';
import '../../viewmodel/my_review/my_review_viewmodel.dart';
```

클래스를 StatefulWidget 으로 바꾸고 VM 보유:

```dart
class MyReviewScreen extends StatefulWidget {
  const MyReviewScreen({super.key});

  @override
  State<MyReviewScreen> createState() => _MyReviewScreenState();
}

class _MyReviewScreenState extends State<MyReviewScreen> {
  final MyReviewViewModel _vm = MyReviewViewModel();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }
```

기존 `static const ... _groups`(mock) 와 `// TODO` 주석들을 모두 제거한다.

- [ ] **Step 2: MyRatingItem → MyReview 매핑 헬퍼**

`_MyReviewScreenState` 에 추가:

```dart
  /// 응답 항목을 기존 ReviewCard 입력(MyReview)으로 변환.
  MyReview _toReview(MyRatingItem item) => MyReview(
        league: item.match?.leagueName ?? '',
        teamName: item.match == null
            ? ''
            : (sideFromTeamSide(item.teamSide) == BadgeSide.blue
                ? item.match!.blueTeamCode
                : item.match!.redTeamCode),
        playerName: item.playerName,
        position: positionFromRole(item.role),
        side: sideFromTeamSide(item.teamSide),
        username: '나',
        timeAgo: ratingTimeAgo(item.createdAt),
        rating: item.rating.toDouble(),
        comment: (item.comment != null && item.comment!.isNotEmpty)
            ? item.comment
            : null,
      );
```

> `MyReview` 의 import(`component/review_card.dart`)는 기존에 있으므로 그대로 둔다. `BadgeSide` import(`nar_badge.dart`)도 기존 존재.

- [ ] **Step 3: build 를 VM 구독으로 교체**

`build` 를 아래 구조로 교체(헤더는 유지):

```dart
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(
              title: '내 리뷰/평점',
              backIconAsset: 'assets/icons/chevron-left.svg',
              scale: scale,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  final groups = _vm.grouped;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CumulativeReviewBar(
                          count: _vm.totalElements,
                          scale: scale,
                        ),
                        for (final entry in groups.entries) ...[
                          SizedBox(height: 16 * scale),
                          ReviewDateHeader(date: entry.key, scale: scale),
                          for (final item in entry.value) ...[
                            SizedBox(height: 2 * scale),
                            ReviewCard(
                              review: _toReview(item),
                              scale: scale,
                              onView: () => _openPlayerRating(item),
                              onDelete: () => _confirmDelete(item),
                            ),
                          ],
                        ],
                        SizedBox(height: 24 * scale),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: 리뷰보기/삭제 핸들러 교체**

기존 `_openPlayerRating(BuildContext, MyReview)` 와 `_confirmDelete(BuildContext)` 를 아래로 교체:

```dart
  /// 리뷰보기 — 선수 평점 상세로 이동.
  void _openPlayerRating(MyRatingItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerRatingScreen(
          player: PlayerRating(
            name: item.playerName,
            position: positionFromRole(item.role),
            rating: item.rating.toDouble(),
            raterCount: 0,
            participantId: item.participantId,
            playerId: item.playerId,
          ),
          teamName: item.match == null
              ? ''
              : (sideFromTeamSide(item.teamSide) == BadgeSide.blue
                  ? item.match!.blueTeamCode
                  : item.match!.redTeamCode),
          side: sideFromTeamSide(item.teamSide),
          gameId: item.gameId,
          participantId: item.participantId,
          playerId: item.playerId,
        ),
      ),
    );
  }

  /// 리뷰삭제 — 확인 후 VM 삭제.
  Future<void> _confirmDelete(MyRatingItem item) async {
    final ok = await showNarConfirmDialog(
      context: context,
      title: '내 평점을 삭제하시겠습니까?',
      message: '삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다.',
      cancelLabel: '취소',
      confirmLabel: '삭제',
    );
    if (ok != true) return;
    await _vm.deleteRating(item);
  }
```

> `PlayerRating` import(`../match_detail/component/match_detail_team_rating_section.dart`)와 `PlayerRatingScreen` import(`../player_rating/player_rating_screen.dart`)는 기존에 있다. `_openPlayerRating` 가 기존엔 `sets`/`initialSet` 를 넘겼는데, me/ratings 진입은 단일 세트 컨텍스트라 세트 드롭다운 없이 진입한다(games 미전달 → 드롭다운 비활성).

- [ ] **Step 5: 분석 통과 확인**

Run: `flutter analyze lib/screens/my_review`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/my_review
git commit -m "feat: 마이페이지 내 리뷰/평점 실데이터 연동

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: 전체 검증**

Run: `flutter analyze` (전체)
Expected: `No issues found!`

Run: `flutter test`
Expected: All tests passed (Task 1·2·4·5·6 테스트 모두 통과)

앱 수동 확인: 마이페이지 → 내 리뷰/평점 → 누적 건수·날짜 그룹·리뷰 카드 실데이터, 리뷰보기 진입, 삭제 동작 확인.

---

## Self-Review 결과

**Spec coverage:**
- §4 인증 정책(조회 optional-auth/작성 authorizedRequest) → Task 3 + Task 8 로그인게이트 ✓
- §6 데이터 계층(repo/api_config/모델) → Task 1·2·3 ✓
- §7 ViewModel 3종 → Task 4·5·6 ✓
- §8 View 연동 3화면 + 매핑유틸 → Task 1·7·8·9 ✓
- §9 에러·빈상태·rateable·미로그인 → Task 4(error)·8(rateable 버튼 비활성·로그인게이트) ✓
- §10 테스트 → Task 1·2·4·5·6 TDD ✓

**Placeholder scan:** "평점 남기기" 버튼/로그인 화면 클래스명 등은 기존 컴포넌트 재사용 지시 + 확인 경로를 명시해 구체화함.

**Type consistency:** `PlayerRatingScreen` 새 파라미터(`gameId`/`participantId`/`playerId`/`games`/`currentSetNumber`)는 Task 7(호출부)·8(정의부)에서 동일 시그니처. `MockRatingRepository`/`MockMatchDetailRepository` 는 Task 4 에서 정의 후 5·6 에서 재사용. `ratingTimeAgo`/`positionFromRole`/`sideFromTeamSide` 시그니처 Task 1 정의와 7·8·9 사용 일치.

**주의(실행 순서):** Task 7 과 8 은 한 단위 — Task 7 단독 analyze 실패가 정상이며 Task 8 Step 5 에서 함께 커밋한다.
