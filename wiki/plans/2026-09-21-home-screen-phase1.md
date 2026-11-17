> 2026-09-24: spec v29 기준 계획(docs/superpowers/plans/2026-09-24-home-screen-v29.md)으로 대체됨.

# 홈 화면 (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 목업(`warding-home-final.html`) 기반의 홈 화면을 앱에 추가한다 — 공지 배너, 오늘의 경기, 순위표(리그 테이블), 커뮤니티, 유튜브 쇼츠 다섯 섹션을 하나의 화면에 모으고, 하단 탭바 첫 번째 탭이자 로그인/온보딩 완료 후 진입 화면으로 연결한다.

**Architecture:** 화면 하나에 `HomeViewModel`(ChangeNotifier) 하나. 5개 데이터 소스(공지·일정·순위표·커뮤니티·쇼츠)를 병렬로 불러오되 섹션마다 독립된 로딩/에러 상태를 갖는다. 화면은 섹션별 위젯으로 쪼개 `screens/home/component/`에 두고, `HomeScreen`이 조립한다. 재사용 가능한 기존 repository(`ScheduleRepository`, `NoticeRepository`, `CommunityRepository`)와 컴포넌트(`NarBanner`, `LoadError`, `NarChip`, `AuthorLine`, `NarBadge`/`NarLiveBadge`)를 최대한 그대로 쓴다.

**Tech Stack:** Flutter/Dart, `package:http`(`lib/util/api_client.dart` 래퍼), `cached_network_image`, `url_launcher`, `flutter_test` + `http/testing.dart`(`MockClient`).

**Spec:** [docs/superpowers/specs/2026-09-21-home-screen-design.md](../specs/2026-09-21-home-screen-design.md) — 근거 목업은 `/Users/yunhongbi/Downloads/warding-home-final.html`.

## Global Constraints

- 색은 전부 `lib/styles/app_colors.dart`의 `AppColors` 기존 토큰을 쓴다. 이번 작업으로 필요한 색은 전부 이미 있다(`liveBadgeBg`/`liveAccent`/`liveSideBorder`/`scoreWin`/`narGreenWin`/`narChipActive`/`narChipSelectedBg` 등) — 새 토큰을 추가하지 않는다.
- 모든 사용자 노출 문자열은 `lib/l10n/app_ko.arb` + `app_en.arb`에 키를 추가하고 `flutter gen-l10n`으로 생성한 뒤 `AppLocalizations.of(context)!.xxx`로 쓴다. 하드코딩 금지.
- 비율 스케일: `final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;`를 모든 신규 위젯에 적용한다(기존 화면과 동일 패턴).
- 파일 위치는 CLAUDE.md 규칙을 따른다 — 화면 `screens/home/`, 화면 전용 위젯 `screens/home/component/`, ViewModel `viewmodel/home/`, 모델 `model/`, 리포지토리 `repository/{기능}/`.
- 새 repository는 기존 6개와 동일한 패턴을 따른다: `XxxRepository._()` private 생성자 + `static final instance`, `lib/util/api_client.dart`를 `as http`로 사용, non-2xx면 `Exception` throw, `jsonDecode(utf8.decode(response.bodyBytes))`로 파싱.
- 테스트는 이 저장소의 기존 관례를 따른다 — mocktail이 아니라 `http.testing.MockClient`로 `api.setApiClientForTesting(...)`를 걸어 실제 싱글턴 repository/viewmodel을 그대로 쓴다 (`test/repository/notice/notice_repository_test.dart`, `test/viewmodel/schedule/schedule_banner_test.dart` 참고).

---

### Task 1: `Standing` 모델

**Files:**
- Create: `lib/model/standing.dart`
- Test: `test/model/standing_test.dart`

**Interfaces:**
- Produces: `StandingsResult{league, supported, reason, scopeLabel, groups}`, `StandingGroup{name, rows}`, `StandingRow{rank, teamCode, teamName, imageUrl, wins, losses, setDiff}` — 모두 `fromJson(Map<String, dynamic>)` 팩토리 보유.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/model/standing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/standing.dart';

void main() {
  group('StandingsResult.fromJson', () {
    test('지원 리그: groups·rows를 그대로 파싱한다', () {
      final json = {
        'league': 'LCK',
        'supported': true,
        'reason': null,
        'scopeLabel': '2026 정규시즌',
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
      };

      final result = StandingsResult.fromJson(json);

      expect(result.league, 'LCK');
      expect(result.supported, isTrue);
      expect(result.scopeLabel, '2026 정규시즌');
      expect(result.groups, hasLength(1));
      final row = result.groups.single.rows.single;
      expect(row.rank, 1);
      expect(row.teamCode, 'GEN');
      expect(row.wins, 19);
      expect(row.losses, 7);
      expect(row.setDiff, 22);
    });

    test('미지원 리그: supported=false와 reason만 있고 groups는 빈 목록', () {
      final json = {
        'league': '월즈',
        'supported': false,
        'reason': '스위스 스테이지는 순위표를 지원하지 않습니다',
        'scopeLabel': '',
        'groups': <dynamic>[],
      };

      final result = StandingsResult.fromJson(json);

      expect(result.supported, isFalse);
      expect(result.reason, '스위스 스테이지는 순위표를 지원하지 않습니다');
      expect(result.groups, isEmpty);
    });

    test('필드 누락에도 죽지 않고 기본값으로 채운다', () {
      final result = StandingsResult.fromJson(const {});

      expect(result.league, '');
      expect(result.supported, isFalse);
      expect(result.reason, isNull);
      expect(result.groups, isEmpty);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/model/standing_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:warding/model/standing.dart'`

- [ ] **Step 3: 모델 구현**

```dart
// lib/model/standing.dart

/// 리그 순위표 조회 결과 (`GET /api/standings`).
///
/// [supported] 가 false 면 이 리그는 순위표 형태를 지원하지 않는다는 뜻이다
/// (스위스 스테이지·토너먼트 등). 이때 [groups] 는 비어 있고 [reason] 에
/// 사용자에게 보여줄 안내 문구가 담긴다.
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

/// 순위표 그룹 한 덩이 (예: '레전드 그룹', '라이즈 그룹'). 그룹이 없는 리그도
/// 서버가 길이 1인 목록으로 내려준다.
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

  /// 세트 득실. 매치 전적이 동률일 때 순위를 가르는 값.
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

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/model/standing_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/standing.dart test/model/standing_test.dart
git commit -m "feat: 홈 화면용 순위표(Standing) 모델 추가"
```

---

### Task 2: `StandingsRepository`

**Files:**
- Modify: `lib/config/api_config.dart` (끝에 순위표 URL 빌더 추가)
- Create: `lib/repository/standings/standings_repository.dart`
- Test: `test/repository/standings/standings_repository_test.dart`

**Interfaces:**
- Consumes: `StandingsResult.fromJson` (Task 1)
- Produces: `StandingsRepository.instance.fetchStandings(String league) → Future<StandingsResult>`, `ApiConfig.standingsUrl({required String league})`

- [ ] **Step 1: 실패하는 테스트 작성**

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
    Uri? capturedUrl;
    api.setApiClientForTesting(MockClient((request) async {
      capturedUrl = request.url;
      return http.Response(
        jsonEncode({
          'league': 'LCK',
          'supported': true,
          'reason': null,
          'scopeLabel': '2026 정규시즌',
          'groups': [
            {
              'name': '레전드 그룹',
              'rows': [
                {
                  'rank': 1,
                  'teamCode': 'GEN',
                  'teamName': 'Gen.G',
                  'wins': 19,
                  'losses': 7,
                  'setDiff': 22,
                },
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final result = await repo.fetchStandings('LCK');

    expect(capturedUrl?.queryParameters['league'], 'LCK');
    expect(result.league, 'LCK');
    expect(result.groups.single.rows.single.teamCode, 'GEN');
  });

  test('미지원 리그는 supported=false로 그대로 올라온다', () async {
    api.setApiClientForTesting(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'league': '월즈',
          'supported': false,
          'reason': '스위스 스테이지는 순위표를 지원하지 않습니다',
          'scopeLabel': '',
          'groups': <dynamic>[],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final result = await repo.fetchStandings('월즈');

    expect(result.supported, isFalse);
    expect(result.reason, isNotEmpty);
  });

  test('non-2xx면 예외를 던진다', () async {
    api.setApiClientForTesting(MockClient((request) async {
      return http.Response('', 500);
    }));

    await expectLater(repo.fetchStandings('LCK'), throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/repository/standings/standings_repository_test.dart`
Expected: FAIL — `standings_repository.dart` 없음

- [ ] **Step 3: `ApiConfig`에 URL 빌더 추가**

`lib/config/api_config.dart`의 `## 9. Standings API` 자리(파일 끝, `logoutUrl` 앞 아무 곳)에 추가:

```dart
  // ── 순위표 (인증 불필요) ─────────────────────────────────────────

  /// 리그 순위표 조회. [league] 는 'LCK'·'LPL'·'LEC'·'LCS' 등.
  /// 순위표가 없는 대회(스위스·토너먼트)는 응답의 `supported`가 false다.
  static String standingsUrl({required String league}) =>
      '$apiBaseUrl/standings?league=${Uri.encodeQueryComponent(league)}';
```

- [ ] **Step 4: Repository 구현**

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

  /// [league] 의 순위표를 조회한다. 캐시하지 않는다 — 리그 칩 전환마다
  /// 새로 받아도 무리 없는 크기다.
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

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/repository/standings/standings_repository_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: 커밋**

```bash
git add lib/config/api_config.dart lib/repository/standings/standings_repository.dart test/repository/standings/standings_repository_test.dart
git commit -m "feat: 순위표 조회 repository 추가 (/api/standings)"
```

---

### Task 3: `StoryVideo` 모델

**Files:**
- Create: `lib/model/story_video.dart`
- Test: `test/model/story_video_test.dart`

**Interfaces:**
- Produces: `StoryVideo{videoId, youtubeVideoId, title, videoUrl, thumbnailUrl, channelName, viewCount, publishedAt}.fromJson(...)`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/model/story_video_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/story_video.dart';

void main() {
  test('StoryVideo.fromJson: 필드를 그대로 파싱한다', () {
    final json = {
      'videoId': 1001,
      'youtubeVideoId': 'abc123',
      'title': '제우스 하이라이트',
      'videoUrl': 'https://youtube.com/watch?v=abc123',
      'thumbnailUrl': 'https://img/thumb.jpg',
      'channelName': 'LCK',
      'viewCount': 12345,
      'publishedAt': '2026-09-20T10:00:00',
    };

    final video = StoryVideo.fromJson(json);

    expect(video.videoId, 1001);
    expect(video.youtubeVideoId, 'abc123');
    expect(video.title, '제우스 하이라이트');
    expect(video.videoUrl, 'https://youtube.com/watch?v=abc123');
    expect(video.viewCount, 12345);
    expect(video.publishedAt, DateTime.parse('2026-09-20T10:00:00'));
  });

  test('필드 누락에도 죽지 않고 기본값으로 채운다', () {
    final video = StoryVideo.fromJson(const {});

    expect(video.videoId, 0);
    expect(video.title, '');
    expect(video.viewCount, 0);
    expect(video.publishedAt, isNull);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/model/story_video_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 모델 구현**

```dart
// lib/model/story_video.dart

/// 유튜브 스토리 영상 한 건 (`GET /api/story/videos` 응답 항목).
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

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/model/story_video_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/story_video.dart test/model/story_video_test.dart
git commit -m "feat: 유튜브 쇼츠(StoryVideo) 모델 추가"
```

---

### Task 4: `ShortsRepository`

**Files:**
- Modify: `lib/config/api_config.dart`
- Create: `lib/repository/shorts/shorts_repository.dart`
- Test: `test/repository/shorts/shorts_repository_test.dart`

**Interfaces:**
- Consumes: `StoryVideo.fromJson` (Task 3)
- Produces: `ShortsRepository.instance.fetchShorts() → Future<List<StoryVideo>>`, `ApiConfig.storyShortsUrl({int size})`

- [ ] **Step 1: 실패하는 테스트 작성**

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

  test('category=shorts로 조회하고 content 배열을 파싱한다', () async {
    Uri? capturedUrl;
    api.setApiClientForTesting(MockClient((request) async {
      capturedUrl = request.url;
      return http.Response(
        jsonEncode({
          'content': [
            {
              'videoId': 1,
              'youtubeVideoId': 'a',
              'title': '영상 1',
              'videoUrl': 'https://youtube.com/watch?v=a',
              'thumbnailUrl': 'https://img/1.jpg',
              'channelName': 'LCK',
              'viewCount': 100,
              'publishedAt': '2026-09-20T10:00:00',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final videos = await repo.fetchShorts();

    expect(capturedUrl?.queryParameters['category'], 'shorts');
    expect(videos, hasLength(1));
    expect(videos.single.title, '영상 1');
  });

  test('content가 없으면 빈 목록', () async {
    api.setApiClientForTesting(MockClient((request) async {
      return http.Response(
        jsonEncode({'content': <dynamic>[]}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final videos = await repo.fetchShorts();

    expect(videos, isEmpty);
  });

  test('non-2xx면 예외를 던진다', () async {
    api.setApiClientForTesting(MockClient((request) async {
      return http.Response('', 500);
    }));

    await expectLater(repo.fetchShorts(), throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/repository/shorts/shorts_repository_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: `ApiConfig`에 URL 빌더 추가**

`lib/config/api_config.dart`의 순위표 URL 빌더(Task 2) 바로 아래에 추가:

```dart
  // ── 유튜브 쇼츠 (인증 불필요) ───────────────────────────────────────

  /// 유튜브 쇼츠 최신 영상 목록. 선수·팀 연관 필드가 없어 필터링은
  /// 제목 문자열 매칭이 필요하다(Phase 1은 "전체" 최신순만 노출).
  static String storyShortsUrl({int size = 12}) =>
      '$apiBaseUrl/story/videos?category=shorts&sort=latest&size=$size';
```

- [ ] **Step 4: Repository 구현**

```dart
// lib/repository/shorts/shorts_repository.dart
import 'dart:convert';

import '../../config/api_config.dart';
import '../../model/story_video.dart';
import '../../util/api_client.dart' as http;

/// 유튜브 쇼츠 API (`/api/story/videos?category=shorts`).
class ShortsRepository {
  ShortsRepository._();
  static final ShortsRepository instance = ShortsRepository._();

  Future<List<StoryVideo>> fetchShorts() async {
    final response = await http.get(Uri.parse(ApiConfig.storyShortsUrl()));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('쇼츠 조회 실패 (${response.statusCode})');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? const [];
    return content
        .map((e) => StoryVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/repository/shorts/shorts_repository_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: 커밋**

```bash
git add lib/config/api_config.dart lib/repository/shorts/shorts_repository.dart test/repository/shorts/shorts_repository_test.dart
git commit -m "feat: 유튜브 쇼츠 조회 repository 추가 (/api/story/videos)"
```

---

### Task 5: l10n 키 추가 + 하단 탭바에 '홈' 탭 연결

**Files:**
- Modify: `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb` (새 키 추가 → `flutter gen-l10n`으로 생성 파일 갱신)
- Create: `assets/icons/home.svg`
- Modify: `lib/components/app_bottom_nav.dart` (`AppNavTab.home` 추가, 바 폭 동적 계산)
- Modify: `test/components/app_bottom_nav_test.dart` (탭 6개 기준 문구만 갱신 — 로직은 그대로 통과해야 함)

**Interfaces:**
- Produces: `AppNavTab.home`, `AppLocalizations.navHome` 등 신규 l10n 게터.

- [ ] **Step 1: arb에 키 추가 (한국어)**

`lib/l10n/app_ko.arb`의 `navSchedule` 위(474번째 줄 근처)에 `navHome`을 추가:

```json
  "navHome": "홈",
  "navSchedule": "경기일정",
```

같은 파일 아무 곳(예: `navMyPage` 다음 줄)에 홈 섹션용 키들을 추가:

```json
  "homeSectionTodayMatches": "오늘의 경기",
  "homeSeeAllMatches": "일정 전체",
  "homeMatchesEmpty": "오늘 예정된 경기가 없어요",
  "homeSectionStandings": "순위표",
  "homeStandingsUnsupported": "아직 지원하지 않는 리그예요",
  "homeStandingsLoadFailed": "순위표를 불러오지 못했어요",
  "homeSectionCommunity": "커뮤니티",
  "homeSeeAllCommunity": "커뮤니티 전체",
  "homeCommunityEmpty": "아직 올라온 글이 없어요",
  "homeSectionShorts": "쇼츠",
  "homeShortsEmpty": "아직 쇼츠가 없어요",
  "homeShortsLoadFailed": "쇼츠를 불러오지 못했어요",
```

- [ ] **Step 2: arb에 키 추가 (영어)**

`lib/l10n/app_en.arb`의 같은 자리에 동일 키의 영문 값:

```json
  "navHome": "Home",
  "navSchedule": "Schedule",
```

```json
  "homeSectionTodayMatches": "Today's Matches",
  "homeSeeAllMatches": "All matches",
  "homeMatchesEmpty": "No matches scheduled today",
  "homeSectionStandings": "Standings",
  "homeStandingsUnsupported": "Standings aren't available for this league yet",
  "homeStandingsLoadFailed": "Failed to load standings",
  "homeSectionCommunity": "Community",
  "homeSeeAllCommunity": "All posts",
  "homeCommunityEmpty": "No posts yet",
  "homeSectionShorts": "Shorts",
  "homeShortsEmpty": "No shorts yet",
  "homeShortsLoadFailed": "Failed to load shorts",
```

- [ ] **Step 3: 로컬라이제이션 코드 생성**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart`, `app_localizations_ko.dart`, `app_localizations_en.dart` 에 `navHome`·`homeSectionTodayMatches` 등 게터가 새로 생김. 커맨드가 에러 없이 끝나야 한다.

Verify: `grep -n "navHome" lib/l10n/app_localizations_ko.dart` → 결과가 나와야 한다.

- [ ] **Step 4: 홈 아이콘 SVG 추가**

```xml
<!-- assets/icons/home.svg -->
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M5 12L3 12L12 3L21 12L19 12" stroke="#CED4DA" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M5 12V19C5 20.1046 5.89543 21 7 21H17C18.1046 21 19 20.1046 19 19V12" stroke="#CED4DA" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M9 21V15C9 13.8954 9.89543 13 11 13H13C14.1046 13 15 13.8954 15 15V21" stroke="#CED4DA" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

(`pubspec.yaml`이 `assets/icons/` 디렉터리 전체를 이미 선언하고 있어 별도 등록 불필요.)

- [ ] **Step 5: `AppNavTab`에 `home` 추가 + 탭 아이템·라벨 등록**

`lib/components/app_bottom_nav.dart` 수정:

```dart
enum AppNavTab { home, schedule, list, community, subscription, mypage }
```

`_items` 목록 맨 앞에 추가:

```dart
  static const List<({String icon, AppNavTab tab})> _items = [
    (icon: 'assets/icons/home.svg', tab: AppNavTab.home),
    (icon: 'assets/icons/calendar-event.svg', tab: AppNavTab.schedule),
    (icon: 'assets/icons/layout-list.svg', tab: AppNavTab.list),
    (
      icon: 'assets/icons/message-circle-heart.svg',
      tab: AppNavTab.community,
    ),
    (icon: 'assets/icons/empty-stars.svg', tab: AppNavTab.subscription),
    (icon: 'assets/icons/user.svg', tab: AppNavTab.mypage),
  ];
```

`build()`의 `labels` 맵에 추가:

```dart
    final labels = {
      AppNavTab.home: l.navHome,
      AppNavTab.schedule: l.navSchedule,
      AppNavTab.list: l.navMatchList,
      AppNavTab.community: l.navCommunity,
      AppNavTab.subscription: l.navSubscription,
      AppNavTab.mypage: l.navMyPage,
    };
```

- [ ] **Step 6: 바 폭을 탭 개수에 맞춰 동적으로 계산**

`_inactiveSize` 선언 바로 아래에 추가하고, `bar`를 만드는 `SizedBox(width: 335 * scale, ...)`를 아래처럼 바꾼다:

```dart
  /// 5탭 디자인 기준 아이템 사이 간격 — (335 - 패딩24 - 활성113 - 비활성4*40) / 4.
  static const double _itemGap = 9.5;

  /// 탭 [itemCount] 개일 때 바 전체 폭(스케일 전). 활성 pill 1개 + 나머지는
  /// 비활성 chip, 간격은 5탭 디자인과 동일하게 유지한다.
  static double _barWidth(int itemCount) =>
      24 + 113 + (itemCount - 1) * (_inactiveSize + _itemGap);
```

```dart
    final bar = SizedBox(
      width: _barWidth(_items.length) * scale,
      height: 72 * scale,
```

- [ ] **Step 7: 기존 오버플로 회귀 테스트가 6탭 기준으로도 통과하는지 확인**

`test/components/app_bottom_nav_test.dart`의 `SvgPicture` 개수 검증(`findsNWidgets(AppNavTab.values.length)`)은 enum 값이 6개가 되면 자동으로 6을 기대하도록 따라간다 — 코드 수정 불필요. 폭 320/375/430에서 overflow 없음을 보는 루프도 그대로 유효하다. 주석의 "탭이 4개에서 5개로" 문구만 정확성을 위해 갱신한다:

```dart
  // 탭이 5개에서 6개로 늘며(홈 탭 추가) 바 폭을 탭 개수에 맞춰 다시 계산한다.
  // 라벨이 가장 긴 탭이 활성일 때가 최악이므로 그 상태로 세 폭을 다 밟는다.
```

Run: `flutter test test/components/app_bottom_nav_test.dart`
Expected: PASS — 특히 "폭 320.0/375.0/430.0 에서 다섯 탭이 overflow 없이 들어간다" 3건이 6탭 기준으로도 통과해야 한다(제목은 남아 있어도 무방, 로직만 확인).

- [ ] **Step 8: 커밋**

```bash
git add lib/l10n lib/components/app_bottom_nav.dart assets/icons/home.svg test/components/app_bottom_nav_test.dart
git commit -m "feat: 하단 탭바에 홈 탭 추가, l10n 키 등록"
```

---

### Task 6: `HomeViewModel`

**Files:**
- Create: `lib/viewmodel/home/home_viewmodel.dart`
- Test: `test/viewmodel/home/home_viewmodel_test.dart`

**Interfaces:**
- Consumes: `NoticeRepository`, `NoticePreferenceRepository`, `ScheduleRepository.fetchMatchesByDate`, `StandingsRepository.fetchStandings`, `CommunityRepository.fetchPosts`, `ShortsRepository.fetchShorts` (모두 기존/Task 2·4).
- Produces:
  - `promotedNotice → Notice?`, `dismissPromotedNotice()`
  - `todayMatches → List<ScheduleMatch>?`, `todayMatchesLoading → bool`, `todayMatchesError → Object?`, `loadTodayMatches()`
  - `standingsLeague → String`, `standingsResult → StandingsResult?`, `standingsLoading → bool`, `standingsError → Object?`, `selectStandingsLeague(String)`, `loadStandings()`, `static const standingsLeagues = ['LCK','LPL','LEC','LCS']`
  - `communityPosts → List<CommunityRemotePost>?`, `communityLoading → bool`, `communityError → Object?`, `loadCommunity()`
  - `shortsVideos → List<StoryVideo>?`, `shortsLoading → bool`, `shortsError → Object?`, `loadShorts()`
  - `refreshAll() → Future<void>`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/viewmodel/home/home_viewmodel_test.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/home/home_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final headers = {'content-type': 'application/json; charset=utf-8'};

  /// 경로별로 다른 응답을 주는 라우팅 MockClient. [overrides]에 없는 경로는
  /// 빈 성공 응답(`{}`/`[]`/`{"content":[]}`)으로 흘려 이 테스트의 관심사가
  /// 아닌 섹션은 그냥 성립만 시킨다.
  void mockApi({
    String? scheduleBody,
    String? standingsBody,
    String? communityBody,
    String? shortsBody,
    int scheduleStatus = 200,
  }) {
    api.setApiClientForTesting(MockClient((request) async {
      final path = request.url.path;
      if (path.contains('notices')) {
        return http.Response('[]', 200, headers: headers);
      }
      if (path.contains('mobile/schedules')) {
        return http.Response(
          scheduleBody ?? jsonEncode({'matches': <dynamic>[]}),
          scheduleStatus,
          headers: headers,
        );
      }
      if (path.contains('standings')) {
        return http.Response(
          standingsBody ??
              jsonEncode({
                'league': request.url.queryParameters['league'],
                'supported': true,
                'scopeLabel': '',
                'groups': <dynamic>[],
              }),
          200,
          headers: headers,
        );
      }
      if (path.contains('community/posts')) {
        return http.Response(
          communityBody ?? jsonEncode({'posts': <dynamic>[]}),
          200,
          headers: headers,
        );
      }
      if (path.contains('story/videos')) {
        return http.Response(
          shortsBody ?? jsonEncode({'content': <dynamic>[]}),
          200,
          headers: headers,
        );
      }
      fail('예상 밖 요청: ${request.url}');
    }));
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    NoticeRepository.instance.resetPromotedCacheForTesting();
    NoticePreferenceRepository.instance.resetCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('생성 시 4개 섹션을 모두 불러온다', () async {
    mockApi(
      scheduleBody: jsonEncode({
        'matches': [
          {
            'matchId': 'm1',
            'scheduledTime': '18:00',
            'leagueInfo': 'LCK',
            'matchTitle': 'GEN vs T1',
            'matchStatus': 'scheduled',
            'isSynced': true,
            'teamA': {
              'teamName': 'Gen.G',
              'teamCode': 'GEN',
              'teamImageUrl': '',
              'score': 0,
            },
            'teamB': {
              'teamName': 'T1',
              'teamCode': 'T1',
              'teamImageUrl': '',
              'score': 0,
            },
          },
        ],
      }),
      communityBody: jsonEncode({
        'posts': [
          {
            'id': 1,
            'title': '글 제목',
            'bodyPreview': '',
            'viewCount': 0,
            'likeCount': 0,
            'commentCount': 0,
            'edited': false,
          },
        ],
      }),
      shortsBody: jsonEncode({
        'content': [
          {
            'videoId': 1,
            'youtubeVideoId': 'a',
            'title': '쇼츠 1',
            'videoUrl': 'https://youtube.com/watch?v=a',
            'thumbnailUrl': '',
            'channelName': 'LCK',
            'viewCount': 10,
          },
        ],
      }),
    );

    final vm = HomeViewModel();
    addTearDown(vm.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.todayMatches, hasLength(1));
    expect(vm.standingsResult?.league, 'LCK');
    expect(vm.communityPosts, hasLength(1));
    expect(vm.shortsVideos, hasLength(1));
    expect(vm.todayMatchesLoading, isFalse);
    expect(vm.standingsLoading, isFalse);
    expect(vm.communityLoading, isFalse);
    expect(vm.shortsLoading, isFalse);
  });

  test('오늘의 경기 조회가 실패해도 다른 섹션은 정상 로드된다', () async {
    mockApi(scheduleStatus: 500);

    final vm = HomeViewModel();
    addTearDown(vm.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.todayMatchesError, isNotNull);
    expect(vm.todayMatches, isNull);
    expect(vm.standingsLoading, isFalse);
    expect(vm.standingsError, isNull);
  });

  test('selectStandingsLeague: 리그를 바꾸면 그 리그로 다시 조회한다', () async {
    mockApi();
    final vm = HomeViewModel();
    addTearDown(vm.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(vm.standingsLeague, 'LCK');

    vm.selectStandingsLeague('LPL');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.standingsLeague, 'LPL');
    expect(vm.standingsResult?.league, 'LPL');
  });

  test('같은 리그를 다시 고르면 아무 일도 하지 않는다', () async {
    mockApi();
    final vm = HomeViewModel();
    addTearDown(vm.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    var notifyCount = 0;
    vm.addListener(() => notifyCount++);
    vm.selectStandingsLeague('LCK');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifyCount, 0);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/viewmodel/home/home_viewmodel_test.dart`
Expected: FAIL — `home_viewmodel.dart` 없음

- [ ] **Step 3: `HomeViewModel` 구현**

```dart
// lib/viewmodel/home/home_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/community_remote_post.dart';
import '../../model/notice.dart';
import '../../model/schedule_match.dart';
import '../../model/standing.dart';
import '../../model/story_video.dart';
import '../../repository/community/community_repository.dart';
import '../../repository/notice/notice_repository.dart';
import '../../repository/preference/notice_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';
import '../../repository/shorts/shorts_repository.dart';
import '../../repository/standings/standings_repository.dart';

/// 홈 화면 ViewModel.
///
/// 공지 배너·오늘의 경기·순위표·커뮤니티·쇼츠 다섯 섹션을 각각 독립적으로
/// 불러온다. 한 섹션이 실패해도 나머지 섹션은 영향받지 않는다
/// ([ScheduleViewModel]과 같은 패턴 — 캐시 가능한 값은 생성자에서 동기로
/// 먼저 채우고, 나머지는 fire-and-forget 비동기 로드).
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    NoticeRepository? notices,
    NoticePreferenceRepository? noticePreferences,
    ScheduleRepository? schedule,
    StandingsRepository? standings,
    CommunityRepository? community,
    ShortsRepository? shorts,
  })  : _notices = notices ?? NoticeRepository.instance,
        _noticePreferences =
            noticePreferences ?? NoticePreferenceRepository.instance,
        _schedule = schedule ?? ScheduleRepository.instance,
        _standings = standings ?? StandingsRepository.instance,
        _community = community ?? CommunityRepository.instance,
        _shorts = shorts ?? ShortsRepository.instance {
    _promotedNotices = _notices.cachedPromoted ?? const [];
    _dismissedNoticeIds = _noticePreferences.cachedValue ?? const {};
    _loadPromotedNotice();
    loadTodayMatches();
    loadStandings();
    loadCommunity();
    loadShorts();
  }

  final NoticeRepository _notices;
  final NoticePreferenceRepository _noticePreferences;
  final ScheduleRepository _schedule;
  final StandingsRepository _standings;
  final CommunityRepository _community;
  final ShortsRepository _shorts;

  bool _disposed = false;

  /// 순위표 리그 칩 목록. Phase 1은 정규 리그 테이블만 지원해 월즈는 뺀다.
  static const List<String> standingsLeagues = ['LCK', 'LPL', 'LEC', 'LCS'];

  // ── 공지 배너 ────────────────────────────────────────────────────
  List<Notice> _promotedNotices = const [];
  Set<int> _dismissedNoticeIds = const {};

  Notice? get promotedNotice {
    for (final notice in _promotedNotices) {
      if (!_dismissedNoticeIds.contains(notice.id)) return notice;
    }
    return null;
  }

  Future<void> _loadPromotedNotice() async {
    try {
      final notices = await _notices.fetchPromoted();
      final dismissed = await _noticePreferences.loadDismissedIds();
      if (_disposed) return;
      final before = promotedNotice;
      _promotedNotices = notices;
      _dismissedNoticeIds = dismissed;
      if (promotedNotice?.id != before?.id) _notify();
    } catch (e) {
      debugPrint('[Home] 배너 공지 조회 실패: $e');
    }
  }

  void dismissPromotedNotice() {
    final notice = promotedNotice;
    if (notice == null) return;
    _dismissedNoticeIds = {..._dismissedNoticeIds, notice.id};
    _notify();
    unawaited(_noticePreferences.addDismissedId(notice.id));
  }

  // ── 오늘의 경기 ──────────────────────────────────────────────────
  List<ScheduleMatch>? _todayMatches;
  bool _todayMatchesLoading = true;
  Object? _todayMatchesError;

  List<ScheduleMatch>? get todayMatches => _todayMatches;
  bool get todayMatchesLoading => _todayMatchesLoading;
  Object? get todayMatchesError => _todayMatchesError;

  Future<void> loadTodayMatches() async {
    _todayMatchesLoading = true;
    _todayMatchesError = null;
    _notify();
    try {
      // 기본값(leagues 생략)은 LCK만 준다 — 홈은 오늘 열리는 모든 리그 경기를
      // 보여줘야 하므로 명시적으로 전체를 요청한다.
      final matches = await _schedule.fetchMatchesByDate(
        DateTime.now(),
        leagues: const ['ALL'],
      );
      if (_disposed) return;
      _todayMatches = matches;
    } catch (e) {
      if (_disposed) return;
      debugPrint('[Home] 오늘의 경기 조회 실패: $e');
      _todayMatchesError = e;
    } finally {
      if (!_disposed) {
        _todayMatchesLoading = false;
        _notify();
      }
    }
  }

  // ── 순위표 ───────────────────────────────────────────────────────
  String _standingsLeague = 'LCK';
  StandingsResult? _standingsResult;
  bool _standingsLoading = true;
  Object? _standingsError;

  String get standingsLeague => _standingsLeague;
  StandingsResult? get standingsResult => _standingsResult;
  bool get standingsLoading => _standingsLoading;
  Object? get standingsError => _standingsError;

  /// 순위표 리그 칩을 바꾼다. 이미 보고 있는 리그면 아무것도 하지 않는다.
  void selectStandingsLeague(String league) {
    if (league == _standingsLeague) return;
    _standingsLeague = league;
    loadStandings();
  }

  Future<void> loadStandings() async {
    final league = _standingsLeague;
    _standingsLoading = true;
    _standingsError = null;
    _notify();
    try {
      final result = await _standings.fetchStandings(league);
      if (_disposed || league != _standingsLeague) return;
      _standingsResult = result;
    } catch (e) {
      if (_disposed || league != _standingsLeague) return;
      debugPrint('[Home] 순위표 조회 실패($league): $e');
      _standingsError = e;
    } finally {
      if (!_disposed && league == _standingsLeague) {
        _standingsLoading = false;
        _notify();
      }
    }
  }

  // ── 커뮤니티 ─────────────────────────────────────────────────────
  static const int _communitySize = 4;

  List<CommunityRemotePost>? _communityPosts;
  bool _communityLoading = true;
  Object? _communityError;

  List<CommunityRemotePost>? get communityPosts => _communityPosts;
  bool get communityLoading => _communityLoading;
  Object? get communityError => _communityError;

  Future<void> loadCommunity() async {
    _communityLoading = true;
    _communityError = null;
    _notify();
    try {
      final page = await _community.fetchPosts(size: _communitySize);
      if (_disposed) return;
      _communityPosts = page.posts;
    } catch (e) {
      if (_disposed) return;
      debugPrint('[Home] 커뮤니티 조회 실패: $e');
      _communityError = e;
    } finally {
      if (!_disposed) {
        _communityLoading = false;
        _notify();
      }
    }
  }

  // ── 쇼츠 ─────────────────────────────────────────────────────────
  List<StoryVideo>? _shortsVideos;
  bool _shortsLoading = true;
  Object? _shortsError;

  List<StoryVideo>? get shortsVideos => _shortsVideos;
  bool get shortsLoading => _shortsLoading;
  Object? get shortsError => _shortsError;

  Future<void> loadShorts() async {
    _shortsLoading = true;
    _shortsError = null;
    _notify();
    try {
      final videos = await _shorts.fetchShorts();
      if (_disposed) return;
      _shortsVideos = videos;
    } catch (e) {
      if (_disposed) return;
      debugPrint('[Home] 쇼츠 조회 실패: $e');
      _shortsError = e;
    } finally {
      if (!_disposed) {
        _shortsLoading = false;
        _notify();
      }
    }
  }

  // ── 공통 ─────────────────────────────────────────────────────────

  /// 당겨서 새로고침 — 섹션을 모두 다시 불러온다. 개별 로더가 각자 예외를
  /// 삼키므로 이 Future 자체는 실패하지 않는다.
  Future<void> refreshAll() {
    return Future.wait([
      _loadPromotedNotice(),
      loadTodayMatches(),
      loadStandings(),
      loadCommunity(),
      loadShorts(),
    ]);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/viewmodel/home/home_viewmodel_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/viewmodel/home/home_viewmodel.dart test/viewmodel/home/home_viewmodel_test.dart
git commit -m "feat: HomeViewModel 추가 — 공지·일정·순위표·커뮤니티·쇼츠 병렬 로드"
```

---

### Task 7: 공통 섹션 헤더 + `HomeTodayMatchesSection`

**Files:**
- Create: `lib/screens/home/component/home_section_header.dart`
- Create: `lib/screens/home/component/home_today_matches_section.dart`
- Test: `test/screens/home/home_today_matches_section_test.dart`

**Interfaces:**
- Consumes: `ScheduleMatch`(기존), `isLiveMatchStatus`(기존, `lib/util/match_status.dart`), `NarBadge`/`NarLiveBadge`(기존, `lib/components/nar_badge.dart`·`nar_live_badge.dart`), `LoadError`(기존, `lib/components/load_error.dart`), `resolveImageUrl`(기존, `lib/util/app_image.dart`).
- Produces: `HomeSectionHeader({title, scale, trailing, onTrailingTap})`, `HomeTodayMatchesSection({matches, loading, error, scale, onRetry, onSeeAll})`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

```dart
// test/screens/home/home_today_matches_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/screens/home/component/home_today_matches_section.dart';

ScheduleMatch _match({
  String status = 'scheduled',
  int scoreA = 0,
  int scoreB = 0,
}) {
  return ScheduleMatch(
    matchId: 'm1',
    scheduledTime: '18:00',
    leagueInfo: 'LCK',
    matchTitle: 'GEN vs T1',
    matchStatus: status,
    isSynced: true,
    teamA: MatchTeam(
      teamName: 'Gen.G',
      teamCode: 'GEN',
      teamImageUrl: '',
      score: scoreA,
    ),
    teamB: MatchTeam(
      teamName: 'T1',
      teamCode: 'T1',
      teamImageUrl: '',
      score: scoreB,
    ),
  );
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('로딩 중이면 스피너를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeTodayMatchesSection(
      matches: null,
      loading: true,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () {},
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('에러면 재시도 버튼을 보여주고 탭하면 콜백이 불린다', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(HomeTodayMatchesSection(
      matches: null,
      loading: false,
      error: Exception('boom'),
      scale: 1,
      onRetry: () => retried = true,
      onSeeAll: () {},
    )));

    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });

  testWidgets('경기가 없으면 빈 안내를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeTodayMatchesSection(
      matches: const [],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () {},
    )));

    expect(find.text('오늘 예정된 경기가 없어요'), findsOneWidget);
  });

  testWidgets('경기가 있으면 팀 코드와 스코어를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeTodayMatchesSection(
      matches: [_match(status: 'completed', scoreA: 2, scoreB: 0)],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () {},
    )));

    expect(find.text('GEN'), findsOneWidget);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('"일정 전체"를 탭하면 콜백이 불린다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(HomeTodayMatchesSection(
      matches: const [],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () => tapped = true,
    )));

    await tester.tap(find.text('일정 전체'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/screens/home/home_today_matches_section_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 공통 섹션 헤더 구현**

```dart
// lib/screens/home/component/home_section_header.dart
import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 홈 화면 섹션 공통 헤더 — 제목 좌측, (옵션) '더보기' 우측.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.scale,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final double scale;

  /// 우측 '더보기' 등 라벨. null 이면 표시하지 않는다.
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        22 * scale,
        20 * scale,
        10 * scale,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 17 * scale,
              color: AppColors.narText,
            ),
          ),
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13 * scale,
                  color: AppColors.narText2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 오늘의 경기 섹션 구현**

```dart
// lib/screens/home/component/home_today_matches_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/load_error.dart';
import '../../../components/nar_badge.dart';
import '../../../components/nar_live_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/schedule_match.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../util/match_status.dart';
import 'home_section_header.dart';

/// 홈 '오늘의 경기' 섹션 — 가로 스크롤 카드 스트립.
class HomeTodayMatchesSection extends StatelessWidget {
  const HomeTodayMatchesSection({
    super.key,
    required this.matches,
    required this.loading,
    required this.error,
    required this.scale,
    required this.onRetry,
    required this.onSeeAll,
  });

  final List<ScheduleMatch>? matches;
  final bool loading;
  final Object? error;
  final double scale;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: l.homeSectionTodayMatches,
          scale: scale,
          trailing: l.homeSeeAllMatches,
          onTrailingTap: onSeeAll,
        ),
        SizedBox(height: 172 * scale, child: _body(l)),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    if (loading && matches == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && matches == null) {
      return LoadError(message: l.matchLoadFailed, onRetry: onRetry);
    }
    final list = matches ?? const [];
    if (list.isEmpty) {
      return Center(
        child: Text(
          l.homeMatchesEmpty,
          style: TextStyle(color: AppColors.narText2, fontSize: 13 * scale),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      itemCount: list.length,
      separatorBuilder: (_, _) => SizedBox(width: 10 * scale),
      itemBuilder: (_, i) => _MatchCard(match: list[i], scale: scale),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.scale});

  final ScheduleMatch match;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final live = isLiveMatchStatus(match.matchStatus);
    return Container(
      width: 172 * scale,
      padding: EdgeInsets.fromLTRB(12 * scale, 10 * scale, 12 * scale, 12 * scale),
      decoration: BoxDecoration(
        color: live ? AppColors.narDark600 : AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: live
            ? Border(left: BorderSide(color: AppColors.liveSideBorder, width: 3 * scale))
            : Border.all(color: AppColors.narLine, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          live
              ? NarLiveBadge(scale: scale)
              : NarBadge(label: match.scheduledTime, scale: scale),
          SizedBox(height: 8 * scale),
          Text(
            '${match.leagueInfo} · ${match.matchTitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 11 * scale,
              color: AppColors.narText2,
            ),
          ),
          SizedBox(height: 10 * scale),
          _TeamRow(team: match.teamA, otherScore: match.teamB.score, scale: scale),
          SizedBox(height: 6 * scale),
          _TeamRow(team: match.teamB, otherScore: match.teamA.score, scale: scale),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team, required this.otherScore, required this.scale});

  final MatchTeam team;
  final int otherScore;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scoreColor =
        team.score > otherScore ? AppColors.scoreWin : AppColors.narDark200;
    return Row(
      children: [
        _TeamLogo(url: team.teamImageUrl, scale: scale),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            team.teamCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
        ),
        Text(
          '${team.score}',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
            fontSize: 16 * scale,
            color: scoreColor,
          ),
        ),
      ],
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.url, required this.scale});

  final String url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 24 * scale;
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.narLine2,
          borderRadius: BorderRadius.circular(6 * scale),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6 * scale),
      child: CachedNetworkImage(
        imageUrl: resolveImageUrl(url)!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: AppColors.narLine2,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/screens/home/home_today_matches_section_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/home/component/home_section_header.dart lib/screens/home/component/home_today_matches_section.dart test/screens/home/home_today_matches_section_test.dart
git commit -m "feat: 홈 화면 오늘의 경기 섹션 위젯 추가"
```

---

### Task 8: `HomeStandingsSection`

**Files:**
- Create: `lib/screens/home/component/home_standings_section.dart`
- Test: `test/screens/home/home_standings_section_test.dart`

**Interfaces:**
- Consumes: `StandingsResult`/`StandingRow`(Task 1), `NarChip`(기존, `lib/components/nar_chip.dart`), `LoadError`(기존).
- Produces: `HomeStandingsSection({league, leagues, result, loading, error, scale, onSelectLeague, onRetry})`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

```dart
// test/screens/home/home_standings_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/standing.dart';
import 'package:warding/screens/home/component/home_standings_section.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  const leagues = ['LCK', 'LPL', 'LEC', 'LCS'];

  testWidgets('리그 칩을 탭하면 콜백이 그 리그로 불린다', (tester) async {
    String? selected;
    await tester.pumpWidget(_wrap(HomeStandingsSection(
      league: 'LCK',
      leagues: leagues,
      result: null,
      loading: true,
      error: null,
      scale: 1,
      onSelectLeague: (l) => selected = l,
      onRetry: () {},
    )));

    await tester.tap(find.text('LPL'));
    expect(selected, 'LPL');
  });

  testWidgets('supported=false면 reason 문구를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeStandingsSection(
      league: 'LPL',
      leagues: leagues,
      result: const StandingsResult(
        league: 'LPL',
        supported: false,
        reason: '아직 데이터가 없습니다',
        scopeLabel: '',
        groups: [],
      ),
      loading: false,
      error: null,
      scale: 1,
      onSelectLeague: (_) {},
      onRetry: () {},
    )));

    expect(find.text('아직 데이터가 없습니다'), findsOneWidget);
  });

  testWidgets('supported=true면 팀 행을 그린다', (tester) async {
    await tester.pumpWidget(_wrap(HomeStandingsSection(
      league: 'LCK',
      leagues: leagues,
      result: const StandingsResult(
        league: 'LCK',
        supported: true,
        scopeLabel: '2026 정규시즌',
        groups: [
          StandingGroup(
            name: '레전드 그룹',
            rows: [
              StandingRow(
                rank: 1,
                teamCode: 'GEN',
                teamName: 'Gen.G',
                wins: 19,
                losses: 7,
                setDiff: 22,
              ),
            ],
          ),
        ],
      ),
      loading: false,
      error: null,
      scale: 1,
      onSelectLeague: (_) {},
      onRetry: () {},
    )));

    expect(find.text('GEN'), findsOneWidget);
    expect(find.textContaining('19'), findsWidgets);
  });

  testWidgets('에러면 재시도 버튼을 보여준다', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(HomeStandingsSection(
      league: 'LCK',
      leagues: leagues,
      result: null,
      loading: false,
      error: Exception('boom'),
      scale: 1,
      onSelectLeague: (_) {},
      onRetry: () => retried = true,
    )));

    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/screens/home/home_standings_section_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현**

```dart
// lib/screens/home/component/home_standings_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/load_error.dart';
import '../../../components/nar_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/standing.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import 'home_section_header.dart';

/// 홈 '순위표' 섹션 — 리그 칩 + 리그 테이블. Phase 1은 정규 리그 테이블만
/// 지원한다(월즈 스위스·토너먼트는 별도 API 지원 전까지 뺐다).
class HomeStandingsSection extends StatelessWidget {
  const HomeStandingsSection({
    super.key,
    required this.league,
    required this.leagues,
    required this.result,
    required this.loading,
    required this.error,
    required this.scale,
    required this.onSelectLeague,
    required this.onRetry,
  });

  final String league;
  final List<String> leagues;
  final StandingsResult? result;
  final bool loading;
  final Object? error;
  final double scale;
  final ValueChanged<String> onSelectLeague;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: l.homeSectionStandings, scale: scale),
        SizedBox(
          height: 34 * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            itemCount: leagues.length,
            separatorBuilder: (_, _) => SizedBox(width: 6 * scale),
            itemBuilder: (_, i) => NarChip(
              label: leagues[i],
              selected: leagues[i] == league,
              scale: scale,
              onTap: () => onSelectLeague(leagues[i]),
            ),
          ),
        ),
        SizedBox(height: 10 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: _body(l),
        ),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    if (loading && result == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && result == null) {
      return SizedBox(
        height: 120 * scale,
        child: LoadError(message: l.homeStandingsLoadFailed, onRetry: onRetry),
      );
    }
    final r = result;
    if (r == null) return const SizedBox.shrink();
    if (!r.supported) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        alignment: Alignment.center,
        child: Text(
          r.reason?.isNotEmpty == true ? r.reason! : l.homeStandingsUnsupported,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.narText2, fontSize: 13 * scale),
        ),
      );
    }
    final rows = [for (final g in r.groups) ...g.rows];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        children: [
          for (final row in rows) _StandingRowTile(row: row, scale: scale),
        ],
      ),
    );
  }
}

class _StandingRowTile extends StatelessWidget {
  const _StandingRowTile({required this.row, required this.scale});

  final StandingRow row;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46 * scale,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.narLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22 * scale,
            child: Text(
              '${row.rank}',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
                fontSize: 13 * scale,
                color: AppColors.narTextTertiary,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          _Logo(url: row.imageUrl, scale: scale),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              row.teamCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
                fontSize: 14 * scale,
                color: AppColors.narTextTertiary,
              ),
            ),
          ),
          Text(
            '${row.wins}-${row.losses}',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
          SizedBox(width: 10 * scale),
          SizedBox(
            width: 34 * scale,
            child: Text(
              row.setDiff > 0 ? '+${row.setDiff}' : '${row.setDiff}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12 * scale,
                color: row.setDiff > 0 ? AppColors.scoreWin : AppColors.narText3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.scale});

  final String? url;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 26 * scale;
    final u = url ?? '';
    if (u.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.narLine2,
          borderRadius: BorderRadius.circular(6 * scale),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6 * scale),
      child: CachedNetworkImage(
        imageUrl: resolveImageUrl(u)!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: AppColors.narLine2,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/screens/home/home_standings_section_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/home/component/home_standings_section.dart test/screens/home/home_standings_section_test.dart
git commit -m "feat: 홈 화면 순위표 섹션 위젯 추가"
```

---

### Task 9: `HomeCommunitySection`

**Files:**
- Create: `lib/screens/home/component/home_community_section.dart`
- Test: `test/screens/home/home_community_section_test.dart`

**Interfaces:**
- Consumes: `CommunityRemotePost`(기존), `AuthorLine`(기존, `lib/screens/community/component/author_line.dart`), `ratingTimeAgo`(기존, `lib/util/rating_mapping.dart`), `LoadError`(기존).
- Produces: `HomeCommunitySection({posts, loading, error, scale, onRetry, onSeeAll, onOpenPost})`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

```dart
// test/screens/home/home_community_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/community_remote_post.dart';
import 'package:warding/screens/home/component/home_community_section.dart';

CommunityRemotePost _post({int id = 1, String title = '글 제목'}) {
  return CommunityRemotePost(
    id: id,
    boardTeamId: null,
    title: title,
    bodyPreview: '',
    author: null,
    viewCount: 0,
    likeCount: 0,
    commentCount: 3,
    edited: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('글이 있으면 제목과 댓글 수를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeCommunitySection(
      posts: [_post(title: '오늘자 후기')],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () {},
      onOpenPost: (_) {},
    )));

    expect(find.text('오늘자 후기'), findsOneWidget);
  });

  testWidgets('글을 탭하면 그 글로 콜백이 불린다', (tester) async {
    CommunityRemotePost? opened;
    final post = _post(id: 42);
    await tester.pumpWidget(_wrap(HomeCommunitySection(
      posts: [post],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () {},
      onOpenPost: (p) => opened = p,
    )));

    await tester.tap(find.text('글 제목'));
    expect(opened?.id, 42);
  });

  testWidgets('글이 없으면 빈 안내를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeCommunitySection(
      posts: const [],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onSeeAll: () {},
      onOpenPost: (_) {},
    )));

    expect(find.text('아직 올라온 글이 없어요'), findsOneWidget);
  });

  testWidgets('에러면 재시도 버튼을 보여준다', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(HomeCommunitySection(
      posts: null,
      loading: false,
      error: Exception('boom'),
      scale: 1,
      onRetry: () => retried = true,
      onSeeAll: () {},
      onOpenPost: (_) {},
    )));

    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/screens/home/home_community_section_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현**

```dart
// lib/screens/home/component/home_community_section.dart
import 'package:flutter/material.dart';

import '../../../components/load_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/community_remote_post.dart';
import '../../../styles/app_colors.dart';
import '../../../util/rating_mapping.dart';
import '../../community/component/author_line.dart';
import 'home_section_header.dart';

/// 홈 '커뮤니티' 섹션. 백엔드가 정렬 파라미터를 지원하지 않아(Phase 1) 서버가
/// 주는 단일 순서(최신순) 그대로 보여준다 — 목업의 최신/인기 탭은 없다.
class HomeCommunitySection extends StatelessWidget {
  const HomeCommunitySection({
    super.key,
    required this.posts,
    required this.loading,
    required this.error,
    required this.scale,
    required this.onRetry,
    required this.onSeeAll,
    required this.onOpenPost,
  });

  final List<CommunityRemotePost>? posts;
  final bool loading;
  final Object? error;
  final double scale;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;
  final ValueChanged<CommunityRemotePost> onOpenPost;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: l.homeSectionCommunity,
          scale: scale,
          trailing: l.homeSeeAllCommunity,
          onTrailingTap: onSeeAll,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: _body(l),
        ),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    if (loading && posts == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && posts == null) {
      return SizedBox(
        height: 100 * scale,
        child: LoadError(message: l.communityLoadFailed, onRetry: onRetry),
      );
    }
    final list = posts ?? const [];
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: AppColors.narLine),
        ),
        child: Text(
          l.homeCommunityEmpty,
          style: TextStyle(color: AppColors.narText2, fontSize: 13 * scale),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine),
      ),
      child: Column(
        children: [
          for (final post in list) _PostTile(post: post, scale: scale, onTap: () => onOpenPost(post)),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.scale, required this.onTap});

  final CommunityRemotePost post;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 11 * scale),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.narLine)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                color: AppColors.narTextTertiary,
              ),
            ),
            SizedBox(height: 4 * scale),
            Row(
              children: [
                Expanded(child: AuthorLine(author: post.author, scale: scale)),
                SizedBox(width: 8 * scale),
                Text(
                  ratingTimeAgo(post.createdAt),
                  style: TextStyle(fontSize: 11 * scale, color: AppColors.narDark200),
                ),
                SizedBox(width: 8 * scale),
                Text(
                  '댓글 ${post.commentCount}',
                  style: TextStyle(fontSize: 11 * scale, color: AppColors.narDark200),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/screens/home/home_community_section_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/home/component/home_community_section.dart test/screens/home/home_community_section_test.dart
git commit -m "feat: 홈 화면 커뮤니티 섹션 위젯 추가"
```

---

### Task 10: `HomeShortsSection`

**Files:**
- Create: `lib/screens/home/component/home_shorts_section.dart`
- Test: `test/screens/home/home_shorts_section_test.dart`

**Interfaces:**
- Consumes: `StoryVideo`(Task 3), `LoadError`(기존).
- Produces: `HomeShortsSection({videos, loading, error, scale, onRetry, onOpenVideo})`.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

```dart
// test/screens/home/home_shorts_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/story_video.dart';
import 'package:warding/screens/home/component/home_shorts_section.dart';

StoryVideo _video({int id = 1, String title = '영상 제목'}) {
  return StoryVideo(
    videoId: id,
    youtubeVideoId: 'yt$id',
    title: title,
    videoUrl: 'https://youtube.com/watch?v=yt$id',
    thumbnailUrl: '',
    channelName: 'LCK',
    viewCount: 1234,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('영상이 있으면 제목을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeShortsSection(
      videos: [_video(title: '제우스 하이라이트')],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onOpenVideo: (_) {},
    )));

    expect(find.textContaining('제우스 하이라이트'), findsOneWidget);
  });

  testWidgets('영상을 탭하면 콜백이 그 영상으로 불린다', (tester) async {
    StoryVideo? opened;
    final video = _video(id: 7);
    await tester.pumpWidget(_wrap(HomeShortsSection(
      videos: [video],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onOpenVideo: (v) => opened = v,
    )));

    await tester.tap(find.textContaining('영상 제목'));
    expect(opened?.videoId, 7);
  });

  testWidgets('영상이 없으면 빈 안내를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(HomeShortsSection(
      videos: const [],
      loading: false,
      error: null,
      scale: 1,
      onRetry: () {},
      onOpenVideo: (_) {},
    )));

    expect(find.text('아직 쇼츠가 없어요'), findsOneWidget);
  });

  testWidgets('에러면 재시도 버튼을 보여준다', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(HomeShortsSection(
      videos: null,
      loading: false,
      error: Exception('boom'),
      scale: 1,
      onRetry: () => retried = true,
      onOpenVideo: (_) {},
    )));

    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/screens/home/home_shorts_section_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현**

```dart
// lib/screens/home/component/home_shorts_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/load_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/story_video.dart';
import '../../../styles/app_colors.dart';
import 'home_section_header.dart';

/// 홈 '쇼츠' 섹션. Phase 1은 "전체" 최신순만 보여준다(선수·팀 매칭 필터는
/// 매칭 로직이 아직 없어 제외 — intent/youtube-shorts 참고). 탭하면 외부
/// 유튜브로 이동한다(인앱 재생 없음).
class HomeShortsSection extends StatelessWidget {
  const HomeShortsSection({
    super.key,
    required this.videos,
    required this.loading,
    required this.error,
    required this.scale,
    required this.onRetry,
    required this.onOpenVideo,
  });

  final List<StoryVideo>? videos;
  final bool loading;
  final Object? error;
  final double scale;
  final VoidCallback onRetry;
  final ValueChanged<StoryVideo> onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: l.homeSectionShorts, scale: scale),
        SizedBox(height: 200 * scale, child: _body(l)),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    if (loading && videos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && videos == null) {
      return LoadError(message: l.homeShortsLoadFailed, onRetry: onRetry);
    }
    final list = videos ?? const [];
    if (list.isEmpty) {
      return Center(
        child: Text(
          l.homeShortsEmpty,
          style: TextStyle(color: AppColors.narText2, fontSize: 13 * scale),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      itemCount: list.length,
      separatorBuilder: (_, _) => SizedBox(width: 10 * scale),
      itemBuilder: (_, i) => _ShortsCard(
        video: list[i],
        scale: scale,
        onTap: () => onOpenVideo(list[i]),
      ),
    );
  }
}

class _ShortsCard extends StatelessWidget {
  const _ShortsCard({required this.video, required this.scale, required this.onTap});

  final StoryVideo video;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112 * scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10 * scale),
                child: video.thumbnailUrl.isEmpty
                    ? Container(color: AppColors.narBgTertiary)
                    : CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            Container(color: AppColors.narBgTertiary),
                      ),
              ),
            ),
            SizedBox(height: 7 * scale),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11 * scale,
                color: AppColors.narTextTertiary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/screens/home/home_shorts_section_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/home/component/home_shorts_section.dart test/screens/home/home_shorts_section_test.dart
git commit -m "feat: 홈 화면 유튜브 쇼츠 섹션 위젯 추가"
```

---

### Task 11: `HomeScreen` 조립 (기존 고아 화면 교체)

**Files:**
- Modify: `lib/screens/home/home_screen.dart` (전체 교체 — 기존 로그아웃 placeholder 제거)
- Test: `test/screens/home/home_screen_test.dart`

**Interfaces:**
- Consumes: Task 6의 `HomeViewModel`, Task 7~10의 섹션 위젯들, 기존 `NarBanner`/`AppBottomNav`/`AppRefreshIndicator`/`BottomNavShrinkController`/`tabRoute`/`NoticeDetailScreen`.
- Produces: `HomeScreen` (StatefulWidget, `const HomeScreen({super.key})`).

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

이 테스트는 `HomeScreen`이 실제 네트워크를 타므로(내부에서 `HomeViewModel()`을 직접 생성) `api.setApiClientForTesting`으로 전부 빈 성공 응답을 흘려, 렌더링 자체가 예외 없이 끝나는지만 확인한다.

```dart
// test/screens/home/home_screen_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/screens/home/home_screen.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    NoticeRepository.instance.resetPromotedCacheForTesting();
    NoticePreferenceRepository.instance.resetCacheForTesting();

    api.setApiClientForTesting(MockClient((request) async {
      final headers = {'content-type': 'application/json; charset=utf-8'};
      final path = request.url.path;
      if (path.contains('notices')) return http.Response('[]', 200, headers: headers);
      if (path.contains('mobile/schedules')) {
        return http.Response(jsonEncode({'matches': <dynamic>[]}), 200, headers: headers);
      }
      if (path.contains('standings')) {
        return http.Response(
          jsonEncode({'league': 'LCK', 'supported': true, 'scopeLabel': '', 'groups': <dynamic>[]}),
          200,
          headers: headers,
        );
      }
      if (path.contains('community/posts')) {
        return http.Response(jsonEncode({'posts': <dynamic>[]}), 200, headers: headers);
      }
      if (path.contains('story/videos')) {
        return http.Response(jsonEncode({'content': <dynamic>[]}), 200, headers: headers);
      }
      return http.Response('{}', 200, headers: headers);
    }));
  });

  tearDown(() => api.setApiClientForTesting(null));

  testWidgets('예외 없이 렌더되고 섹션 제목이 모두 보인다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('ko'),
      home: HomeScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('오늘의 경기'), findsOneWidget);
    expect(find.text('순위표'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('쇼츠'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/screens/home/home_screen_test.dart`
Expected: FAIL — 기존 고아 `HomeScreen`은 이 섹션 제목들을 그리지 않는다.

- [ ] **Step 3: `HomeScreen` 구현 (기존 파일 전체 교체)**

```dart
// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_refresh_indicator.dart';
import '../../components/nar_banner.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_remote_post.dart';
import '../../model/story_video.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/home/home_viewmodel.dart';
import '../community/community_screen.dart';
import '../community/post_detail_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../notice/notice_detail_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import 'component/home_community_section.dart';
import 'component/home_shorts_section.dart';
import 'component/home_standings_section.dart';
import 'component/home_today_matches_section.dart';

/// 홈 — 하단 네비 '홈' 탭이자 로그인/온보딩 완료 후 진입 화면.
///
/// 공지 배너·오늘의 경기·순위표·커뮤니티·쇼츠 다섯 섹션을 세로로 나열한다.
/// 섹션마다 독립적으로 불러오고 실패해도 나머지는 정상 표시된다
/// ([HomeViewModel] 참고).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeViewModel _viewModel = HomeViewModel();
  final BottomNavShrinkController _navShrink = BottomNavShrinkController();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }

  void _openNotice() {
    final notice = _viewModel.promotedNotice;
    if (notice == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailScreen(notice: notice, showListButton: true),
      ),
    );
  }

  void _openPost(CommunityRemotePost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(postId: post.id)),
    );
  }

  Future<void> _openVideo(StoryVideo video) async {
    final uri = Uri.tryParse(video.videoUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _navShrink.handleNotification,
                child: AppRefreshIndicator(
                  onRefresh: _viewModel.refreshAll,
                  child: ListView(
                    physics: AppRefreshIndicator.physics,
                    padding: EdgeInsets.only(bottom: 128 * scale),
                    children: [
                      if (_viewModel.promotedNotice != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(20 * scale, 4 * scale, 20 * scale, 0),
                          child: NarBanner(
                            scale: scale,
                            icon: Text('📢', style: TextStyle(fontSize: 16 * scale)),
                            text: _viewModel.promotedNotice!.title,
                            onTap: _openNotice,
                            onClose: _viewModel.dismissPromotedNotice,
                          ),
                        ),
                      HomeTodayMatchesSection(
                        matches: _viewModel.todayMatches,
                        loading: _viewModel.todayMatchesLoading,
                        error: _viewModel.todayMatchesError,
                        scale: scale,
                        onRetry: _viewModel.loadTodayMatches,
                        onSeeAll: () => Navigator.of(context)
                            .pushReplacement(tabRoute(const MatchListScreen())),
                      ),
                      HomeStandingsSection(
                        league: _viewModel.standingsLeague,
                        leagues: HomeViewModel.standingsLeagues,
                        result: _viewModel.standingsResult,
                        loading: _viewModel.standingsLoading,
                        error: _viewModel.standingsError,
                        scale: scale,
                        onSelectLeague: _viewModel.selectStandingsLeague,
                        onRetry: _viewModel.loadStandings,
                      ),
                      HomeCommunitySection(
                        posts: _viewModel.communityPosts,
                        loading: _viewModel.communityLoading,
                        error: _viewModel.communityError,
                        scale: scale,
                        onRetry: _viewModel.loadCommunity,
                        onSeeAll: () => Navigator.of(context)
                            .pushReplacement(tabRoute(const CommunityScreen())),
                        onOpenPost: _openPost,
                      ),
                      HomeShortsSection(
                        videos: _viewModel.shortsVideos,
                        loading: _viewModel.shortsLoading,
                        error: _viewModel.shortsError,
                        scale: scale,
                        onRetry: _viewModel.loadShorts,
                        onOpenVideo: _openVideo,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: ListenableBuilder(
                  listenable: _navShrink,
                  builder: (context, _) => AppBottomNav(
                    currentTab: AppNavTab.home,
                    onTabSelected: _onTabSelected,
                    compact: _navShrink.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

위 코드의 `PostDetailScreen(postId: post.id)`는 `PostDetailScreen({required int postId})`(`lib/screens/community/post_detail_screen.dart`)와 시그니처가 일치하고, `launchUrl`/`LaunchMode`는 위 코드 상단에 이미 추가한 `package:url_launcher/url_launcher.dart` import로 해결된다.

- [ ] **Step 4: 기존 고아 화면이 쓰던 로그아웃/placeholder 관련 미사용 import 정리 확인**

`flutter analyze lib/screens/home/home_screen.dart`를 돌려 미사용 import·미사용 `mainScreenPlaceholder` l10n 키 경고가 없는지 확인한다. `mainScreenPlaceholder` 키는 다른 곳에서 안 쓰이면 arb에서 지워도 되지만, 이번 스코프는 화면 교체이므로 지우지 않아도 무방하다(죽은 키 정리는 별도 작업).

Run: `flutter analyze lib/screens/home/home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/screens/home/home_screen_test.dart`
Expected: PASS

- [ ] **Step 6: 전체 유닛/위젯 테스트 회귀 확인**

Run: `flutter test`
Expected: 기존 테스트 전부 PASS (특히 `test/components/app_bottom_nav_test.dart`, `test/viewmodel/schedule/*`, `test/repository/notice/*`).

- [ ] **Step 7: 커밋**

```bash
git add lib/screens/home/home_screen.dart test/screens/home/home_screen_test.dart
git commit -m "feat: HomeScreen을 5섹션 홈 화면으로 교체"
```

---

### Task 12: 하단 탭 전환 배선 + 로그인/온보딩 진입 화면 변경

**Files:**
- Modify: `lib/screens/schedule/schedule_screen.dart`
- Modify: `lib/screens/match_list/match_list_screen.dart`
- Modify: `lib/screens/subscription/subscription_screen.dart`
- Modify: `lib/screens/mypage/mypage_screen.dart`
- Modify: `lib/screens/community/community_screen.dart`
- Modify: `lib/screens/splash_screen.dart`
- Modify: `lib/screens/login/login_screen.dart`
- Modify: `lib/screens/onboarding/onboarding_screen.dart`

**Interfaces:**
- Consumes: `HomeScreen`(Task 11), 각 화면의 기존 `_onTabSelected`/`AppNavTab`.

이 작업은 8개 파일에 걸친 배선 변경이라 자동 테스트보다 "탭 전환이 컴파일되고 analyze를 통과하는지"로 검증한다. `_onTabSelected`가 모든 `AppNavTab` 값을 처리하지 않아도 컴파일은 되지만(if-else 사슬이라 exhaustive 체크가 없다), 빠뜨리면 그 탭에서 홈으로 못 가는 회귀이므로 아래 하나하나 정확히 반영한다.

- [ ] **Step 1: `schedule_screen.dart`에 홈 탭 분기 추가**

Import 추가 (다른 화면 import들 사이):
```dart
import '../home/home_screen.dart';
```

`_onTabSelected` 수정:
```dart
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.home) {
      Navigator.of(context).pushReplacement(tabRoute(const HomeScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }
```

`AppBottomNav(currentTab: AppNavTab.schedule, ...)` 호출부는 그대로 둔다(이 화면 자체가 '일정' 탭이라 바뀔 이유 없음).

- [ ] **Step 2: `match_list_screen.dart`에 홈 탭 분기 추가**

Import 추가:
```dart
import '../home/home_screen.dart';
```

`_onTabSelected` 수정:
```dart
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.home) {
      Navigator.of(context).pushReplacement(tabRoute(const HomeScreen()));
    } else if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }
```

- [ ] **Step 3: `subscription_screen.dart`에 홈 탭 분기 추가**

Import 추가:
```dart
import '../home/home_screen.dart';
```

`_onTabSelected` 수정:
```dart
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.home) {
      Navigator.of(context).pushReplacement(tabRoute(const HomeScreen()));
    } else if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }
```

- [ ] **Step 4: `mypage_screen.dart`에 홈 탭 분기 추가**

Import 추가:
```dart
import '../home/home_screen.dart';
```

`_onTabSelected` 수정 (이 화면은 `(BuildContext context, AppNavTab tab)` 시그니처인 점 주의):
```dart
  void _onTabSelected(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.home) {
      Navigator.of(context).pushReplacement(tabRoute(const HomeScreen()));
    } else if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    }
  }
```

- [ ] **Step 5: `community_screen.dart`에 홈 탭 분기 추가**

Import 추가:
```dart
import '../home/home_screen.dart';
```

`_onTabSelected` 수정:
```dart
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.home) {
      Navigator.of(context).pushReplacement(tabRoute(const HomeScreen()));
    } else if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }
```

- [ ] **Step 6: 스플래시 진입 화면을 홈으로 변경**

`lib/screens/splash_screen.dart`:

```dart
import 'schedule/schedule_screen.dart';
```
→
```dart
import 'home/home_screen.dart';
```

```dart
    final destination = jwt == null
        ? const LoginScreen()
        : const ScheduleScreen();
```
→
```dart
    final destination = jwt == null
        ? const LoginScreen()
        : const HomeScreen();
```

- [ ] **Step 7: 로그인 완료 진입 화면을 홈으로 변경**

`lib/screens/login/login_screen.dart`:

```dart
import '../schedule/schedule_screen.dart';
```
→
```dart
import '../home/home_screen.dart';
```

```dart
          builder: (_) =>
              onboarded ? const ScheduleScreen() : const OnboardingScreen(),
```
→
```dart
          builder: (_) =>
              onboarded ? const HomeScreen() : const OnboardingScreen(),
```

- [ ] **Step 8: 온보딩 완료 진입 화면을 홈으로 변경**

`lib/screens/onboarding/onboarding_screen.dart`:

```dart
import '../schedule/schedule_screen.dart';
```
→
```dart
import '../home/home_screen.dart';
```

```dart
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ScheduleScreen()),
      (route) => false,
    );
```
→
```dart
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
```

- [ ] **Step 9: 정적 분석 + 전체 테스트로 배선 검증**

Run: `flutter analyze`
Expected: `No issues found!` (미사용 import·타입 오류 없음)

Run: `flutter test`
Expected: 전체 PASS. 특히 `splash_screen`/`login_screen`/`onboarding_screen`를 다루는 기존 테스트가 있다면(`test/screens/splash`, `test/screens/login`, `test/screens/onboarding` 등) `ScheduleScreen` 텍스트/타입을 직접 검증하던 부분이 깨질 수 있다 — 깨지면 해당 테스트를 `HomeScreen`으로 여는 게 새 기대 동작이 맞는지 확인 후 기대값을 갱신한다(레이스가 아니라 의도된 동작 변경).

- [ ] **Step 10: 커밋**

```bash
git add lib/screens/schedule/schedule_screen.dart \
        lib/screens/match_list/match_list_screen.dart \
        lib/screens/subscription/subscription_screen.dart \
        lib/screens/mypage/mypage_screen.dart \
        lib/screens/community/community_screen.dart \
        lib/screens/splash_screen.dart \
        lib/screens/login/login_screen.dart \
        lib/screens/onboarding/onboarding_screen.dart
git commit -m "feat: 홈 탭 전환 배선, 로그인/온보딩 완료 후 홈으로 진입"
```

---

### Task 13: 시뮬레이터 수동 검증

**Files:** 없음 (검증 전용 태스크)

- [ ] **Step 1: 앱 실행**

`run-warding` 스킬로 iOS 시뮬레이터에서 앱을 빌드·실행한다. (또는 수동: `flutter run -d <ios-simulator-id>`.)

- [ ] **Step 2: 로그인 후 홈 진입 확인**

로그인(또는 기존 세션)으로 들어가 첫 화면이 홈(5섹션)인지, 하단 탭바에 '홈'이 첫 번째로 있고 6개 탭이 겹치거나 잘리지 않는지 스크린샷으로 확인한다.

- [ ] **Step 3: 섹션별 동작 확인**

- 오늘의 경기: 가로 스크롤, LIVE 배지(라이브 경기가 있는 날이면).
- 순위표: LCK/LPL/LEC/LCS 칩 전환, 미지원 리그에서 안내 문구.
- 커뮤니티: 글 목록, 탭하면 상세로 이동.
- 쇼츠: 가로 스크롤, 탭하면 외부 유튜브 앱/브라우저로 전환.
- 당겨서 새로고침 동작.
- 다른 탭(일정/리스트/커뮤니티/구독/마이) → 홈 탭 왕복 전환.

- [ ] **Step 4: 문제 발견 시**

발견한 문제를 정리해 후속 수정 태스크로 남긴다(이 계획 범위 밖 — 별도 커밋/PR로 처리).

---

## 참고 — 이번 스코프에서 의도적으로 뺀 것

스펙 문서([2026-09-21-home-screen-design.md](../specs/2026-09-21-home-screen-design.md))의 "제외" 절과 동일:

- 구독 선수 솔랭 상태 히어로 섹션 (실시간 조회 REST API 없음)
- 월즈 등 스위스/토너먼트 순위 뷰 (`/api/standings`가 `supported=false`)
- 커뮤니티 최신순/인기순 탭 (`/api/mobile/community/posts`에 정렬 파라미터 없음)
- 쇼츠 "내 선수"/"내 팀" 필터, 인앱 재생 (`intent/youtube-shorts/intent.md`의 Phase 1 범위 절 참고)
- "구독 N명 전체" 진입점 (히어로 섹션과 함께 보류)
