# 홈 화면 (spec v29) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `warding-docs/features/home/spec.md`(v29) 기준으로 홈 화면을 완성한다 — 실데이터가 있는 섹션은 API에 연결하고, 백엔드가 아직 없는 솔랭·평점·뉴스는 repository 인터페이스 뒤의 목업으로 두며, "내 선수(구독 전체)" 화면을 새로 만들고 앱 진입 화면을 홈으로 바꾼다.

**Architecture:** 이미 작업 트리에 있는 목업 UI(`lib/screens/home/`, `lib/viewmodel/home/home_viewmodel.dart`, 하단 탭 `home`)를 그대로 이어서 쓴다. `HomeViewModel`의 `static const mock*`를 섹션별 데이터 소스 인터페이스로 갈아끼운다. 실데이터 소스(일정·순위·커뮤니티·공지·쇼츠·구독 선수)는 기존 repository 패턴(`XxxRepository.instance`, `api_client.dart`)을 따르고, 미구현 소스(솔랭·평점·뉴스)는 `Mock*Source`가 같은 인터페이스를 구현한다. spec의 "로딩·에러는 안 그림"에 따라 섹션은 로딩·에러 때 스피너나 에러 UI를 그리지 않고 마지막 값(없으면 섹션 숨김/빈 상태)을 유지한다.

**Tech Stack:** Flutter/Dart, `package:http`(`lib/util/api_client.dart` 래퍼), `cached_network_image`, `flutter_test` + `http/testing.dart`(`MockClient`).

**Spec:** `/Volumes/Extreme SSD/Projects/teamProject/warding-docs/features/home/spec.md` (목업: 같은 폴더 `mockup.html`, v29). 이 계획은 옛 계획 `2026-09-21-home-screen-phase1.md`와 `specs/2026-09-21-home-screen-design.md`를 **대체**한다(솔랭·구독 전체·정렬 탭을 제외하던 옛 범위가 새 spec과 어긋난다).

## Global Constraints

- 색은 `AppColors` 토큰만 쓴다. 필요한 색이 없으면 위젯에 박지 말고 `lib/styles/app_colors.dart`에 먼저 추가한다. 솔랭 강조는 브랜드 3색(`narBg` 계열)만 쓴다 — 초록·주황·보라 단색 신호색 금지(spec 결정 2026-09-22).
- 사용자 노출 문자열은 `lib/l10n/app_ko.arb` + `app_en.arb`에 키를 추가하고 `flutter gen-l10n` 후 `AppLocalizations.of(context)!.xxx`로 쓴다.
- 신규 위젯은 `final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;` 패턴으로 수치에 `scale`을 곱한다.
- 파일 위치는 CLAUDE.md 규칙: 화면 `screens/{기능}/`, 화면 전용 위젯 `screens/{기능}/component/`, ViewModel `viewmodel/{기능}/`, 모델 `model/`, repository `repository/{기능}/`. ViewModel은 `BuildContext`에 의존하지 않고, 화면 전환은 View가 한다.
- 새 repository는 `XxxRepository._()` + `static final instance`, `api_client.dart`를 `as http`로 사용, non-2xx면 `Exception`, `jsonDecode(utf8.decode(response.bodyBytes))`.
- 테스트는 `mocktail`이 아니라 `http.testing.MockClient` + `api.setApiClientForTesting(...)`(`test/repository/notice/notice_repository_test.dart` 참고).
- spec 화면 상태 표: 오늘 경기·순위표·콘텐츠·내 선수는 **로딩·에러를 그리지 않는다**(솔랭 카드도 로딩·에러 안 그림). 폴링 실패 시 마지막 값을 유지할지는 spec 미결이므로 **마지막 값을 유지**로 구현하고 코드 주석에 미결임을 남긴다.
- 솔랭 규칙(spec 결정): 위쪽 큰 카드는 진행 중인 선수만, 아래 줄은 오늘 끝난 경기만. 끝난 경기는 선수당 최신 1건, 최대 8명, 나머지는 "+N명". 큰 카드 순서는 핀 선수 먼저, 없으면 가장 최근 시작한 선수 먼저. 라이브 카드 숫자는 경과 시간 하나뿐(관전하기·포지션·스코어 없음). 끝난 카드는 "12분 전 종료", 경기 길이는 "32분"(“플레이” 없음).
- 평점은 한줄평이 달린 것만(별점 1~5 정수, 한줄평 150자). 커뮤니티 기본 탭은 최신순, 콘텐츠 기본 탭은 뉴스. 쇼츠 "전체"는 내 선수∪내 팀, 정렬은 내 선수 → 내 팀 → 나머지. 순위표 1등은 따로 꾸미지 않는다. 내 선수 화면은 보기 전용(알림 벨 없음).
- 커밋은 태스크마다. 커밋 메시지 끝에 `Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz`를 붙인다. 기존 미커밋 변경은 Task 0에서 먼저 한 번 커밋한다.

## File Structure

| 파일 | 역할 |
|---|---|
| `lib/model/standing.dart` (신규) | 순위표 응답 모델 |
| `lib/model/story_video.dart` (신규) | 쇼츠 영상 모델 |
| `lib/repository/standings/standings_repository.dart` (신규) | `/api/standings` |
| `lib/repository/shorts/shorts_repository.dart` (신규) | 쇼츠 목록 |
| `lib/repository/community/community_repository.dart` (수정) | `fetchPosts`에 `sort` 추가 |
| `lib/repository/home/home_sources.dart` (신규) | `SoloRankSource`·`ReviewSource`·`NewsSource` 인터페이스 + `Mock*Source` |
| `lib/viewmodel/home/home_viewmodel.dart` (수정) | 목업 상수 → 소스 주입, 섹션별 상태 |
| `lib/viewmodel/my_players/my_players_viewmodel.dart` (신규) | 내 선수 화면 상태(검색·팀 필터·상태별 그룹) |
| `lib/screens/my_players/my_players_screen.dart` (신규) | 내 선수 화면 |
| `lib/screens/home/component/*` (수정) | 섹션 위젯을 VM 실데이터·빈 상태에 연결 |
| `lib/screens/splash_screen.dart`, `login_screen.dart`, `onboarding_screen.dart` (수정) | 진입 화면을 홈으로 |

---

### Task 0: 현재 작업 트리 기준점 커밋

**Files:** 기존 미커밋 홈 관련 파일 전체 (`git status` 기준).

- [ ] **Step 1: 현재 테스트가 통과하는지 확인**

Run: `flutter gen-l10n && flutter test test/viewmodel/home test/components/app_bottom_nav_test.dart`
Expected: PASS. 실패하면 이 계획을 진행하지 말고 원인부터 보고한다.

- [ ] **Step 2: 홈 관련 파일만 골라 커밋** (`intent/youtube-shorts/intent.md`, `ios/Podfile.lock`은 이 작업과 무관하니 제외)

```bash
git checkout -b feat/home-screen
git add assets/icons/home.svg lib/components lib/l10n lib/screens/home lib/screens/community lib/screens/match_list lib/screens/mypage lib/screens/schedule lib/screens/subscription lib/viewmodel/home test/viewmodel/home
git commit -m "feat: 홈 화면 목업 UI와 하단 탭 '홈' 추가

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 1: 순위표 모델 + `StandingsRepository`

**Files:**
- Create: `lib/model/standing.dart`, `lib/repository/standings/standings_repository.dart`
- Modify: `lib/config/api_config.dart`
- Test: `test/model/standing_test.dart`, `test/repository/standings/standings_repository_test.dart`

**Interfaces:**
- Produces: `StandingsResult{league, supported, reason, scopeLabel, groups}`, `StandingGroup{name, rows}`, `StandingRow{rank, teamCode, teamName, imageUrl, wins, losses, setDiff}`(모두 `fromJson`), `StandingsRepository.instance.fetchStandings(String league) → Future<StandingsResult>`, `ApiConfig.standingsUrl({required String league})`.

- [ ] **Step 1: 백엔드 응답 모양 확인** — spec은 "순위 `/api/standings`, LCK만 준다"라고만 쓴다. 필드명을 추측하지 않는다.

Run: `gh search code 'standings' --repo NAR-GG/nar-back-repo --json path --jq '.[].path'` 로 컨트롤러·DTO를 찾아 읽고, 아래 테스트의 JSON 키(`groups[].rows[]`, `rank/teamCode/teamName/imageUrl/wins/losses/setDiff`)가 실제 DTO와 같은지 대조한다. 다르면 테스트 JSON과 모델 파싱 키를 실제 DTO에 맞춘다.

- [ ] **Step 2: 모델 실패 테스트 작성**

```dart
// test/model/standing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/standing.dart';

void main() {
  test('지원 리그: groups·rows를 그대로 파싱한다', () {
    final result = StandingsResult.fromJson({
      'league': 'LCK',
      'supported': true,
      'reason': null,
      'scopeLabel': '정규시즌',
      'groups': [
        {
          'name': '레전드 그룹',
          'rows': [
            {
              'rank': 1,
              'teamCode': 'GEN',
              'teamName': 'Gen.G',
              'imageUrl': 'https://x/gen.png',
              'wins': 19,
              'losses': 7,
              'setDiff': 22,
            },
          ],
        },
      ],
    });

    expect(result.supported, isTrue);
    final row = result.groups.single.rows.single;
    expect(row.rank, 1);
    expect(row.teamCode, 'GEN');
    expect(row.setDiff, 22);
  });

  test('필드 누락에도 죽지 않고 기본값으로 채운다', () {
    final result = StandingsResult.fromJson(const {});
    expect(result.supported, isFalse);
    expect(result.groups, isEmpty);
  });
}
```

- [ ] **Step 3: 실행 → 실패 확인** — Run: `flutter test test/model/standing_test.dart` / Expected: FAIL(파일 없음)

- [ ] **Step 4: 모델 구현**

```dart
// lib/model/standing.dart

/// 리그 순위표 조회 결과 (`GET /api/standings`).
class StandingsResult {
  const StandingsResult({
    required this.league,
    required this.supported,
    this.reason,
    required this.scopeLabel,
    required this.groups,
  });

  final String league;
  final bool supported;
  final String? reason;
  final String scopeLabel;
  final List<StandingGroup> groups;

  factory StandingsResult.fromJson(Map<String, dynamic> json) {
    return StandingsResult(
      league: json['league'] as String? ?? '',
      supported: json['supported'] as bool? ?? false,
      reason: json['reason'] as String?,
      scopeLabel: json['scopeLabel'] as String? ?? '',
      groups: (json['groups'] as List<dynamic>? ?? const [])
          .map((e) => StandingGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 순위표 그룹 한 덩이(예: '레전드 그룹').
class StandingGroup {
  const StandingGroup({required this.name, required this.rows});

  final String name;
  final List<StandingRow> rows;

  factory StandingGroup.fromJson(Map<String, dynamic> json) {
    return StandingGroup(
      name: json['name'] as String? ?? '',
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 순위표 한 행(팀 한 개).
class StandingRow {
  const StandingRow({
    required this.rank,
    required this.teamCode,
    required this.teamName,
    this.imageUrl,
    required this.wins,
    required this.losses,
    required this.setDiff,
  });

  final int rank;
  final String teamCode;
  final String teamName;
  final String? imageUrl;
  final int wins;
  final int losses;
  final int setDiff;

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    return StandingRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamCode: json['teamCode'] as String? ?? '',
      teamName: json['teamName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      setDiff: (json['setDiff'] as num?)?.toInt() ?? 0,
    );
  }
}
```

- [ ] **Step 5: 통과 확인** — Run: `flutter test test/model/standing_test.dart` / Expected: PASS(2)

- [ ] **Step 6: repository 실패 테스트 작성**

```dart
// test/repository/standings/standings_repository_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/standings/standings_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = StandingsRepository.instance;
  tearDown(() => api.setApiClientForTesting(null));

  test('league 쿼리파라미터로 조회하고 응답을 파싱한다', () async {
    Uri? captured;
    api.setApiClientForTesting(MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'league': 'LCK',
          'supported': true,
          'scopeLabel': '정규시즌',
          'groups': [
            {
              'name': '레전드 그룹',
              'rows': [
                {'rank': 1, 'teamCode': 'GEN', 'teamName': 'Gen.G', 'wins': 19, 'losses': 7, 'setDiff': 22},
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final result = await repo.fetchStandings('LCK');

    expect(captured?.queryParameters['league'], 'LCK');
    expect(result.groups.single.rows.single.teamCode, 'GEN');
  });

  test('non-2xx면 예외를 던진다', () async {
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 500)));
    await expectLater(repo.fetchStandings('LCK'), throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 7: 실행 → 실패 확인** — Run: `flutter test test/repository/standings/standings_repository_test.dart` / Expected: FAIL

- [ ] **Step 8: URL 빌더 + repository 구현**

`lib/config/api_config.dart` 끝(`}` 앞)에 추가:

```dart
  // ── 순위표 (인증 불필요) ─────────────────────────────────────────

  /// 리그 순위표 조회. 현재 서버는 LCK만 준다.
  static String standingsUrl({required String league}) =>
      '$apiBaseUrl/standings?league=${Uri.encodeQueryComponent(league)}';
```

```dart
// lib/repository/standings/standings_repository.dart
import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/standing.dart';
import '../../util/api_client.dart' as http;

/// 리그 순위표 API (`/api/standings`).
class StandingsRepository {
  StandingsRepository._();
  static final StandingsRepository instance = StandingsRepository._();

  Future<StandingsResult> fetchStandings(String league) async {
    final response =
        await http.get(Uri.parse(ApiConfig.standingsUrl(league: league)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('순위표 조회 실패 ($league, ${response.statusCode})');
    }
    return StandingsResult.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
```

- [ ] **Step 9: 통과 확인 후 커밋**

Run: `flutter test test/model/standing_test.dart test/repository/standings` / Expected: PASS

```bash
git add lib/model/standing.dart lib/repository/standings lib/config/api_config.dart test/model/standing_test.dart test/repository/standings
git commit -m "feat: 순위표 모델·repository 추가 (/api/standings)

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 2: 커뮤니티 `sort` 파라미터

**Files:**
- Modify: `lib/config/api_config.dart:339-346`(`communityPostsUrl`), `lib/repository/community/community_repository.dart:58-72`(`fetchPosts`)
- Test: `test/repository/community/community_repository_sort_test.dart`

**Interfaces:**
- Produces: `fetchPosts({int? boardTeamId, int? cursor, int size = 20, String? sort})` — `sort`는 `'hot'` 또는 `'latest'`, null이면 쿼리에 붙이지 않는다(기존 호출 동작 불변). `ApiConfig.communityPostsUrl(..., String? sort)`.

- [ ] **Step 1: 실패 테스트 작성** — 기존 커뮤니티 repository 테스트가 인증 헤더를 어떻게 모킹하는지 `ls test/repository/community`로 먼저 확인하고 같은 셋업(`FlutterSecureStorage.setMockInitialValues({})`, `AuthService.instance.resetJwtCacheForTesting()`)을 쓴다.

```dart
// test/repository/community/community_repository_sort_test.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
  });
  tearDown(() => api.setApiClientForTesting(null));

  Future<Uri> capture({String? sort}) async {
    Uri? url;
    api.setApiClientForTesting(MockClient((request) async {
      url = request.url;
      return http.Response(jsonEncode({'posts': <dynamic>[]}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await CommunityRepository.instance.fetchPosts(size: 4, sort: sort);
    return url!;
  }

  test('sort=hot 이면 쿼리에 붙는다', () async {
    expect((await capture(sort: 'hot')).queryParameters['sort'], 'hot');
  });

  test('sort 를 안 주면 쿼리에 붙지 않는다', () async {
    expect((await capture()).queryParameters.containsKey('sort'), isFalse);
  });
}
```

- [ ] **Step 2: 실행 → 실패 확인** — Run: `flutter test test/repository/community/community_repository_sort_test.dart` / Expected: FAIL(`sort` 파라미터 없음)

- [ ] **Step 3: 구현**

`communityPostsUrl`에 `String? sort` 추가하고 `if (sort != null) query.write('&sort=$sort');`. `fetchPosts`에 `String? sort`를 받아 그대로 넘긴다.

- [ ] **Step 4: 통과 + 기존 커뮤니티 테스트 회귀 확인**

Run: `flutter test test/repository/community test/viewmodel/community` / Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/config/api_config.dart lib/repository/community/community_repository.dart test/repository/community
git commit -m "feat: 커뮤니티 글 목록에 sort(hot|latest) 파라미터 추가

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 3: 쇼츠 모델 + `ShortsRepository`

**Files:**
- Create: `lib/model/story_video.dart`, `lib/repository/shorts/shorts_repository.dart`
- Modify: `lib/config/api_config.dart`
- Test: `test/model/story_video_test.dart`, `test/repository/shorts/shorts_repository_test.dart`

**Interfaces:**
- Produces: `StoryVideo{videoId, youtubeVideoId, title, videoUrl, thumbnailUrl, channelName, viewCount, publishedAt}.fromJson`, `ShortsRepository.instance.fetchShorts({String sort = 'latest'}) → Future<List<StoryVideo>>`, `ApiConfig.shortsUrl({String sort, int size})`.

- [ ] **Step 1: 엔드포인트·응답 필드 확인** — spec은 `/api/videos?category=shorts&sort=latest|popular`이고, 옛 계획은 `/api/story/videos`였다. 둘이 다르다.

Run: `gh search code 'videos' --repo NAR-GG/nar-back-repo --json path --jq '.[].path'`(이미 `YoutubeService.java`가 잡힌다). 컨트롤러의 `@RequestMapping`·`@GetMapping` 경로와 응답 DTO 필드(`videoId`·`youtubeVideoId`·`title`·`thumbnailUrl`·`viewCount`·`publishedAt`·페이지 래퍼가 `content`인지)를 읽고, 아래 코드의 경로·키를 **실제 값으로 확정**한다. 확정한 경로는 `ApiConfig.shortsUrl` 주석에 남긴다. 팀·선수 연관 필드가 응답에 있는지도 함께 확인해 Task 5의 쇼츠 필터 방식을 정한다(없으면 제목 문자열 매칭).

- [ ] **Step 2: 모델 테스트 → 실패 확인 → 구현**

```dart
// test/model/story_video_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/story_video.dart';

void main() {
  test('필드를 그대로 파싱한다', () {
    final v = StoryVideo.fromJson({
      'videoId': 1001,
      'youtubeVideoId': 'abc123',
      'title': '제우스 하이라이트',
      'videoUrl': 'https://youtube.com/watch?v=abc123',
      'thumbnailUrl': 'https://img/t.jpg',
      'channelName': 'LCK',
      'viewCount': 12345,
      'publishedAt': '2026-09-20T10:00:00',
    });
    expect(v.title, '제우스 하이라이트');
    expect(v.viewCount, 12345);
    expect(v.publishedAt, DateTime.parse('2026-09-20T10:00:00'));
  });

  test('필드 누락에도 죽지 않는다', () {
    final v = StoryVideo.fromJson(const {});
    expect(v.videoId, 0);
    expect(v.publishedAt, isNull);
  });
}
```

```dart
// lib/model/story_video.dart

/// 유튜브 쇼츠 한 건.
class StoryVideo {
  const StoryVideo({
    required this.videoId,
    required this.youtubeVideoId,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.channelName,
    required this.viewCount,
    this.publishedAt,
  });

  final int videoId;
  final String youtubeVideoId;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String channelName;
  final int viewCount;
  final DateTime? publishedAt;

  factory StoryVideo.fromJson(Map<String, dynamic> json) {
    return StoryVideo(
      videoId: (json['videoId'] as num?)?.toInt() ?? 0,
      youtubeVideoId: json['youtubeVideoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      channelName: json['channelName'] as String? ?? '',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }
}
```

Run: `flutter test test/model/story_video_test.dart` → 파일 만들기 전 FAIL, 구현 후 PASS.

- [ ] **Step 3: repository 테스트 → 실패 확인 → 구현** (Step 1에서 확정한 경로를 쓴다. 아래는 spec 기준 `/videos`)

```dart
// test/repository/shorts/shorts_repository_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/shorts/shorts_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ShortsRepository.instance;
  tearDown(() => api.setApiClientForTesting(null));

  test('category=shorts, sort를 쿼리로 보내고 content를 파싱한다', () async {
    Uri? captured;
    api.setApiClientForTesting(MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'content': [
            {'videoId': 1, 'youtubeVideoId': 'a', 'title': '영상 1', 'viewCount': 100},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final videos = await repo.fetchShorts(sort: 'popular');

    expect(captured?.queryParameters['category'], 'shorts');
    expect(captured?.queryParameters['sort'], 'popular');
    expect(videos.single.title, '영상 1');
  });

  test('non-2xx면 예외', () async {
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 500)));
    await expectLater(repo.fetchShorts(), throwsA(isA<Exception>()));
  });
}
```

`api_config.dart`:

```dart
  // ── 유튜브 쇼츠 (인증 불필요) ───────────────────────────────────────

  /// 쇼츠 목록. [sort] 는 'latest' | 'popular'.
  static String shortsUrl({String sort = 'latest', int size = 20}) =>
      '$apiBaseUrl/videos?category=shorts&sort=$sort&size=$size';
```

```dart
// lib/repository/shorts/shorts_repository.dart
import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/story_video.dart';
import '../../util/api_client.dart' as http;

/// 유튜브 쇼츠 API.
class ShortsRepository {
  ShortsRepository._();
  static final ShortsRepository instance = ShortsRepository._();

  Future<List<StoryVideo>> fetchShorts({String sort = 'latest'}) async {
    final response =
        await http.get(Uri.parse(ApiConfig.shortsUrl(sort: sort)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('쇼츠 조회 실패 (${response.statusCode})');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['content'] as List<dynamic>? ?? const [])
        .map((e) => StoryVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

Run: `flutter test test/model/story_video_test.dart test/repository/shorts` / Expected: PASS

- [ ] **Step 4: 커밋**

```bash
git add lib/model/story_video.dart lib/repository/shorts lib/config/api_config.dart test/model/story_video_test.dart test/repository/shorts
git commit -m "feat: 쇼츠 모델·repository 추가

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 4: 미구현 API용 데이터 소스 인터페이스 + 목업 구현

백엔드가 없는 솔랭 상태·평점·뉴스를 인터페이스 뒤로 옮긴다. 현재 `HomeViewModel`에 박힌 `mockLiveNow`·`mockFinishedToday`·`mockReviews`·`mockNews`가 `Mock*Source`로 간다. 백엔드가 준비되면 구현체만 교체한다.

**Files:**
- Create: `lib/repository/home/home_sources.dart`
- Modify: `lib/viewmodel/home/home_viewmodel.dart`(모델 클래스 `HomeLiveSoloPlayer` 등은 그대로 두고 `mock*` 상수만 옮긴다)
- Test: `test/repository/home/home_sources_test.dart`

**Interfaces:**
- Produces:
  - `SoloRankSnapshot{List<HomeLiveSoloPlayer> live, List<HomeFinishedSoloPlayer> finished, int subscribedTotal}`
  - `abstract class SoloRankSource { Future<SoloRankSnapshot> fetch(); }` — 솔랭 DTO(`gameStartTime`·챔피언·직전 결과)가 생기면 구현체를 교체한다(spec "새로").
  - `abstract class ReviewSource { Future<List<HomeReviewItem>> fetchRecent(); }` — 한줄평 달린 것만 반환한다는 계약.
  - `abstract class NewsSource { Future<List<HomeNewsArticle>> fetchTop(); }` — 주의: 실제 `/api/community/news`는 LoL 필터가 붙기 전에는 홈에 내보내면 안 된다(spec 미결). 그래서 이 소스는 **목업 구현만** 연결한다.
  - `MockSoloRankSource`, `MockReviewSource`, `MockNewsSource` — 각각 위 인터페이스 구현, 현재 `HomeViewModel.mock*` 값을 그대로 반환.

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/repository/home/home_sources_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/home/home_sources.dart';

void main() {
  test('MockSoloRankSource: 진행 중과 끝난 경기를 따로 준다', () async {
    final snap = await MockSoloRankSource().fetch();
    expect(snap.live, isNotEmpty);
    expect(snap.finished, isNotEmpty);
    expect(snap.subscribedTotal, greaterThanOrEqualTo(snap.live.length));
  });

  test('MockReviewSource: 한줄평이 빈 항목은 없다', () async {
    final reviews = await MockReviewSource().fetchRecent();
    expect(reviews, isNotEmpty);
    expect(reviews.every((r) => r.comment.trim().isNotEmpty), isTrue);
    expect(reviews.every((r) => r.stars >= 1 && r.stars <= 5), isTrue);
    expect(reviews.every((r) => r.comment.length <= 150), isTrue);
  });

  test('MockNewsSource: 기사를 준다', () async {
    expect(await MockNewsSource().fetchTop(), isNotEmpty);
  });
}
```

- [ ] **Step 2: 실행 → 실패 확인** — Run: `flutter test test/repository/home/home_sources_test.dart` / Expected: FAIL

- [ ] **Step 3: 구현** — `home_sources.dart`에 위 인터페이스와 `Mock*Source`를 만들고, 값은 `home_viewmodel.dart`의 `mockLiveNow`·`mockFinishedToday`·`mockSubscribedTotal`·`mockReviews`·`mockNews`를 **그대로 이동**한다(`const` 목록을 소스 안으로). 주의: 이동하면 `home_viewmodel.dart`가 `home_sources.dart`를 import하고, `home_sources.dart`도 `HomeLiveSoloPlayer` 등 모델을 쓰므로 **순환 import**가 생긴다. 모델 클래스(`HomeLiveSoloPlayer`, `HomeFinishedSoloPlayer`, `HomeReviewItem`, `HomeNewsArticle`, `HomeStandingRow` 등)를 `lib/model/home_models.dart`로 먼저 옮기고 양쪽이 그것을 import하게 한다. 기존 import(`home_viewmodel.dart`를 통해 모델을 쓰는 섹션 위젯·테스트)는 `import '../../../model/home_models.dart';`를 추가해 고친다.

- [ ] **Step 4: 통과 + 컴파일 확인**

Run: `flutter analyze lib/model/home_models.dart lib/repository/home lib/viewmodel/home lib/screens/home && flutter test test/repository/home` / Expected: 오류 0, PASS. (이 시점에 `home_viewmodel_test`는 아직 `mock*` 상수를 참조하므로 Task 5에서 다시 쓴다 — 지금은 상수를 VM에 그대로 두고 소스가 같은 값을 복제 참조하게 해 테스트를 깨지 않는다.)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/home_models.dart lib/repository/home lib/viewmodel/home lib/screens/home test/repository/home
git commit -m "refactor: 홈 미구현 API용 데이터 소스 인터페이스와 목업 구현 분리

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 5: `HomeViewModel`을 소스 기반으로 재구성

**Files:**
- Modify: `lib/viewmodel/home/home_viewmodel.dart`
- Test: `test/viewmodel/home/home_viewmodel_test.dart`(전면 재작성)

**Interfaces:**
- Consumes: Task 1~4의 repository·소스, 기존 `ScheduleRepository.fetchMatchesByDate(DateTime, {List<String> leagues})`, `NoticeRepository.fetchPromoted/cachedPromoted`, `NoticePreferenceRepository`, `SubscriptionRepository.fetchSubscribedPlayers() → Future<List<PlayerSubscription>>`, `CommunityRepository.fetchPosts({size, sort})`.
- Produces (기존 UI가 쓰는 이름은 유지한다):
  - 생성자: `HomeViewModel({NoticeRepository? notices, NoticePreferenceRepository? noticePreferences, ScheduleRepository? schedule, StandingsRepository? standings, CommunityRepository? community, ShortsRepository? shorts, SubscriptionRepository? subscriptions, SoloRankSource? soloRank, ReviewSource? reviews, NewsSource? news})`
  - 솔랭: `List<HomeLiveSoloPlayer> soloLive`(핀 먼저 → 없으면 가장 최근 시작 순), `List<HomeFinishedSoloPlayer> soloFinished`(선수당 최신 1건, 최대 8명), `int soloHiddenCount`, `int subscribedTotal`, `SoloCardState soloState`(`enum SoloCardState { noSubscription, noneActive, active }`), `soloSwipeIndex`/`setSoloSwipeIndex`, `Set<String> pinnedPlayerNames`/`togglePin(String)`
  - 오늘 경기: `List<ScheduleMatch> todayMatchesSorted`(진행 중 먼저), `loadTodayMatches()`
  - 순위: `List<HomeLeagueChip> leagueChips`(LCK만 `live: true`, LPL·LEC·LCS·월즈 `live: false`), `selectLeague`, `StandingsResult? standings`
  - 커뮤니티: `HomeCommunitySort communitySort`(기본 `latest`), `setCommunitySort`(hot이면 `fetchPosts(sort:'hot')`), `List<CommunityRemotePost> communityPosts`, `List<HomeReviewItem> reviews`
  - 콘텐츠: `HomeContentTab contentTab`(기본 `news`), `setContentTab`, `List<HomeNewsArticle> news`, `HomeShortsFilter shortsFilter`(기본 `all`), `setShortsFilter`, `List<HomeShortsVideo> shortsFiltered`
  - 공통: `Future<void> refreshAll()`
  - 로딩·에러 getter는 만들지 않는다(spec: 안 그림). 실패는 `debugPrint`만 하고 마지막 값을 유지한다.

- [ ] **Step 1: 실패 테스트 작성** — 솔랭 규칙과 상태 전이를 가짜 소스로 검증한다. 소스는 `SoloRankSource` 익명 구현으로 주입한다.

```dart
// test/viewmodel/home/home_viewmodel_test.dart (핵심 케이스)
class _FakeSolo implements SoloRankSource {
  _FakeSolo(this.snap);
  final SoloRankSnapshot snap;
  @override
  Future<SoloRankSnapshot> fetch() async => snap;
}

HomeLiveSoloPlayer live(String name, int elapsed) => HomeLiveSoloPlayer(
    name: name, teamCode: 'T1', champion: '아리', elapsedSeconds: elapsed);
HomeFinishedSoloPlayer done(String name, int minutesAgo) =>
    HomeFinishedSoloPlayer(
        name: name, teamCode: 'T1', won: true, minutesAgo: minutesAgo);

test('구독 0명이면 noSubscription', () async {
  final vm = HomeViewModel(
    soloRank: _FakeSolo(const SoloRankSnapshot(live: [], finished: [], subscribedTotal: 0)),
    /* 나머지는 빈 응답 MockClient 로 성립시킨다 */
  );
  await pumpEventQueue();
  expect(vm.soloState, SoloCardState.noSubscription);
});

test('구독은 있는데 진행 중이 0명이면 noneActive', () async { /* subscribedTotal: 5, live: [] */ });

test('진행 중이 있으면 active, 가장 최근 시작(경과 시간 짧은) 선수가 먼저', () async {
  // live: A 경과 900초, B 경과 100초 → soloLive.first.name == 'B'
});

test('핀 고정 선수가 최근 시작 순서보다 먼저', () async {
  // togglePin('A') 후 soloLive.first.name == 'A'
});

test('끝난 경기는 선수당 1건, 최대 8명, 나머지는 soloHiddenCount', () async {
  // finished 에 같은 선수 2건 + 서로 다른 선수 9명 → soloFinished.length == 8,
  // 같은 이름 중복 없음, soloHiddenCount == subscribedTotal - live.length - 8
});

test('커뮤니티 기본은 최신순이고 hot 으로 바꾸면 sort=hot 으로 다시 조회한다', () async { /* MockClient 로 쿼리 캡처 */ });

test('콘텐츠 기본 탭은 뉴스', () { expect(vm.contentTab, HomeContentTab.news); });

test('쇼츠 전체 필터: 내 선수 → 내 팀 → 나머지 순', () async { /* 매칭 3종 섞어 정렬 검증 */ });

test('일정 조회가 실패해도 마지막 값을 유지하고 다른 섹션은 정상', () async {
  // 1차 성공 후 2차 500 → todayMatchesSorted 유지
});
```

각 케이스는 위 주석대로 **완성된 테스트 코드**로 채운다(가짜 소스·`MockClient` 라우팅은 옛 계획 Task 6의 `mockApi` 헬퍼 패턴을 재사용: 경로에 `notices`/`schedule`/`standings`/`community/posts`/`videos`/`player-subscriptions`가 있으면 각각 응답, 그 밖은 `fail`).

- [ ] **Step 2: 실행 → 실패 확인** — Run: `flutter test test/viewmodel/home/home_viewmodel_test.dart` / Expected: FAIL(`SoloCardState` 등 미정의)

- [ ] **Step 3: 구현**
  - `SoloCardState` enum 추가. `_recomputeSolo()`: 소스 스냅샷에서 `soloLive`(핀 우선, 그다음 `elapsedSeconds` 오름차순 = 가장 최근 시작), `soloFinished`(이름 기준 중복 제거해 `minutesAgo` 최소인 1건만, 8명 cut), `soloHiddenCount = max(0, subscribedTotal - soloLive.length - soloFinished.length)`, `soloState` 판정을 한다.
  - `subscribedTotal`은 `SubscriptionRepository.fetchSubscribedPlayers().length`를 우선 쓰고 실패하면 소스 값을 쓴다(구독 수는 실데이터가 이미 있다).
  - 생성자에서 공지 캐시를 동기로 채우고 나머지는 fire-and-forget 로드. 섹션 로더는 예외를 삼키고 `debugPrint`, 마지막 값 유지.
  - `setCommunitySort(hot)`은 `fetchPosts(size: 4, sort: 'hot')`, `latest`는 `sort: 'latest'`.
  - 쇼츠: `ShortsRepository.fetchShorts()`로 받은 `StoryVideo`를 `HomeShortsVideo`로 변환(제목에 구독 선수 활동명·이름이 포함되면 `matchedPlayer` 설정, 팀 코드는 채널/제목 매칭). 매칭 방식은 Task 3 Step 1에서 확인한 응답 필드에 따른다. "내 팀"은 구독 선수 소속팀 합집합(spec 미결의 잠정안, 주석으로 남긴다).
  - 옛 `mock*` static 상수는 제거하고 테스트·위젯의 참조를 VM getter로 바꾼다.

- [ ] **Step 4: 통과 확인** — Run: `flutter test test/viewmodel/home` / Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/viewmodel/home test/viewmodel/home
git commit -m "feat: HomeViewModel 실데이터·소스 기반 재구성

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 6: 섹션 위젯을 VM·spec 상태 규칙에 연결

**Files:**
- Modify: `lib/screens/home/home_screen.dart`, `lib/screens/home/component/home_solo_rank_section.dart`, `home_today_matches_section.dart`, `home_standings_section.dart`, `home_community_section.dart`, `home_content_section.dart`
- Modify: `lib/l10n/app_ko.arb`, `app_en.arb`(+ `flutter gen-l10n`)
- Test: `test/screens/home/home_solo_rank_section_test.dart`, `home_standings_section_test.dart`, `home_content_section_test.dart`

**Interfaces:**
- Consumes: Task 5의 VM getter 전부, `AppColors` 토큰.
- Produces: 없음(화면 조립). 오늘 경기 스트립 마지막 카드 → `onSeeSchedule` 콜백, 솔랭 카드 "구독 N명 전체" → `onOpenMyPlayers` 콜백(Task 7에서 연결).

- [ ] **Step 1: 솔랭 카드 상태별 위젯 테스트 작성** — `noSubscription`이면 점선 빈 카드와 빈 프로필 이미지, `noneActive`이면 한 줄짜리 조용한 상태, `active`이면 큰 카드 + 아래 끝난 줄 + "+N명" 칩 + "구독 N명 전체"가 보인다. `active`에서 관전하기·포지션·스코어 텍스트가 **없음**을 `findsNothing`으로 확인한다. 끝난 카드에 "분 전 종료" 문구, 길이는 "분"만(“플레이” 없음)을 검증한다. 경과 시간은 라이브 카드 유일한 숫자다.

- [ ] **Step 2: 순위 테스트** — LPL·LEC·LCS 칩은 점선 스타일이며 탭해도 `selectLeague`가 불리지 않는다. 1위 행에 별도 강조 위젯이 없다(순위 숫자 스타일이 다른 행과 같음). 데이터 없음이면 섹션 자체가 스피너를 그리지 않는다(`find.byType(CircularProgressIndicator)` `findsNothing`).

- [ ] **Step 3: 콘텐츠 테스트** — 기본 탭이 뉴스, 쇼츠 탭에서 "내 선수" 필터가 0건이면 점선 박스 문구가 보인다, 평점 한줄평은 콘텐츠가 아니라 커뮤니티 섹션 탭에 있다. 커뮤니티 기본 탭은 최신순.

- [ ] **Step 4: 실행 → 실패 확인** — Run: `flutter test test/screens/home` / Expected: FAIL

- [ ] **Step 5: 구현**
  - 각 섹션이 `viewModel`의 getter를 읽도록 바꾼다(목업 상수 참조 제거). 로딩/에러 UI를 추가하지 않는다.
  - 솔랭 카드에 3상태 분기와 점선 빈 카드(`DottedBorder`가 없다면 `CustomPainter`로 직접 그린다 — 의존성 추가 금지; 순위표 점선 칩도 같은 페인터를 공유하는 `lib/components/dashed_border.dart`로 만든다).
  - 강조색은 `AppColors.narBg` 계열 옅은 오버레이. 기존에 신호색(초록·주황·보라 단색)을 쓴 곳이 있으면 브랜드 3색으로 바꾼다 — `grep -n "Color(0x" lib/screens/home`으로 하드코딩도 함께 걷어낸다.
  - 오늘 경기 스트립 마지막 카드(“일정 전체”)를 탭하면 `onSeeSchedule` → `HomeScreen`이 `Navigator.pushReplacement(tabRoute(const ScheduleScreen()))`.
  - `HomeScreen._TopBar`의 알림 배지 숫자 `'3'` 하드코딩은 spec에 없는 목업 값이다. 안 읽은 알림 수를 주는 기존 `MemberNotificationRepository`가 있으면 그것을 쓰고, 없으면 배지를 뺀다(하드코딩 유지 금지).
  - 새 l10n 키(빈 상태 문구 등)는 ko/en 둘 다 추가하고 `flutter gen-l10n`.

- [ ] **Step 6: 통과 + 수동 확인**

Run: `flutter test test/screens/home test/viewmodel/home && flutter analyze lib/screens/home`
그다음 `run-warding` 스킬로 iOS 시뮬레이터에서 홈을 띄워 5개 섹션 스크린샷을 `mockup.html`(375px)과 나란히 비교한다. 솔랭·평점·뉴스는 목업 값이고 나머지는 실데이터인지 눈으로 확인한다.

- [ ] **Step 7: 커밋**

```bash
git add lib/screens/home lib/components/dashed_border.dart lib/l10n test/screens/home
git commit -m "feat: 홈 섹션을 실데이터·spec 상태 규칙에 연결

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 7: 내 선수(구독 전체) 화면

spec 화면 목록: "구독 100명 기준. 검색줄과 팀별 필터가 있다. 상태별로 묶는다(솔랭 중 / 오늘 경기함 / 소식 없음)". 소식 없는 선수는 "N명 더 보기" 뒤에 접는다. 보기 전용, 알림 벨 없음. 뒤로가기 → 홈.

**Files:**
- Create: `lib/viewmodel/my_players/my_players_viewmodel.dart`, `lib/screens/my_players/my_players_screen.dart`, `lib/screens/my_players/component/my_player_tile.dart`
- Modify: `lib/screens/home/home_screen.dart`(`onOpenMyPlayers` → `Navigator.push`), `lib/l10n/*.arb`
- Test: `test/viewmodel/my_players/my_players_viewmodel_test.dart`, `test/screens/my_players/my_players_screen_test.dart`

**Interfaces:**
- Consumes: `SubscriptionRepository.fetchSubscribedPlayers() → List<PlayerSubscription>{playerId, playerName, playerImageUrl, teamCode, ...}`, `SoloRankSource.fetch() → SoloRankSnapshot`.
- Produces:
  - `enum MyPlayerStatus { liveSolo, playedToday, quiet }`
  - `class MyPlayerEntry { final PlayerSubscription player; final MyPlayerStatus status; final HomeLiveSoloPlayer? live; final HomeFinishedSoloPlayer? finished; }`
  - `MyPlayersViewModel({SubscriptionRepository? subscriptions, SoloRankSource? soloRank})` — `String query`, `setQuery(String)`, `String? teamCode`, `setTeamCode(String?)`, `List<String> teamCodes`(구독 선수 소속팀 유니크), `List<MyPlayerEntry> get liveSolo/playedToday/quiet`(검색·팀 필터 적용), `bool quietExpanded`, `toggleQuietExpanded()`, `int get quietHiddenCount`.
  - `MyPlayersScreen({super.key})`

- [ ] **Step 1: VM 실패 테스트 작성** — 100명(예: 팀 10개 × 10명) 가짜 구독을 만들어 검증한다.
  - 상태 분류: 솔랭 진행 이름 → `liveSolo`, 오늘 종료 이름 → `playedToday`, 나머지 → `quiet`. 진행 중이면서 종료 기록도 있는 선수는 `liveSolo`에만 (같은 선수 두 번 나오지 않는다).
  - `setQuery('fak')` → 이름 부분일치(대소문자 무시)로 세 그룹 모두 필터.
  - `setTeamCode('T1')` → 해당 팀만. `null`이면 전체.
  - `quiet`는 기본 접힘: 화면에 보일 개수 상한(예: 5)을 두고 `quietHiddenCount = quiet.length - 5`, `toggleQuietExpanded()` 후 전부.

- [ ] **Step 2: 실행 → 실패 확인** — Run: `flutter test test/viewmodel/my_players` / Expected: FAIL

- [ ] **Step 3: VM 구현** — `ChangeNotifier`, `BuildContext` 의존 없음. 생성자에서 두 소스를 병렬 로드(실패 시 마지막 값 유지·`debugPrint`), 분류·필터는 getter에서 계산.

- [ ] **Step 4: 화면 위젯 테스트 → 구현** — 위젯 테스트: 검색줄, 팀 칩 줄(`NarChipMultiSelect` 재사용), 섹션 제목 3개(솔랭 중/오늘 경기함/소식 없음), "N명 더 보기" 탭 시 펼침, 앱바에 알림 벨 아이콘 **없음**(`find.byIcon`/`assets/icons/bell.svg` findsNothing), 로딩·에러 UI 없음. 화면은 `ListenableBuilder`로 VM을 구독하고 `scale` 규칙을 따른다. 목록은 100명 기준이므로 `ListView.builder`/`SliverList`를 쓴다(`Column` 안에 100개 위젯을 펼치지 않는다). 뒤로가기는 `Navigator.pop`(홈으로 돌아옴).

- [ ] **Step 5: 홈 연결** — `HomeScreen`에서 `onOpenMyPlayers: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyPlayersScreen()))`. push라서 뒤로가기가 홈으로 돌아온다(spec 사용자 흐름 3번).

- [ ] **Step 6: 통과 확인 후 커밋**

Run: `flutter test test/viewmodel/my_players test/screens/my_players test/screens/home && flutter analyze lib/screens/my_players lib/viewmodel/my_players`

```bash
git add lib/viewmodel/my_players lib/screens/my_players lib/screens/home lib/l10n test/viewmodel/my_players test/screens/my_players
git commit -m "feat: 내 선수(구독 전체) 화면 추가

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 8: 앱 진입 화면을 홈으로

**Files:**
- Modify: `lib/screens/splash_screen.dart:280-282`, `lib/screens/login/login_screen.dart:49`, `lib/screens/onboarding/onboarding_screen.dart:66`
- Test: 기존 테스트 중 진입 화면을 검증하는 것(`grep -rn "ScheduleScreen" test`)을 함께 갱신

- [ ] **Step 1: 영향 범위 확인** — Run: `grep -rn "ScheduleScreen" lib test`. 다른 탭 화면이 '경기일정' 탭 복귀에 쓰는 `ScheduleScreen()`은 그대로 둔다(탭 이동). 바꿀 곳은 **진입점 세 곳**(스플래시·로그인·온보딩 완료)뿐이다.

- [ ] **Step 2: 실패 테스트 작성/수정** — 진입을 검증하는 기존 테스트가 있으면 기대 위젯을 `HomeScreen`으로 바꿔 먼저 실패시킨다. 없으면 splash `_proceed`가 jwt 있을 때 `HomeScreen`을 띄우는 위젯 테스트를 추가한다(`test/screens`에 splash 테스트 패턴이 없으면 이 스텝은 `flutter analyze`와 Step 4 수동 확인으로 대체하고 그 사실을 보고에 적는다).

- [ ] **Step 3: 구현** — 세 곳의 `const ScheduleScreen()`을 `const HomeScreen()`으로 바꾸고 import를 정리한다. `HomeScreen` 상단 문서 주석의 "로그인 후 진입점은 여전히 ScheduleScreen이다" 문장을 지운다(사실이 바뀐다).

- [ ] **Step 4: 딥링크·Live Activity 회귀 확인** — `splash_screen.dart`의 보류 딥링크 소비 로직(pushReplacement 이후 push)은 목적지 화면이 바뀌어도 동일하게 동작해야 한다. 코드를 읽어 목적지 타입에 의존하는 분기가 없는지 확인하고, 시뮬레이터에서 앱 재시작 시 홈이 뜨는지 `run-warding`으로 확인한다.

- [ ] **Step 5: 전체 테스트 + 커밋**

Run: `flutter test` / Expected: 전부 PASS

```bash
git add lib/screens/splash_screen.dart lib/screens/login/login_screen.dart lib/screens/onboarding/onboarding_screen.dart lib/screens/home/home_screen.dart test
git commit -m "feat: 앱 진입 화면을 경기일정에서 홈으로 변경

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

### Task 9: 문서 동기화 (CLAUDE.md 규칙)

**Files:**
- Create: `wiki/features/home.md`
- Modify: `wiki/features/index.md`, `wiki/index.md`, `wiki/log.md`, `CLAUDE.md`(진행 상황), `docs/superpowers/plans/2026-09-21-home-screen-phase1.md`·`specs/2026-09-21-home-screen-design.md` 상단에 "2026-09-24 v29 spec 기준 계획으로 대체됨" 한 줄

- [ ] **Step 1: `wiki/features/home.md`** — 프론트매터 `type: feature`, 섹션 5개·내 선수 화면·데이터 소스 표(실데이터 vs 목업)·spec 링크(`warding-docs/features/home/spec.md`)·미결 요약. 기존 `wiki/features/matches.md`의 형식을 먼저 읽고 맞춘다. 링크는 번들-상대 `[제목](/features/home.md)` 형식.
- [ ] **Step 2:** `wiki/features/index.md`와 루트 `wiki/index.md`에 링크, `wiki/log.md` 맨 위에 `## 2026-09-24` 항목 추가.
- [ ] **Step 3:** `CLAUDE.md`의 "다음 작업: 경기 페이지" 진행 상황에 "홈 화면(솔랭·평점·뉴스는 목업, 백엔드 대기)"을 반영한다.
- [ ] **Step 4: 커밋**

```bash
git add wiki CLAUDE.md docs/superpowers
git commit -m "docs: 홈 화면 wiki·진행 상황 동기화

Claude-Session: https://claude.ai/code/session_01J2gethNxve7XVWBxeV8ZHz"
```

---

## Self-Review (spec 대비)

| spec 항목 | 담당 |
|---|---|
| 사용자 흐름 1 (앱 진입 = 홈) | Task 8 |
| 흐름 2 솔랭 카드(진행 중 경과 시간 / 끝남 결과) | Task 4·5·6 (목업 소스) |
| 흐름 3 "구독 N명 전체" → 내 선수, 뒤로 = 홈 | Task 7 |
| 흐름 4 오늘 경기 마지막 카드 → 일정 탭 | Task 6 |
| 흐름 5 순위 리그 칩 | Task 1·5·6 |
| 흐름 6 커뮤니티(글·평점)·콘텐츠(뉴스·쇼츠) 탭 | Task 2·3·5·6 |
| 화면 상태 표(빈 상태·로딩/에러 안 그림) | Global Constraints, Task 5·6 |
| 결정: 솔랭 규칙·평점 규칙·기본 탭·쇼츠 정렬·1위 무강조·브랜드 3색 | Global Constraints, Task 5·6 |
| API 표 중 "새로"(솔랭 DTO·평점 최근순·`/api/mobile/home`·한글 활동명) | 이번 범위 밖 — Task 4 인터페이스 뒤 목업, 백엔드 준비 시 구현체 교체 |
| 뉴스(TOP 5 고정·LoL 필터 없음) | Task 4: 목업만 연결(spec 미결 "필터 붙기 전엔 홈에 내보내면 안 됨") |

**범위 밖(spec 미결이라 임의로 정하지 않음):** 핀 고정 최대 인원, 스와이프 중 카드 교체 시점, 결과 카드 노출 시간(6시간 추정), 평점 "최근" 범위·최소 참여, 스위스/토너먼트 전환, 섹션 순서 변경, 쇼츠 인앱 재생, `/api/mobile/home` 일괄 수신. 핀 고정은 Task 5에서 인원 제한 없이 로컬 상태로만 구현하고 미결임을 주석에 남긴다.

**타입 일관성 점검:** `SoloRankSnapshot{live, finished, subscribedTotal}`(Task 4) ↔ Task 5·7 사용 일치, `SoloCardState`(Task 5) ↔ Task 6 사용 일치, `MyPlayerEntry.live/finished`는 Task 4 모델 타입 재사용, `fetchPosts(sort:)`(Task 2) ↔ Task 5 사용 일치.
