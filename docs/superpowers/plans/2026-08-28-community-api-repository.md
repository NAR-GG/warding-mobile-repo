# 커뮤니티 API 연동 1단계 (모델 + Repository) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 API 20개(게시글 8·댓글 4·신고차단 3·내활동 4·사진서명 1)를 호출하는 모델 + Repository 계층을 만든다. 화면·ViewModel은 건드리지 않는다 — `community_dummy.dart`와 그걸 쓰는 현재 화면들은 이 단계가 끝난 뒤에도 그대로 컴파일된다.

**Architecture:** `RatingRepository`/`ProfileImageRepository` 패턴을 그대로 따른다 — 싱글턴 `instance`, GET은 `_optionalAuthGet`(토큰 있으면 첨부, 없으면 무토큰), 쓰기는 `AuthService.authorizedRequest`(토큰 없으면 throw, 만료 시 자동 재발급). API 응답 모델은 기존 더미 모델(`CommunityPost`/`CommunityComment`)과 이름이 겹치지 않게 `Remote` 접두어를 붙인다. 서버 에러 코드(`COMMUNITY_TEAM_COOLDOWN` 등)와 `Retry-After` 헤더는 공통 `CommunityApiException`으로 구조화해 던진다.

**Tech Stack:** Flutter, `package:http`(`lib/util/api_client.dart` 래퍼 경유), `flutter_test` + `http/testing.dart`(`MockClient`) — 신규 dev dependency 없음.

**Spec:** [docs/superpowers/specs/2026-08-28-community-api-repository-design.md](../specs/2026-08-28-community-api-repository-design.md)

## Global Constraints

- 읽기(GET)는 비로그인 허용, 쓰기(POST/PUT/DELETE)는 전부 인증 필요 (401).
- 커서 페이지네이션: 글/스크랩/좋아요한 글/내 댓글 목록은 **내림차순(최신순)**, 댓글 목록만 **오름차순(오래된 순)**.
- 에러 응답 바디는 `{ code, message }` 형태. 쿨다운(`COMMUNITY_TEAM_COOLDOWN`, 403)과 작성 간격(`COMMUNITY_WRITE_INTERVAL`, 429) 위반은 `Retry-After` 응답 헤더(초)가 같이 온다.
- 답글은 `replyToCommentId`에 **대상 댓글 id를 그대로** 보낸다 — parent 계산은 서버가 한다.
- 게시글 수정의 `imageUrls`는 전체 교체다: 필드를 생략하지 않고 `null`을 보내면 이미지 변경 없음, `[]`을 보내면 전부 제거.
- 이 단계는 화면·ViewModel·마이페이지 진입점을 만들지 않는다. `community_dummy.dart`와 그 화면들은 수정하지 않는다.
- 새 API 모델은 더미 모델과 이름이 겹치면 `Remote` 접두어(`CommunityRemotePost`, `CommunityRemoteComment` 등)를 붙인다. 겹치지 않는 모델(`CommunityAuthor`, `CommunityBoardViewer` 등)은 접두어 없이 둔다.

---

## File Structure

**생성:**
- `lib/model/community_author.dart` — `CommunityAuthor`
- `lib/model/community_post_image.dart` — `CommunityPostImage`
- `lib/model/community_remote_post.dart` — `CommunityWriteLockReason`/`CommunityBoardViewer`/`CommunityPostViewer`/`CommunityRemotePost`/`CommunityRemotePostDetail`/`CommunityRemotePostPage`
- `lib/model/community_remote_comment.dart` — `CommunityCommentStatus`/`CommunityRemoteComment`/`CommunityRemoteCommentPage`
- `lib/model/community_report.dart` — `CommunityReportTargetType`/`CommunityReportReason`
- `lib/model/community_my_activity.dart` — `CommunityScrapItem`/`CommunityScrapPage`/`CommunityLikeItem`/`CommunityLikePage`/`CommunityMyComment`/`CommunityMyCommentPage`
- `lib/repository/community/community_api_exception.dart` — `CommunityApiException`
- `lib/repository/community/community_repository.dart` — `CommunityRepository` (게시글 8 + 댓글 4)
- `lib/repository/community/community_report_repository.dart` — `CommunityReportRepository` (신고·차단 3)
- `lib/repository/community/community_activity_repository.dart` — `CommunityActivityRepository` (내 활동 4)
- `lib/repository/community/community_image_repository.dart` — `CommunityImageRepository` (사진 서명 업로드)
- `test/model/community_author_test.dart`
- `test/model/community_remote_post_test.dart`
- `test/model/community_remote_comment_test.dart`
- `test/model/community_report_test.dart`
- `test/model/community_my_activity_test.dart`
- `test/repository/community/community_api_exception_test.dart`
- `test/repository/community/community_repository_test.dart`
- `test/repository/community/community_report_repository_test.dart`
- `test/repository/community/community_activity_repository_test.dart`
- `test/repository/community/community_image_repository_test.dart`

**수정:**
- `lib/config/api_config.dart` — 커뮤니티 20개 엔드포인트 URL 빌더 추가

---

## Task 1: `CommunityApiException`

**Files:**
- Create: `lib/repository/community/community_api_exception.dart`
- Test: `test/repository/community/community_api_exception_test.dart`

**Interfaces:**
- Produces: `CommunityApiException({required int statusCode, required String message, String? code, int? retryAfterSeconds})`, `CommunityApiException.fromResponse(http.Response response)` (factory). 뒤 모든 Task가 에러를 던질 때 이 타입을 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/repository/community/community_api_exception_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:warding/repository/community/community_api_exception.dart';

void main() {
  test('code·message·Retry-After 헤더를 파싱한다', () {
    final response = http.Response(
      '{"timestamp":"2026-08-28T00:00:00","status":403,"error":"FORBIDDEN",'
      '"code":"COMMUNITY_TEAM_COOLDOWN","message":"응원팀을 바꾼 지 얼마 되지 않았습니다."}',
      403,
      headers: {'retry-after': '86400'},
    );

    final exception = CommunityApiException.fromResponse(response);

    expect(exception.statusCode, 403);
    expect(exception.code, 'COMMUNITY_TEAM_COOLDOWN');
    expect(exception.message, '응원팀을 바꾼 지 얼마 되지 않았습니다.');
    expect(exception.retryAfterSeconds, 86400);
  });

  test('Retry-After 헤더가 없으면 null', () {
    final response = http.Response(
      '{"code":"COMMUNITY_BOARD_FORBIDDEN","message":"권한이 없습니다."}',
      403,
    );

    final exception = CommunityApiException.fromResponse(response);

    expect(exception.retryAfterSeconds, isNull);
  });

  test('본문이 JSON이 아니면 code는 null, message는 HTTP 상태코드로 대체', () {
    final response = http.Response('<html>Bad Gateway</html>', 502);

    final exception = CommunityApiException.fromResponse(response);

    expect(exception.code, isNull);
    expect(exception.message, 'HTTP 502');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/repository/community/community_api_exception_test.dart`
Expected: FAIL — `community_api_exception.dart` 가 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/repository/community/community_api_exception.dart`:

```dart
import 'dart:convert';

import '../../util/api_client.dart' as http;

/// 커뮤니티 API가 2xx가 아닐 때 던지는 공통 예외.
///
/// 서버 에러 응답(`{code, message}`)과 `Retry-After` 헤더(초)를 구조화해
/// 담는다. ViewModel은 [code]로 분기해 쿨다운·작성 간격 등 문구를 그린다.
class CommunityApiException implements Exception {
  const CommunityApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.retryAfterSeconds,
  });

  final int statusCode;

  /// 예: `COMMUNITY_TEAM_COOLDOWN`, `COMMUNITY_WRITE_INTERVAL`. 서버가 안 주면 null.
  final String? code;

  final String message;

  /// `Retry-After` 헤더(초). 쿨다운·작성 간격 위반에만 온다.
  final int? retryAfterSeconds;

  factory CommunityApiException.fromResponse(http.Response response) {
    var message = 'HTTP ${response.statusCode}';
    String? code;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        code = body['code'] as String?;
        message = body['message'] as String? ?? message;
      }
    } catch (_) {
      // 본문이 JSON이 아니면(게이트웨이 에러 페이지 등) 기본 메시지를 쓴다.
    }
    final retryAfter = response.headers['retry-after'];
    return CommunityApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      retryAfterSeconds: retryAfter != null ? int.tryParse(retryAfter) : null,
    );
  }

  @override
  String toString() =>
      'CommunityApiException($statusCode, code=$code, message=$message, '
      'retryAfterSeconds=$retryAfterSeconds)';
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/repository/community/community_api_exception_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/repository/community/community_api_exception.dart test/repository/community/community_api_exception_test.dart
git commit -m "feat: 커뮤니티 API 공통 에러 타입 CommunityApiException 추가"
```

---

## Task 2: `ApiConfig` 커뮤니티 URL 빌더

**Files:**
- Modify: `lib/config/api_config.dart:326-329` (`deviceUrl` 다음, `// ── 약관·정책` 앞)

**Interfaces:**
- Produces: `communityPostsUrl`, `communityCreatePostUrl`, `communityPostUrl`, `communityPostViewUrl`, `communityPostLikeUrl`, `communityPostScrapUrl`, `communityCommentsUrl`, `communityCreateCommentUrl`, `communityCommentUrl`, `communityCommentLikeUrl`, `communityReportsUrl`, `communityBlocksUrl`, `communityBlockUrl`, `meCommunityScrapsUrl`, `meCommunityPostsUrl`, `meCommunityLikesUrl`, `meCommunityCommentsUrl`, `communityImageSignatureUrl`. Task 8~12가 전부 이 이름을 그대로 쓴다.

이 파일은 순수 문자열 조립이라(분기 없음) 별도 테스트를 만들지 않는다 — 정확성은 Task 8~12의 Repository 테스트가 URL 경로를 검증하며 실질적으로 확인한다. 기존 `api_config.dart`도 이 방식이다(전용 테스트 없음).

- [ ] **Step 1: 구현**

`lib/config/api_config.dart`에서 다음 블록을 찾는다:

```dart
  /// 현재 기기 비활성화 (DELETE).
  static String deviceUrl(String deviceId) =>
      '$apiBaseUrl/mobile/me/devices/$deviceId';

  // ── 약관·정책 (웹 문서) ─────────────────────────────────────────────
```

`deviceUrl` 메서드와 `// ── 약관·정책` 사이에 아래 블록을 삽입한다:

```dart
  // ── 커뮤니티 (읽기는 비로그인 허용, 쓰기는 인증 필요) ────────────────

  /// 게시글 목록. [boardTeamId] 생략 = 전체 게시판, 값 = 그 팀 게시판.
  /// [size] 기본 20, 최대 50.
  static String communityPostsUrl({
    int? boardTeamId,
    String? cursor,
    int size = 20,
  }) {
    final query = StringBuffer('size=$size');
    if (boardTeamId != null) query.write('&boardTeamId=$boardTeamId');
    if (cursor != null && cursor.isNotEmpty) {
      query.write('&cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    return '$apiBaseUrl/mobile/community/posts?$query';
  }

  /// 게시글 작성(POST).
  static String get communityCreatePostUrl =>
      '$apiBaseUrl/mobile/community/posts';

  /// 게시글 상세(GET) / 수정(PUT) / 삭제(DELETE).
  static String communityPostUrl(int postId) =>
      '$apiBaseUrl/mobile/community/posts/$postId';

  /// 조회수 +1(POST).
  static String communityPostViewUrl(int postId) =>
      '$apiBaseUrl/mobile/community/posts/$postId/view';

  /// 추천 토글(POST).
  static String communityPostLikeUrl(int postId) =>
      '$apiBaseUrl/mobile/community/posts/$postId/like';

  /// 스크랩 토글(POST).
  static String communityPostScrapUrl(int postId) =>
      '$apiBaseUrl/mobile/community/posts/$postId/scrap';

  /// 댓글 목록(GET, 오래된 순). [size] 기본 50, 최대 100.
  static String communityCommentsUrl(
    int postId, {
    String? cursor,
    int size = 50,
  }) {
    final query = StringBuffer('size=$size');
    if (cursor != null && cursor.isNotEmpty) {
      query.write('&cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    return '$apiBaseUrl/mobile/community/posts/$postId/comments?$query';
  }

  /// 댓글 작성(POST).
  static String communityCreateCommentUrl(int postId) =>
      '$apiBaseUrl/mobile/community/posts/$postId/comments';

  /// 댓글 삭제(DELETE).
  static String communityCommentUrl(int commentId) =>
      '$apiBaseUrl/mobile/community/comments/$commentId';

  /// 댓글 추천 토글(POST).
  static String communityCommentLikeUrl(int commentId) =>
      '$apiBaseUrl/mobile/community/comments/$commentId/like';

  /// 신고 등록(POST).
  static String get communityReportsUrl =>
      '$apiBaseUrl/mobile/community/reports';

  /// 차단(POST).
  static String get communityBlocksUrl =>
      '$apiBaseUrl/mobile/community/blocks';

  /// 차단 해제(DELETE).
  static String communityBlockUrl(int memberId) =>
      '$apiBaseUrl/mobile/community/blocks/$memberId';

  static String _meCommunityUrl(
    String path, {
    String? cursor,
    int size = 20,
  }) {
    final query = StringBuffer('size=$size');
    if (cursor != null && cursor.isNotEmpty) {
      query.write('&cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    return '$apiBaseUrl/mobile/me/community/$path?$query';
  }

  /// 내 스크랩 목록(GET, 최신순, 커서 = scrapId).
  static String meCommunityScrapsUrl({String? cursor, int size = 20}) =>
      _meCommunityUrl('scraps', cursor: cursor, size: size);

  /// 내가 쓴 글 목록(GET, 최신순, 커서 = 글 id).
  static String meCommunityPostsUrl({String? cursor, int size = 20}) =>
      _meCommunityUrl('posts', cursor: cursor, size: size);

  /// 좋아요한 글 목록(GET, 최신순, 커서 = likeId).
  static String meCommunityLikesUrl({String? cursor, int size = 20}) =>
      _meCommunityUrl('likes', cursor: cursor, size: size);

  /// 내가 쓴 댓글 목록(GET, 최신순, 커서 = 댓글 id).
  static String meCommunityCommentsUrl({String? cursor, int size = 20}) =>
      _meCommunityUrl('comments', cursor: cursor, size: size);

  /// 커뮤니티 사진 Cloudinary 서명 업로드용 파라미터 발급(POST, 인증 필요).
  /// [profileImageSignatureUrl]과 달리 이미지 1장마다 새 publicId가 발급된다.
  static String get communityImageSignatureUrl =>
      '$apiBaseUrl/auth/me/community-image/signature';

```

(블록을 삽입한 뒤에도 `// ── 약관·정책` 섹션은 그대로 이어진다.)

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/config/api_config.dart`
Expected: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/config/api_config.dart
git commit -m "feat: ApiConfig에 커뮤니티 API 20개 URL 빌더 추가"
```

---

## Task 3: `CommunityAuthor` 모델

**Files:**
- Create: `lib/model/community_author.dart`
- Test: `test/model/community_author_test.dart`

**Interfaces:**
- Produces: `CommunityAuthor({required int memberId, required String nickname, String? profileImageUrl, int? teamId, String? teamCode, String? teamImageUrl})`, `CommunityAuthor.fromJson(Map<String, dynamic>)`. Task 4·5가 글/댓글 작성자로 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/model/community_author_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_author.dart';

void main() {
  test('fromJson이 필드를 그대로 매핑한다', () {
    final author = CommunityAuthor.fromJson(const {
      'memberId': 7,
      'nickname': '이름#0001',
      'profileImageUrl': 'https://example.com/p.png',
      'teamId': 1,
      'teamCode': 'T1',
      'teamImageUrl': 'https://example.com/t.png',
    });

    expect(author.memberId, 7);
    expect(author.nickname, '이름#0001');
    expect(author.teamId, 1);
    expect(author.teamCode, 'T1');
    expect(author.teamImageUrl, 'https://example.com/t.png');
  });

  test('팀 정보가 없으면 null', () {
    final author = CommunityAuthor.fromJson(const {
      'memberId': 7,
      'nickname': '무소속',
    });

    expect(author.teamId, isNull);
    expect(author.teamCode, isNull);
    expect(author.teamImageUrl, isNull);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/model/community_author_test.dart`
Expected: FAIL — 파일 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/model/community_author.dart`:

```dart
/// 커뮤니티 글·댓글 작성자 스냅샷.
///
/// 응답에 `author` 자체가 없으면(회원 하드 삭제) 상위 모델에서
/// `CommunityAuthor?`가 null — "탈퇴한 사용자"로 그린다.
class CommunityAuthor {
  const CommunityAuthor({
    required this.memberId,
    required this.nickname,
    this.profileImageUrl,
    this.teamId,
    this.teamCode,
    this.teamImageUrl,
  });

  final int memberId;
  final String nickname;
  final String? profileImageUrl;

  /// **작성 시점** 응원팀 스냅샷. 작성자가 나중에 팀을 옮겨도 이 값은
  /// 그대로다 — 현재 팀을 조인하면 과거 글의 뱃지가 전부 새 팀으로 뒤집힌다.
  final int? teamId;
  final String? teamCode;
  final String? teamImageUrl;

  factory CommunityAuthor.fromJson(Map<String, dynamic> json) {
    return CommunityAuthor(
      memberId: (json['memberId'] as num?)?.toInt() ?? 0,
      nickname: json['nickname'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      teamId: (json['teamId'] as num?)?.toInt(),
      teamCode: json['teamCode'] as String?,
      teamImageUrl: json['teamImageUrl'] as String?,
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/model/community_author_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/community_author.dart test/model/community_author_test.dart
git commit -m "feat: CommunityAuthor 모델 추가"
```

---

## Task 4: 게시글 모델 (`CommunityRemotePost` 계열)

**Files:**
- Create: `lib/model/community_post_image.dart`
- Create: `lib/model/community_remote_post.dart`
- Test: `test/model/community_remote_post_test.dart`

**Interfaces:**
- Consumes: `CommunityAuthor`/`CommunityAuthor.fromJson` (Task 3).
- Produces: `CommunityPostImage({required int id, required String url})`. `CommunityWriteLockReason` enum(`notFan`/`cooldown`, `.fromApi(String?)`). `CommunityBoardViewer({required bool canWrite, CommunityWriteLockReason? reason, DateTime? writableFrom})`. `CommunityPostViewer({required bool liked, required bool scrapped, required bool mine, required bool blockedAuthor})`. `CommunityRemotePost` (필드: `id, boardTeamId, title, bodyPreview, author, viewCount, likeCount, commentCount, edited, createdAt, thumbnailUrl, imageCount`). `CommunityRemotePostDetail` (필드: `summary`(`CommunityRemotePost`), `body, images, viewer` + getters `id/boardTeamId/title/author/viewCount/likeCount/commentCount/edited/createdAt`). `CommunityRemotePostPage({required List<CommunityRemotePost> posts, int? nextCursor, CommunityBoardViewer? boardViewer})`. 전부 `.fromJson(Map<String, dynamic>)` 팩토리 보유. Task 7·8·11이 이 타입들을 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/model/community_remote_post_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_remote_post.dart';

void main() {
  group('CommunityRemotePost.fromJson', () {
    test('목록 요약 필드를 그대로 매핑한다', () {
      final post = CommunityRemotePost.fromJson(const {
        'id': 42,
        'boardTeamId': null,
        'title': '오늘 밴픽 얘기',
        'bodyPreview': '본문 앞부분',
        'author': {'memberId': 7, 'nickname': '이름#0001'},
        'viewCount': 10,
        'likeCount': 3,
        'commentCount': 5,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
        'thumbnailUrl': 'https://res.cloudinary.com/x.png',
        'imageCount': 2,
      });

      expect(post.id, 42);
      expect(post.boardTeamId, isNull);
      expect(post.author?.nickname, '이름#0001');
      expect(post.imageCount, 2);
      expect(post.createdAt, DateTime.parse('2026-08-26T21:00:00'));
    });

    test('author가 없으면 탈퇴한 사용자로 null', () {
      final post = CommunityRemotePost.fromJson(const {
        'id': 1,
        'title': '',
        'bodyPreview': '',
        'author': null,
        'viewCount': 0,
        'likeCount': 0,
        'commentCount': 0,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
      });

      expect(post.author, isNull);
    });
  });

  group('CommunityRemotePostDetail.fromJson', () {
    test('본문·이미지·viewer를 포함해 매핑한다', () {
      final detail = CommunityRemotePostDetail.fromJson(const {
        'id': 42,
        'title': '제목',
        'bodyPreview': '',
        'author': {'memberId': 7, 'nickname': '이름#0001'},
        'viewCount': 10,
        'likeCount': 3,
        'commentCount': 5,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
        'body': '전문',
        'images': [
          {'id': 3, 'url': 'https://res.cloudinary.com/a.png'},
        ],
        'viewer': {
          'liked': true,
          'scrapped': false,
          'mine': false,
          'blockedAuthor': false,
        },
      });

      expect(detail.body, '전문');
      expect(detail.images, hasLength(1));
      expect(detail.images.first.id, 3);
      expect(detail.viewer.liked, isTrue);
      expect(detail.title, '제목');
      expect(detail.author?.memberId, 7);
    });

    test('blockedAuthor가 true면 title·body·images가 비어도 그대로 담는다', () {
      final detail = CommunityRemotePostDetail.fromJson(const {
        'id': 42,
        'title': '',
        'bodyPreview': '',
        'author': null,
        'viewCount': 0,
        'likeCount': 0,
        'commentCount': 0,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
        'body': '',
        'images': [],
        'viewer': {
          'liked': false,
          'scrapped': false,
          'mine': false,
          'blockedAuthor': true,
        },
      });

      expect(detail.viewer.blockedAuthor, isTrue);
      expect(detail.title, '');
      expect(detail.images, isEmpty);
    });
  });

  group('CommunityRemotePostPage.fromJson', () {
    test('boardViewer가 없으면 null', () {
      final page = CommunityRemotePostPage.fromJson(const {
        'posts': [],
        'nextCursor': null,
      });

      expect(page.boardViewer, isNull);
      expect(page.nextCursor, isNull);
    });

    test('COOLDOWN 잠금 바를 파싱한다', () {
      final page = CommunityRemotePostPage.fromJson(const {
        'posts': [],
        'nextCursor': 42,
        'boardViewer': {
          'canWrite': false,
          'reason': 'COOLDOWN',
          'writableFrom': '2026-09-20T21:00:00',
        },
      });

      expect(page.nextCursor, 42);
      expect(page.boardViewer?.canWrite, isFalse);
      expect(page.boardViewer?.reason, CommunityWriteLockReason.cooldown);
      expect(
        page.boardViewer?.writableFrom,
        DateTime.parse('2026-09-20T21:00:00'),
      );
    });

    test('NOT_FAN 잠금 바를 파싱한다', () {
      final page = CommunityRemotePostPage.fromJson(const {
        'posts': [],
        'boardViewer': {'canWrite': false, 'reason': 'NOT_FAN'},
      });

      expect(page.boardViewer?.reason, CommunityWriteLockReason.notFan);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/model/community_remote_post_test.dart`
Expected: FAIL — 파일 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/model/community_post_image.dart`:

```dart
/// 게시글 상세에 첨부된 이미지 한 장.
///
/// [id]는 이미지 신고(`CommunityReportTargetType.image`)의 targetId로 쓰인다.
class CommunityPostImage {
  const CommunityPostImage({required this.id, required this.url});

  final int id;
  final String url;

  factory CommunityPostImage.fromJson(Map<String, dynamic> json) {
    return CommunityPostImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
    );
  }
}
```

Create `lib/model/community_remote_post.dart`:

```dart
import 'community_author.dart';
import 'community_post_image.dart';

/// 팀 게시판 쓰기 잠금 사유.
enum CommunityWriteLockReason {
  /// 내 응원팀이 아닌 팀 게시판.
  notFan,

  /// 응원팀을 바꾼 지 30일이 안 지남.
  cooldown;

  static CommunityWriteLockReason? fromApi(String? value) {
    switch (value) {
      case 'NOT_FAN':
        return CommunityWriteLockReason.notFan;
      case 'COOLDOWN':
        return CommunityWriteLockReason.cooldown;
      default:
        return null;
    }
  }
}

/// 팀 게시판 쓰기 잠금 바. 팀 게시판 + 로그인일 때만 목록 응답에 실린다.
class CommunityBoardViewer {
  const CommunityBoardViewer({
    required this.canWrite,
    this.reason,
    this.writableFrom,
  });

  final bool canWrite;
  final CommunityWriteLockReason? reason;

  /// [reason]이 cooldown일 때 다시 쓸 수 있게 되는 시각.
  final DateTime? writableFrom;

  factory CommunityBoardViewer.fromJson(Map<String, dynamic> json) {
    return CommunityBoardViewer(
      canWrite: json['canWrite'] as bool? ?? false,
      reason: CommunityWriteLockReason.fromApi(json['reason'] as String?),
      writableFrom: DateTime.tryParse(json['writableFrom'] as String? ?? ''),
    );
  }
}

/// 게시글 상세 조회자 관점 상태.
class CommunityPostViewer {
  const CommunityPostViewer({
    required this.liked,
    required this.scrapped,
    required this.mine,
    required this.blockedAuthor,
  });

  final bool liked;
  final bool scrapped;
  final bool mine;

  /// true면 [CommunityRemotePostDetail.title]/[CommunityRemotePostDetail.body]/
  /// [CommunityRemotePostDetail.images]가 빈 값으로 온다 — "차단한 사용자의
  /// 글입니다" 자리를 그린다.
  final bool blockedAuthor;

  static const _empty = CommunityPostViewer(
    liked: false,
    scrapped: false,
    mine: false,
    blockedAuthor: false,
  );

  factory CommunityPostViewer.fromJson(Map<String, dynamic> json) {
    return CommunityPostViewer(
      liked: json['liked'] as bool? ?? false,
      scrapped: json['scrapped'] as bool? ?? false,
      mine: json['mine'] as bool? ?? false,
      blockedAuthor: json['blockedAuthor'] as bool? ?? false,
    );
  }
}

/// 게시글 목록 요약 한 건.
class CommunityRemotePost {
  const CommunityRemotePost({
    required this.id,
    required this.boardTeamId,
    required this.title,
    required this.bodyPreview,
    required this.author,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.edited,
    required this.createdAt,
    this.thumbnailUrl,
    this.imageCount = 0,
  });

  final int id;

  /// null이면 전체 게시판 글.
  final int? boardTeamId;

  final String title;
  final String bodyPreview;

  /// 응답에 `author`가 없으면(탈퇴 회원) null.
  final CommunityAuthor? author;

  final int viewCount;
  final int likeCount;
  final int commentCount;

  /// 수정됨 표시 기준. `updatedAt`으로 판단하지 않는다.
  final bool edited;

  final DateTime? createdAt;
  final String? thumbnailUrl;
  final int imageCount;

  factory CommunityRemotePost.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    return CommunityRemotePost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      boardTeamId: (json['boardTeamId'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      bodyPreview: json['bodyPreview'] as String? ?? '',
      author: author == null
          ? null
          : CommunityAuthor.fromJson(author as Map<String, dynamic>),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      edited: json['edited'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 게시글 상세 — 목록 요약 필드 + 본문·이미지·조회자 상태.
class CommunityRemotePostDetail {
  const CommunityRemotePostDetail({
    required this.summary,
    required this.body,
    required this.images,
    required this.viewer,
  });

  final CommunityRemotePost summary;
  final String body;
  final List<CommunityPostImage> images;
  final CommunityPostViewer viewer;

  int get id => summary.id;
  int? get boardTeamId => summary.boardTeamId;
  String get title => summary.title;
  CommunityAuthor? get author => summary.author;
  int get viewCount => summary.viewCount;
  int get likeCount => summary.likeCount;
  int get commentCount => summary.commentCount;
  bool get edited => summary.edited;
  DateTime? get createdAt => summary.createdAt;

  factory CommunityRemotePostDetail.fromJson(Map<String, dynamic> json) {
    return CommunityRemotePostDetail(
      summary: CommunityRemotePost.fromJson(json),
      body: json['body'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((e) => CommunityPostImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      viewer: json['viewer'] == null
          ? CommunityPostViewer._empty
          : CommunityPostViewer.fromJson(
              json['viewer'] as Map<String, dynamic>,
            ),
    );
  }
}

/// 게시글 목록 페이지 응답.
class CommunityRemotePostPage {
  const CommunityRemotePostPage({
    required this.posts,
    this.nextCursor,
    this.boardViewer,
  });

  final List<CommunityRemotePost> posts;
  final int? nextCursor;

  /// 팀 게시판 + 로그인일 때만 채워진다.
  final CommunityBoardViewer? boardViewer;

  factory CommunityRemotePostPage.fromJson(Map<String, dynamic> json) {
    return CommunityRemotePostPage(
      posts: (json['posts'] as List<dynamic>? ?? const [])
          .map((e) => CommunityRemotePost.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
      boardViewer: json['boardViewer'] == null
          ? null
          : CommunityBoardViewer.fromJson(
              json['boardViewer'] as Map<String, dynamic>,
            ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/model/community_remote_post_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/community_post_image.dart lib/model/community_remote_post.dart test/model/community_remote_post_test.dart
git commit -m "feat: 게시글 API 모델(CommunityRemotePost 계열) 추가"
```

---

## Task 5: 댓글 모델 (`CommunityRemoteComment` 계열)

**Files:**
- Create: `lib/model/community_remote_comment.dart`
- Test: `test/model/community_remote_comment_test.dart`

**Interfaces:**
- Consumes: `CommunityAuthor`/`CommunityAuthor.fromJson` (Task 3).
- Produces: `CommunityCommentStatus` enum(`visible/deleted/blocked/hidden`, `.fromApi(String?)`). `CommunityRemoteComment` (필드: `id, parentId, status, body, author, mentionNickname, likeCount, liked, mine, createdAt`). `CommunityRemoteCommentPage({required List<CommunityRemoteComment> comments, int? nextCursor})`. Task 8이 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/model/community_remote_comment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_remote_comment.dart';

void main() {
  group('CommunityRemoteComment.fromJson', () {
    test('VISIBLE 댓글은 body·author를 그대로 담는다', () {
      final comment = CommunityRemoteComment.fromJson(const {
        'id': 9,
        'parentId': 5,
        'body': '이거 진짜 체감됐음',
        'status': 'VISIBLE',
        'author': {'memberId': 1, 'nickname': '황금독수리'},
        'mentionNickname': '번역봇#0002',
        'likeCount': 1,
        'liked': false,
        'mine': false,
        'createdAt': '2026-08-26T21:00:00',
      });

      expect(comment.status, CommunityCommentStatus.visible);
      expect(comment.body, '이거 진짜 체감됐음');
      expect(comment.author?.nickname, '황금독수리');
      expect(comment.mentionNickname, '번역봇#0002');
      expect(comment.parentId, 5);
    });

    test('최상위 댓글은 parentId가 null', () {
      final comment = CommunityRemoteComment.fromJson(const {
        'id': 1,
        'parentId': null,
        'body': '본문',
        'status': 'VISIBLE',
        'author': {'memberId': 1, 'nickname': 'a'},
        'likeCount': 0,
        'liked': false,
        'mine': false,
        'createdAt': '2026-08-26T21:00:00',
      });

      expect(comment.parentId, isNull);
    });

    for (final status in ['DELETED', 'BLOCKED', 'HIDDEN']) {
      test('$status 댓글은 body·author가 null이어도 행이 유지된다', () {
        final comment = CommunityRemoteComment.fromJson({
          'id': 4,
          'parentId': null,
          'body': null,
          'status': status,
          'author': null,
          'likeCount': 0,
          'liked': false,
          'mine': false,
          'createdAt': '2026-08-26T21:00:00',
        });

        expect(comment.id, 4);
        expect(comment.body, isNull);
        expect(comment.author, isNull);
      });
    }
  });

  group('CommunityRemoteCommentPage.fromJson', () {
    test('오래된 순 커서 페이지를 파싱한다', () {
      final page = CommunityRemoteCommentPage.fromJson(const {
        'comments': [
          {
            'id': 9,
            'parentId': null,
            'body': '본문',
            'status': 'VISIBLE',
            'author': {'memberId': 1, 'nickname': 'a'},
            'likeCount': 0,
            'liked': false,
            'mine': false,
            'createdAt': '2026-08-26T21:00:00',
          },
        ],
        'nextCursor': 9,
      });

      expect(page.comments, hasLength(1));
      expect(page.nextCursor, 9);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/model/community_remote_comment_test.dart`
Expected: FAIL — 파일 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/model/community_remote_comment.dart`:

```dart
import 'community_author.dart';

/// 댓글 상태. VISIBLE이 아니면 [CommunityRemoteComment.body]/
/// [CommunityRemoteComment.author]가 null로 온다(행은 유지된다 — 자리 보존).
enum CommunityCommentStatus {
  visible,
  deleted,
  blocked,
  hidden;

  static CommunityCommentStatus fromApi(String? value) {
    switch (value) {
      case 'DELETED':
        return CommunityCommentStatus.deleted;
      case 'BLOCKED':
        return CommunityCommentStatus.blocked;
      case 'HIDDEN':
        return CommunityCommentStatus.hidden;
      case 'VISIBLE':
      default:
        return CommunityCommentStatus.visible;
    }
  }
}

/// 커뮤니티 댓글 한 건. 답글은 1단까지만 접는다 — [parentId]는 항상
/// 최상위 댓글을 가리킨다(답글의 답글도 같은 층에 쌓인다).
class CommunityRemoteComment {
  const CommunityRemoteComment({
    required this.id,
    required this.parentId,
    required this.status,
    required this.body,
    required this.author,
    required this.likeCount,
    required this.liked,
    required this.mine,
    required this.createdAt,
    this.mentionNickname,
  });

  final int id;
  final int? parentId;
  final CommunityCommentStatus status;

  /// status가 VISIBLE이 아니면 null.
  final String? body;

  /// status가 VISIBLE이 아니면 null.
  final CommunityAuthor? author;

  /// 답글이 특정 사용자에게 향할 때 본문 앞에 붙는 `@닉네임`.
  final String? mentionNickname;

  final int likeCount;
  final bool liked;
  final bool mine;
  final DateTime? createdAt;

  factory CommunityRemoteComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    return CommunityRemoteComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentId: (json['parentId'] as num?)?.toInt(),
      status: CommunityCommentStatus.fromApi(json['status'] as String?),
      body: json['body'] as String?,
      author: author == null
          ? null
          : CommunityAuthor.fromJson(author as Map<String, dynamic>),
      mentionNickname: json['mentionNickname'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] as bool? ?? false,
      mine: json['mine'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// 댓글 목록 페이지 응답(오래된 순).
class CommunityRemoteCommentPage {
  const CommunityRemoteCommentPage({required this.comments, this.nextCursor});

  final List<CommunityRemoteComment> comments;
  final int? nextCursor;

  factory CommunityRemoteCommentPage.fromJson(Map<String, dynamic> json) {
    return CommunityRemoteCommentPage(
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map(
            (e) => CommunityRemoteComment.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/model/community_remote_comment_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/community_remote_comment.dart test/model/community_remote_comment_test.dart
git commit -m "feat: 댓글 API 모델(CommunityRemoteComment 계열) 추가"
```

---

## Task 6: 신고 enum (`CommunityReportTargetType`/`CommunityReportReason`)

**Files:**
- Create: `lib/model/community_report.dart`
- Test: `test/model/community_report_test.dart`

**Interfaces:**
- Produces: `CommunityReportTargetType` enum(`post/comment/image`) + `.apiValue` getter(`POST/COMMENT/IMAGE`). `CommunityReportReason` enum(`abuse/obscene/ad/fraud/spam/etc`) + `.apiValue` getter(`ABUSE/OBSCENE/AD/FRAUD/SPAM/ETC`). Task 10이 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/model/community_report_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_report.dart';

void main() {
  test('CommunityReportTargetType.apiValue는 서버 문자열과 일치한다', () {
    expect(CommunityReportTargetType.post.apiValue, 'POST');
    expect(CommunityReportTargetType.comment.apiValue, 'COMMENT');
    expect(CommunityReportTargetType.image.apiValue, 'IMAGE');
  });

  test('CommunityReportReason.apiValue는 서버 문자열과 일치한다', () {
    expect(CommunityReportReason.abuse.apiValue, 'ABUSE');
    expect(CommunityReportReason.obscene.apiValue, 'OBSCENE');
    expect(CommunityReportReason.ad.apiValue, 'AD');
    expect(CommunityReportReason.fraud.apiValue, 'FRAUD');
    expect(CommunityReportReason.spam.apiValue, 'SPAM');
    expect(CommunityReportReason.etc.apiValue, 'ETC');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/model/community_report_test.dart`
Expected: FAIL — 파일 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/model/community_report.dart`:

```dart
/// 신고 대상 종류.
enum CommunityReportTargetType {
  post,
  comment,
  image;

  String get apiValue => switch (this) {
    CommunityReportTargetType.post => 'POST',
    CommunityReportTargetType.comment => 'COMMENT',
    CommunityReportTargetType.image => 'IMAGE',
  };
}

/// 신고 사유. [etc]는 상세 사유(`detail`, ≤200자)가 필수다.
enum CommunityReportReason {
  abuse,
  obscene,
  ad,
  fraud,
  spam,
  etc;

  String get apiValue => switch (this) {
    CommunityReportReason.abuse => 'ABUSE',
    CommunityReportReason.obscene => 'OBSCENE',
    CommunityReportReason.ad => 'AD',
    CommunityReportReason.fraud => 'FRAUD',
    CommunityReportReason.spam => 'SPAM',
    CommunityReportReason.etc => 'ETC',
  };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/model/community_report_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/community_report.dart test/model/community_report_test.dart
git commit -m "feat: 신고 대상·사유 enum(CommunityReportTargetType/CommunityReportReason) 추가"
```

---

## Task 7: 내 활동 모델 (`CommunityScrapItem`/`CommunityLikeItem`/`CommunityMyComment`)

**Files:**
- Create: `lib/model/community_my_activity.dart`
- Test: `test/model/community_my_activity_test.dart`

**Interfaces:**
- Consumes: `CommunityRemotePost`/`CommunityRemotePost.fromJson` (Task 4).
- Produces: `CommunityScrapItem({required int scrapId, required CommunityRemotePost post})`, `CommunityScrapPage({required List<CommunityScrapItem> items, int? nextCursor})`. `CommunityLikeItem({required int likeId, required CommunityRemotePost post})`, `CommunityLikePage({required List<CommunityLikeItem> items, int? nextCursor})`. `CommunityMyComment({required int id, required int postId, required String postTitle, required String body, required int likeCount, required DateTime? createdAt})`, `CommunityMyCommentPage({required List<CommunityMyComment> comments, int? nextCursor})`. Task 11이 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/model/community_my_activity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_my_activity.dart';

Map<String, dynamic> _postJson({int id = 1}) => {
  'id': id,
  'title': '제목',
  'bodyPreview': '',
  'author': null,
  'viewCount': 0,
  'likeCount': 0,
  'commentCount': 0,
  'edited': false,
  'createdAt': '2026-08-26T21:00:00',
};

void main() {
  test('CommunityScrapPage는 scrapId 커서로 항목을 담는다', () {
    final page = CommunityScrapPage.fromJson({
      'items': [
        {'scrapId': 12, 'post': _postJson(id: 42)},
      ],
      'nextCursor': 12,
    });

    expect(page.items.first.scrapId, 12);
    expect(page.items.first.post.id, 42);
    expect(page.nextCursor, 12);
  });

  test('CommunityLikePage는 likeId 커서로 항목을 담는다', () {
    final page = CommunityLikePage.fromJson({
      'items': [
        {'likeId': 7, 'post': _postJson(id: 1)},
      ],
      'nextCursor': 7,
    });

    expect(page.items.first.likeId, 7);
    expect(page.nextCursor, 7);
  });

  test('CommunityMyComment는 postId·postTitle을 담는다', () {
    final page = CommunityMyCommentPage.fromJson(const {
      'comments': [
        {
          'id': 9,
          'postId': 3,
          'postTitle': '원글 제목',
          'body': '내가 쓴 댓글',
          'likeCount': 1,
          'createdAt': '2026-08-26T21:00:00',
        },
      ],
      'nextCursor': 9,
    });

    expect(page.comments.first.postId, 3);
    expect(page.comments.first.postTitle, '원글 제목');
    expect(page.nextCursor, 9);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/model/community_my_activity_test.dart`
Expected: FAIL — 파일 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/model/community_my_activity.dart`:

```dart
import 'community_remote_post.dart';

/// 내 스크랩 한 건.
class CommunityScrapItem {
  const CommunityScrapItem({required this.scrapId, required this.post});

  final int scrapId;
  final CommunityRemotePost post;

  factory CommunityScrapItem.fromJson(Map<String, dynamic> json) {
    return CommunityScrapItem(
      scrapId: (json['scrapId'] as num?)?.toInt() ?? 0,
      post: CommunityRemotePost.fromJson(json['post'] as Map<String, dynamic>),
    );
  }
}

/// 내 스크랩 페이지 응답 (최신순, 커서 = scrapId).
class CommunityScrapPage {
  const CommunityScrapPage({required this.items, this.nextCursor});

  final List<CommunityScrapItem> items;
  final int? nextCursor;

  factory CommunityScrapPage.fromJson(Map<String, dynamic> json) {
    return CommunityScrapPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CommunityScrapItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}

/// 좋아요한 글 한 건.
class CommunityLikeItem {
  const CommunityLikeItem({required this.likeId, required this.post});

  final int likeId;
  final CommunityRemotePost post;

  factory CommunityLikeItem.fromJson(Map<String, dynamic> json) {
    return CommunityLikeItem(
      likeId: (json['likeId'] as num?)?.toInt() ?? 0,
      post: CommunityRemotePost.fromJson(json['post'] as Map<String, dynamic>),
    );
  }
}

/// 좋아요한 글 페이지 응답 (최신순, 커서 = likeId).
class CommunityLikePage {
  const CommunityLikePage({required this.items, this.nextCursor});

  final List<CommunityLikeItem> items;
  final int? nextCursor;

  factory CommunityLikePage.fromJson(Map<String, dynamic> json) {
    return CommunityLikePage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CommunityLikeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}

/// 내가 쓴 댓글 한 건. 원글이 삭제되면 목록에서 빠지므로 [postId]는
/// 항상 유효한 이동 대상이다.
class CommunityMyComment {
  const CommunityMyComment({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.body,
    required this.likeCount,
    required this.createdAt,
  });

  final int id;
  final int postId;
  final String postTitle;
  final String body;
  final int likeCount;
  final DateTime? createdAt;

  factory CommunityMyComment.fromJson(Map<String, dynamic> json) {
    return CommunityMyComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      postTitle: json['postTitle'] as String? ?? '',
      body: json['body'] as String? ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// 내가 쓴 댓글 페이지 응답 (최신순, 커서 = 댓글 id).
class CommunityMyCommentPage {
  const CommunityMyCommentPage({required this.comments, this.nextCursor});

  final List<CommunityMyComment> comments;
  final int? nextCursor;

  factory CommunityMyCommentPage.fromJson(Map<String, dynamic> json) {
    return CommunityMyCommentPage(
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map((e) => CommunityMyComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/model/community_my_activity_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/model/community_my_activity.dart test/model/community_my_activity_test.dart
git commit -m "feat: 내 활동 모델(CommunityScrapItem/CommunityLikeItem/CommunityMyComment) 추가"
```

---

## Task 8: `CommunityRepository` — 게시글 8종

**Files:**
- Create: `lib/repository/community/community_repository.dart`
- Test: `test/repository/community/community_repository_test.dart`

**Interfaces:**
- Consumes: `CommunityApiException`/`.fromResponse` (Task 1); `ApiConfig.communityPostsUrl/communityCreatePostUrl/communityPostUrl/communityPostViewUrl/communityPostLikeUrl/communityPostScrapUrl` (Task 2); `CommunityRemotePostPage`/`CommunityRemotePostDetail` (Task 4).
- Produces: `CommunityRepository.instance`, `fetchPosts({int? boardTeamId, String? cursor, int size = 20}) → Future<CommunityRemotePostPage>`, `fetchPostDetail(int postId) → Future<CommunityRemotePostDetail>`, `createPost({int? boardTeamId, required String title, required String body, List<String> imageUrls = const []}) → Future<int>`, `updatePost(int postId, {int? boardTeamId, required String title, required String body, List<String>? imageUrls}) → Future<void>`, `deletePost(int postId) → Future<void>`, `markPostViewed(int postId) → Future<void>`, `toggleLike(int postId) → Future<({bool liked, int likeCount})>`, `toggleScrap(int postId) → Future<bool>`. Task 9가 같은 클래스에 댓글 메서드를 이어 붙인다.

**구현 전 확인:** 스펙 문서 9번 섹션 — `boardViewer`가 목록 응답의 형제 키라는 가정을 `https://api.nar.kr/swagger-ui.html`로 확인한다. 다르면 `CommunityRemotePostPage.fromJson`(Task 4)만 조정하면 되고 이 Task의 나머지에는 영향 없다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/repository/community/community_repository_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_api_exception.dart';
import 'package:warding/repository/community/community_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityRepository.instance;

  void loginAs(String jwt) {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': jwt,
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  group('fetchPosts', () {
    test('토큰이 없으면 인증 헤더 없이 GET한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/mobile/community/posts');
          expect(request.headers['Authorization'], isNull);
          return http.Response('{"posts":[],"nextCursor":null}', 200);
        }),
      );

      final page = await repo.fetchPosts();

      expect(page.posts, isEmpty);
    });

    test('토큰이 있으면 Authorization 헤더와 boardTeamId 쿼리를 싣는다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-jwt');
          expect(request.url.query, contains('boardTeamId=39'));
          return http.Response('{"posts":[],"nextCursor":null}', 200);
        }),
      );

      await repo.fetchPosts(boardTeamId: 39);
    });

    test('실패 응답은 CommunityApiException을 던진다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          return http.Response(
            '{"code":"COMMUNITY_BOARD_FORBIDDEN","message":"권한이 없습니다."}',
            403,
          );
        }),
      );

      await expectLater(
        () => repo.fetchPosts(),
        throwsA(
          isA<CommunityApiException>().having(
            (e) => e.code,
            'code',
            'COMMUNITY_BOARD_FORBIDDEN',
          ),
        ),
      );
    });
  });

  test('fetchPostDetail은 상세를 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/community/posts/42');
        return http.Response(
          '{"id":42,"title":"제목","bodyPreview":"","author":null,'
          '"viewCount":0,"likeCount":0,"commentCount":0,"edited":false,'
          '"createdAt":"2026-08-26T21:00:00","body":"전문","images":[],'
          '"viewer":{"liked":false,"scrapped":false,"mine":false,"blockedAuthor":false}}',
          200,
        );
      }),
    );

    final detail = await repo.fetchPostDetail(42);

    expect(detail.id, 42);
    expect(detail.body, '전문');
  });

  group('createPost', () {
    test('작성 후 새 글 id를 반환한다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/community/posts');
          expect(request.body, contains('"title":"제목"'));
          return http.Response('{"id":43}', 200);
        }),
      );

      final id = await repo.createPost(title: '제목', body: '본문');

      expect(id, 43);
    });

    test('쿨다운 위반은 code와 retryAfterSeconds를 담아 던진다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          return http.Response(
            '{"code":"COMMUNITY_TEAM_COOLDOWN",'
            '"message":"응원팀을 바꾼 지 얼마 되지 않았습니다."}',
            403,
            headers: {'retry-after': '2592000'},
          );
        }),
      );

      await expectLater(
        () => repo.createPost(boardTeamId: 39, title: '제목', body: '본문'),
        throwsA(
          isA<CommunityApiException>()
              .having((e) => e.code, 'code', 'COMMUNITY_TEAM_COOLDOWN')
              .having(
                (e) => e.retryAfterSeconds,
                'retryAfterSeconds',
                2592000,
              ),
        ),
      );
    });
  });

  group('updatePost / deletePost / markPostViewed', () {
    setUp(() => loginAs('test-jwt'));

    test('imageUrls를 생략(null)하면 본문에 null로 실린다 — 이미지 변경 없음', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/mobile/community/posts/42');
          expect(request.body, contains('"imageUrls":null'));
          return http.Response('', 200);
        }),
      );

      await repo.updatePost(42, title: '수정', body: '수정 본문');
    });

    test('imageUrls에 빈 배열을 주면 전부 제거 요청이 실린다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.body, contains('"imageUrls":[]'));
          return http.Response('', 200);
        }),
      );

      await repo.updatePost(
        42,
        title: '수정',
        body: '수정 본문',
        imageUrls: const [],
      );
    });

    test('deletePost는 DELETE로 호출한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/mobile/community/posts/42');
          return http.Response('', 204);
        }),
      );

      await repo.deletePost(42);
    });

    test('markPostViewed는 인증 없이 POST한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/community/posts/42/view');
          expect(request.headers['Authorization'], isNull);
          return http.Response('', 204);
        }),
      );

      await repo.markPostViewed(42);
    });
  });

  group('toggleLike / toggleScrap', () {
    setUp(() => loginAs('test-jwt'));

    test('toggleLike는 서버 응답의 liked·likeCount를 그대로 반환한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/posts/42/like');
          return http.Response('{"liked":true,"likeCount":4}', 200);
        }),
      );

      final result = await repo.toggleLike(42);

      expect(result.liked, isTrue);
      expect(result.likeCount, 4);
    });

    test('toggleScrap은 scrapped를 반환한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/posts/42/scrap');
          return http.Response('{"scrapped":true}', 200);
        }),
      );

      final scrapped = await repo.toggleScrap(42);

      expect(scrapped, isTrue);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/repository/community/community_repository_test.dart`
Expected: FAIL — `community_repository.dart` 가 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/repository/community/community_repository.dart`:

```dart
import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_remote_post.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';
import 'community_api_exception.dart';

/// 커뮤니티 게시글·댓글 API (`/api/mobile/community/...`).
///
/// 조회(GET)는 비로그인도 허용한다 — 토큰이 있으면 [_optionalAuthGet]이
/// 자동으로 실어 보내 차단 필터·내 좋아요/스크랩 여부가 붙는다. 쓰기는 전부
/// [AuthService.authorizedRequest]로 인증을 강제한다.
class CommunityRepository {
  CommunityRepository._();
  static final CommunityRepository instance = CommunityRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _optionalAuthGet(String url) async {
    final token = await _auth.jwt;
    if (token == null || token.isEmpty) {
      return http.get(Uri.parse(url));
    }
    return _auth.authorizedRequest(
      (t) => http.get(Uri.parse(url), headers: _headers(t)),
    );
  }

  void _checkOk(http.Response response, String eventName) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = CommunityApiException.fromResponse(response);
      SentryLogger.warning(
        module: 'API',
        eventName: eventName,
        reason: 'status_${response.statusCode}',
        extra: {'statusCode': response.statusCode, 'code': exception.code},
      );
      throw exception;
    }
  }

  // ── 게시글 ───────────────────────────────────────────────────────

  /// 게시글 목록. [boardTeamId] 생략 = 전체 게시판.
  Future<CommunityRemotePostPage> fetchPosts({
    int? boardTeamId,
    String? cursor,
    int size = 20,
  }) async {
    final response = await _optionalAuthGet(
      ApiConfig.communityPostsUrl(
        boardTeamId: boardTeamId,
        cursor: cursor,
        size: size,
      ),
    );
    _checkOk(response, 'fetchCommunityPosts');
    return CommunityRemotePostPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 게시글 상세.
  Future<CommunityRemotePostDetail> fetchPostDetail(int postId) async {
    final response = await _optionalAuthGet(
      ApiConfig.communityPostUrl(postId),
    );
    _checkOk(response, 'fetchCommunityPostDetail');
    return CommunityRemotePostDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 게시글을 작성하고 새 글 id를 반환한다. [boardTeamId]가 null이면 전체
  /// 게시판(팀 게시판은 서버가 내 응원팀인지 재검사한다).
  Future<int> createPost({
    int? boardTeamId,
    required String title,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCreatePostUrl),
        headers: _headers(token),
        body: jsonEncode({
          'boardTeamId': boardTeamId,
          'title': title,
          'body': body,
          'imageUrls': imageUrls,
        }),
      ),
    );
    _checkOk(response, 'createCommunityPost');
    return ((jsonDecode(response.body) as Map<String, dynamic>)['id'] as num)
        .toInt();
  }

  /// 게시글을 수정한다(작성자만). [imageUrls]는 전체 교체 — null이면 이미지
  /// 변경 없음, `[]`이면 전부 제거.
  Future<void> updatePost(
    int postId, {
    int? boardTeamId,
    required String title,
    required String body,
    List<String>? imageUrls,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.communityPostUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({
          'boardTeamId': boardTeamId,
          'title': title,
          'body': body,
          'imageUrls': imageUrls,
        }),
      ),
    );
    _checkOk(response, 'updateCommunityPost');
  }

  /// 게시글을 삭제한다(작성자만, 소프트 삭제).
  Future<void> deletePost(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.communityPostUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'deleteCommunityPost');
  }

  /// 조회수 +1. 비로그인 포함, 중복 호출도 허용된다.
  Future<void> markPostViewed(int postId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.communityPostViewUrl(postId)),
    );
    _checkOk(response, 'viewCommunityPost');
  }

  /// 추천 토글. 더블탭해도 안전(멱등).
  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityPostLikeUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityPostLike');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      liked: data['liked'] as bool? ?? false,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// 스크랩 토글.
  Future<bool> toggleScrap(int postId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityPostScrapUrl(postId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityPostScrap');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['scrapped'] as bool? ?? false;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/repository/community/community_repository_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/repository/community/community_repository.dart test/repository/community/community_repository_test.dart
git commit -m "feat: CommunityRepository 게시글 8종 API 추가"
```

---

## Task 9: `CommunityRepository` — 댓글 4종 (이어붙이기)

**Files:**
- Modify: `lib/repository/community/community_repository.dart` (Task 8이 만든 클래스에 메서드 추가)
- Modify: `test/repository/community/community_repository_test.dart` (Task 8이 만든 파일에 그룹 추가)

**Interfaces:**
- Consumes: `ApiConfig.communityCommentsUrl/communityCreateCommentUrl/communityCommentUrl/communityCommentLikeUrl` (Task 2); `CommunityRemoteCommentPage`/`CommunityCommentStatus` (Task 5); `CommunityRepository`(Task 8, 같은 클래스에 메서드 추가).
- Produces: `fetchComments(int postId, {String? cursor, int size = 50}) → Future<CommunityRemoteCommentPage>`, `createComment(int postId, {required String body, int? replyToCommentId}) → Future<int>`, `deleteComment(int commentId) → Future<void>`, `toggleCommentLike(int commentId) → Future<({bool liked, int likeCount})>`.

**구현 전 확인:** 스펙 문서 9번 섹션 — 댓글 작성 응답이 글 작성과 같은 `{ "id": ... }` 형태라는 가정을 Swagger로 확인한다. 다르면 `createComment`의 반환 파싱 한 줄만 조정.

- [ ] **Step 1: 실패하는 테스트 추가**

`test/repository/community/community_repository_test.dart`의 import 목록에 댓글 모델을 추가:

```dart
import 'package:warding/model/community_remote_comment.dart';
```

파일 맨 끝, `main()` 함수의 마지막 `group('toggleLike / toggleScrap', ...)` 블록 다음(닫는 `}` `);` 뒤, `main()`을 닫는 `}` 앞)에 아래 그룹을 추가:

```dart

  group('comments', () {
    test('fetchComments는 오래된 순 페이지를 파싱한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/posts/42/comments');
          return http.Response(
            '{"comments":[{"id":9,"parentId":5,"body":"답글","status":"VISIBLE",'
            '"author":{"memberId":1,"nickname":"a"},"likeCount":1,"liked":false,'
            '"mine":false,"createdAt":"2026-08-26T21:00:00"}],"nextCursor":9}',
            200,
          );
        }),
      );

      final page = await repo.fetchComments(42);

      expect(page.comments, hasLength(1));
      expect(page.comments.first.status, CommunityCommentStatus.visible);
    });

    test('createComment는 replyToCommentId를 대상 댓글 id 그대로 보낸다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/community/posts/42/comments');
          expect(request.body, contains('"replyToCommentId":5'));
          return http.Response('{"id":10}', 200);
        }),
      );

      final id = await repo.createComment(
        42,
        body: '답글',
        replyToCommentId: 5,
      );

      expect(id, 10);
    });

    test('최상위 댓글이면 replyToCommentId를 보내지 않는다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.body, isNot(contains('replyToCommentId')));
          return http.Response('{"id":11}', 200);
        }),
      );

      await repo.createComment(42, body: '최상위 댓글');
    });

    test('deleteComment는 DELETE로 호출한다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/mobile/community/comments/9');
          return http.Response('', 204);
        }),
      );

      await repo.deleteComment(9);
    });

    test('toggleCommentLike는 liked·likeCount를 반환한다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/comments/9/like');
          return http.Response('{"liked":true,"likeCount":2}', 200);
        }),
      );

      final result = await repo.toggleCommentLike(9);

      expect(result.liked, isTrue);
      expect(result.likeCount, 2);
    });
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/repository/community/community_repository_test.dart`
Expected: FAIL — `fetchComments`/`createComment`/`deleteComment`/`toggleCommentLike` 메서드가 없어 컴파일 에러.

- [ ] **Step 3: 구현**

`lib/repository/community/community_repository.dart`의 import 목록에 댓글 모델을 추가:

```dart
import '../../model/community_remote_comment.dart';
```

(`import '../../model/community_remote_post.dart';` 다음 줄에)

클래스의 `toggleScrap` 메서드가 끝나는 지점(`}`)과 클래스를 닫는 마지막 `}` 사이에 아래 댓글 메서드 4개를 추가:

```dart

  // ── 댓글 ────────────────────────────────────────────────────────

  /// 댓글 목록(오래된 순). 1단 스레드 조립은 호출부(뷰모델) 몫이다.
  Future<CommunityRemoteCommentPage> fetchComments(
    int postId, {
    String? cursor,
    int size = 50,
  }) async {
    final response = await _optionalAuthGet(
      ApiConfig.communityCommentsUrl(postId, cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityComments');
    return CommunityRemoteCommentPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 댓글을 작성하고 새 댓글 id를 반환한다. 답글이면 [replyToCommentId]에
  /// **대상 댓글 id를 그대로** 넘긴다 — 답글의 답글이어도 마찬가지다. parent
  /// 올려붙이기와 멘션 대상은 서버가 계산하므로 앱이 parentId를 직접
  /// 계산하지 않는다.
  Future<int> createComment(
    int postId, {
    required String body,
    int? replyToCommentId,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCreateCommentUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({
          'body': body,
          if (replyToCommentId != null) 'replyToCommentId': replyToCommentId,
        }),
      ),
    );
    _checkOk(response, 'createCommunityComment');
    return ((jsonDecode(response.body) as Map<String, dynamic>)['id'] as num)
        .toInt();
  }

  /// 댓글을 삭제한다(작성자만, 소프트 삭제).
  Future<void> deleteComment(int commentId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.communityCommentUrl(commentId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'deleteCommunityComment');
  }

  /// 댓글 추천 토글.
  Future<({bool liked, int likeCount})> toggleCommentLike(
    int commentId,
  ) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityCommentLikeUrl(commentId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'toggleCommunityCommentLike');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      liked: data['liked'] as bool? ?? false,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    );
  }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/repository/community/community_repository_test.dart`
Expected: PASS (15 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/repository/community/community_repository.dart test/repository/community/community_repository_test.dart
git commit -m "feat: CommunityRepository 댓글 4종 API 추가"
```

---

## Task 10: `CommunityReportRepository`

**Files:**
- Create: `lib/repository/community/community_report_repository.dart`
- Test: `test/repository/community/community_report_repository_test.dart`

**Interfaces:**
- Consumes: `CommunityApiException` (Task 1); `ApiConfig.communityReportsUrl/communityBlocksUrl/communityBlockUrl` (Task 2); `CommunityReportTargetType`/`CommunityReportReason` (Task 6).
- Produces: `CommunityReportRepository.instance`, `report({required CommunityReportTargetType targetType, required int targetId, required CommunityReportReason reason, String? detail}) → Future<void>`, `block(int memberId) → Future<void>`, `unblock(int memberId) → Future<void>`.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/repository/community/community_report_repository_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/model/community_report.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_api_exception.dart';
import 'package:warding/repository/community/community_report_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityReportRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('report는 targetType·reason을 API 문자열로 보낸다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/community/reports');
        expect(request.body, contains('"targetType":"IMAGE"'));
        expect(request.body, contains('"reason":"ETC"'));
        expect(request.body, contains('"detail":"기타 사유"'));
        return http.Response('', 204);
      }),
    );

    await repo.report(
      targetType: CommunityReportTargetType.image,
      targetId: 3,
      reason: CommunityReportReason.etc,
      detail: '기타 사유',
    );
  });

  test('중복 신고는 409 CommunityApiException을 던진다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        return http.Response(
          '{"code":"COMMUNITY_ALREADY_REPORTED","message":"이미 신고했습니다."}',
          409,
        );
      }),
    );

    await expectLater(
      () => repo.report(
        targetType: CommunityReportTargetType.post,
        targetId: 42,
        reason: CommunityReportReason.spam,
      ),
      throwsA(
        isA<CommunityApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });

  test('block은 POST /blocks에 memberId를 보낸다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/mobile/community/blocks');
        expect(request.body, contains('"memberId":7'));
        return http.Response('', 204);
      }),
    );

    await repo.block(7);
  });

  test('unblock은 DELETE /blocks/{memberId}로 호출한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/mobile/community/blocks/7');
        return http.Response('', 204);
      }),
    );

    await repo.unblock(7);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/repository/community/community_report_repository_test.dart`
Expected: FAIL — `community_report_repository.dart` 가 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/repository/community/community_report_repository.dart`:

```dart
import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_report.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';
import 'community_api_exception.dart';

/// 커뮤니티 신고·차단 API (`/api/mobile/community/reports`, `/blocks`).
/// 전부 인증이 필요하다.
class CommunityReportRepository {
  CommunityReportRepository._();
  static final CommunityReportRepository instance =
      CommunityReportRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  void _checkOk(http.Response response, String eventName) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = CommunityApiException.fromResponse(response);
      SentryLogger.warning(
        module: 'API',
        eventName: eventName,
        reason: 'status_${response.statusCode}',
        extra: {'statusCode': response.statusCode, 'code': exception.code},
      );
      throw exception;
    }
  }

  /// 글·댓글·이미지를 신고한다. 같은 대상 재신고는 409
  /// ([CommunityApiException.statusCode]) — "이미 신고했습니다" 처리는
  /// 호출부 몫. [reason]이 [CommunityReportReason.etc]면 [detail](≤200자) 필수.
  Future<void> report({
    required CommunityReportTargetType targetType,
    required int targetId,
    required CommunityReportReason reason,
    String? detail,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityReportsUrl),
        headers: _headers(token),
        body: jsonEncode({
          'targetType': targetType.apiValue,
          'targetId': targetId,
          'reason': reason.apiValue,
          'detail': detail,
        }),
      ),
    );
    _checkOk(response, 'reportCommunityTarget');
  }

  /// 사용자를 차단한다. 이미 차단했어도 204(멱등). 자기 자신은 400.
  Future<void> block(int memberId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityBlocksUrl),
        headers: _headers(token),
        body: jsonEncode({'memberId': memberId}),
      ),
    );
    _checkOk(response, 'blockCommunityMember');
  }

  /// 차단을 해제한다(멱등).
  Future<void> unblock(int memberId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.communityBlockUrl(memberId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'unblockCommunityMember');
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/repository/community/community_report_repository_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/repository/community/community_report_repository.dart test/repository/community/community_report_repository_test.dart
git commit -m "feat: CommunityReportRepository(신고·차단) 추가"
```

---

## Task 11: `CommunityActivityRepository`

**Files:**
- Create: `lib/repository/community/community_activity_repository.dart`
- Test: `test/repository/community/community_activity_repository_test.dart`

**Interfaces:**
- Consumes: `CommunityApiException` (Task 1); `ApiConfig.meCommunityScrapsUrl/meCommunityPostsUrl/meCommunityLikesUrl/meCommunityCommentsUrl` (Task 2); `CommunityRemotePostPage` (Task 4); `CommunityScrapPage`/`CommunityLikePage`/`CommunityMyCommentPage` (Task 7).
- Produces: `CommunityActivityRepository.instance`, `fetchScraps({String? cursor, int size = 20}) → Future<CommunityScrapPage>`, `fetchMyPosts({String? cursor, int size = 20}) → Future<CommunityRemotePostPage>`, `fetchMyLikes({String? cursor, int size = 20}) → Future<CommunityLikePage>`, `fetchMyComments({String? cursor, int size = 20}) → Future<CommunityMyCommentPage>`.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/repository/community/community_activity_repository_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_activity_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityActivityRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('fetchScraps는 scrapId 커서 페이지를 파싱하고 Authorization을 싣는다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/scraps');
        expect(request.headers['Authorization'], 'Bearer test-jwt');
        return http.Response(
          '{"items":[{"scrapId":12,"post":{"id":42,"title":"제목",'
          '"bodyPreview":"","author":null,"viewCount":0,"likeCount":0,'
          '"commentCount":0,"edited":false,"createdAt":"2026-08-26T21:00:00"}}],'
          '"nextCursor":12}',
          200,
        );
      }),
    );

    final page = await repo.fetchScraps();

    expect(page.items, hasLength(1));
    expect(page.items.first.scrapId, 12);
    expect(page.items.first.post.id, 42);
  });

  test('fetchMyPosts는 게시글 페이지 형태로 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/posts');
        return http.Response('{"posts":[],"nextCursor":null}', 200);
      }),
    );

    final page = await repo.fetchMyPosts();

    expect(page.posts, isEmpty);
  });

  test('fetchMyLikes는 likeId 커서 페이지를 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/likes');
        return http.Response(
          '{"items":[{"likeId":7,"post":{"id":1,"title":"","bodyPreview":"",'
          '"author":null,"viewCount":0,"likeCount":0,"commentCount":0,'
          '"edited":false,"createdAt":"2026-08-26T21:00:00"}}],"nextCursor":7}',
          200,
        );
      }),
    );

    final page = await repo.fetchMyLikes();

    expect(page.items.first.likeId, 7);
  });

  test('fetchMyComments는 postId·postTitle을 포함해 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/comments');
        return http.Response(
          '{"comments":[{"id":9,"postId":3,"postTitle":"원글 제목","body":"...",'
          '"likeCount":1,"createdAt":"2026-08-26T21:00:00"}],"nextCursor":9}',
          200,
        );
      }),
    );

    final page = await repo.fetchMyComments();

    expect(page.comments.first.postId, 3);
    expect(page.comments.first.postTitle, '원글 제목');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/repository/community/community_activity_repository_test.dart`
Expected: FAIL — `community_activity_repository.dart` 가 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/repository/community/community_activity_repository.dart`:

```dart
import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_my_activity.dart';
import '../../model/community_remote_post.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';
import 'community_api_exception.dart';

/// 마이페이지 "내 활동" API (`/api/mobile/me/community/...`). 전부 인증
/// 필수이고, 삭제·블라인드된 항목은 서버가 이미 걸러서 내려준다.
class CommunityActivityRepository {
  CommunityActivityRepository._();
  static final CommunityActivityRepository instance =
      CommunityActivityRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _get(String url) => _auth.authorizedRequest(
    (token) => http.get(Uri.parse(url), headers: _headers(token)),
  );

  void _checkOk(http.Response response, String eventName) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = CommunityApiException.fromResponse(response);
      SentryLogger.warning(
        module: 'API',
        eventName: eventName,
        reason: 'status_${response.statusCode}',
        extra: {'statusCode': response.statusCode, 'code': exception.code},
      );
      throw exception;
    }
  }

  /// 내 스크랩 목록 (최신순, 커서 = scrapId).
  Future<CommunityScrapPage> fetchScraps({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityScrapsUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityScraps');
    return CommunityScrapPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 내가 쓴 글 목록 (전체·팀 게시판 섞여서, 최신순).
  Future<CommunityRemotePostPage> fetchMyPosts({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityPostsUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityMyPosts');
    return CommunityRemotePostPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 좋아요한 글 목록 (최신순, 커서 = likeId).
  Future<CommunityLikePage> fetchMyLikes({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityLikesUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityMyLikes');
    return CommunityLikePage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 내가 쓴 댓글 목록 (최신순, 커서 = 댓글 id). 원글이 삭제된 댓글은 빠진다.
  Future<CommunityMyCommentPage> fetchMyComments({
    String? cursor,
    int size = 20,
  }) async {
    final response = await _get(
      ApiConfig.meCommunityCommentsUrl(cursor: cursor, size: size),
    );
    _checkOk(response, 'fetchCommunityMyComments');
    return CommunityMyCommentPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/repository/community/community_activity_repository_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/repository/community/community_activity_repository.dart test/repository/community/community_activity_repository_test.dart
git commit -m "feat: CommunityActivityRepository(내 활동 4종) 추가"
```

---

## Task 12: `CommunityImageRepository`

**Files:**
- Create: `lib/repository/community/community_image_repository.dart`
- Test: `test/repository/community/community_image_repository_test.dart`

**Interfaces:**
- Consumes: `ApiConfig.communityImageSignatureUrl` (Task 2).
- Produces: `CommunityImageRepository.instance`, `CommunityImageRepository({AuthService? auth})`, `upload(File file) → Future<String>`(secure_url).

`ProfileImageRepository`(`lib/repository/profile/profile_image_repository.dart`)와 동일한 흐름(서명 발급 → Cloudinary multipart 업로드 → `secure_url`)을 별도 클래스로 둔다. Cloudinary 업로드 leg(`request.send()`)는 `package:http`의 `BaseRequest.send()`가 내부에서 매번 새 `Client()`를 만들어 쓰므로(`http-1.6.0/lib/src/base_request.dart:141`) `setApiClientForTesting`으로 가로챌 수 없다 — `ProfileImageRepository`도 같은 이유로 테스트가 없다. 그래서 이 Task는 가로챌 수 있는 서명 발급 단계까지만 단위 테스트한다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `test/repository/community/community_image_repository_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_image_repository.dart';
import 'package:warding/util/api_client.dart' as api;

// Cloudinary 업로드 leg(`request.send()`)는 `BaseRequest.send()`가 내부에서
// 매번 새 `Client()`를 만들어 쓰므로(package:http 1.6.0, base_request.dart:141)
// `setApiClientForTesting`으로 가로챌 수 없다. `ProfileImageRepository`와
// 같은 제약이라 여기서도 서명 발급 단계까지만 단위 테스트한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityImageRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('서명 발급이 실패하면 예외를 던진다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, contains('community-image/signature'));
        expect(request.headers['Authorization'], 'Bearer test-jwt');
        return http.Response('{"message":"서명 발급 실패"}', 500);
      }),
    );

    await expectLater(
      () => repo.upload(File('/nonexistent/path.png')),
      throwsA(isA<Exception>()),
    );
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/repository/community/community_image_repository_test.dart`
Expected: FAIL — `community_image_repository.dart` 가 없어 컴파일 에러.

- [ ] **Step 3: 구현**

Create `lib/repository/community/community_image_repository.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 커뮤니티 사진 업로드 — 백엔드에서 Cloudinary 서명 파라미터를 발급받아
/// 앱이 Cloudinary로 직접 업로드하고, 받은 `secure_url`을 돌려준다. 이미지
/// 1장 = 서명 1회([ProfileImageRepository]와 달리 `publicId`가 매번 새로
/// 발급된다).
///
/// 흐름: `POST /api/auth/me/community-image/signature`(인증) → Cloudinary
/// `image/upload`(multipart) → `secure_url`. 받은 URL들을 모아 글 작성/수정
/// API의 `imageUrls`로 보낸다.
class CommunityImageRepository {
  CommunityImageRepository({AuthService? auth})
    : _auth = auth ?? AuthService.instance;

  static final CommunityImageRepository instance = CommunityImageRepository();

  final AuthService _auth;

  /// [file]을 Cloudinary에 업로드하고 `secure_url`을 반환한다.
  Future<String> upload(File file) async {
    final sig = await _fetchSignature();
    return _uploadToCloudinary(sig, file);
  }

  Future<_CommunityImageSignature> _fetchSignature() async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityImageSignatureUrl),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'communityImageSignature',
        reason: 'status_${response.statusCode}',
        extra: {
          'endpoint': ApiConfig.communityImageSignatureUrl,
          'statusCode': response.statusCode,
        },
      );
      throw Exception('커뮤니티 사진 서명 발급 실패 (${response.statusCode})');
    }
    return _CommunityImageSignature.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> _uploadToCloudinary(
    _CommunityImageSignature sig,
    File file,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(sig.uploadUrl))
      ..fields['api_key'] = sig.apiKey
      ..fields['timestamp'] = sig.timestamp.toString()
      ..fields['public_id'] = sig.publicId
      ..fields['overwrite'] = sig.overwrite.toString()
      ..fields['signature'] = sig.signature
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    debugPrint('[CommunityImage] uploading → ${sig.publicId}');
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'communityImageUpload',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': sig.uploadUrl, 'statusCode': response.statusCode},
      );
      throw Exception(
        'Cloudinary 업로드 실패 (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      SentryLogger.error(
        module: 'Logic',
        eventName: 'communityImageUpload',
        reason: 'missing_secure_url',
        extra: {'publicId': sig.publicId},
      );
      throw Exception('Cloudinary 응답에 secure_url이 없습니다: ${response.body}');
    }
    debugPrint('[CommunityImage] uploaded ✓ $url');
    return url;
  }
}

/// `POST /api/auth/me/community-image/signature` 응답.
class _CommunityImageSignature {
  const _CommunityImageSignature({
    required this.uploadUrl,
    required this.apiKey,
    required this.timestamp,
    required this.publicId,
    required this.overwrite,
    required this.signature,
  });

  final String uploadUrl;
  final String apiKey;
  final int timestamp;
  final String publicId;
  final bool overwrite;
  final String signature;

  factory _CommunityImageSignature.fromJson(Map<String, dynamic> json) {
    return _CommunityImageSignature(
      uploadUrl: json['uploadUrl'] as String,
      apiKey: json['apiKey'] as String,
      timestamp: json['timestamp'] as int,
      publicId: json['publicId'] as String,
      overwrite: json['overwrite'] as bool? ?? false,
      signature: json['signature'] as String,
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/repository/community/community_image_repository_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: 전체 회귀 확인 + 커밋**

Run: `flutter analyze` (전체) — 이번 단계에서 만든 파일 전부 대상. `community_dummy.dart`·기존 커뮤니티 화면은 손대지 않았으므로 기존 이슈 외 새 이슈가 없어야 한다.
Run: `flutter test test/model test/repository/community` — 이번 단계에서 만든 모델·Repository 테스트 전체 통과.

```bash
git add lib/repository/community/community_image_repository.dart test/repository/community/community_image_repository_test.dart
git commit -m "feat: CommunityImageRepository(사진 서명 업로드) 추가"
```

---

## 완료 기준

- [ ] `lib/model/community_author.dart`, `community_post_image.dart`, `community_remote_post.dart`, `community_remote_comment.dart`, `community_report.dart`, `community_my_activity.dart` 존재하고 각각 `fromJson` 테스트 통과.
- [ ] `lib/repository/community/` 아래 4개 Repository(`community_repository.dart`, `community_report_repository.dart`, `community_activity_repository.dart`, `community_image_repository.dart`) + `community_api_exception.dart` 존재.
- [ ] 커뮤니티 API 20개 전부 Repository 메서드로 호출 가능 (게시글 8·댓글 4·신고차단 3·내활동 4·사진서명 1).
- [ ] `ApiConfig`에 커뮤니티 URL 빌더 추가, 기존 빌더 스타일과 동일.
- [ ] `flutter test`로 이번 단계 테스트 전체(모델 6개 + Repository 5개 파일) 통과.
- [ ] `flutter analyze` — 새로 만든/수정한 파일에 이슈 없음.
- [ ] `community_dummy.dart`와 이를 쓰는 화면들은 수정하지 않았고, 지금도 그대로 컴파일된다 (`flutter analyze lib/screens/community`로 확인).
