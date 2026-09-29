import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

import 'package:warding/model/home_models.dart';
import 'package:warding/model/notice.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/repository/subscription/subscription_repository.dart';
import 'package:warding/repository/team/team_logo_directory.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/home/home_viewmodel.dart';
import 'package:warding/viewmodel/my_players/my_players_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

class _FakeSolo implements SoloRankSource {
  _FakeSolo(this.snap);
  final SoloRankSnapshot snap;
  @override
  Future<SoloRankSnapshot> fetch() async => snap;
}

class _MockSchedule extends Mock implements ScheduleRepository {}

class _MockNotices extends Mock implements NoticeRepository {}

class _MockNoticePrefs extends Mock implements NoticePreferenceRepository {}

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

  /// `GET auth/me` 의 응원팀 ID. null 이면 응원팀 없음.
  int? favoriteTeamId;

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
    if (path.endsWith('auth/me')) {
      return _json({'id': 1, 'nickname': 'me#1', 'favoriteTeamId': favoriteTeamId});
    }
    if (path.contains('onboarding/teams')) {
      return _json([
        {'id': 7, 'name': 'T1', 'code': 'T1', 'imageUrl': ''},
        {'id': 8, 'name': 'Gen.G', 'code': 'GEN', 'imageUrl': ''},
      ]);
    }
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
  String teamCode = '',
}) => {
  'videoId': title.hashCode,
  'teamCode': teamCode,
  'youtubeVideoId': 'yt',
  'title': title,
  'videoUrl': '',
  'thumbnailUrl': '',
  'channelName': channel,
  'viewCount': views,
};

const _emptySolo = SoloRankSnapshot(live: [], finished: []);

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
      // 솔랭 항목은 구독한 선수만 보이므로, 스냅샷에 나온 선수를 먼저 구독
      // 목록에 넣고 나머지를 'Sub{i}' 로 채워 [subscribed] 명을 맞춘다.
      final names = <String>{
        for (final p in snap.live) p.name,
        for (final p in snap.finished) p.name,
      }.take(subscribed).toList();
      server.subscriptions = [
        for (final n in names) _sub(n, 'T1', 'T1'),
        for (var i = names.length; i < subscribed; i++)
          _sub('Sub$i', 'T1', 'T1'),
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
    TeamLogoDirectory.instance.resetForTesting();
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

    test('구독은 있는데 진행 중도 끝난 경기도 0명이면 noneActive', () async {
      final vm = build(
        snap: const SoloRankSnapshot(live: [], finished: []),
        subscribed: 5,
      );
      await pumpEventQueue();
      expect(vm.soloState, SoloCardState.noneActive);
      expect(vm.soloLive, isEmpty);
      expect(vm.soloFinished, isEmpty);
    });

    test('진행 중 0명이어도 끝난 경기가 있으면 active(2026-09-29 결정)', () async {
      final vm = build(
        snap: SoloRankSnapshot(live: const [], finished: [done('Oner', 10)]),
        subscribed: 5,
      );
      await pumpEventQueue();
      expect(vm.soloState, SoloCardState.active);
      expect(vm.soloLive, isEmpty);
      expect(vm.soloFinished.map((p) => p.name), ['Oner']);
      expect(vm.soloHiddenCount, 4);
    });

    test('진행 중이 있으면 active, 가장 최근 시작(경과 시간 짧은) 선수가 먼저', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('A', 900), live('B', 100), live('C', 500)],
          finished: const [],
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
        ),
        subscribed: 10,
      );
      await pumpEventQueue();

      expect(vm.soloLive.map((p) => p.name), ['A']);
      expect(vm.soloFinished.map((p) => p.name), ['B']);
      expect(vm.soloHiddenCount, 10 - 1 - 1);
    });

    test('숨김 수는 음수가 되지 않는다 — 구독 안 한 선수는 세지 않는다', () async {
      final vm = build(
        snap: SoloRankSnapshot(
          live: [live('A', 60), live('B', 30)],
          finished: [done('C', 3)],
        ),
        subscribed: 1, // A 만 구독
      );
      await pumpEventQueue();
      expect(vm.soloLive.map((p) => p.name), ['A']);
      expect(vm.soloFinished, isEmpty);
      expect(vm.soloHiddenCount, 0);
    });

    test('로그인 상태면 구독 수는 소스 값이 아니라 실제 구독 목록 길이', () async {
      server.subscriptions = [
        _sub('Faker', 'T1', 'T1'),
        _sub('Chovy', 'GEN', 'Gen.G'),
      ];
      setUpServer(loggedIn: true);
      final vm = build(
        snap: const SoloRankSnapshot(live: [], finished: []),
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
        snap: const SoloRankSnapshot(live: [], finished: []),
      );
      await pumpEventQueue();
      expect(vm.subscribedTotal, 0);
      expect(vm.soloState, SoloCardState.noSubscription);
    });
  });

  group('솔랭 항목은 실제 구독과 대조한다', () {
    PlayerSubscription subOf(String name) => PlayerSubscription(
      playerId: name.hashCode,
      playerName: name,
      playerImageUrl: '',
      role: 'MID',
      teamId: 1,
      teamCode: 'T1',
      teamName: 'T1',
      teamImageUrl: '',
      subscribed: true,
      startEnabled: true,
      endEnabled: true,
    );

    final fixture = SoloRankSnapshot(
      live: [live('Faker', 300), live('Chovy', 100), live('Zeus', 50)],
      finished: [
        done('Oner', 12),
        done('Canyon', 40),
        done('Faker', 90),
        done('Oner', 200),
        done('Ruler', 5),
      ],
    );
    final subs = [
      for (final n in ['Faker', 'Chovy', 'Oner', 'Canyon', 'Keria']) subOf(n),
    ];

    test('구독하지 않은 선수의 솔랭은 홈에 나오지 않는다', () async {
      final repo = MockSubscriptionRepository();
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => subs);
      final vm = HomeViewModel(
        subscriptions: repo,
        soloRank: _FakeSolo(fixture),
        reviews: const MockReviewSource(),
        news: const MockNewsSource(),
      );
      addTearDown(vm.dispose);
      await pumpEventQueue();

      expect(vm.soloLive.map((p) => p.name), ['Chovy', 'Faker']);
      expect(vm.soloFinished.map((p) => p.name), ['Oner', 'Canyon']);
      expect(vm.soloHiddenCount, 5 - 2 - 2);
    });

    test('홈과 내 선수 화면이 같은 fixture 에서 같은 결과를 낸다', () async {
      final repo = MockSubscriptionRepository();
      when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => subs);
      final home = HomeViewModel(
        subscriptions: repo,
        soloRank: _FakeSolo(fixture),
        reviews: const MockReviewSource(),
        news: const MockNewsSource(),
      );
      addTearDown(home.dispose);
      final mine = MyPlayersViewModel(
        subscriptions: repo,
        soloRank: _FakeSolo(fixture),
      );
      addTearDown(mine.dispose);
      await pumpEventQueue();

      expect(home.soloLive.map((p) => p.name), [
        for (final e in mine.liveSolo) e.player.playerName,
      ]);
      expect(home.soloFinished.map((p) => p.name), [
        for (final e in mine.playedToday) e.player.playerName,
      ]);
      expect(home.soloHiddenCount, mine.quiet.length);
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
      // 기본 정렬이 평점 한줄평이라(2026-09-29 결정) 글 목록 대신 리뷰로 확인한다.
      expect(vm.communitySort, HomeCommunitySort.review);
      expect(vm.reviews, isNotEmpty);
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
    test('기본은 평점 한줄평이고 글을 조회하지 않는다', () async {
      final vm = build();
      await pumpEventQueue();

      expect(vm.communitySort, HomeCommunitySort.review);
      expect(server.requestsTo('community/posts'), isEmpty);
      expect(vm.reviews, MockReviewSource.reviews);
    });

    test('최신순으로 바꾸면 그때 처음 조회한다', () async {
      final vm = build();
      await pumpEventQueue();

      vm.setCommunitySort(HomeCommunitySort.latest);
      await pumpEventQueue();

      final calls = server.requestsTo('community/posts');
      expect(calls.length, 1);
      expect(calls.single.queryParameters['sort'], 'latest');
      expect(calls.single.queryParameters['size'], '4');
      expect(vm.communityPosts.single.title, '글-latest');

      vm.setCommunitySort(HomeCommunitySort.review);
      await pumpEventQueue();
      expect(server.requestsTo('community/posts').length, 1);

      vm.setCommunitySort(HomeCommunitySort.latest);
      await pumpEventQueue();

      final after = server.requestsTo('community/posts');
      expect(after.length, 2);
      expect(after.last.queryParameters['sort'], 'latest');
    });

    test('인기순은 칩에 없고 고를 수도 없다', () async {
      final vm = build();
      await pumpEventQueue();

      expect(
        vm.availableCommunitySorts,
        isNot(contains(HomeCommunitySort.hot)),
      );
      vm.setCommunitySort(HomeCommunitySort.hot);
      expect(vm.communitySort, HomeCommunitySort.review);
    });

    test('평점 탭은 글을 조회하지 않고 ReviewSource 의 한줄평을 보여준다', () async {
      final vm = build();
      await pumpEventQueue();

      expect(vm.communitySort, HomeCommunitySort.review);
      expect(server.requestsTo('community/posts'), isEmpty);
      expect(vm.reviews, MockReviewSource.reviews);
    });

    test('글 조회가 실패하면 마지막 목록을 유지한다', () async {
      final vm = build();
      await pumpEventQueue();

      vm.setCommunitySort(HomeCommunitySort.latest);
      await pumpEventQueue();
      expect(vm.communityPosts.single.title, '글-latest');

      vm.setCommunitySort(HomeCommunitySort.review);
      server.communityFails = true;
      vm.setCommunitySort(HomeCommunitySort.latest);
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

    test('쇼츠 전체 필터: 서버 순서(최신순) 그대로, 카드는 10개까지', () async {
      server.shorts = [
        for (var i = 0; i < 12; i++)
          _video('영상 $i', teamCode: i.isEven ? 'T1' : ''),
      ];
      final vm = build();
      await pumpEventQueue();

      final req = server.requestsTo('story/videos').single.queryParameters;
      expect(req['sort'], 'latest');
      expect(req['size'], '10');
      expect(req.containsKey('teamCode'), isFalse);

      expect(vm.shortsFilter, HomeShortsFilter.all);
      expect(vm.shortsFiltered.map((v) => v.title), [
        for (var i = 0; i < 10; i++) '영상 $i',
      ]);
      expect(vm.shortsFiltered.first.teamCode, 'T1');
    });

    test('내 팀 필터는 응원팀 채널만 — 서버 teamCode 로 받고 LCK 는 뺀다', () async {
      server.favoriteTeamId = 7;
      server.shorts = [
        _video('LCK 이주의 베스트 5', teamCode: ''),
        _video('T1 하이라이트', teamCode: 'T1'),
        _video('젠지 브이로그', teamCode: 'GEN'),
      ];
      setUpServer(loggedIn: true);
      AuthService.instance.resetMeCacheForTesting();
      final vm = build();
      await pumpEventQueue();

      vm.setShortsFilter(HomeShortsFilter.team);
      await pumpEventQueue();

      final req = server.requestsTo('story/videos').last.queryParameters;
      expect(req['teamCode'], 'T1');
      expect(vm.hasPreferredTeam, isTrue);
      expect(vm.shortsFiltered.map((v) => v.title), ['T1 하이라이트']);

      // 전체로 돌아오면 LCK·다른 팀도 다시 나온다.
      vm.setShortsFilter(HomeShortsFilter.all);
      await pumpEventQueue();
      expect(vm.shortsFiltered.length, 3);
    });

    test('응원팀이 없으면 내 팀 필터는 요청 없이 빈 목록', () async {
      server.favoriteTeamId = null;
      server.shorts = [_video('T1 하이라이트', teamCode: 'T1')];
      setUpServer(loggedIn: true);
      AuthService.instance.resetMeCacheForTesting();
      final vm = build();
      await pumpEventQueue();
      final before = server.requestsTo('story/videos').length;

      vm.setShortsFilter(HomeShortsFilter.team);
      await pumpEventQueue();

      expect(vm.hasPreferredTeam, isFalse);
      expect(vm.shortsFiltered, isEmpty);
      expect(server.requestsTo('story/videos').length, before);
    });

    test('세로 썸네일 주소는 영상 ID 로 만든다', () async {
      server.shorts = [_video('A')];
      final vm = build();
      await pumpEventQueue();

      expect(
        vm.shortsFiltered.single.verticalThumbnailUrl,
        'https://i.ytimg.com/vi/yt/oardefault.jpg',
      );
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
      expect(vm.availableCommunitySorts, [
        HomeCommunitySort.latest,
        HomeCommunitySort.review,
      ]);

      vm.setCommunitySort(HomeCommunitySort.review);
      expect(vm.communitySort, HomeCommunitySort.review);

      reviews.items = const [];
      await vm.refreshAll();
      await pumpEventQueue();
      expect(vm.availableCommunitySorts, [HomeCommunitySort.latest]);
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

    test('조회 중에 닫은 배너는 옛 닫음 목록 응답이 와도 다시 뜨지 않는다', () async {
      const notice = Notice(id: 7, title: '점검 안내', content: '', pinned: false);
      final notices = _MockNotices();
      final prefs = _MockNoticePrefs();
      final fetch = Completer<List<Notice>>();
      when(() => notices.cachedPromoted).thenReturn(const [notice]);
      when(() => notices.fetchPromoted()).thenAnswer((_) => fetch.future);
      when(() => prefs.cachedValue).thenReturn(null);
      // 닫기 전에 읽힌(=7 이 없는) 목록을 돌려준다.
      when(() => prefs.loadDismissedIds()).thenAnswer((_) async => <int>{});
      when(() => prefs.addDismissedId(any())).thenAnswer((_) async {});

      final vm = HomeViewModel(
        notices: notices,
        noticePreferences: prefs,
        soloRank: _FakeSolo(_emptySolo),
        reviews: const MockReviewSource(),
        news: const MockNewsSource(),
      );
      addTearDown(vm.dispose);
      expect(vm.promotedNotice?.id, 7);

      vm.dismissBanner();
      expect(vm.bannerVisible, isFalse);

      fetch.complete(const [notice]);
      await pumpEventQueue();
      expect(vm.bannerVisible, isFalse);
    });
  });

  group('겹치는 로드 — 나중 요청이 이긴다', () {
    setUpAll(() => registerFallbackValue(DateTime(2000)));

    test('오늘 경기: 늦게 도착한 옛 응답이 새 응답을 덮지 않는다', () async {
      final schedule = _MockSchedule();
      final gates = <Completer<List<ScheduleMatch>>>[];
      when(
        () =>
            schedule.fetchMatchesByDate(any(), leagues: any(named: 'leagues')),
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
        SoloRankSnapshot(live: [live('New', 10)], finished: const []),
      );
      await second;
      solo.pending[0].complete(
        SoloRankSnapshot(live: [live('Old', 10)], finished: const []),
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
    // 기본 정렬이 평점 한줄평이라(2026-09-29 결정) 글 목록은 조회하지 않는다.
    expect(vm.communitySort, HomeCommunitySort.review);
    expect(server.requestsTo('community/posts').length, 0);
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
