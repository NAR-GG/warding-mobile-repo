import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

import 'package:warding/model/home_models.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/repository/subscription/subscription_repository.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/home/home_viewmodel.dart';

class _FakeSolo implements SoloRankSource {
  _FakeSolo(this.snap);
  final SoloRankSnapshot snap;
  @override
  Future<SoloRankSnapshot> fetch() async => snap;
}

class _MockSchedule extends Mock implements ScheduleRepository {}

/// 부를 때마다 [pending] 의 다음 Completer 를 기다리는 솔랭 소스 —
/// 응답 순서를 테스트가 정한다.
class _GatedSolo implements SoloRankSource {
  final List<Completer<SoloRankSnapshot>> pending = [];
  @override
  Future<SoloRankSnapshot> fetch() {
    final c = Completer<SoloRankSnapshot>();
    pending.add(c);
    return c.future;
  }
}

class _SwitchableReviews implements ReviewSource {
  _SwitchableReviews(this.items);
  List<HomeReviewItem> items;
  @override
  Future<List<HomeReviewItem>> fetchRecent() async => items;
}

HomeLiveSoloPlayer live(String name, int elapsed) => HomeLiveSoloPlayer(
  name: name,
  teamCode: 'T1',
  champion: '아리',
  elapsedSeconds: elapsed,
);

HomeFinishedSoloPlayer done(String name, int minutesAgo) =>
    HomeFinishedSoloPlayer(
      name: name,
      teamCode: 'T1',
      won: true,
      minutesAgo: minutesAgo,
    );

/// 홈이 부르는 API 응답을 한곳에서 갈아끼우는 테스트용 서버.
///
/// 경로별로 응답을 돌려주고, 모르는 경로는 500 과 함께 [unknown] 에 남긴다 —
/// 뷰모델이 예상 밖의 API 를 부르면 테스트가 바로 드러내도록.
class _FakeApi {
  /// 오늘 경기 응답(`matches` 배열). null 이면 500.
  ///
  /// [ScheduleRepository] 는 진행 중 경기가 없는 응답을 30초 캐시하고 테스트용
  /// 초기화 훅이 없다. 테스트끼리 캐시가 새지 않게 기본값을 진행 중 경기로 둔다
  /// (진행 중 경기가 섞인 응답은 캐시하지 않는다).
  List<Map<String, dynamic>>? schedule = [_match('m1', 'inProgress')];

  /// 커뮤니티 글 응답. 요청된 sort 값을 제목에 박아 돌려준다.
  bool communityFails = false;

  /// 쇼츠 응답(`content` 배열).
  List<Map<String, dynamic>> shorts = const [];

  /// 구독 선수 응답. null 이면 500.
  List<Map<String, dynamic>>? subscriptions = const [];

  /// 알림함 미읽음 수(커뮤니티 묶음). null 이면 500.
  int? unreadNotifications = 0;

  final List<Uri> requests = [];
  final List<Uri> unknown = [];

  List<Uri> requestsTo(String pathPart) =>
      requests.where((u) => u.path.contains(pathPart)).toList();

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  MockClient get client => MockClient((request) async {
    final url = request.url;
    requests.add(url);
    final path = url.path;
    if (path.contains('notices')) return _json(const []);
    if (path.contains('schedule')) {
      final s = schedule;
      return s == null
          ? _json({'message': 'fail'}, 500)
          : _json({'matches': s});
    }
    if (path.contains('standings')) {
      return _json({
        'league': url.queryParameters['league'],
        'supported': true,
        'scopeLabel': '정규시즌',
        'groups': [
          {
            'name': '레전드 그룹',
            'rows': [
              {
                'rank': 1,
                'teamCode': 'GEN',
                'teamName': '젠지',
                'wins': 19,
                'losses': 7,
                'setDiff': 22,
              },
            ],
          },
        ],
      });
    }
    if (path.contains('community/posts')) {
      if (communityFails) return _json({'message': 'fail'}, 500);
      final sort = url.queryParameters['sort'];
      return _json({
        'posts': [
          {
            'id': 1,
            'title': '글-$sort',
            'bodyPreview': '',
            'viewCount': 0,
            'likeCount': 0,
            'commentCount': 0,
            'edited': false,
          },
        ],
      });
    }
    if (path.contains('story/videos')) return _json({'content': shorts});
    if (path.contains('player-subscriptions')) {
      final s = subscriptions;
      return s == null ? _json({'message': 'fail'}, 500) : _json(s);
    }
    if (path.contains('me/notifications')) {
      final n = unreadNotifications;
      return n == null
          ? _json({'message': 'fail'}, 500)
          : _json({'notifications': const [], 'unreadCount': n});
    }
    unknown.add(url);
    return _json({'message': 'unexpected $url'}, 500);
  });
}

Map<String, dynamic> _match(String id, String status) => {
  'matchId': id,
  'scheduledTime': '18:00',
  'leagueName': 'LCK',
  'matchTitle': '정규시즌',
  'matchStatus': status,
  'isSynced': true,
  'blueTeam': {'teamName': 'T1', 'teamCode': 'T1', 'teamImageUrl': ''},
  'redTeam': {'teamName': 'Gen.G', 'teamCode': 'GEN', 'teamImageUrl': ''},
};

Map<String, dynamic> _sub(String name, String teamCode, String teamName) => {
  'playerId': name.hashCode,
  'playerName': name,
  'playerImageUrl': '',
  'role': 'MID',
  'teamId': teamCode.hashCode,
  'teamCode': teamCode,
  'teamName': teamName,
  'teamImageUrl': '',
  'subscribed': true,
};

Map<String, dynamic> _video(
  String title, {
  String channel = '',
  int views = 0,
}) => {
  'videoId': title.hashCode,
  'youtubeVideoId': 'yt',
  'title': title,
  'videoUrl': '',
  'thumbnailUrl': '',
  'channelName': channel,
  'viewCount': views,
};

const _emptySolo = SoloRankSnapshot(live: [], finished: [], subscribedTotal: 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi server;

  /// [loggedIn] 이면 JWT 를 심어 구독 선수 API 가 실제로 불리게 한다.
  void setUpServer({bool loggedIn = false}) {
    FlutterSecureStorage.setMockInitialValues(
      loggedIn ? {'jwt': 'test-jwt'} : {},
    );
    AuthService.instance.resetJwtCacheForTesting();
    api.setApiClientForTesting(server.client);
  }

  /// [subscribed] 를 주면 로그인 상태로 그 수만큼의 구독 선수를 돌려준다 —
  /// 구독 수는 실제 구독 목록 길이로만 센다(비회원·조회 실패는 0명).
  HomeViewModel build({
    SoloRankSnapshot snap = _emptySolo,
    int? subscribed,
    ReviewSource reviews = const MockReviewSource(),
    NewsSource news = const MockNewsSource(),
  }) {
    if (subscribed != null) {
      server.subscriptions = [
        for (var i = 0; i < subscribed; i++) _sub('Sub$i', 'T1', 'T1'),
      ];
      setUpServer(loggedIn: true);
    }
    final vm = HomeViewModel(
      soloRank: _FakeSolo(snap),
      reviews: reviews,
      news: news,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  setUp(() {
    server = _FakeApi();
    NoticeRepository.instance.resetPromotedCacheForTesting();
    NoticePreferenceRepository.instance.resetCacheForTesting();
    SubscriptionRepository.instance.resetCacheForTesting();
    setUpServer();
  });

  tearDown(() {
    expect(server.unknown, isEmpty, reason: '예상 밖의 API 호출');
    api.setApiClientForTesting(null);
  });

  group('솔랭 카드', () {
    test('구독 0명이면 noSubscription', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.subscribedTotal, 0);
      expect(vm.soloState, SoloCardState.noSubscription);
    });

    test('구독은 있는데 진행 중이 0명이면 noneActive', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: const [],
          finished: [done('Oner', 10)],
          subscribedTotal: 0,
        ),
        subscribed: 5,
      );
      await pumpEventQueue();
      expect(vm.soloState, SoloCardState.noneActive);
      expect(vm.soloLive, isEmpty);
      expect(vm.soloFinished.map((p) => p.name), ['Oner']);
      expect(vm.soloHiddenCount, 4);
    });

    test('진행 중이 있으면 active, 가장 최근 시작(경과 시간 짧은) 선수가 먼저', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('A', 900), live('B', 100), live('C', 500)],
          finished: const [],
          subscribedTotal: 0,
        ),
        subscribed: 3,
      );
      await pumpEventQueue();
      expect(vm.soloState, SoloCardState.active);
      expect(vm.soloLive.map((p) => p.name), ['B', 'C', 'A']);
    });

    test('핀 고정 선수가 최근 시작 순서보다 먼저', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('A', 900), live('B', 100), live('C', 500)],
          finished: const [],
          subscribedTotal: 0,
        ),
        subscribed: 3,
      );
      await pumpEventQueue();

      var notified = 0;
      vm.addListener(() => notified++);
      vm.togglePin('A');

      expect(vm.pinnedPlayerNames, {'A'});
      expect(vm.soloLive.map((p) => p.name), ['A', 'B', 'C']);
      expect(notified, 1);

      vm.togglePin('A');
      expect(vm.pinnedPlayerNames, isEmpty);
      expect(vm.soloLive.first.name, 'B');
    });

    test('끝난 경기는 선수당 1건, 최대 8명, 나머지는 soloHiddenCount', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('L', 60)],
          finished: [
            done('P0', 50),
            done('P0', 5), // 같은 선수의 더 최근 판 — 이 건만 남아야 한다.
            for (var i = 1; i <= 9; i++) done('P$i', 10 + i),
          ],
          subscribedTotal: 0,
        ),
        subscribed: 20,
      );
      await pumpEventQueue();

      final names = vm.soloFinished.map((p) => p.name).toList();
      expect(names.length, 8);
      expect(names.toSet().length, 8, reason: '같은 선수가 두 번 나오면 안 된다');
      expect(names.first, 'P0');
      expect(vm.soloFinished.first.minutesAgo, 5);
      expect(names, ['P0', 'P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7']);
      expect(vm.soloHiddenCount, 20 - 1 - 8);
    });

    test('지금 진행 중인 선수는 끝난 경기 줄에서 빠지고 숨김 수도 두 번 세지 않는다', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          // A 는 오늘 1판을 끝내고 지금 2판째를 하는 중이다.
          live: [live('A', 60)],
          finished: [done('A', 3), done('B', 10)],
          subscribedTotal: 0,
        ),
        subscribed: 10,
      );
      await pumpEventQueue();

      expect(vm.soloLive.map((p) => p.name), ['A']);
      expect(vm.soloFinished.map((p) => p.name), ['B']);
      expect(vm.soloHiddenCount, 10 - 1 - 1);
    });

    test('숨김 수는 음수가 되지 않는다', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('A', 60), live('B', 30)],
          finished: [done('C', 3)],
          subscribedTotal: 0,
        ),
        subscribed: 1,
      );
      await pumpEventQueue();
      expect(vm.soloHiddenCount, 0);
    });

    test('로그인 상태면 구독 수는 소스 값이 아니라 실제 구독 목록 길이', () async {
      server.subscriptions = [
        _sub('Faker', 'T1', 'T1'),
        _sub('Chovy', 'GEN', 'Gen.G'),
      ];
      setUpServer(loggedIn: true);
      final vm = build(
        snap: const SoloRankSnapshot(
          live: [],
          finished: [],
          subscribedTotal: 27,
        ),
      );
      await pumpEventQueue();
      expect(vm.subscribedTotal, 2);
      expect(server.requestsTo('player-subscriptions'), isNotEmpty);
    });

    test('비회원은 솔랭 소스가 몇 명을 주든 구독 0명 — noSubscription', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('Faker', 60)],
          finished: [done('Oner', 10)],
          subscribedTotal: 27,
        ),
      );
      await pumpEventQueue();
      expect(vm.subscribedTotal, 0);
      expect(vm.soloState, SoloCardState.noSubscription);
      expect(vm.soloHiddenCount, 0);
    });

    test('구독 목록 조회가 실패해도 소스의 구독 수로 대신하지 않는다', () async {
      server.subscriptions = null;
      setUpServer(loggedIn: true);
      final vm = build(
        snap: const SoloRankSnapshot(
          live: [],
          finished: [],
          subscribedTotal: 27,
        ),
      );
      await pumpEventQueue();
      expect(vm.subscribedTotal, 0);
      expect(vm.soloState, SoloCardState.noSubscription);
    });
  });

  group('오늘 경기', () {
    test('모든 리그의 오늘 경기를 받아 진행 중인 경기를 앞으로 둔다', () async {
      server.schedule = [
        _match('done', 'completed'),
        _match('soon', 'unstarted'),
        _match('now', 'inProgress'),
      ];
      final vm = build();
      await pumpEventQueue();

      expect(vm.todayMatchesSorted.map((m) => m.matchId), [
        'now',
        'done',
        'soon',
      ]);
      final req = server.requestsTo('schedule').single;
      expect(req.queryParametersAll['league'], isNot(['LCK']));
      expect(req.queryParametersAll['league']!.length, greaterThan(1));
    });

    test('일정 조회가 실패해도 마지막 값을 유지하고 다른 섹션은 정상', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.todayMatchesSorted.map((m) => m.matchId), ['m1']);

      server.schedule = null;
      await vm.loadTodayMatches();

      expect(vm.todayMatchesSorted.map((m) => m.matchId), ['m1']);
      expect(vm.standings?.groups.single.rows.single.teamCode, 'GEN');
      expect(vm.communityPosts, isNotEmpty);
    });
  });

  group('순위표', () {
    test('LCK 만 live 칩이고 나머지 리그는 선택되지 않는다', () async {
      final vm = build();
      await pumpEventQueue();

      expect(vm.leagueChips.map((c) => c.code), [
        'LCK',
        'LPL',
        'LEC',
        'LCS',
        '월즈',
      ]);
      expect(vm.leagueChips.where((c) => c.live).map((c) => c.code), ['LCK']);
      expect(vm.selectedLeague, 'LCK');
      vm.selectLeague('LPL');
      expect(vm.selectedLeague, 'LCK');
      expect(vm.standings?.league, 'LCK');
      expect(
        server.requestsTo('standings').map((u) => u.queryParameters['league']),
        ['LCK'],
      );
    });

    test('그룹 펼치기/접기 토글', () {
      final vm = build();
      expect(vm.standingsExpanded, isFalse);
      vm.toggleStandingsExpanded();
      expect(vm.standingsExpanded, isTrue);
      vm.toggleStandingsExpanded();
      expect(vm.standingsExpanded, isFalse);
    });
  });

  group('커뮤니티', () {
    test('기본은 최신순이고 hot 으로 바꾸면 sort=hot 으로 다시 조회한다', () async {
      final vm = build();
      await pumpEventQueue();

      expect(vm.communitySort, HomeCommunitySort.latest);
      final first = server.requestsTo('community/posts').single;
      expect(first.queryParameters['sort'], 'latest');
      expect(first.queryParameters['size'], '4');
      expect(vm.communityPosts.single.title, '글-latest');

      vm.setCommunitySort(HomeCommunitySort.hot);
      await pumpEventQueue();

      final calls = server.requestsTo('community/posts');
      expect(calls.length, 2);
      expect(calls.last.queryParameters['sort'], 'hot');
      expect(calls.last.queryParameters['size'], '4');
      expect(vm.communityPosts.single.title, '글-hot');
    });

    test('평점 탭은 글을 다시 조회하지 않고 ReviewSource 의 한줄평을 보여준다', () async {
      final vm = build();
      await pumpEventQueue();

      vm.setCommunitySort(HomeCommunitySort.review);
      await pumpEventQueue();

      expect(server.requestsTo('community/posts').length, 1);
      expect(vm.reviews, MockReviewSource.reviews);
    });

    test('글 조회가 실패하면 마지막 목록을 유지한다', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.communityPosts.single.title, '글-latest');

      server.communityFails = true;
      vm.setCommunitySort(HomeCommunitySort.hot);
      await pumpEventQueue();

      expect(vm.communityPosts.single.title, '글-latest');
    });
  });

  group('콘텐츠', () {
    test('콘텐츠 기본 탭은 뉴스이고 NewsSource 의 기사를 보여준다', () async {
      final vm = build();
      await pumpEventQueue();
      // 뉴스가 도착하면 기본 탭은 뉴스(도착 전엔 뉴스 탭이 없어 쇼츠로 보인다).
      expect(vm.contentTab, HomeContentTab.news);
      expect(vm.news, MockNewsSource.articles);

      vm.setContentTab(HomeContentTab.shorts);
      expect(vm.contentTab, HomeContentTab.shorts);
    });

    test('쇼츠 전체 필터: 내 선수 → 내 팀 → 나머지 순', () async {
      server.subscriptions = [
        _sub('Faker', 'T1', 'T1'),
        _sub('Chovy', 'GEN', 'Gen.G'),
      ];
      server.shorts = [
        _video('LCK 이주의 베스트 5', channel: 'LCK', views: 10),
        _video('T1 vs HLE 풀경기 요약', channel: 'LCK', views: 20),
        _video('Faker 시즌 최고의 아리', channel: 'T1 Faker', views: 30),
        _video('젠지 브이로그', channel: 'Gen.G Esports', views: 40),
        _video('kt 인터뷰', channel: 'kt rolster', views: 50),
        _video('쵸비 원콤 CHOVY 하이라이트', channel: 'LCK', views: 60),
      ];
      setUpServer(loggedIn: true);
      final vm = build();
      await pumpEventQueue();

      expect(
        server.requestsTo('story/videos').single.queryParameters['sort'],
        'latest',
      );

      final all = vm.shortsFiltered;
      expect(vm.shortsFilter, HomeShortsFilter.all);
      expect(all.map((v) => v.title), [
        'Faker 시즌 최고의 아리',
        '쵸비 원콤 CHOVY 하이라이트',
        'T1 vs HLE 풀경기 요약',
        '젠지 브이로그',
        'LCK 이주의 베스트 5',
        'kt 인터뷰',
      ]);
      expect(all[0].matchedPlayer, 'Faker');
      expect(all[0].teamCode, 'T1');
      expect(all[0].views, 30);
      expect(all[1].matchedPlayer, 'Chovy');
      expect(all[1].teamCode, 'GEN');
      expect(all[2].matchedPlayer, isNull);
      expect(all[2].teamCode, 'T1');
      expect(all[3].teamCode, 'GEN');
      expect(all[4].teamCode, '');

      vm.setShortsFilter(HomeShortsFilter.player);
      expect(vm.shortsFiltered.map((v) => v.matchedPlayer), ['Faker', 'Chovy']);

      // 내 팀 필터는 걸러내기만 한다(정렬 규칙은 전체 필터에만 있다) —
      // 내 선수 영상도 그 선수의 팀이 내 팀이라 함께 남는다.
      vm.setShortsFilter(HomeShortsFilter.team);
      expect(vm.shortsFiltered.map((v) => v.title), [
        'T1 vs HLE 풀경기 요약',
        'Faker 시즌 최고의 아리',
        '젠지 브이로그',
        '쵸비 원콤 CHOVY 하이라이트',
      ]);
    });

    test('구독이 없으면(비회원) 쇼츠 내 선수 필터는 비어 있다', () async {
      server.shorts = [_video('Faker 하이라이트', views: 1)];
      final vm = build();
      await pumpEventQueue();

      expect(vm.shortsFiltered.single.matchedPlayer, isNull);
      vm.setShortsFilter(HomeShortsFilter.player);
      expect(vm.shortsFiltered, isEmpty);
    });
  });

  group('빈 소스(릴리즈 기본값)', () {
    test('뉴스가 비면 뉴스 탭을 빼고 쇼츠가 실제 탭이 된다', () async {
      final vm = build(news: const EmptyNewsSource());
      await pumpEventQueue();
      expect(vm.availableContentTabs, [HomeContentTab.shorts]);
      expect(vm.contentTab, HomeContentTab.shorts);
    });

    test('뉴스가 있으면 뉴스 · 쇼츠 두 탭이고 기본은 뉴스', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.availableContentTabs, [
        HomeContentTab.news,
        HomeContentTab.shorts,
      ]);
      expect(vm.contentTab, HomeContentTab.news);
    });

    test('한줄평이 비면 평점 탭을 빼고, 골라 둔 평점 탭은 최신순으로 돌린다', () async {
      final reviews = _SwitchableReviews(MockReviewSource.reviews);
      final vm = build(reviews: reviews);
      await pumpEventQueue();
      expect(vm.availableCommunitySorts, HomeCommunitySort.values);

      vm.setCommunitySort(HomeCommunitySort.review);
      expect(vm.communitySort, HomeCommunitySort.review);

      reviews.items = const [];
      await vm.refreshAll();
      await pumpEventQueue();
      expect(vm.availableCommunitySorts, [
        HomeCommunitySort.latest,
        HomeCommunitySort.hot,
      ]);
      expect(vm.communitySort, HomeCommunitySort.latest);
      expect(vm.communityPosts.single.title, '글-latest');

      // 빈 상태에서는 평점 탭을 고를 수 없다.
      vm.setCommunitySort(HomeCommunitySort.review);
      expect(vm.communitySort, HomeCommunitySort.latest);
    });

    test('빈 솔랭 소스 + 구독 있음이면 조용한 상태(noneActive)', () async {
      final vm = build(
        snap: await const EmptySoloRankSource().fetch(),
        subscribed: 3,
      );
      await pumpEventQueue();
      expect(vm.soloState, SoloCardState.noneActive);
      expect(vm.soloLive, isEmpty);
      expect(vm.soloFinished, isEmpty);
      expect(vm.soloHiddenCount, 3);
    });
  });

  group('쇼츠 링크', () {
    test('videoUrl 이 있으면 그대로, 없으면 유튜브 쇼츠 주소로 연다', () async {
      server.shorts = [
        {..._video('A'), 'videoUrl': 'https://youtu.be/abc'},
        {..._video('B'), 'youtubeVideoId': 'xyz', 'videoUrl': ''},
      ];
      final vm = build();
      await pumpEventQueue();

      expect(vm.shortsFiltered.map((v) => v.url), [
        'https://youtu.be/abc',
        'https://www.youtube.com/shorts/xyz',
      ]);
    });
  });

  group('알림 배지', () {
    test('비회원이면 미읽음 0 이고 알림 API 를 부르지 않는다', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.unreadNotificationCount, 0);
      expect(server.requestsTo('me/notifications'), isEmpty);
    });

    test('로그인이면 커뮤니티 묶음 미읽음 수를 받는다', () async {
      server.unreadNotifications = 4;
      setUpServer(loggedIn: true);
      final vm = build();
      await pumpEventQueue();

      expect(vm.unreadNotificationCount, 4);
      final req = server.requestsTo('me/notifications').single;
      expect(req.queryParameters['group'], 'COMMUNITY');

      // 알림함에서 읽고 돌아오면 다시 센다.
      server.unreadNotifications = 0;
      await vm.refreshUnreadNotifications();
      expect(vm.unreadNotificationCount, 0);
    });

    test('조회가 실패하면 0 으로 둔다(배지 숨김)', () async {
      server.unreadNotifications = null;
      setUpServer(loggedIn: true);
      final vm = build();
      await pumpEventQueue();
      expect(vm.unreadNotificationCount, 0);
    });
  });

  group('공지 배너', () {
    test('공지가 없으면 배너를 그리지 않는다', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.promotedNotice, isNull);
      expect(vm.bannerVisible, isFalse);
    });
  });

  group('겹치는 로드 — 나중 요청이 이긴다', () {
    setUpAll(() => registerFallbackValue(DateTime(2000)));

    test('오늘 경기: 늦게 도착한 옛 응답이 새 응답을 덮지 않는다', () async {
      final schedule = _MockSchedule();
      final gates = <Completer<List<ScheduleMatch>>>[];
      when(
        () => schedule.fetchMatchesByDate(
          any(),
          leagues: any(named: 'leagues'),
        ),
      ).thenAnswer((_) {
        final c = Completer<List<ScheduleMatch>>();
        gates.add(c);
        return c.future;
      });
      final vm = HomeViewModel(
        schedule: schedule,
        soloRank: _FakeSolo(_emptySolo),
        reviews: const MockReviewSource(),
        news: const MockNewsSource(),
      );
      addTearDown(vm.dispose);
      await pumpEventQueue();
      expect(gates.length, 1); // 생성자의 refreshAll

      final second = vm.loadTodayMatches();
      await pumpEventQueue();
      expect(gates.length, 2);

      // 새 요청이 먼저 끝나고, 옛 요청이 뒤늦게 끝난다.
      gates[1].complete([ScheduleMatch.fromJson(_match('new', 'inProgress'))]);
      await second;
      gates[0].complete([ScheduleMatch.fromJson(_match('old', 'inProgress'))]);
      await pumpEventQueue();

      expect(vm.todayMatchesSorted.map((m) => m.matchId), ['new']);
    });

    test('솔랭: 늦게 도착한 옛 응답이 새 응답을 덮지 않는다', () async {
      final solo = _GatedSolo();
      server.subscriptions = [_sub('Old', 'T1', 'T1'), _sub('New', 'T1', 'T1')];
      setUpServer(loggedIn: true);
      final vm = HomeViewModel(
        soloRank: solo,
        reviews: const MockReviewSource(),
        news: const MockNewsSource(),
      );
      addTearDown(vm.dispose);
      await pumpEventQueue();
      expect(solo.pending.length, 1);

      final second = vm.refreshAll();
      await pumpEventQueue();
      expect(solo.pending.length, 2);

      solo.pending[1].complete(
        SoloRankSnapshot(
          live: [live('New', 10)],
          finished: const [],
          subscribedTotal: 0,
        ),
      );
      await second;
      solo.pending[0].complete(
        SoloRankSnapshot(
          live: [live('Old', 10)],
          finished: const [],
          subscribedTotal: 0,
        ),
      );
      await pumpEventQueue();

      expect(vm.soloLive.map((p) => p.name), ['New']);
    });
  });

  group('앱 복귀 새로고침', () {
    test('마지막 새로고침이 최근이면 건너뛴다', () async {
      final vm = build();
      await pumpEventQueue();
      final before = server.requestsTo('schedule').length;

      await vm.refreshOnResume();
      expect(server.requestsTo('schedule').length, before);
    });

    test('간격이 지났으면 다시 불러온다', () async {
      final vm = build();
      await pumpEventQueue();
      final before = server.requestsTo('schedule').length;

      await vm.refreshOnResume(minInterval: Duration.zero);
      expect(server.requestsTo('schedule').length, before + 1);
    });
  });

  test('refreshAll 은 섹션들을 다시 조회한다', () async {
    final vm = build();
    await pumpEventQueue();
    final before = server.requests.length;

    await vm.refreshAll();

    expect(server.requestsTo('schedule').length, 2);
    expect(server.requestsTo('standings').length, 2);
    expect(server.requestsTo('community/posts').length, 2);
    expect(server.requestsTo('story/videos').length, 2);
    expect(server.requests.length, greaterThan(before));
  });

  test('dispose 뒤에 응답이 도착해도 예외 없이 무시한다', () async {
    final vm = HomeViewModel(
      soloRank: _FakeSolo(_emptySolo),
      reviews: const MockReviewSource(),
      news: const MockNewsSource(),
    );
    vm.dispose();
    await pumpEventQueue();
  });
}
