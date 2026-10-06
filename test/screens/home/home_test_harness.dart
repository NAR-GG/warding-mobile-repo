import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/repository/subscription/subscription_repository.dart';
import 'package:warding/repository/team/team_logo_directory.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import '../../support/l10n_test_setup.dart';

/// 홈 섹션 위젯 테스트 공용 준비물.
///
/// 섹션은 진짜 [HomeViewModel] 을 구독한다. 뷰모델이 부르는 API 는
/// [HomeFakeApi] 가 경로별로 대답하고, 백엔드에 아직 없는 소스(솔랭·평점·뉴스)는
/// 주입한 가짜/목업 소스를 쓴다 — 뷰모델 테스트와 같은 방식이다.

class FakeSoloSource implements SoloRankSource {
  FakeSoloSource(this.snap);
  final SoloRankSnapshot snap;
  @override
  Future<SoloRankSnapshot> fetch() async => snap;
}

class HomeFakeApi {
  /// 구독 선수 응답. 로그인 상태에서만 불린다.
  List<Map<String, dynamic>> subscriptions = const [];

  /// 쇼츠 응답(`content`).
  List<Map<String, dynamic>> shorts = const [];

  /// 순위표 행 — 레전드 그룹 하나.
  List<Map<String, dynamic>> standingsRows = [
    standingRow(1, 'GEN', '젠지', 19, 7, 22),
    standingRow(2, 'HLE', '한화생명e스포츠', 18, 8, 17),
  ];

  /// 순위표 그룹 전체를 직접 지정한다. null 이면 [standingsRows] 로 레전드
  /// 그룹 하나만 내려준다 — 그룹이 둘 이상인 리그(LCK 레전드·라이즈,
  /// ASIAN_GAMES 그룹 스테이지)의 "더보기" 라벨을 검증할 때 쓴다.
  List<Map<String, dynamic>>? standingsGroups;

  /// 리그 코드 → `bracket` 응답. 여기 담긴 리그는 `supported: false` +
  /// `reason: "BRACKET_ONLY"` 로 내려가 앱이 대진 카드를 그려야 한다.
  /// 리그 코드와 무관하게 응답만으로 분기하는지 확인할 때 쓴다.
  Map<String, Map<String, dynamic>> standingsBracketLeagues = {};

  /// `/mobile/schedules/filters` 의 리그 메타(`LeagueOption`). null 이면
  /// 메타 없는 구버전 응답이라 앱이 하드코딩 폴백 칩을 쓴다.
  List<Map<String, dynamic>>? leagueMeta;

  /// 오늘 경기 응답. 기본 T1 vs Gen.G 진행 중 1건.
  List<Map<String, dynamic>> matches = [
    {
      'matchId': 'm1',
      'scheduledTime': '17:00',
      'leagueName': 'LCK',
      'matchTitle': '정규시즌',
      'matchStatus': 'inProgress',
      'isSynced': true,
      'blueTeam': {'teamName': 'T1', 'teamCode': 'T1', 'teamImageUrl': ''},
      'redTeam': {'teamName': 'Gen.G', 'teamCode': 'GEN', 'teamImageUrl': ''},
    },
  ];

  final List<Uri> requests = [];

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
      // 리그 메타(`alarm` 필드)를 담아 주면 앱이 서버 값으로 칩을 만든다.
      // 비워 두면 `hasLeagueMeta: false` 라 하드코딩 폴백 칩이 쓰인다.
      if (path.contains('filters') && leagueMeta != null) {
        return _json({'leagues': leagueMeta});
      }
      return _json({'matches': matches});
    }
    if (path.contains('standings')) {
      final league = url.queryParameters['league'];
      // 대진 포맷으로 둔 리그는 BRACKET_ONLY + bracket 을 준다.
      if (standingsBracketLeagues.containsKey(league)) {
        return _json({
          'league': league,
          'supported': false,
          'reason': 'BRACKET_ONLY',
          'scopeLabel': '녹아웃 스테이지',
          'groups': const [],
          'bracket': standingsBracketLeagues[league],
        });
      }
      return _json({
        'league': league,
        'supported': true,
        'scopeLabel': '정규시즌',
        'groups':
            standingsGroups ??
            [
              {'name': '레전드 그룹', 'rows': standingsRows},
            ],
      });
    }
    if (path.contains('community/posts')) {
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
    // TeamLogoDirectory 가 HomeViewModel 생성 시 항상 부른다(팀 로고 프리페치).
    // 이 하네스는 팀 로고 자체를 검증하지 않으므로 빈 목록으로 조용히 채운다.
    if (path.contains('onboarding/teams')) return _json(const []);
    if (path.contains('player-subscriptions')) return _json(subscriptions);
    if (path.contains('me/notifications')) {
      return _json({'notifications': const [], 'unreadCount': 0});
    }
    return _json({'message': 'unexpected $url'}, 500);
  });
}

Map<String, dynamic> standingRow(
  int rank,
  String code,
  String name,
  int wins,
  int losses,
  int setDiff,
) => {
  'rank': rank,
  'teamCode': code,
  'teamName': name,
  'wins': wins,
  'losses': losses,
  'setDiff': setDiff,
};

Map<String, dynamic> subscriptionJson(String name, String teamCode) => {
  'playerId': name.hashCode,
  'playerName': name,
  'playerImageUrl': '',
  'role': 'MID',
  'teamId': teamCode.hashCode,
  'teamCode': teamCode,
  'teamName': teamCode,
  'teamImageUrl': '',
  'subscribed': true,
};

Map<String, dynamic> shortsJson(String title, {String channel = ''}) => {
  'videoId': title.hashCode,
  'youtubeVideoId': 'yt${title.hashCode}',
  'title': title,
  'videoUrl': '',
  'thumbnailUrl': '',
  'channelName': channel,
  'viewCount': 12000,
};

const emptySolo = SoloRankSnapshot(live: [], finished: []);

/// 테스트마다 부르는 준비 — 캐시를 비우고 가짜 서버를 꽂는다.
HomeFakeApi setUpHomeApi({bool loggedIn = false}) {
  final server = HomeFakeApi();
  FlutterSecureStorage.setMockInitialValues(
    loggedIn ? {'jwt': 'test-jwt'} : {},
  );
  AuthService.instance.resetJwtCacheForTesting();
  NoticeRepository.instance.resetPromotedCacheForTesting();
  NoticePreferenceRepository.instance.resetCacheForTesting();
  SubscriptionRepository.instance.resetCacheForTesting();
  ScheduleRepository.instance.resetCacheForTesting();
  TeamLogoDirectory.instance.resetForTesting();
  api.setApiClientForTesting(server.client);
  addTearDown(() => api.setApiClientForTesting(null));
  return server;
}

/// 뷰모델을 만들고 모든 섹션 로드가 끝날 때까지 기다린 뒤 [section] 을 띄운다.
Future<HomeViewModel> pumpHomeSection(
  WidgetTester tester, {
  required Widget Function(HomeViewModel vm) section,
  SoloRankSnapshot solo = emptySolo,
  ReviewSource reviews = const MockReviewSource(),
  NewsSource news = const MockNewsSource(),
}) async {
  late HomeViewModel vm;
  await tester.runAsync(() async {
    vm = HomeViewModel(
      soloRank: FakeSoloSource(solo),
      reviews: reviews,
      news: news,
    );
    // 생성자가 띄운 로드와 별개로 한 번 더 기다려 결과가 확실히 반영되게 한다.
    await vm.refreshAll();
  });
  addTearDown(vm.dispose);

  // 기준 폭 375, 섹션 하나가 통째로 들어가는 높이 — 아래쪽 칩도 탭할 수 있게.
  tester.view.physicalSize = const Size(375, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    wrapWithL10n(
      SingleChildScrollView(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => section(vm),
        ),
      ),
    ),
  );
  await tester.pump();
  return vm;
}

HomeLiveSoloPlayer livePlayer(String name, int elapsedSeconds) =>
    HomeLiveSoloPlayer(
      name: name,
      teamCode: 'GEN',
      // 빈 챔피언 = 스플래시 아트 없음. 테스트에서 네트워크 이미지를 띄우지 않는다.
      champion: '',
      elapsedSeconds: elapsedSeconds,
    );

HomeFinishedSoloPlayer finishedPlayer(
  String name,
  int minutesAgo, {
  bool won = true,
  int? durationMinutes,
}) => HomeFinishedSoloPlayer(
  name: name,
  teamCode: 'GEN',
  won: won,
  minutesAgo: minutesAgo,
  durationMinutes: durationMinutes,
);
