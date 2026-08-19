import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/util/api_client.dart' as api;

/// 캘린더 상단 띠배너 공지 조회의 캐시 동작.
///
/// 배너는 캘린더 위에 얹혀 있어서, 늦게 도착하면 그 순간 목록에 끼어들어
/// 캘린더를 아래로 밀고 높이까지 줄인다(화면이 한 번 출렁인다). 그래서
/// 스플래시가 미리 받아 두고 일정 화면이 그 결과를 그대로 쓰는 구조인데,
/// 그게 성립하려면 두 번째 조회가 네트워크를 다시 치지 않아야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = NoticeRepository.instance;

  /// 배너 엔드포인트가 받은 요청 수 — 캐시가 먹었는지 세는 기준.
  var hits = 0;

  String bannerBody(List<({int id, String title})> notices) => jsonEncode([
        for (final n in notices)
          {
            'id': n.id,
            'title': n.title,
            'content': '',
            'pinned': false,
            'publishedAt': '2026-08-19T10:00:00',
          },
      ]);

  /// 배너 조회에 [body] 로 답하는 클라이언트를 깐다.
  void mockBanner(String body, {int status = 200}) {
    api.setApiClientForTesting(MockClient((request) async {
      if (!request.url.path.contains('notice')) {
        fail('예상 밖 요청: ${request.url}');
      }
      hits++;
      return http.Response(body, status, headers: {
        'content-type': 'application/json; charset=utf-8',
      });
    }));
  }

  setUp(() {
    hits = 0;
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    // instance 는 이 파일의 모든 테스트가 공유하는 싱글턴이다.
    repo.resetPromotedCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('두 번째 조회는 캐시를 쓴다 — 스플래시 프리페치가 헛돌지 않도록', () async {
    mockBanner(bannerBody([(id: 1, title: '점검 안내')]));

    final first = await repo.fetchPromoted();
    final second = await repo.fetchPromoted();

    expect(first.single.title, '점검 안내');
    expect(second.single.title, '점검 안내');
    expect(hits, 1, reason: '같은 조회를 두 번 하면 네트워크는 한 번만 탄다');
  });

  test('동시에 부르면 한 요청에 합류한다', () async {
    mockBanner(bannerBody([(id: 1, title: '점검 안내')]));

    // 스플래시 프리페치와 일정 화면 진입이 겹치는 상황.
    final results = await Future.wait([
      repo.fetchPromoted(),
      repo.fetchPromoted(),
    ]);

    expect(results[0].single.id, 1);
    expect(results[1].single.id, 1);
    expect(hits, 1);
  });

  test('cachedPromoted: 받기 전엔 null, 받은 뒤엔 동기로 준다', () async {
    mockBanner(bannerBody([(id: 7, title: '업데이트')]));

    // 일정 화면이 첫 프레임에 배너 유무를 정하는 근거다.
    expect(repo.cachedPromoted, isNull);

    await repo.fetchPromoted();

    expect(repo.cachedPromoted?.single.id, 7);
  });

  test('빈 목록도 캐시한다 — 공지가 없다는 사실도 첫 프레임에 알아야 한다', () async {
    mockBanner('[]');

    await repo.fetchPromoted();

    expect(repo.cachedPromoted, isEmpty);
    await repo.fetchPromoted();
    expect(hits, 1);
  });

  test('forceRefresh 는 캐시를 건너뛴다', () async {
    mockBanner(bannerBody([(id: 1, title: '이전')]));
    await repo.fetchPromoted();

    mockBanner(bannerBody([(id: 2, title: '새 공지')]));
    final refreshed = await repo.fetchPromoted(forceRefresh: true);

    expect(refreshed.single.title, '새 공지');
    expect(hits, 2, reason: '캐시가 있어도 새로 받아야 하므로 왕복이 한 번 더 든다');
    // 새로 받은 값이 캐시도 덮어써, 이어지는 조회는 갱신본을 본다.
    expect(repo.cachedPromoted?.single.title, '새 공지');
  });

  test('실패한 요청은 캐시에 남지 않는다 — 다음 조회가 다시 시도한다', () async {
    mockBanner('', status: 500);

    await expectLater(repo.fetchPromoted(), throwsA(isA<Exception>()));
    expect(repo.cachedPromoted, isNull);

    mockBanner(bannerBody([(id: 3, title: '복구됨')]));
    final retried = await repo.fetchPromoted();

    expect(retried.single.title, '복구됨');
  });
}
